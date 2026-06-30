# ADR-0042 implementation — Build-time feature flags and sunset telemetry

You are working in the RingDrill repository. Implement [ADR-0042](../adrs/0042-feature-flags-and-sunset-telemetry.md). The ADR is `proposed` at the time this prompt is written. Do not change its status to `accepted` unless the maintainer explicitly instructs you in the same conversation.

Read ADR-0042 in full before starting.

## Scope

Five small deliverables, ordered for clean commits:

1. Central `AppFlags` class in `lib/utils/app_flags.dart`
2. Sentry scope tagging at boot
3. Sunset-telemetry event for legacy apex
4. About page "Build flags" section when any flag is set
5. `docs/feature-flags.md` living index plus a README pointer

No new dependencies. No infrastructure changes. No new dart-defines beyond what already exists.

## Steps

### Step 1 — `AppFlags` registry

Create `lib/utils/app_flags.dart`:

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
      description:
          'Kill switch hiding the in-app migration UI before web.ringdrill.app is live.',
    ),
    AppFlagInfo(
      name: 'RINGDRILL_FORCE_LEGACY_HOST',
      value: forceLegacyHost,
      kind: AppFlagKind.temporary,
      description:
          'Dev override that makes isLegacyHost() return true regardless of actual host.',
    ),
    AppFlagInfo(
      name: 'RINGDRILL_LOCAL_BASE_URL',
      value: localBaseUrl,
      kind: AppFlagKind.permanent,
      description:
          'Points the catalog client at a local netlify dev instance.',
    ),
  ];

  static Iterable<AppFlagInfo> get activeOnly =>
      all.where((f) => !f.isDefault);
}
```

Refactor `lib/web/legacy_host_web.dart` and `lib/utils/app_config.dart` so existing flag-reading sites reference `AppFlags.X` where compile-time `const` is not required. Keep `const`-required call sites as-is, but mirror their declarations through `AppFlags` so the registry stays complete.

Unit test verifies:

* `AppFlags.all` has exactly three entries with the expected names
* Default values are correct (`false`, `false`, `''`)
* `activeOnly` is empty when no flags are set
* `AppFlagInfo.isDefault` correctly handles bool `false`, empty string and num zero
* `kind` and `description` are populated for each entry

Commit: `feat(config): centralise build-time feature flags in AppFlags`. Verify `git status` is clean.

### Step 2 — Sentry scope tagging at boot

In `lib/main.dart`, after Sentry is initialised inside the existing consent gate, add scope configuration that tags every event with flag state and origin:

```dart
Sentry.configureScope((scope) {
  for (final f in AppFlags.all) {
    scope.setTag('flag.${f.name}', f.value.toString());
  }
  scope.setTag('app.origin', kIsWeb ? Uri.base.host : 'native');
  scope.setTag('app.legacy_apex', isLegacyHost().toString());
});
```

Place the call inside the consent gate per ADR-0006. If consent is denied Sentry never initialises and the tagging never runs — that is correct.

Acceptance: build runs without error, Sentry-tagged events from a debug session show the expected tags.

Commit: `feat(observability): tag Sentry scope with build flags and origin`. Verify `git status` is clean.

### Step 3 — Sunset telemetry for legacy apex

In `lib/main.dart`, after Sentry scope is configured, conditionally emit one info-level Sentry event when `isLegacyHost()` returns `true`:

```dart
if (isLegacyHost()) {
  Sentry.captureMessage(
    'boot on legacy apex',
    level: SentryLevel.info,
  );
}
```

The event fires once per launch. No persistence (`SharedPreferences`) is needed because each session has its own boot, and Sentry sessions deduplicate user counts naturally.

Acceptance: when running with `--dart-define=RINGDRILL_FORCE_LEGACY_HOST=true` and consent granted, Sentry receives one event per boot. When running on a non-legacy host, no event fires.

Commit: `feat(observability): emit sunset telemetry event when booting on legacy apex`. Verify `git status` is clean.

### Step 4 — About page "Build flags" section

Open `lib/views/about_page.dart`. After the existing rows, render a "Build flags" section that only appears when both `kDebugMode` is `true` AND `AppFlags.activeOnly` is non-empty:

* A heading `ListTile` with `Icons.flag_outlined` leading and a `titleMedium`-weight title "Build flags". Matches the visual rhythm of existing About sections (version, commit, developed by).
* Then one `ListTile` per active flag:
  - `title`: the flag name (e.g. `MIGRATION_DISABLED`)
  - `subtitle`: a `Column` with two rows — the current value (`true`, `false`, or the string) on the first line, the short description from `AppFlagInfo.description` on the second
  - `trailing`: a compact `Chip` reading `Temporary` or `Permanent` from `AppFlagInfo.kind`. Use a non-fancy chip style; `VisualDensity.compact` and a `labelStyle` of `bodySmall` keeps it from dominating the row.
* No translation strings for the heading copy or chip labels — this is a developer-facing surface. Use English text directly.

Release builds must NOT render the section regardless of flag state. The Sentry tags carry the same information for production debugging, so the UI surface stays clean for end users.

Acceptance:
* Debug build with no dart-defines → section hidden.
* Debug build with `--dart-define=MIGRATION_DISABLED=true` → section visible with heading and one entry. Entry shows name on title line, `true` and description on subtitle lines, "Temporary" chip on trailing.
* Release build with `--dart-define=MIGRATION_DISABLED=true` → section hidden.

Commit: `feat(about): surface active build flags in the About page`. Verify `git status` is clean.

### Step 5 — Living docs

Create `docs/feature-flags.md` with a table per ADR-0042's spec. Fill in the three currently active flags:

```markdown
# Build-time feature flags

This is the living index of every dart-define flag the app reads at
build time. Update this file in the same commit that introduces,
changes or removes a flag.

The shape of this index and the conventions are defined in
[ADR-0042](./adrs/0042-feature-flags-and-sunset-telemetry.md).

| Name | Type | Kind | Default | Purpose | Introduced by | Sunset criterion |
|------|------|------|---------|---------|---------------|------------------|
| `MIGRATION_DISABLED` | `bool` | Temporary | `false` | Kill switch that hides the in-app migration banner, drawer entry and explainer when the new `web.ringdrill.app` PWA is not yet ready. | [ADR-0039](./adrs/0039-site-pwa-api-origins.md) Phase 1 | Remove when sunset telemetry reports 0 legacy-apex sessions over 30 consecutive days after Phase 3 cutover. |
| `RINGDRILL_FORCE_LEGACY_HOST` | `bool` | Temporary | `false` | Dev-only override that makes `isLegacyHost()` return true regardless of the actual host. Used to exercise the migration UI on `localhost` during development. | [ADR-0039](./adrs/0039-site-pwa-api-origins.md) Phase 1 | Remove together with `MIGRATION_DISABLED`. Same sunset criterion. |
| `RINGDRILL_LOCAL_BASE_URL` | `String` | Permanent | `''` | Debug-only override that points the catalog client at a local `netlify dev` instance. Documented in [ADR-0013](./adrs/0013-local-catalog-testing.md). | [ADR-0013](./adrs/0013-local-catalog-testing.md) | — |
```

Update the project README's Documentation section to add a bullet pointing at `docs/feature-flags.md`:

```
* [`docs/feature-flags.md`](docs/feature-flags.md): living index of every build-time dart-define flag, its purpose and its sunset criterion. Updated in the same commit as a flag is added, changed or removed.
```

Commit: `docs(flags): add living build-flag index and link from README`. Verify `git status` is clean.

### Step 6 — Verification

* `flutter analyze` clean
* `flutter test` clean
* `git status` clean
* Run a debug build with **no** dart-defines. Confirm the About page does NOT show a Build flags section. Confirm Sentry events (if consent granted) carry `flag.MIGRATION_DISABLED=false`.
* Run a debug build with `--dart-define=RINGDRILL_FORCE_LEGACY_HOST=true`. Confirm About page shows the Build flags section. Confirm one sunset-telemetry event fires per boot.
* Run a debug build with `--dart-define=MIGRATION_DISABLED=true`. Confirm `isLegacyHost()` returns false, banner is hidden, About page shows the flag.

## Out of scope

* Runtime flag service
* A/B testing infrastructure
* Renaming existing flags
* Any change to `deploy-web.yml`, the Makefile or any GHA workflow (the existing flag plumbing carries through unchanged)
* Removing the migration kill switch (sunset criterion lives in the docs; the actual removal is a later, separate change)

## Definition of done

Five commits in order: `feat(config)`, `feat(observability)`, `feat(observability)`, `feat(about)`, `docs(flags)`. Tests pass. Manual verification per Step 6 passes. `git status` clean after every commit.

ADR-0042 stays `proposed` unless the maintainer explicitly accepts.

## Commit message conventions

Conventional commits, lowercase, imperative present tense, English. Match the style of recent commits in the repo. Each step has its own commit.
