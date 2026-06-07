## Closing

2026-06-07: Stage 2 landed in three commits on main.

**New files:**
- `lib/views/widgets/ring_rotation_figure.dart` — `RingRotationFigure` + `_RingRotationFigurePainter`
- `lib/views/widgets/concept_primer_content.dart` — reusable primer card body (used by stage 5 Help)
- `lib/views/concept_primer_screen.dart` — thin `Scaffold` wrapper for `/welcome`
- `test/views/widgets/ring_rotation_figure_test.dart` — smoke render in light + dark
- `test/views/concept_primer_screen_test.dart` — route gate + CTA flag-writes + figure in primer

**Modified files:**
- `lib/utils/app_config.dart` — `keyOnboardingSeen = 'app:onboardingSeen:v1'`
- `lib/main.dart` — reads `isOnboardingSeen` at boot, threads to `RingDrillApp` and `buildRouter`
- `lib/views/main_screen.dart` — `buildRouter(bool, bool)` signature; primer gate in redirect; `/welcome` GoRoute with `parentNavigatorKey: key`; `import concept_primer_screen.dart`
- `lib/l10n/app_en.arb`, `lib/l10n/app_nb.arb` — six new keys; regenerated `app_localizations*.dart`
- `test/views/program_scoped_routing_test.dart` — updated `buildRouter(false)` → `buildRouter(false, true)`

**Final l10n key names:** `primerSkip`, `primerHeading`, `primerBody`, `primerOpenExample`, `primerStartEmpty`, `primerTeamLabel` (int placeholder `n`).

**Flag decision adopted:** `AppConfig.keyOnboardingSeen = 'app:onboardingSeen:v1'` — a dedicated sibling key, NOT a reuse of `keyIsFirstLaunch`. `keyIsFirstLaunch` is cleared at boot before the router runs and is overloaded with consent semantics; reusing it would lose primer gate correctness on force-quit.

**Redirect ordering fix:** The primer gate must come BEFORE `legacyProgramRedirect` in `buildRouter`'s redirect callback. `legacyProgramRedirect` intercepts `location == '/'` and returns `programPath(activeUuid)` when an active program exists, which would bypass the gate. The final order: `/i/`, `/o/` → primer gate (`!isOnboardingSeen && location == '/'`) → legacy redirects → `_activateCanonicalProgramPath`.

**Consent dialog sequencing:** No code change needed. `MainScreen` lives inside the ShellRoute builder, which is only called when a shell path (e.g. `/program/...`) matches. While the user is at `/welcome`, the ShellRoute never matches, so `MainScreen.initState` never fires. The consent dialog shows the first time the user lands on a program path after dismissing the primer — primer first, consent on shell mount, naturally.

**Stage 3 seam:** `lib/views/concept_primer_screen.dart:_dismiss` contains a `// TODO(DESIGN-007 stage 3): import bundled example plan, then navigate to the active program` marker on the "Åpne et eksempel" path. Stage 3 wires the example plan import here.

**Stage 5 seam:** `ConceptPrimerContent` (in `lib/views/widgets/concept_primer_content.dart`) is the reuse surface. Stage 5 mounts it directly inside the Help/FAQ screen chrome (without `ConceptPrimerScreen`'s `Scaffold`).

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
