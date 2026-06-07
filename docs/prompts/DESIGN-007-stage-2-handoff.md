## Investigation

2026-06-07: Router redirect lives at `lib/views/main_screen.dart:158`. `buildRouter(bool isFirstLaunch)` owns the root navigator `key` (line 144). The redirect checks `/i/`, `/o/`, and legacy redirects first; root `/` is intercepted inside the ShellRoute at line 253 (`GoRoute(path: '/', redirect: (_, _) => _activeProgramPath())`). The primer redirect will slot in the top-level callback **after** legacy redirects and **before** `_activateCanonicalProgramPath` — only activating when `location == '/'` — so it never fights deep-link paths. Brief routes at lines 202–233 show the existing `parentNavigatorKey: key` pattern for top-level routes over the root navigator; `/welcome` will follow the same pattern.

**Flag decision — `AppConfig.keyOnboardingSeen = 'app:onboardingSeen:v1'`** (dedicated sibling of `keyIsFirstLaunch`). `keyIsFirstLaunch` is cleared at `lib/main.dart:64` *before* the router is built at line 178 — reusing it would lose force-quit-during-primer correctness. It is also overloaded with analytics-consent semantics. A dedicated `keyOnboardingSeen` is read at boot (alongside the existing `isFirstLaunch` read), threaded into `RingDrillApp` and `buildRouter` as a second bool, and written `true` on any primer CTA dismissal. It is captured at boot — not a live listenable.

**Consent dialog sequencing.** `MainScreen.initState` fires `_showConsentDialog()` (line 1581) only when `widget.isFirstLaunch` is true. Since `/welcome` is a top-level route over the root navigator (redirected to from `/` before the ShellRoute ever matches), `MainScreen` never mounts while the primer is visible. It mounts — and the consent dialog fires — only after the user dismisses the primer and navigates to a program path. No code change to the consent dialog is required; the natural routing sequence gives us primer-first, then consent on shell mount.

**SVG→Canvas colour mapping for `RingRotationFigure`.** All colours resolved from `Theme.of(context).colorScheme`:
- Dashed ring stroke (`color-border-tertiary`) → `outlineVariant`
- Rotation arcs + arrowheads (`accent` #1D9E75) → `primary`
- Post fill (`accent-fill` #E1F5EE) → `primaryContainer`
- Post outline stroke → `primary`
- Post number text (`accent-text` #0F6E56) → `onPrimaryContainer`
- Team chip fill (`team` #185FA5) → `secondary`
- Team chip text (#fff) → `onSecondary`
