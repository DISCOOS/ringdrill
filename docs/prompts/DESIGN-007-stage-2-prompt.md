You are working in the RingDrill repository. Implement **stage 2 of DESIGN-007** ("Onboarding sequence and in-app help"): the **concept primer** shown once on first launch, the **seen flag** that gates it, and the reusable **`RingRotationFigure`** illustration. The authoritative spec is:

- `docs/design/007-onboarding-and-help.md` (DESIGN-007, Accepted) — read *Layer 1 — Concept primer*, *Ring figure (`RingRotationFigure`)*, *Persistence*, *Resolved (2026-06-07)*, and *Implementation notes → Stage 2*. Also skim *Non-goals* so you do not pull in later stages.

Read it in full first. If this prompt contradicts it, the spec wins; stop and ask.

Stage 1 (teaching empty states) has landed — see `docs/prompts/DESIGN-007-stage-1-handoff.md`. Stage 2 builds on a clean main but does not depend on stage 1 code.

## What stage 2 is, and is not

Stage 2 adds a single full-screen **concept primer** card, reached on first launch via a top-level route, that teaches the ring rotation with the `RingRotationFigure` illustration and two CTAs. It is gated by a device-local seen flag so it shows once. The illustration is built as a reusable `CustomPainter` widget so the stage 5 Help surface can reuse it.

**In scope:**

- A reusable `RingRotationFigure` widget — a `CustomPainter`, **not** an image or SVG asset — ported from the mockup SVG in `docs/design/mockups/onboarding-concept-primer.html`. It takes its colours from `Theme.of(context).colorScheme` (light/dark automatic) and a size; no baked-in fills, no new dependency, nothing bundled. Not animated. The three posts are labelled `2a` / `2b` / `2c` via `Numbering.station(StationNumberFormat.alpha, exerciseNumber: 2, stationIndex: 0/1/2)` — not synthetic `A1` text. Team chips sit **on the arrows** ("on the way to"), per the mockup.
- A **concept primer** screen matching `docs/design/mockups/onboarding-concept-primer.html`: three progress dots and a **"Hopp over"** affordance on top (dots are decorative in v1 — one card), the `RingRotationFigure` as the largest element, heading **"Lagene roterer"**, one body line, and two buttons — primary **"Åpne et eksempel"** and secondary **"Start en tom plan"**. The primer content is a **reusable widget** (so stage 5 Help can show it again), with the screen/route a thin wrapper around it.
- A **top-level primer route** (e.g. `/welcome`) registered with `parentNavigatorKey: key` so it lives over the root navigator like the brief routes, **not** inside the `IndexedStack` shell. The router redirect routes to it from the root path on first launch (see *Wiring*, below).
- The **seen flag** in `shared_preferences` and `AppConfig`, gating the primer to once. See *Flag decision* — this is the one genuine design choice in stage 2; resolve it explicitly and record the choice in the handoff.
- Button wiring: **"Start en tom plan"** marks onboarding seen and navigates to the (empty) active Program tab. **"Hopp over"** does the same. **"Åpne et eksempel"** is **stubbed** until stage 3 — wire it to the same "mark seen + go to Program" path for now, with a `// TODO(DESIGN-007 stage 3)` marker, so the primer is fully dismissable. Do not bundle an example plan here.
- New `nb` / `en` localization keys for every primer string (heading, body, "Hopp over", "Åpne et eksempel", "Start en tom plan").

**Out of scope (do not touch):**

- **No example plan** (stage 3). "Åpne et eksempel" is stubbed as above; do not bundle a `.drill` or wire the import pipeline.
- **No "Start her" cue** (stage 4). Do not add the inline FAB pill.
- **No Help / FAQ surface** (stage 5). Do not add the Settings entry or the "Slik fungerer RingDrill" re-entry. Just leave `RingRotationFigure` and the primer-content widget reusable so stage 5 can mount them.
- **No animation** of the ring (deferred decision 5).
- **No `BriefTheme`** anywhere in the primer. Plain Material.
- **No new data-model fields, no `@freezed`/`json_serializable` change, no codegen** beyond the l10n regeneration that editing the `.arb` files triggers.

## Ground rules

Read `AGENTS.md` and follow every numbered rule. The ones that bite here:

- **Localize every user-visible string.** Add each key to both `app_en.arb` and `app_nb.arb`; run `make build` after editing the arb files. Norwegian for *station* stays "post"/"poster" ([[feedback_post_station_terminology]]) — though the primer copy here uses "lag"/"post" only inside the figure labels and body line.
- **CLI must stay Flutter-free.** Widget layer only; nothing the CLI imports may pull in `RingRotationFigure` or the primer.
- **Do not edit `*.freezed.dart`, `*.g.dart` or `app_localizations*.dart`.** Only `make build` regenerates l10n.
- **Mobile-safe imports.** No `dart:html` / `package:web`.
- **No new Sentry/analytics calls.**
- **Match existing Dart style.** No new lint suppressions without an inline reason. There is **no existing `CustomPainter` in the codebase** (`lib/views/widgets/` has badges, mini-maps and sheets but no painter), so this is the first — keep it self-contained and well-commented, colours strictly from `ColorScheme`.
- **Verify before claiming green.** `flutter analyze` and `flutter test` at the end of each step.

## Investigate before you wire (do this first, no commit)

1. **The router redirect and first-launch threading.** `buildRouter(bool isFirstLaunch)` lives in `lib/views/main_screen.dart` (around line 143). The `redirect` callback handles `/i/`, `/o/`, legacy redirects, then `_activateCanonicalProgramPath(location)`; the root `/` route redirects to `_activeProgramPath()`. The captured `isFirstLaunch` bool is threaded into `MainScreen` (around line 240). Decide where the primer redirect slots in: it must fire **only** from the root path on first launch and must not fight the `/i/`, `/o/` or brief deep-link paths. Per the spec's *Resolved* point 1, the captured bool is enough — the guard only routes to the primer from the root, so it does not re-trigger once on a program path, and the flag need not be a live listenable.
2. **The boot sequence and the existing flag.** `lib/main.dart` reads `AppConfig.keyIsFirstLaunch` (around line 47), and on first launch **immediately clears it to `false` and sets the analytics-consent default** (lines 61–65), *before* the router runs. So `keyIsFirstLaunch` is already consumed at boot and is also the trigger for the consent dialog (see point 3). This is exactly why the **seen flag decision below matters** — reusing `keyIsFirstLaunch` for the primer is fragile because it is cleared before routing and is overloaded with consent semantics.
3. **The consent dialog interaction.** `MainScreen.initState` calls `if (widget.isFirstLaunch) _showConsentDialog();` (`lib/views/main_screen.dart` around line 691). On first launch the consent dialog fires inside the shell. Since the primer is a top-level route over the root navigator, both want to appear on first launch. Work out the sequencing so the user is not shown the consent dialog *underneath* the primer (e.g. primer first, consent on dismiss when landing in the shell; or confirm the existing order is acceptable). Note what you decide in the handoff.
4. **`Numbering` and the badge widgets.** `lib/models/numbering.dart` gives `Numbering.station(StationNumberFormat.alpha, exerciseNumber: 2, stationIndex: i)` → `2a`/`2b`/`2c`. `lib/views/widgets/station_number_badge.dart` and `exercise_number_badge.dart` exist if you want to match badge styling, but the figure draws its own labels with `TextPainter`, not these widgets.
5. **The mockup SVG → `Canvas` mapping.** `docs/design/mockups/onboarding-concept-primer.html` has the exact geometry: `viewBox 0 0 240 212`, dashed ring `circle cx=120 cy=108 r=70` (`dasharray 4 6`), three rotation arcs with arrowhead markers, three post circles (`r=20`) at top / lower-left / lower-right with `2a`/`2b`/`2c`, and three team chips (rounded rects, `Lag 1/2/3`) sitting on the arrows. Map: dashed ring → `drawCircle` with a dashed `Path`; arrows → `drawArc` + a small arrowhead `Path`; posts → `drawCircle`; chips → `drawRRect`; labels → `TextPainter`. Replace the mockup's hard-coded accent/`team`/fill hexes with `ColorScheme` roles (e.g. accent → `primary`, accent-fill → `primaryContainer`, post text → `onPrimaryContainer`, team chip → `secondary`/`tertiary`, chip text → its `on*`, dashed ring → `outlineVariant`). Pick the closest roles and note the mapping in a comment.

Append a short note of what you found to `docs/prompts/DESIGN-007-stage-2-handoff.md` (create it) before step 1.

### Flag decision (resolve explicitly)

The spec leaves this open ("The 'Start her' dismissal can share this flag or use a sibling key, decided at implementation"; *Resolved* point 1 says the captured `isFirstLaunch` bool is enough for the primer guard). Given that `keyIsFirstLaunch` is cleared at boot before routing **and** is overloaded with consent semantics, the recommended approach is a **dedicated `AppConfig.keyOnboardingSeen` (`'app:onboardingSeen:v1'`)**, written `true` when the primer is dismissed (any of the three CTAs), and read fresh at boot to compute the bool threaded into `buildRouter`. This:

- keeps the primer independent of the consent default and the consent-dialog trigger,
- survives a force-quit mid-primer correctly (the primer re-shows until actually dismissed, unlike reusing the already-cleared `keyIsFirstLaunch`),
- gives stage 4's "Start her" a clean sibling flag to gate on.

Adopt this unless investigation surfaces a cheaper path that keeps the same correctness. If you reuse `keyIsFirstLaunch` instead, justify it in the handoff and confirm the force-quit and consent-overload concerns are handled. Either way, `main.dart` computes the bool and `buildRouter` consumes it as today — do not turn the flag into a live listenable (the spec rules that out).

## Copy

Final primer copy. Use verbatim. Suggested key scheme `primer*`.

| Key | `nb` | `en` |
|---|---|---|
| `primerSkip` | Hopp over | Skip |
| `primerHeading` | Lagene roterer | Teams rotate |
| `primerBody` | Hvert lag er på vei til neste post. Når runden er over, rykker alle videre samtidig. Det er hele RingDrill. | Each team is on its way to the next station. When the round ends, everyone advances together. That is all of RingDrill. |
| `primerOpenExample` | Åpne et eksempel | Open an example |
| `primerStartEmpty` | Start en tom plan | Start an empty plan |

The figure's own labels (`2a`/`2b`/`2c`, `Lag 1`/`Lag 2`/`Lag 3`) come from `Numbering` and a team-label string. For the team chips use the existing team-label localization if one exists (investigate); otherwise add a `primerTeamLabel` taking the team number (`nb` "Lag {n}", `en` "Team {n}") and note it in the handoff.

## Commits

Conventional Commits, scope `onboarding` (the figure and primer are new surfaces; `program` was stage 1's scope). One commit per step, `git status` clean between steps (commit every changed file each step, including the regenerated l10n and any test files). Do not squash. There are unrelated uncommitted changes in `lib/views/roleplay_form_screen.dart` and `lib/views/roleplays_view.dart` that are **not** part of DESIGN-007 — do not stage, commit, revert, or build on them.

## Steps

### Step 1 — `feat(onboarding)`: `RingRotationFigure` widget + l10n keys

Add `RingRotationFigure` (`lib/views/widgets/ring_rotation_figure.dart`) as a `CustomPainter`-backed widget taking a size and reading colours from `ColorScheme`, ported from the mockup geometry, posts labelled via `Numbering`. Add the `primer*` l10n keys (and `primerTeamLabel` if needed). Run `make build`. The figure compiles and is covered by a minimal render check (pumps in both light and dark `ThemeData`, asserts no exceptions and that it paints at a given size). No primer screen or route yet.

Gates green. Commit.

### Step 2 — `feat(onboarding)`: concept primer content widget + seen flag + route

Add the reusable primer-content widget (progress dots, "Hopp over", the figure, heading, body, two CTAs) and a thin primer screen/route wrapper. Add `AppConfig.keyOnboardingSeen` (per *Flag decision*), read it at boot in `main.dart` to compute the bool threaded into `buildRouter`, and register the top-level `/welcome` route with `parentNavigatorKey: key` over the root navigator. Wire the redirect to route to `/welcome` from the root path when onboarding is unseen. Wire the CTAs: "Start en tom plan" and "Hopp over" mark seen and navigate to the active Program tab; "Åpne et eksempel" marks seen and goes to Program for now with a `// TODO(DESIGN-007 stage 3)`. Resolve the consent-dialog sequencing from investigation point 3.

Gates green. Commit.

### Step 3 — `test(onboarding)`: cover the primer route, gate, and CTAs

Widget/router tests under `test/`: the primer shows at `/welcome` (or via the root redirect) when onboarding is unseen and is skipped when seen; each of the three CTAs marks the flag and lands on the Program tab; the figure renders inside the primer in light and dark without exceptions. Do not add coverage for unrelated surrounding code. If a full router integration test is too heavy, cover the redirect-decision logic and the CTA flag-writes directly, and note the seam in the handoff.

Gates green. Commit.

## When you finish or get stuck

- Append a closing entry to `docs/prompts/DESIGN-007-stage-2-handoff.md` summarizing the landed state, the final key names, the flag decision you made, and the consent-dialog sequencing, so stage 3 (example plan) and stage 5 (Help reuse of `RingRotationFigure`) can build on it.
- Off-scope findings go to `docs/prompts/DESIGN-007-followups.md` (one line each). New defects become their own numbered follow-up, not extra steps here ([[feedback_new_findings_own_prompt]]).
- If a step is blocked by an ambiguous spec or unmet precondition, stop and write a one-paragraph note to `docs/prompts/DESIGN-007-stage-2-blockers.md`, then exit rather than guessing.
- Stage 2 introduces a first-launch route gate; smoke-test a fresh install (clear `shared_preferences` or use `Upgrader.clearSavedSettings` in debug) so the primer actually appears once and never again, before pushing.
