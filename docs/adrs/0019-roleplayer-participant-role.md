---
status: accepted
date: 2026-05-23
deciders: ["@kengu"]
consulted: []
informed: []
---

# ADR-0019: Roleplayer as a third session participant role

## Context and problem statement

[ADR-0018](./0018-roleplayer-data-model.md) introduced `RolePlay` (the publishable role) and `Actor` (the local PII record) at the program level. Both are program data and do not yet exist in the realtime/session layer defined by [ADR-0009](./0009-realtime-transport-and-session-model.md).

The session model today recognises a coordinator (writes `exercise` and `teams`) and other participants distinguished by `checkedInTeamUuid` (team member who broadcasts position) versus null (observer). SAR exercises need a third runtime participant role: a roleplayer — the human on the ground enacting a `RolePlay`. They need to see exercise state and the role they are playing, and to share position so the coordinator and observers can see where the role is.

A direct subquestion: whose identity travels over the wire? Actor records are PII and never leave the owner's device ([ADR-0018](./0018-roleplayer-data-model.md)). The session layer must signal "this participant is playing role X" without exposing the human behind X.

## Decision drivers

* Three UI participant roles must stay distinguishable: coordinator, observer, roleplayer. Collapsing roleplayer into observer was considered and rejected.
* Observer and roleplayer share the same player shell during runs. Their data shape on the wire is similar, and DESIGN-003 will treat them as variants of one UI surface.
* No PII over the wire. Other devices see the role name from local `rolePlays` lookup, not the Actor's real name. (Display alternative 1.)
* Minimal change to the SessionParticipant schema in ADR-0009. One optional field is preferable to a new participant type or enum.
* Position broadcasting (ADR-0012) extends naturally without restructuring. The broadcaster activates whenever the participant has either a team membership or a role assignment.

## Considered options

* **Option A (chosen):** Add `rolePlayUuid: String?` to `SessionParticipant`. A participant with `rolePlayUuid != null` is a roleplayer. Position broadcasting activates on `checkedInTeamUuid != null` OR `rolePlayUuid != null`.
* **Option B:** Add a `participantType` enum on `SessionParticipant`. Each role gets its own optional payload.
* **Option C:** Subsume roleplayer into observer with no model change. Distinguish them only in UI based on whether the local device has an Actor assignment.

## Decision outcome

Chosen option: **Option A**, because it extends the existing schema by one optional field, keeps all role distinctions in the same flat structure as `isCoordinator` and `checkedInTeamUuid`, and lets position broadcasting reuse the existing activation pipeline with a one-line condition change.

### Participant role mapping

The three UI roles map to flag combinations on `SessionParticipant`:

| UI role     | Condition                                        |
|-------------|--------------------------------------------------|
| Coordinator | `isCoordinator == true`                          |
| Roleplayer  | `rolePlayUuid != null`                           |
| Observer    | `isCoordinator == false && rolePlayUuid == null` |

`checkedInTeamUuid` is orthogonal to role. A roleplayer may also carry a `checkedInTeamUuid` if the role is operationally associated with a team for position-aggregation purposes, but the role-name takes precedence in display.

A device cannot hold roleplayer and coordinator simultaneously. The check-in UX enforces this by greying out the coordinator toggle when `rolePlayUuid` is set, and clearing `rolePlayUuid` if the user flips themselves to coordinator. The trust model is unchanged: the client enforces this, the server does not.

### Identity on the wire

Only `rolePlayUuid` travels in the session status. No `actorUuid`, no `displayName` derived from the Actor record. Other devices resolve the role's name and description from the program's `rolePlays` list locally. A participant who has not yet loaded the program shows a placeholder ("Ukjent rolle" / "Unknown role") until the program lands.

The owner of the roster (typically the coordinator) can still cross-reference locally: `rolePlayUuid → RolePlay.actorUuid → Actor.realName` lives entirely on their device. The session UI does not surface that mapping; it shows the role.

This preserves the [ADR-0018](./0018-roleplayer-data-model.md) PII boundary across the realtime layer without any new strip step.

### Position broadcasting

[ADR-0012](./0012-position-sharing-and-team-aggregation.md)'s broadcaster activation gains one term:

> This device's own `SessionParticipant.checkedInTeamUuid != null` **OR** `SessionParticipant.rolePlayUuid != null`.

Consent rules ([ADR-0012](./0012-position-sharing-and-team-aggregation.md): `app:liveConsent:v1` and `app:positionConsent:v1`) apply unchanged. The check-in prompt for a roleplayer surfaces the same position-sharing consent as for a team member.

Rendering distinguishes the two marker kinds visually. Team-member positions remain as today: a marker in the team's colour, labelled with `displayName`. Roleplayer positions render with a distinct shape (proposed: a tagged circle, exact glyph in DESIGN-003) so the operator can tell a markør from a field broadcaster at a glance. The marker label is the role name from the local `rolePlays` lookup.

### Patch authorization

The `participant_position` patch authorization in ADR-0009 currently reads:

> the device whose `participantId` matches the patch, provided their `participants[participantId].checkedInTeamUuid` is non-null.

It becomes:

> the device whose `participantId` matches the patch, provided their `participants[participantId].checkedInTeamUuid` is non-null OR `rolePlayUuid` is non-null.

`participant` patches that toggle `rolePlayUuid` follow the same self-ownership rule as the rest of the patch protocol: a device may only set its own slot. Multiple devices claiming the same `rolePlayUuid` simultaneously is allowed by the protocol (the coordinator UX surfaces it as a conflict the operator resolves off-app).

### Player UI

Observer and roleplayer share the observer-player shell from DESIGN-001. DESIGN-003 specifies the role-specific tab content (role brief, signalement, behaviour notes) and how it slots in alongside the existing lag/post tabs. ADR-0019 commits only to the shell sharing, not to the tab layout.

The coordinator player ([DESIGN-001](../design/exercise-player.md)) gains awareness of roleplayer participants in its participant list and on the map, but its own three-tab structure is unchanged.

### Consequences

* Good: One new optional field on `SessionParticipant`. Backward compatible. A 1.0-client opening a session with roleplayers simply does not display them.
* Good: PII boundary from [ADR-0018](./0018-roleplayer-data-model.md) extends naturally to the realtime layer. No new strip step, no new privacy-gate.
* Good: Position broadcast reuses the existing pipeline with a one-line activation condition.
* Good: Observer-player shell carries the new role without a parallel UI tree.
* Bad: Devices that do not yet have the program loaded show a placeholder for the role name until the program lands. The same is true for team names today, so this is a known and accepted UX pattern.
* Bad: A roleplayer who joins via the catalog (no `actors/` folder, [ADR-0018](./0018-roleplayer-data-model.md)) has no local Actor record. They pick a `RolePlay` to play directly. The link "which human is playing which role" exists only on the coordinator's device when peer-to-peer transport was used. This is a feature of the privacy model, not a bug, but it shapes how casting flows in DESIGN-003.
* Bad: Coordinator-and-roleplayer mutual exclusion is client-enforced only. A misbehaving client could publish both flags; the rest of the system tolerates it (the role wins in display, the coordinator authorisation still applies on `exercise`/`teams` writes).

## Pros and cons of the options

### Option A — `rolePlayUuid` field on `SessionParticipant` (chosen)

* Good: One optional field. Backward compatible. Matches the flat-flag pattern of `isCoordinator` and `checkedInTeamUuid`.
* Good: Trivial extension to the position broadcaster's activation condition.
* Bad: Encodes the role distinction implicitly via a flag combination rather than an explicit type.

### Option B — `participantType` enum

* Good: Each role has a named type, no flag-combination decoding at the call site.
* Bad: Breaks the additive evolution of the existing schema. Existing devices write `isCoordinator` and `checkedInTeamUuid`; introducing an enum forces every reader to handle both shapes during the migration.
* Bad: Adds three places to keep in sync (enum, flag fields, validation), where Option A adds one field.

### Option C — Subsume roleplayer into observer

* Good: Zero schema change.
* Bad: The coordinator cannot tell from the session status alone whether a participant is enacting a role or just watching. Resolving that would require a side channel or local-only state, which contradicts the "one status envelope" rule from [ADR-0009](./0009-realtime-transport-and-session-model.md).
* Bad: Position broadcasting cannot be enabled selectively for roleplayers without a wire-visible signal.

## Links

* Related ADRs:
  * [ADR-0009](./0009-realtime-transport-and-session-model.md) — extends `SessionParticipant` schema and `participant_position` authorization rule.
  * [ADR-0011](./0011-synchronized-exercise-control.md) — coordinator role unchanged.
  * [ADR-0012](./0012-position-sharing-and-team-aggregation.md) — broadcaster activation gains a `rolePlayUuid` term, rendering gains a distinct marker for roleplayers.
  * [ADR-0018](./0018-roleplayer-data-model.md) — defines `RolePlay` and `Actor` at the program level. PII boundary preserved.
* Related designs:
  * [DESIGN-001](../design/exercise-player.md) — observer-player shell, now shared with roleplayer.
  * Planned DESIGN-003 — Markører-fanen, role-specific tab content in the player shell.
* Related code:
  * `lib/data/session_status.dart` — new `rolePlayUuid` field on `SessionParticipant`.
  * `lib/services/position_broadcast_service.dart` — activation condition gains a `rolePlayUuid` term.
  * `lib/views/map_view.dart` — distinct marker rendering for roleplayer positions.
  * `lib/views/session_check_in_screen.dart` — roleplayer option in the check-in UX, with the coordinator toggle greyed when a role is selected.
