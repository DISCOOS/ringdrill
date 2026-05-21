---
status: accepted
date: 2026-05-20
deciders: ["@kengu"]
consulted: []
informed: []
---

# ADR-0011: Synchronized exercise control with coordinator-driven state

## Context and problem statement

[`ExerciseService`](../../lib/services/exercise_service.dart) is a local singleton today. It computes phase and round deterministically from the exercise's `startTime`, the three durations and the wall clock. Two devices running the same exercise show the same phase at the same wall-clock moment, but there is no shared "start" and no way to skip a round. A coordinator's decision to start a drill earlier or jump ahead never reaches the other devices.

This ADR introduces coordinator-driven exercise state broadcast through the [ADR-0009](./0009-realtime-transport-and-session-model.md) session-status transport. Start, stop and manual round transitions issued by any coordinator take effect on all devices within the three-second latency target. The `SessionExerciseState` and `SessionTeam` placeholders from ADR-0009 are filled in here. Sessions exist only for published catalog plans (per ADR-0009). Local plans are not synchronized between devices.

## Decision drivers

* The exercise math in [`ExerciseService`](../../lib/services/exercise_service.dart) is already deterministic given an effective start time and the three durations. Followers should compute their own state from a small broadcast description, not from a stream of per-second tick events.
* The transport from ADR-0009 carries small slot-scoped patches with three-second polling and cache-purge. Exercise state is low-volume (start, round jumps, stop) and fits naturally in the existing `exercise` slot.
* Coordinators are participants who self-assign the role. Multiple coordinators may exist per session. Authority is independent of slug ownership: the person who published the plan is not necessarily the person running today's drill.
* Network loss must be survivable. A device that misses messages keeps showing what it last saw, advancing local time, and converges back to the broadcast state on the next successful read. The math must not desync silently when a device disconnects and reconnects.
* The CLI must stay Flutter-free per [ADR-0005](./0005-cli-must-remain-flutter-free.md). New session-aware code lives in services and data, not in the CLI.

## Considered options

* **Coordinators broadcast state, all devices compute locally (chosen).** Coordinator publishes `SessionExerciseState` (`runState`, `runningSince`). Every device (coordinator and follower alike) feeds it into the existing deterministic timer.
* **Coordinators broadcast ticks.** Coordinator publishes a new `ExerciseEvent` on every phase transition. Heavier traffic and redundant given the math is already deterministic.
* **Peer-to-peer consensus.** Disproportionate complexity for a coordinator-led drill.

## Decision outcome

Chosen option: **coordinators broadcast state, all devices compute locally**, because it reuses the deterministic math in `ExerciseService`, keeps the broadcast payload small enough to fit comfortably inside the function-invocation budget, and degrades gracefully under packet loss.

### Filling in the placeholders from ADR-0009

`SessionExerciseState` and `SessionTeam` become:

```dart
@freezed
sealed class SessionExerciseState with _$SessionExerciseState {
  const factory SessionExerciseState({
    /// uuid of the Exercise currently being run. The full Exercise is read
    /// from the local program (active program, by uuid), not broadcast.
    /// All devices must have the same program installed for this to work.
    required String exerciseUuid,

    required DrillRunState runState,

    /// Wall-clock time the timer was last (re)started. Null when runState
    /// is pending or done. Round jumps move this backwards: jumping to
    /// round N sets runningSince = now - N × roundDurationSeconds so the
    /// natural math lands on the requested round.
    DateTime? runningSince,

    /// Identifier of the device that owns this exercise state. Null for
    /// catalog plans where ownership is implied by ownsCatalogSlug.
    String? ownerParticipantId,
  }) = _SessionExerciseState;
}

enum DrillRunState { pending, running, done }

@freezed
sealed class SessionTeam with _$SessionTeam {
  const factory SessionTeam({
    /// The local `Team.uuid` value. This is the stable identifier and is
    /// what `SessionParticipant.checkedInTeamId` and
    /// `ParticipantPosition.teamUuid` reference.
    required String teamUuid,

    /// The team's display name, copied from `Team.name`.
    required String name,

    /// The team's position in the local team list, copied from
    /// `Team.index`. Used for stable ordering and color assignment in
    /// the UI. Not an identity field.
    required int index,
  }) = _SessionTeam;
}
```

The `teams` slot is written by a coordinator at session creation, derived from the Exercise's `numberOfTeams` and the local team registry. It is updated only when the registry changes.

### Effective elapsed time

When `runState == running`, `effectiveElapsedSeconds = now - runningSince`. Otherwise the elapsed value is not meaningful for phase or round computation. From this single number, `ExerciseService`'s existing math produces phase, round and progress.

### Coordinator actions and the patches they produce

| Action          | Patch                                                                                              | Effect on state                                                                       |
|-----------------|-----------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------|
| Start drill     | `exercise` with `runState=running, runningSince=now, exerciseUuid=...`                              | Followers' timers spin up and display execution phase of round 0.                     |
| Jump to round N | `exercise` with `runState=running, runningSince=now - N × roundDurationSeconds`                     | Followers snap to the phase and round implied by the rewound `runningSince`.          |
| Stop            | `exercise` with `runState=done, runningSince=null`                                                  | All devices show the "done" state.                                                    |

Restart-from-scratch is a `stop` followed by a fresh `start`.

### Authorization

The `exercise` and `teams` patches require the writer's participant slot to have `isCoordinator == true`. There is no bearer token, no slug-ownership requirement, no separate credential.

Coordinator is an opt-in role that any participant can self-assign by patching their own slot (per [ADR-0009](./0009-realtime-transport-and-session-model.md) patch protocol). Multiple coordinators may exist in the same session. This matches the social reality of a SAR drill: the publisher of a catalog plan is not always the person running today's drill, and authority to coordinate may shift between staff during the weekend (handover at shift change, takeover if the primary coordinator's device fails, parallel coordination of separate sub-drills).

Conflicts between coordinators are resolved last-writer-wins per slot. Honest coordinators rely on radio and physical coordination off-app to avoid stepping on each other. The UX must surface the coordinator list and recent state changes so participants stay aware of who is driving the drill.

Followers (non-coordinator participants) patch only their own slots and never write `exercise` or `teams`.

### Pairing the local ExerciseService with the broadcast state

`ExerciseService` gains two thin operating modes.

* **Coordinator mode.** `start`, `jumpToRound(n)` and `stop` run the existing local logic and publish the corresponding `SessionExerciseState` patch through `LiveStatusService`.
* **Follower mode.** A new `mirror(SessionExerciseState, Exercise)` method drives the internal state from the broadcast. The same `_progress` loop emits the same `ExerciseEvent` stream. Start/stop/jump controls are hidden in the follower UI.

`LiveStatusService` decides "am I a coordinator" from this device's own participant slot. The mode can flip mid-session if the user toggles the coordinator role.

### Network loss

A device that loses its connection keeps computing locally from its last `SessionExerciseState`. The math is deterministic, so a brief outage produces the same display as if the device had stayed connected. On reconnect it adopts the latest state, which only differs from the local computation if a coordinator stopped the drill or jumped while the device was offline.

If all coordinators disconnect, the session retains the last published state. Followers continue computing. When any coordinator reconnects, its next action propagates as normal.

### Cost

State patches are rare. Per intensive drill weekend:

```
Start writes:    ~7 (one per drill)
Round jumps:     ~5 (rare manual overrides)
Stop writes:     ~7
Teams updates:   ~5 (mostly at session creation)
Total:           ~24
```

That is well inside the ~140 state writes already budgeted in ADR-0009's cost model. No revision to the cost analysis is needed.

### Where the code lives

* `lib/data/session_status.dart` gets the filled-in `SessionExerciseState` and `SessionTeam` types.
* `lib/services/exercise_service.dart` gains `jumpToRound(n)` and a `mirror` method. The existing `start` and `stop` keep their current signatures.
* `lib/services/live_status_service.dart` wires coordinator-role detection (own participant slot) to ExerciseService.
* No new keys in `lib/utils/app_config.dart`. Authorization reuses the existing slug-ownership flag and the upload ETag.
* `lib/views/coordinator_screen.dart` exposes start/stop/jump controls when the device has `isCoordinator == true`, hides them otherwise. It also surfaces the list of current coordinators so the user can see who else is driving.
* `lib/data/live_status_client.dart` already exposes `patchExercise` and `patchTeams` from ADR-0009. No client API additions.

### Consequences

* Good: Reuses the deterministic math already in `ExerciseService`. Followers get the same `ExerciseEvent` stream the local-only path produces.
* Good: State is captured in two fields (`runState`, `runningSince`). No bloat on `ExercisePhase` or existing UI bindings.
* Good: Network loss is recoverable. Followers continue locally and converge on reconnect.
* Good: Cost is negligible on top of ADR-0009. Exercise state is low-volume.
* Good: Multi-coordinator support is robust to handover, device failure and parallel sub-drills. The publisher of a plan does not have to be the runtime driver.
* Bad: Local plans are not synchronized between devices. By design, but worth stating explicitly.
* Bad: Round jumps rewind `runningSince` and lose elapsed bookkeeping for the skipped portion. The math snaps to the new round. Intended UX.
* Bad: Two coordinators issuing conflicting commands resolve last-writer-wins. The UI may flicker briefly. Honest coordinators rely on radio off-app to avoid this.
* Bad: A participant can self-assign as coordinator without any check. Trust is at the UX layer, not the protocol. A malicious participant could disrupt a drill. Acceptable risk for the trust model the rest of the app already operates under (anyone with the link can join).
* Bad: Followers see a brief lag between coordinator actions and their own state. Bounded by the three-second poll plus cache-purge propagation. Acceptable for drill-control actions.

## Pros and cons of the options

### Coordinators broadcast state, all devices compute locally (chosen)
* Good: Tiny payload, deterministic math, robust to packet loss.
* Bad: All devices must hold the same Exercise definition locally.

### Coordinators broadcast ticks
* Bad: Higher traffic, no graceful degradation under loss.

### Peer-to-peer consensus
* Bad: Disproportionate complexity for a coordinator-led activity.

## Migration plan

1. Add `DrillRunState`, fill in `SessionExerciseState` and `SessionTeam` in `lib/data/session_status.dart`. Run `make build`.
2. Add `jumpToRound(n)` to `ExerciseService`. It rewinds the internal start time and lets the existing `_progress` loop produce the rest.
3. Add `ExerciseService.mirror(state, exercise)` and route it through `LiveStatusService` for follower devices.
4. Wire the session-status write function to validate `exercise` and `teams` patches against `participants[writerId].isCoordinator`.
6. Update `coordinator_screen.dart` to show start/stop/jump controls when `isCoordinator == true`, hide otherwise. Surface the list of current coordinators.
7. Test under live session conditions: start, jump, stop, network drop and reconnect.

## Links

* Related ADRs: [ADR-0005](./0005-cli-must-remain-flutter-free.md), [ADR-0008](./0008-persistent-program-library-and-catalog.md), [ADR-0009](./0009-realtime-transport-and-session-model.md)
* Related code: `lib/services/exercise_service.dart`, `lib/services/live_status_service.dart`, `lib/data/session_status.dart`, `lib/data/program_repository.dart`, `lib/views/coordinator_screen.dart`, `lib/services/notification_service.dart`
