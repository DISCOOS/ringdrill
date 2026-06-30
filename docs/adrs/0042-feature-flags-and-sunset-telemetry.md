---
status: proposed
date: 2026-06-29
deciders: ["@kengu"]
consulted: []
informed: []
---

# ADR-0042: Centralise build-time feature flags with sunset telemetry

## Context and problem statement

ADR-0039 introduced a build-time kill switch `MIGRATION_DISABLED` so Phase 1 of the migration could ship to apex without lighting up the migration UI before Phase 2 was ready. That joined two existing dart-define flags: `RINGDRILL_LOCAL_BASE_URL` (debug local-backend override, ADR-0013) and `RINGDRILL_FORCE_LEGACY_HOST` (dev-only banner override).

Three flags is small, but the pattern is now established. Without conventions in place we end up with ad-hoc flags scattered across `app_config.dart`, `legacy_host_web.dart` and future files, no way to know which flags are active in a given build, and no signal to tell us when legacy code paths gated by a flag can finally be deleted. The `MIGRATION_DISABLED` flag specifically must be removable when the legacy apex PWA is no longer in active use, and we need a concrete signal to know when that moment has arrived.

The decision is about how much operational scaffolding we put around build-time flags before they grow further, and how we collect signals to retire them.

## Decision drivers

* The project is small (one developer, few users). Any operational machinery must be cheap to maintain.
* All current flags are compile-time `dart-define` values. A runtime flag system requires a service, consent gating (ADR-0006), client cache, fallback logic. More complexity than is justified today.
* We need to know when legacy code paths can be retired safely. For the migration this is concrete: when the legacy apex PWA has 0 active sessions over a sustained period, we can delete the migration UI, the kill switch and the `/migrate` fallback.
* Sentry is already wired up behind the analytics consent gate (ADR-0006). It can carry tags on every event and on sessions for free.
* Contributors need to know which flags exist, what they do and when they can be retired.

## Considered options

* Option A: Centralised compile-time registry + Sentry tagging + living docs index (chosen). Three small lifts: a single Dart class that gathers all flag accessors, Sentry scope tags set at boot, a `docs/feature-flags.md` index with per-flag lifecycle.
* Option B: Status quo. Each flag declared where it is used, no central index, no telemetry. Easiest right now, but means the migration kill switch lives without a retirement signal and we cannot tell from outside the codebase how many users are still on legacy paths.
* Option C: Runtime feature flag service. A Netlify function returns flag state, the client caches it. Lets us flip flags without a redeploy. Adds: a flag service, a cache, consent gating for the fetch (per ADR-0006), fallback when the service is unreachable. Too much machinery for our scale.
* Option D: A/B testing infrastructure. Experiment framework, cohort assignment, variant telemetry. Requires significantly more user base than we have to be useful. Out of scope.

## Decision outcome

Chosen option: **A (centralised registry + Sentry tagging + living docs)**.

A wins because it is cheap to introduce, integrates with infrastructure we already have (`bool.fromEnvironment`, Sentry), and gives us a concrete sunset signal for the migration kill switch. B leaves us blind. C and D add complexity that does not pay off at our scale yet; both are kept as future options if usage demands it.

### Central registry

A new file `lib/utils/app_flags.dart` exports a single `AppFlags` class that holds compile-time constants for every active flag and a `Map<String, Object> all` accessor for debugging.

```dart
class AppFlags {
  static const migrationDisabled =
      bool.fromEnvironment('MIGRATION_DISABLED');
  static const forceLegacyHost =
      bool.fromEnvironment('RINGDRILL_FORCE_LEGACY_HOST');
  static const localBaseUrl =
      String.fromEnvironment('RINGDRILL_LOCAL_BASE_URL');

  static Map<String, Object> get all => {
    'MIGRATION_DISABLED': migrationDisabled,
    'RINGDRILL_FORCE_LEGACY_HOST': forceLegacyHost,
    'RINGDRILL_LOCAL_BASE_URL': localBaseUrl,
  };
}
```

Existing references in `lib/web/legacy_host_web.dart` and `lib/utils/app_config.dart` keep `bool.fromEnvironment` declarations where compile-time `const` is required, but `AppFlags` becomes the single source of truth for debugging and for the index.

### Sentry tagging at boot

After Sentry is initialised in `main.dart`, configure scope with tags for every flag and for the runtime origin:

```dart
Sentry.configureScope((scope) {
  AppFlags.all.forEach((k, v) => scope.setTag('flag.$k', v.toString()));
  scope.setTag('app.origin', kIsWeb ? Uri.base.host : 'native');
  scope.setTag('app.legacy_apex', isLegacyHost().toString());
});
```

Every captured event carries these tags. Sentry queries become "events where `app.legacy_apex=true`" or "events where `flag.MIGRATION_DISABLED=false`". The tags also flow onto Sentry sessions when session tracking is on, which is what we want for sunset telemetry — counting active sessions per tag value over time.

### Sunset telemetry

When the app boots and `isLegacyHost()` returns true, the app emits an info-level Sentry event once per session with message `boot on legacy apex`. The event carries the relevant tags. Combined with Sentry sessions, this gives a queryable signal over time: "how many sessions in the last 30 days came from the legacy apex". When that number falls toward zero and stays there for a defined window, the kill switch and the migration code paths can be retired.

Sunset criterion for the migration UI: 0 legacy-apex sessions over 30 consecutive days after the Phase 3 cutover lands. At that point ADR-0039's migration code, the `/migrate` page, the `MIGRATION_DISABLED` flag and all related ARB strings can be deleted in a single sane-up commit.

### About page surfacing

When any flag in `AppFlags.all` has a non-default value (i.e. is explicitly set at build time), the About page renders a small "Build flags" section listing each active flag. Helps developers and users identify what a specific build is running with, especially in bug reports.

### Living documentation

A new `docs/feature-flags.md` is the canonical index of all build-time flags. Per flag the table lists:

* name (the dart-define key)
* type (`bool` / `String`)
* kind (`Permanent` or `Temporary`)
* default
* purpose (one sentence)
* introduced by (commit or ADR)
* sunset criterion (when can it be deleted, mandatory for `Temporary`, dash for `Permanent`)

`Temporary` is the default. A flag is `Permanent` only when it gates infrastructure that has no end date, such as a dev-only escape hatch or a local-override hook documented in another ADR. Every `Temporary` flag carries a concrete sunset criterion. Removing a flag is a code change like any other and updates this file in the same commit.

The doc is updated in the same commit as a flag is introduced, modified or deleted. Treated as part of the change, not an afterthought.

### Naming convention

For new flags going forward, use one of two prefixes:

* `RINGDRILL_` for environment or developer overrides that are not part of normal product behaviour (`RINGDRILL_LOCAL_BASE_URL`, `RINGDRILL_FORCE_LEGACY_HOST`).
* No prefix for kill switches and feature toggles that gate product behaviour in production (`MIGRATION_DISABLED`).

Existing flags are not renamed. Consistency applies to new flags only.

### Out of scope

* Runtime flag service. Reserved as a future ADR if scale demands.
* A/B testing infrastructure.
* Renaming existing flags to fit any new naming convention.
* Removing the existing kill switch. That happens against the sunset criterion above.

### Consequences

* Good: Every flag is discoverable in one place (`AppFlags` and `docs/feature-flags.md`).
* Good: Sentry events and sessions carry flag state, so bug reports tied to specific flag values are filterable.
* Good: Sunset telemetry gives a concrete signal for retiring legacy code paths. Specifically lets us know when the migration UI can be deleted.
* Good: About page exposes active flags to users and developers without forcing them into devtools.
* Bad: A small but real addition of code that must stay in sync (`AppFlags.all` and the docs file).
* Bad: Sentry tagging fires for every event including routine user actions. Cardinality is bounded (three flags × a small set of values) so tag-budget exhaustion is not a concern, but worth noting.
* Bad: Compile-time flags still require redeploy to flip. Fine for our cadence; for emergencies it is not. Acceptable trade-off until a runtime service is justified.

## Pros and cons of the options

### Option A: Centralised registry + Sentry tagging + docs index (chosen)
* Good: Cheap. Three small concrete deliverables.
* Good: Builds on infrastructure that already exists (Sentry).
* Bad: Adds a place that must stay in sync as flags change.

### Option B: Status quo
* Good: No work needed.
* Bad: No retirement signal for legacy code. No discoverability.

### Option C: Runtime feature flag service
* Good: Flip flags without redeploy.
* Bad: Service + cache + consent gating + fallback. Several weeks of work for value we do not need yet.

### Option D: A/B testing
* Good: Run experiments.
* Bad: Requires significantly larger user base than RingDrill has.

## Links

* Related ADRs: [ADR-0006](./0006-sentry-behind-consent-gate.md) (Sentry behind consent gate), [ADR-0013](./0013-local-catalog-testing.md) (local catalog testing escape hatch), [ADR-0039](./0039-site-pwa-api-origins.md) (site/PWA/API origin split; introduced `MIGRATION_DISABLED`)
* Related code: `lib/utils/app_config.dart`, `lib/web/legacy_host_web.dart`, `lib/main.dart`, `lib/views/about_page.dart`
* Future ADRs deferred: runtime feature flag service (if scale demands), A/B testing infrastructure
