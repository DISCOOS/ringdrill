You are working in the RingDrill repository. Implement a batch of small, independent DESIGN-006 polish fixes — items 5, 9, 10, 11 and 12 from `docs/prompts/DESIGN-006-followups.md`. Read that list and DESIGN-006 (`docs/design/006-program-tab-consolidation.md`) for context. If anything here contradicts the specs, the specs win; stop and ask.

These are post-consolidation fixes. Stages 1–4 (segmented Program tab, program-scoped routing, overview, Roster tab) have landed. Each step below is independent, additive and main-safe — do them in any order, one commit each, and they can be pushed once green.

## Ground rules

Read `AGENTS.md`. The ones that bite:

- **Localize** any new user-visible string in both `app_en.arb` and `app_nb.arb`, then run `make build` (gen-l10n). Do not hand-edit `app_localizations*.dart`.
- **CLI Flutter-free, mobile-safe imports, no new Sentry.** Widget-layer only.
- **Match existing Dart style.** No new lint suppressions without an inline reason.
- **Verify before claiming green.** `flutter analyze` and `flutter test` at the end of each step. Add a focused widget test where it is cheap and meaningful.

## Commits

Conventional Commits with a scope. One commit per step, `git status` clean between steps. Do not squash.

## Steps

### Step 1 — `fix(widget)`: clip the PlanStatusBadge InkWell to the badge (item 12)

In `lib/views/plan_status_badge.dart` (~line 195) the tappable badge wraps its content in an `InkWell` with `borderRadius: 4` but no clipping `Material`/`Ink` of a matching shape, so the tap ripple/highlight is not confined to the badge and bleeds onto the AppBar. Wrap the `InkWell` in a transparent `Material` (`type: MaterialType.transparency`) with a matching `borderRadius`/shape, or use `Ink` + `ClipRRect`, so the splash clips to the badge. Verify the ripple stays inside the badge bounds and the hit area matches the visible badge.

Gates green. Commit.

### Step 2 — `fix(widget)`: stop `PhaseTile` overflowing at narrow widths (item 5)

In `lib/views/phase_tile.dart` the inner `Row` overflows by ~10 px when the content width is ~314 px (a station detail sheet rendered at a 700 px viewport in the wide master/detail layout). Let the row fit narrow widths: wrap the flexible child in `Expanded`/`Flexible`, allow the label to ellipsize or wrap, or otherwise remove the fixed overflow. Verify no overflow at ~314 px and that the normal layout is unchanged.

Gates green. Commit.

### Step 3 — `feat(l10n)`: rename the Spill create FAB to "Nytt spill" (item 10)

The Spill segment's create FAB in `lib/views/roleplays_view.dart` labels itself with `localizations.newRole` ("Ny rolle"). Add a new key for the create action so the label reads **nb "Nytt spill"** and matches the segment ("Spill"). English: mirror the segment ("Script") — suggest **"New play"**, or "New script entry" if avoiding "play" reads better; pick one and note it in the commit body. It still creates a `RolePlay` for now (when `SilentWitness` lands, this becomes a choice). Run `make build`. Label change only.

Gates green. Commit.

### Step 4 — `refactor(roleplay)`: retire the cast-roster action from the Spill segment (item 9)

The Roster tab (stage 4) is now the actor registry's home, so the cast-roster action in `RolePlaysController.buildActions` (`Icons.recent_actors`, tooltip "Spilles av") is redundant. Remove it and keep only the exercise filter action. Remove `RolePlaysView._openCastRoster` if nothing else references it. **Keep** the per-role **cast picker** (assigning an `Actor` to a `RolePlay` from the role's detail) — that is separate. Update the DESIGN-006 FAB/actions table so the Spill row keeps only the filter. Update any roleplays test that asserted on `Icons.recent_actors`.

Gates green. Commit.

### Step 5 — `fix(roster)`: refresh the Roster actor subtitle on cast changes (item 11)

In the Roster tab, an `Actor` row's subtitle (its role-play assignment) does not update when the actor is cast to or uncast from a `RolePlay` in the Spill segment. `RosterView` already subscribes to `ProgramService().events` and rebuilds (`lib/views/roster_view.dart` ~line 91), so investigate which link is broken: confirm that casting (saving a `RolePlay` with an `actorUuid`) fires the event `RosterView` listens to, and that the subtitle **recomputes** the actor→roles mapping on each build rather than reading a cached value. Fix whichever is stale. Add a widget test that casts an actor and asserts the subtitle updates.

Gates green. Commit.

## When you finish or get stuck

- Mark items 5, 9, 10, 11, 12 resolved in `docs/prompts/DESIGN-006-followups.md` as you land each.
- Off-scope findings become new numbered follow-ups in that file, not extra steps here.
- If a step is blocked, write a one-paragraph note to `docs/prompts/DESIGN-006-polish-blockers.md` and exit rather than guessing.
