You are working in the RingDrill repository. Implement **stage 1 of DESIGN-007** ("Onboarding sequence and in-app help"): turn the four Program-tab segment empty states into **teaching empty states**. The authoritative spec is:

- `docs/design/007-onboarding-and-help.md` (DESIGN-007, Accepted) — read *Layer 3 — Teaching empty states* and *Implementation notes → Stage 1*. Also skim *Non-goals* so you do not pull in later stages.

Read it in full first. If this prompt contradicts it, the spec wins; stop and ask.

This is the first stage and depends on nothing else. It needs no new persistence, no routing change, and no data-model change. It is additive and main-safe.

## What stage 1 is, and is not

Stage 1 gives all four Program segments (Øvelser, Poster, Spill, Team) a teaching empty state: an icon, a title, and one or two lines of copy that name what the segment needs and point at the action that supplies it. Three segments have a bare one-line text today and get upgraded. **Team has no empty state at all** — `TeamsView.buildList` maps `teams` straight to a `ListView`, so an empty list renders a blank segment and there is no `noTeamsYet` key. Stage 1 adds one.

**In scope:**

- A reusable teaching-empty-state widget (circular icon badge, title, body, optional action affordance), colours from the theme, matching the look in `docs/design/mockups/onboarding-empty-state.html`.
- Wiring it into **all four** Program segment bodies so they share one consistent design, each with its own copy (see [Copy](#copy)). The text differs per segment by design: Øvelser names the run precondition, Poster and Team explain they are derived from exercises and point back to Øvelser, and Spill explains what a role is and uses its own create path.
- Create-action behaviour stays as DESIGN-006 set it: Øvelser keeps its "Ny øvelse" FAB and Spill its "+" / "Nytt spill" path, while Poster and Team have **no own create FAB**, so their empty states point back to Øvelser rather than inventing a creator.
- New `nb` / `en` localization keys for the four titles and bodies (suggested scheme `empty<Segment>Title` / `empty<Segment>Body`). The old single-line keys (`noExercisesYet`, `noStationsYet`, `noRolesInProgram`) are superseded — remove any this stage leaves unused so no orphan keys remain. Team gets a brand-new pair (no `noTeamsYet` exists today).

**Out of scope (do not touch):**

- **No "Start her" cue.** That pill is stage 4, gated by the onboarding-seen flag. Do not add it, and do not add the `shared_preferences` flag here.
- **No concept primer** (stage 2), **no example plan** (stage 3), **no Help/FAQ** (stage 5).
- **No Roster change.** `noActorsInRoster` is the Roster tab, not a Program segment. Leave it.
- **No new create affordances.** Do not add a FAB to Poster or Team; DESIGN-006 deliberately left them without one.
- **No data-model fields and no codegen** beyond the l10n regeneration that editing the `.arb` files triggers.
- **No `BriefTheme`.** Plain Material style.

## Ground rules

Read `AGENTS.md` and follow every numbered rule. The ones that bite here:

- **Localize every user-visible string.** Add each key to both `app_en.arb` and `app_nb.arb`; run `make build` after editing the arb files. Norwegian for *station* stays "post"/"poster" ([[feedback_post_station_terminology]]).
- **CLI must stay Flutter-free.** Widget layer only.
- **Do not edit `*.freezed.dart`, `*.g.dart` or `app_localizations*.dart`.** Only `make build` regenerates l10n.
- **Mobile-safe imports.** No `dart:html` / `package:web`.
- **No new Sentry/analytics calls.**
- **Match existing Dart style.** No new lint suppressions without an inline reason.
- **Verify before claiming green.** `flutter analyze` and `flutter test` at the end of each step.

## Investigate before you wire (do this first, no commit)

1. Where each segment renders its empty state today and which key it uses. Confirmed starting points: `noExercisesYet` (Øvelser), `noStationsYet` (Poster), `noRolesInProgram` (Spill). **Team has none** — `TeamsView.buildList` (`lib/views/teams_view.dart`) maps `teams` straight to a `ListView` with no empty branch, and there is no `noTeamsYet` key, so add both the empty branch and the key. Files: `lib/views/program_view.dart`, `lib/views/station_list_view.dart`, `lib/views/roleplays_view.dart`, `lib/views/teams_view.dart`.
2. The per-segment create affordance, to confirm the DESIGN-006 table: Øvelser FAB "Ny øvelse", Spill create "+"/"Nytt spill", Poster and Team none. Wire each empty state's action (or absence of one) to match what actually exists.
3. Whether a reusable empty-state widget already exists to extend, or each view inlines its own. Do **not** conflate with `lib/views/shell/detail_empty_pane.dart` (`detailEmpty*`), which is the wide-screen detail pane, a different surface.
4. The icons the segments already use (`Icons.update`, `Icons.place`, `Icons.theater_comedy`, `Icons.group` per DESIGN-006), so the empty-state icons match their segment.

Append a short note of what you found to `docs/prompts/DESIGN-007-stage-1-handoff.md` (create it) before step 1.

### Recommended approach (adopt unless investigation shows a cheaper path)

One shared `TeachingEmptyState` widget used by **all four** segments, so they look consistent. Match the visual in the mockup `docs/design/mockups/onboarding-empty-state.html`: a centred column with a circular tinted icon badge on top, a title, then one or two muted body lines. The widget takes an icon, a title, a body, and an optional action (label + callback). Colours from `Theme.of(context).colorScheme`. No "Start her" parameter — that is stage 4, so do not design the API around it yet, just leave it easy to add later. Each segment body renders it when its list is empty, replacing the current bare text (and, for Team, filling the gap where there is none). Keep the existing create FABs exactly where they are; the empty state does not own them.

## Copy

Final per-segment copy. Norwegian uses "post"/"poster" for *station*; English uses "station(s)" ([[feedback_post_station_terminology]]). Use these verbatim.

| Segment (key stem) | Icon | `nb` title | `nb` body | `en` title | `en` body |
|---|---|---|---|---|---|
| Øvelser (`emptyExercises`) | `Icons.update` | Ingen øvelser ennå | En øvelse trenger antall poster og antall lag for å kunne kjøres. Legg til den første for å se ringen i arbeid. | No exercises yet | An exercise needs a number of stations and a number of teams before it can run. Add your first to see the ring in motion. |
| Poster (`emptyStations`) | `Icons.place` | Ingen poster ennå | Poster legges til inne i øvelsene dine. Opprett en øvelse først, så dukker postene opp her. | No stations yet | Stations are added inside your exercises. Create an exercise first and they will show up here. |
| Spill (`emptyRoles`) | `Icons.theater_comedy` | Ingen roller ennå | Roller er markørene som spiller ut scenarioet på postene. Trykk + for å legge til den første. | No roles yet | Roles are played out at the stations to drive the scenario. Tap + to add the first one. |
| Lag (`emptyTeams`) | `Icons.group` | Ingen lag ennå | Lag kommer fra antall lag i øvelsene dine. Opprett en øvelse først, så dukker lagene opp her. | No teams yet | Teams come from the team count in your exercises. Create an exercise first and they will show up here. |

Only Spill mentions "+", because only it (and Øvelser, via its FAB) has a creator. Poster and Lag point back to Øvelser instead.

## Commits

Conventional Commits, scope `program`. One commit per step, `git status` clean between steps (commit every changed file each step, including the regenerated l10n and any test files). Do not squash.

## Steps

### Step 1 — `feat(program)`: shared TeachingEmptyState widget + l10n keys

Add the `TeachingEmptyState` widget and the new `nb` / `en` keys for the four titles and bodies. Run `make build`. Remove old single-line keys this stage makes unused. No segment is wired yet; the widget compiles and is covered by a minimal render check.

Gates green. Commit.

### Step 2 — `feat(program)`: wire the four segment empty states

Render `TeachingEmptyState` in Øvelser, Poster, Spill and Team when each is empty, with the copy and icon for each segment, and the matching action (Øvelser and Spill route to their existing create paths; Poster and Team point back to Øvelser, no FAB added). For Team this means adding the missing empty branch to `TeamsView.buildList` (it has none today). The bare empty-state text is gone from the other three.

Gates green. Commit.

### Step 3 — `test(program)`: cover the four empty states

Widget tests under `test/`: each segment shows its teaching empty state with the right title, body and icon when empty, and hides it when the segment has content; Øvelser and Spill expose their create action while Poster and Team do not gain a FAB. Do not add coverage for unrelated surrounding code.

Gates green. Commit.

## When you finish or get stuck

- Append a closing entry to `docs/prompts/DESIGN-007-stage-1-handoff.md` summarizing the landed state and the final key names, so stage 2 can build on it.
- Off-scope findings go to `docs/prompts/DESIGN-007-followups.md` (one line each). New defects become their own numbered follow-up, not extra steps here ([[feedback_new_findings_own_prompt]]).
- If a step is blocked by an ambiguous spec or unmet precondition, stop and write a one-paragraph note to `docs/prompts/DESIGN-007-stage-1-blockers.md`, then exit rather than guessing.
- Stage 1 is additive and may be pushed once green.
