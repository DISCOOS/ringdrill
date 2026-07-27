---
status: proposed
date: 2026-07-27
deciders: ["kengu"]
consulted: []
informed: []
---

# ADR-0056: One drill player with three peer modes — exercise, station, roleplay

## Context and problem statement

The fullscreen drill player (DESIGN-001) only ever showed an exercise. `_DrillPlayerHost` collapsed *any* `ContextSheetTarget` to `exerciseUuidOf(target)` and built a `CoordinatorScreen`, so a station or roleplay opened while its exercise was live appeared in a bottom sheet (narrow) or the detail pane (wide) — beside the player rather than in it. That is inconsistent: the player is meant to be *the* surface for a running exercise, and a post or a markør of that exercise is exactly what an instructor looks at while it runs.

Two structural problems came with it:

* **A latent bug.** Inside the player, `ContextSheet.of` resolves the player's own controller, opened via `adoptInlineTarget` (`_isOpen = true`, `_navigator = null`, `_activeScope = null`). `show()`'s "navigate within the open sheet" branch is gated on `_navigator != null`, so an in-player `show(StationSheetTarget)` fell through and opened a **modal on top of the player**; dismissing it ran the modal-close cleanup (`_target = null; _isOpen = false`), blanking the player and making every later navigation stack another modal. It was invisible only because every target collapsed to the same uuid — same `ValueKey`, no rebuild.
* **Two fake players.** `PlanView`'s live branch and `StationsView`'s map both pushed a bare `CoordinatorScreen` through `showDrillPlayerSheet` with no `ContextSheet` above it, so the player's own mini bar resolved the *shell's* controller and mutated the pane behind the player.

The maintainer's framing: *"I think we should think of exercise, stations and roleplays as different modes of the player, not different players."*

## Decision drivers

* One player at a time. *"I do not like stacked drill players. There is only one drill player at any one time."*
* The badge selector should follow what the surface is showing — a station selector in station mode, a roleplay selector in roleplay mode.
* Opening a station/roleplay while the player is up must switch the player's target, not open a sheet over it.
* Must hold in narrow *and* master/detail.
* The existing safety guard — the running exercise cannot be switched from the mini bar — must survive.

## Considered options

* **Option A — Peer modes of one player.** The player is a host for any target; exercise/station/roleplay are peers. X always closes the player. The badge is a within-mode selector; content taps move down a level; a pinned parent row moves back up.
* **Option B — Drill-down with target history.** The player keeps a stack of targets; X pops one level and closes only at the root.
* **Option C — Leave it.** Stations and roleplays keep opening beside the player.

## Decision outcome

Chosen option: **Option A**.

Option B was implemented on paper and dropped: a history stack means X does different things depending on invisible state, diverges from Android back unless `PopScope` is taught the same rules, and needs a root-target field that every entry point has to set correctly. Option A has one rule — **X always closes the player** — and needs no history at all.

### The player hosts any target

`_DrillPlayerHost` renders `defaultContextSheetBody(context, target)` keyed `ValueKey(target)` — the same helper the shell's sheet host and `MasterDetailPane` use, so the player can never diverge from what a target renders as elsewhere. Targets have no `==`, so each replacement is a distinct key and the subtree remounts; that is required, since these screens resolve their entity in `initState`.

### Inline mode is explicit

`ContextSheetController` gains `_isInline`, set by `adoptInlineTarget`. A non-brief `show()` on an inline controller **replaces** the host's body instead of presenting anything over it. Briefs stay the deliberate exception — they are a modal surface by definition — and save/restore `_isInline` along with the rest of the prior state.

Also added: `clearSelection()`. `close()` deliberately returns without touching an `adoptWideSelection` target (no navigator, no active scope), which is correct for its own callers and asserted by `master_detail_target_sync_test.dart`; the docked mini player needs the pane actually cleared before opening the player over it.

### The navigation grammar

* **Within a mode**: the mini bar's badge. Its picker (`showPlayerTargetPicker`) lists siblings of the current mode's type — exercises in exercise mode, that exercise's stations in station mode, its roleplays in roleplay mode. The badge itself follows the mode: `#1` / `1.2` / `1.2-1`, in the three matching swatches.
* **Down a level**: tapping content. A station row inside the exercise view enters station mode; a markør row inside a station enters roleplay mode. These already called `show()`, so the inline branch above is the whole mechanism.
* **Up a level**: a pinned parent row at the top of the station/roleplay picker — the parent exercise, with its own exercise badge, above a divider. Since X closes the player rather than unwinding, this is the only way up, and pinning it keeps it reachable without scrolling while the list below stays purely siblings.
* **Out**: X, from every mode. Identical to Android back, so no `PopScope` divergence.

### The live-exercise guard, restated

The original rule was "the running state's badge is non-interactive so users can't switch while an exercise is live". Restated per mode: the badge is inert **in exercise mode while running**, and tappable in station and roleplay mode, where it only moves between siblings *inside* that same live exercise. One expression, in one place:

```dart
interactive = onPickTarget != null && (mode is! ExercisePlayerMode || !isStarted);
```

### Entry policy

`DrillPlayerScope` (an `InheritedWidget` over the shell's `DrillPlayerCoordinator`, mounted by `MainScreen`) plus `openContextTarget(context, target)`: routes to the player when `shouldHostInPlayer(target)`, else falls back to `ContextSheet.of(context).showOrReplace(...)`. The predicate admits only the three declared modes, only for the exercise actually running, only while it still exists in the active plan (uuid equality alone does not exclude a stale cross-plan target), and never from inside the player — where the inline controller already swaps the body in place.

Migrated: the "user tapped an item in a planning list" call sites (`plan_view`, `station_list_view`, `roleplay_list_view`, `exercise_mini_map`, `station_role_summary`). Left alone: briefs, teams, `deep_link_launchers` (no scope on a cold link, so it falls back automatically), and `adoptWideSelection` — so the wide auto-select-first can never open a player.

**Not** an intercept inside `show()`. `showOrReplace`/`replace` bypass an intercept, so behaviour would depend on which widget was tapped, and `replace` has no `BuildContext` with which to push a route even if it wanted one; `StationsView` keys its map-detail toggle off its own target and would regress; and a global hook inverts the dependency direction and leaks between tests.

### Teams are not a mode

A team — per-exercise (`TeamSheetTarget`) or plan-wide (`TeamOverviewSheetTarget`) — is excluded from the predicate, so team taps behave exactly as before. Teams could plausibly become a fourth mode later; `PlayerMode` is sealed, so adding one is a compile error at every place that has to handle it rather than a silently-wrong default.

### Consequences

* Good: one player, one dismissal rule, and stations/roleplays of a live exercise finally render *in* it — narrow and wide alike, since the player is a fullscreen overlay above the shell either way.
* Good: the inline-mode branch fixes the latent modal-over-the-player bug on its own, before anything depends on it.
* Good: two bare-`CoordinatorScreen` pseudo-players are gone; there is one way to open the player.
* Good: the badge label is computed once instead of once per player state — with three badge kinds, the old duplication would have drifted.
* Bad: no way *up* from station/roleplay mode except the pinned picker row. Accepted deliberately over a history stack; the pinned row is one tap and always visible.
* Bad: `openContextTarget` is a convention call sites must adopt — a new list-tap site that calls `show()` directly still works, it just won't enter the player. Preferred over a global intercept for the reasons above.

## Pros and cons of the options

### Option A
* See *Consequences* above.

### Option B
* Good: "back" inside the player feels like ordinary navigation.
* Bad: X becomes state-dependent, needs a matching `PopScope` fix so Android back agrees, and needs a root-target field every entry point must set. Three mechanisms where Option A needs none.

### Option C
* Good: zero cost.
* Bad: leaves the inconsistency the maintainer raised, and leaves the latent `show()`-over-inline bug in place — which would have surfaced the moment anything else made the player render targets faithfully.

## Links

* Related: ADR-0026 (sheet-based context navigation and replace-semantics — this extends the same target vocabulary to an inline host), ADR-0049 (the adaptive picker primitive `showPlayerTargetPicker` builds on), ADR-0048 / DESIGN-010 (the resolve-context cascade each mode's screen seeds), DESIGN-001 (the player itself; its V1 scope parked the "observer player" variants this delivers).
* Related code: `lib/views/widgets/context_sheet.dart`, `lib/views/drill_player/drill_player_coordinator.dart`, `lib/views/drill_player/drill_mini_player.dart`, `lib/views/drill_player/player_mode.dart`, `lib/views/drill_player/player_target_picker.dart`, `lib/views/drill_player/drill_player_scope.dart`.
