---
status: accepted
date: 2026-07-28
deciders: ["kengu"]
consulted: []
informed: []
---

# ADR-0057: Editing is gated on the device's role, and frozen on a running exercise

## Context and problem statement

`AppUserRole` existed to pick a default brief audience: an Øvelsesleder saw director content, a Veileder saw instructor content (ADR-0038, DESIGN-006 step 4). It had no bearing on what the device could *change*.

Meanwhile every list grew its own edit affordances — `Dismissible(endToStart)` swipe-to-edit plus `ExpandableTile.onLongPress` (ADR-0031), create FABs, "+ Legg til" rows, AppBar pencils. None of them asked who was holding the device, and none asked whether an exercise was running. So on a live exercise every role could swipe a post open and edit it mid-drill, which the maintainer reported as plainly wrong.

Two problems, and they are separable:

* **Who may edit what.** The staff roles do different work; the affordances treated them identically.
* **When editing is safe at all.** An exercise's structure — its rounds, its posts, its rotation — is what every other device in the drill is rendering from. Changing it under a running exercise invalidates their state.

There was also no third role. "Actors may change roleplays" had nowhere to live, since `AppUserRole` held only director and instructor.

## Decision drivers

* One statement of the rules. Seven surfaces carry edit affordances; a rule repeated seven times is a rule that drifts.
* An affordance a role cannot use should not be visible. A create button that errors on tap is worse than one that is absent.
* The role must be changeable in passing, and changing it must take effect immediately on everything already on screen.
* A live exercise must not be edited out from under the devices following it — with one deliberate exception.

## Considered options

* **Option A — a permission function plus wrapper widgets.** `canEdit(role, target)` states the matrix; `IfEditable` and `EditableRow` are the only ways an affordance reaches the screen.
* **Option B — a `canEdit` call at each site.** Same predicate, no wrappers.
* **Option C — gate at the form instead.** Let every affordance through and refuse inside the editor.

## Decision outcome

Chosen option: **Option A**.

Option B was rejected on a specific failure mode: an ungated affordance looks exactly like a gated one in review, because the absence of a call is invisible. An unwrapped button is visibly missing something. With seven surfaces and more arriving, that difference is the whole safety margin.

Option C was rejected because it moves the discovery to after the tap: the user swipes, the editor opens, and *then* they are told no — or worse, the editor opens read-only and looks broken. It also does nothing about the affordance's presence, which is itself information about what this device is for.

### The roles

`AppUserRole` gains **actor** — the person, not the character; an `Actor` in the roster is who portrays a `RolePlay`. Norwegian calls both "markør", matching field practice, so the label does too.

An actor reads the brief as a **director**, not as a reduced audience. They are staff running the scenario from the inside and need the same detail, including other actors' PII, since they have to find and work with them. Participants are the audience that gets less, and they do not use the app.

### Three questions, not one

An affordance asks one of three things, and they have genuinely different answers (`EditPermission` names which):

* `canEdit(role, target, {exerciseUuid})` — change something that exists.
* `canDelete(...)` — remove it. **Director only**, for every target, and with **no live exemption**.
* `canCreate(...)` — add a new one. Director only, *except* the staff roster, which an actor may add themselves to.

Delete does not inherit edit's delegations because removing content is a command act, not authorship. An actor writes a markør's script; an instructor adjusts a team; neither thereby removes one from the plan — nor the persons and locations a scenario references, which an actor *overrides* rather than deletes. And where editing a live roleplay is the point of the exemption, deleting one the running exercise still references is unrecoverable, so the live lock is absolute for delete.

Create split off for the roster: anyone working the exercise can put themselves on the staff list, while changing or removing *other people's* records stays with the director.

### The matrix

| | plan | exercise | station | team | roleplay | staff roster |
|---|---|---|---|---|---|---|
| **director** | edit · create · delete | edit · create · delete | edit · create · delete | edit · create · delete | edit · create · delete | edit · create · delete |
| **instructor** | | | | edit | | |
| **actor** | | | | | edit | create |

`EditTarget` is deliberately coarser than the model: permission follows the *kind of work* a role does, not the entity graph. A station's persons and locations are part of building the scenario, so they answer as `station` rather than earning entries of their own.

**Reordering counts as editing.** Changing the order of exercises or posts renumbers them for every device reading the plan, so it is director-only — both the drag-handle mode and the one-shot sort actions, which commit an order just as permanently. Gated inside `ReorderableSection` itself (a required `target`) rather than at its call sites, so a new reorderable list cannot ship ungated.

**Known gap: "only myself" is not expressible.** The intent for the roster is that an actor may add *and manage their own* entry. Only the add half is implemented: nothing links this device to a particular roster record, because DESIGN-011 deliberately keeps roster people separate from app users. So an actor may create an entry but may not edit or delete one, including their own. Narrowing that to self needs the account link on the ADR-0024/0025 track; DESIGN-011's `Staff` model (director/instructor/other as stored roles, markør derived from casting) is where the roster grows the other staff kinds this rule will then cover.

### The live lock

While an exercise is running, its structure is frozen — for **everyone, including the director**. Changing rounds or posts under a drill in progress invalidates what every other device is showing.

**Roleplays are the exception.** A marker's behaviour is exactly what gets adjusted mid-scenario, so it stays editable while live. That is the one edit the lock lets through, and it is why the exception exists at all.

The lock is scoped to the exercise actually running (`ExerciseService.isStartedOn`), not to "something is running": a different exercise's posts are still being planned while this one runs. Plan-level targets (the plan, the roster) are not tied to an exercise and so are not locked by one.

### The wrappers

* `IfCreatable` — the gate for every "+" affordance: create FABs, "+ Ny person" rows, AppBar add buttons. Hides rather than disables, because a create action a role will never have is noise, not information. (Contrast the drill player's picker, which keeps rows *visible but inert* to explain a **temporary** live lock — a permanent absence and a temporary refusal want different treatments.)
* `IfEditable` / `IfDeletable` — the same, for a single affordance that changes or removes something that exists: an AppBar pencil, an AppBar bin. Separate widgets rather than one with a flag, so the stricter question is visible at the call site — `IfEditable(destructive: true)` next to a bin reads as a typo.
* `EditableRow` — swipe-to-edit and long-press-to-edit in one place, since they are one affordance conceptually. Each list previously built its own `Dismissible` with its own background and `confirmDismiss`, kept consistent by hand. When the role may not edit, the row renders bare: no swipe, no long-press, no background. Not a disabled state — a swipe that visibly starts and then snaps back reads as a bug rather than as a permission.
* `DeletableRow` — the delete twin, and deliberately **not** a mode of `EditableRow`: the two have opposite dismiss contracts. `EditableRow` returns false from `confirmDismiss` so the row springs back and a form opens; a delete row must confirm, dismiss for real, and have its caller remove the item. One widget doing both on a flag would mean silent data loss when the flag is wrong in one direction, and a row that mysteriously bounces back in the other.

All are built on `EditGate`, which listens to `appUserRole` and asks whichever of the three questions its `permission` names.

**Where a viewer's affordance is gated, the pattern is: the role *hides*, the live lock *disables*.** A role that never gets an action should not see a dead button; a temporary freeze should say why, which is what the `stopExerciseFirst` tooltip is for.

### The role becomes listenable, and readable synchronously

Gating forced two changes to how the role is read.

`appUserRole` is now a `ValueNotifier`. Before, the role was read once per screen and never re-read, so switching it would have left every open surface stale — a gated affordance is only honest if it reacts.

And it is read **synchronously**, through the `Prefs` service. An awaited read lands a frame late, and for a gate that frame shows the affordances of the *wrong role*. That is also what made the brief render once as director and again when the stored role arrived, showing the wrong audience in between.

### Where the role is chosen

Out of Settings, into the drawer header's trailing corner (compact) and the navigation rail's trailing slot (medium/expanded). The role decides what the UI offers now, so three taps deep in Settings is the wrong depth for it. Its icon is `Icons.face` — this app's established one-concrete-actor sign, carried by `FaceBadgeIcon` and the cast pill.

### Consequences

* Good: the rules exist once, and are tested from both directions — an actor may edit roleplays *and nothing else*, and may delete nothing at all.
* Good: the three questions make the interesting cases statable in one line each, instead of hiding in which wrapper a surface happened to use.
* Good: an affordance cannot be added without meeting the gate, because the wrapper is how it gets on screen.
* Good: switching role updates every affordance already visible.
* Bad: the wrappers are a convention, not an enforcement. A new affordance that skips them still renders. Mitigated by the wrappers being the shorter path, not by the type system — except for reordering, where `ReorderableSection` requires the `target` and so cannot be used ungated. That is the pattern to prefer when a shared widget owns the affordance.
* Bad: the roster rule is broader than intended until self-identity exists (see the gap above): an actor may add anyone, not only themselves.
* Bad: hiding rather than disabling means a role cannot discover *why* something is absent. Accepted for permanent absences; the live lock is the case where the app explains itself instead.
* Bad: the matrix is device-local and advisory. It shapes the UI; it is not authorisation. Anyone can change their own role, and nothing on the wire depends on it — ADR-0025 owns actual authorisation, for catalog writes.

## Pros and cons of the options

### Option A
* See *Consequences* above.

### Option B
* Good: no new widgets.
* Bad: a missing gate is invisible in review, across seven surfaces and counting.

### Option C
* Good: one enforcement point.
* Bad: tells the user no *after* they act, and leaves affordances on screen that describe capabilities the device does not have.

## Links

* Related: ADR-0031 (the swipe and long-press affordances this gates), ADR-0038 (the onboarding that introduced `AppUserRole`), ADR-0019 (the session participant roles — a different axis: coordinator/observer/roleplayer describe a *session*, not this device's staff function), ADR-0025 (real authorisation, for catalog writes), ADR-0049 (the picker the role selector is built on), DESIGN-006 step 4 (role → brief audience).
* Related code: `lib/services/edit_permissions.dart`, `lib/services/app_user_role.dart`, `lib/views/widgets/edit_affordance.dart`, `lib/views/widgets/app_user_role_selector.dart`, `lib/utils/prefs.dart`.
