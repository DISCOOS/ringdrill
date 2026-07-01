---
status: accepted
date: 2026-06-29
deciders: ["@kengu"]
consulted: []
informed: []
---

# ADR-0042: Centralise build-time feature flags with sunset telemetry

## Context and problem statement

ADR-0039 introduced a build-time feature flag `MIGRATION_DISABLED` so Phase 1 of the migration could ship to apex without lighting up the migration UI before Phase 2 was ready. That joined two existing dart-define flags: `RINGDRILL_LOCAL_BASE_URL` (debug local-backend override, ADR-0013) and `RINGDRILL_FORCE_LEGACY_HOST` (dev-only banner override).

Three flags is small, but the pattern is now established. Without conventions in place we end up with ad-hoc flags scattered across `app_config.dart`, `legacy_host_web.dart` and future files, no way to know which flags are active in a given build, and no signal to tell us when legacy code paths gated by a flag can finally be deleted. The `MIGRATION_DISABLED` flag specifically must be removable when the legacy apex PWA is no longer in active use, and we need a concrete signal to know when that moment has arrived.

The decision is about how much operational scaffolding we put around build-time flags before they grow further, and how we collect signals to retire them.

## Decision drivers

* The project is small (one developer, few users). Any operational machinery must be cheap to maintain.
* All current flags are compile-time `dart-define` values. A runtime flag system requires a service, consent gating (ADR-0006), client cache, fallback logic. More complexity than is justified today.
* We need to know when legacy code paths can be retired safely. For the migration this is concrete: when the legacy apex PWA has 0 active sessions over a sustained period, we can delete the migration UI, the feature flag and the `/migrate` fallback.
* Sentry is already wired up behind the analytics consent gate (ADR-0006). It can carry tags on every event and on sessions for free.
* Contributors need to know which flags exist, what they do and when they can be retired.

## Considered options

* Option A: Centralised compile-time registry + Sentry tagging + living docs index (chosen). Three small lifts: a single Dart class that gathers all flag accessors, Sentry scope tags set at boot, a `docs/feature-flags.md` index with per-flag lifecycle.
* Option B: Status quo. Each flag declared where it is used, no central index, no telemetry. Easiest right now, but means the migration feature flag lives without a retirement signal and we cannot tell from outside the codebase how many users are still on legacy paths.
* Option C: Runtime feature flag service. A Netlify function returns flag state, the client caches it. Lets us flip flags without a redeploy. Adds: a flag service, a cache, consent gating for the fetch (per ADR-0006), fallback when the service is unreachable. Too much machinery for our scale.
* Option D: A/B testing infrastructure. Experiment framework, cohort assignment, variant telemetry. Requires significantly more user base than we have to be useful. Out of scope.

## Decision outcome

Chosen option: **A (centralised registry + Sentry tagging + living docs)**.

A wins because it is cheap to introduce, integrates with infrastructure we already have (`bool.fromEnvironment`, Sentry), and gives us a concrete sunset signal for the migration feature flag. B leaves us blind. C and D add complexity that does not pay off at our scale yet; both are kept as future options if usage demands it.

### Central registry

A new file `lib/utils/app_flags.dart` exports an `AppFlags` class plus an `AppFlagInfo` data class. Each flag has a structured entry carrying its compile-time value, its lifecycle kind, and a short developer-facing description. The list of entries (`AppFlags.all`) is the single source of truth for in-app debugging surfaces and for keeping `docs/feature-flags.md` honest.

```dart
enum AppFlagKind { permanent, temporary }

class AppFlagInfo {
  const AppFlagInfo({
    required this.name,
    required this.value,
    required this.kind,
    required this.description,
  });

  final String name;
  final Object value;
  final AppFlagKind kind;
  final String description;

  bool get isDefault =>
      (value is bool && value == false) ||
      (value is String && (value as String).isEmpty) ||
      (value is num && value == 0);
}

class AppFlags {
  static const migrationDisabled =
      bool.fromEnvironment('MIGRATION_DISABLED');
  static const forceLegacyHost =
      bool.fromEnvironment('RINGDRILL_FORCE_LEGACY_HOST');
  static const localBaseUrl =
      String.fromEnvironment('RINGDRILL_LOCAL_BASE_URL');

  static const List<AppFlagInfo> all = [
    AppFlagInfo(
      name: 'MIGRATION_DISABLED',
      value: migrationDisabled,
      kind: AppFlagKind.temporary,
      description: 'Feature flag hiding the in-app migration UI before web.ringdrill.app is live.',
    ),
    AppFlagInfo(
      name: 'RINGDRILL_FORCE_LEGACY_HOST',
      value: forceLegacyHost,
      kind: AppFlagKind.temporary,
      description: 'Dev override that makes isLegacyHost() return true regardless of actual host.',
    ),
    AppFlagInfo(
      name: 'RINGDRILL_LOCAL_BASE_URL',
      value: localBaseUrl,
      kind: AppFlagKind.permanent,
      description: 'Points the catalog client at a local netlify dev instance.',
    ),
  ];

  static Iterable<AppFlagInfo> get activeOnly =>
      all.where((f) => !f.isDefault);
}
```

Existing references in `lib/web/legacy_host_web.dart` and `lib/utils/app_config.dart` keep `bool.fromEnvironment` declarations where compile-time `const` is required, and consume `AppFlags.X` (the bare value constant) where they previously had their own private constant.

The Sentry-tagging code iterates `AppFlags.all` and tags each entry's `name` and `value`. Description and kind stay client-side only — they exist to help developers reading the About page, not Sentry queries.

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

When the app boots and `isLegacyHost()` returns true, the app emits an info-level Sentry event once per session with message `boot on legacy apex`. The event carries the relevant tags. Combined with Sentry sessions, this gives a queryable signal over time: "how many sessions in the last 30 days came from the legacy apex". When that number falls toward zero and stays there for a defined window, the feature flag and the migration code paths can be retired.

Sunset criterion for the migration UI: 0 legacy-apex sessions over 30 consecutive days after the Phase 3 cutover lands. At that point ADR-0039's migration code, the `MigrationBanner`, the `LegacyBadge` and its `migrationBannerForceShowTick` notifier (see [Persistent legacy marker](#persistent-legacy-marker)), the `/migrate` page, the `MIGRATION_DISABLED` flag and all related ARB strings can be deleted in a single clean-up commit.

### About page surfacing

In debug builds, when `AppFlags.activeOnly` is non-empty, the About page renders a "Developer info" section listing each active flag as a `ListTile` row:

* `title`: the flag name, e.g. `MIGRATION_DISABLED`, in the same style as other About titles.
* `subtitle`: a small two-line block. First line is the current value (`true`, `false`, the string), second line is the short developer description from `AppFlagInfo.description`.
* `trailing`: a compact `Chip` reading `Temporary` or `Permanent` (from `AppFlagInfo.kind`). Gives the lifecycle at a glance without taking subtitle space.

The section heading is "Developer info" / "Utviklerinformasjon", framed broadly so future debug items (device info, feature toggles, dev tools) can slot in alongside build flags without another rename.

**Localization split:** UI chrome is localized so the section fits the surrounding About page in the current app language. This means the section heading and the `Temporary` / `Permanent` chip label go through ARB (`developerInfoSectionTitle`, `buildFlagKindTemporary`, `buildFlagKindPermanent`). Flag data stays English: flag names are the dart-define keys themselves and would be misleading if translated; values are raw data; descriptions live next to the flag definition in `AppFlags` as code documentation and are written for developers reading the code, not localized end users.

Release builds do not render the section regardless of flag state. Production users have no use for this information, and Sentry tags already carry the flag state for any bug report we receive from production. Keeping the section debug-only avoids both UI clutter and a low-value support question vector.

### Persistent legacy marker

ADR-0039's `MigrationBanner` is a dismissable call-to-action. It carries the export and "open the new app" actions, and it stays out of the way for 24 hours after the user dismisses it. That serves the action, but it leaves a gap: a user on the legacy apex PWA who dismissed the banner has no standing reminder that they are on the old surface, and no quick way back to the migration actions until the banner re-arms.

A separate persistent marker fills that gap. Unlike the "Build flags" section above, this one is **release-visible** — the legacy users it addresses are production users, not developers. A new `LegacyBadge` widget renders a small, non-dismissable corner marker whenever `isLegacyHost()` returns true. It reuses `isLegacyHost()` directly, so it inherits the same gate: hidden in production before Phase 2, suppressible via `MIGRATION_DISABLED`, forceable in local development via `RINGDRILL_FORCE_LEGACY_HOST`, and — like the banner — shown only for an *installed* PWA (standalone display mode), since browser visitors fail over to the Astro `/migrate` page after cutover. On native builds the stub `isLegacyHost()` returns false, so the marker is web-only for free.

The interaction is a three-layer hierarchy that keeps the primary actions shallow:

1. The `LegacyBadge` is ambient and permanent. Its only job is to signal "this is the old web app". Tapping it does not navigate away — it re-surfaces the `MigrationBanner` even if the user dismissed it, by clearing the 24-hour dismiss state. A shared `migrationBannerForceShowTick` `ValueNotifier` (the same idiom as `stationsTabReselectTick`) carries the signal from the badge to the banner without coupling the two widgets. Normal dismiss behaviour is otherwise unchanged, so the badge is the on-demand escape hatch that brings the banner back.
2. The `MigrationBanner` keeps the export and "open the new app" actions one tap deep. It gains a "Read more" button that opens the full `MigrationPage` explainer via `openFormSurface`. This button replaces the old `migrationBannerMoreInfoHint` line, which pointed users at the drawer in prose ("You'll find more information about the migration in the menu"). The explicit button removes that "go hunting in the menu" wording, and the `migrationBannerMoreInfoHint` ARB string is deleted.
3. The `MigrationPage` full-page explainer (why, what changes, the steps, re-export) is reached from the banner's "Read more" button and, unchanged, from the existing "About the migration" drawer entry.

The `LegacyBadge` widget, the `migrationBannerForceShowTick` notifier, the "Read more" button and the new ARB strings all belong to the same removable cluster as the rest of ADR-0039's migration UI. They are deleted together against the sunset criterion below, in the same clean-up commit.

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
* No prefix for feature flags that gate product behaviour in production (`MIGRATION_DISABLED`).

Existing flags are not renamed. Consistency applies to new flags only.

### Out of scope

* Runtime flag service. Reserved as a future ADR if scale demands.
* A/B testing infrastructure.
* Renaming existing flags to fit any new naming convention.
* Removing the existing feature flag. That happens against the sunset criterion above.

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
* Related code: `lib/utils/app_config.dart`, `lib/web/legacy_host_web.dart`, `lib/main.dart`, `lib/views/about_page.dart`, `lib/views/shell/legacy_badge.dart`, `lib/views/shell/migration_banner.dart`, `lib/views/migration_page.dart`
* Future ADRs deferred: runtime feature flag service (if scale demands), A/B testing infrastructure
