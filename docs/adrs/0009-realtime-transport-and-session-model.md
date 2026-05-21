---
status: accepted
date: 2026-05-20
deciders: ["@kengu"]
consulted: []
informed: []
---

# ADR-0009: Short polling with CDN-cached session status as live transport

## Context and problem statement

RingDrill is single-device today. [`ExerciseService`](../../lib/services/exercise_service.dart) is a local singleton that computes phase and round from wall-clock time. Catalog refresh in [`ProgramService.refreshCatalogItem`](../../lib/services/program_service.dart) is pull-based, using `HEAD` with `If-None-Match` against `/api/drills/head/:slug`. The Netlify backend exposes only stateless REST functions (see [`netlify.toml`](../../netlify.toml)).

Three planned capabilities need a live channel between devices that have the same plan open:

* Live catalog updates (ADR-0010): when a published plan gets a new version, other devices with that plan open should be notified without manual refresh.
* Synchronized exercise control (ADR-0011): start, stop, pause and manual round transitions on one device must reflect on the others.
* Position sharing (ADR-0012): each participant device is "checked in" to a team and broadcasts that team's position to the others.

All three need the same shape: a small per-session state that any participant can read and that authorized participants can update slot by slot. This ADR commits the transport, the session schema and the patch protocol that the three capability ADRs build on.

## Decision drivers

* Infrastructure complexity stays low. No new external services, no new credentials beyond what Netlify already provisions automatically.
* Free plan only. The Netlify Free plan has a hard credit cap and cannot incur charges. No payment method on the team, no auto-recharge. The math must close inside 300 credits per month including existing baseline traffic.
* End-to-end latency from a publisher write to a follower read is three seconds or less.
* One function pair (read and write) serves all three capabilities. The status schema is rich enough to cover exercise state, team registry, participant check-ins and team positions.
* The app runs on Android, iOS, web/PWA, macOS, Linux and Windows on the same `package:http` we already use.
* There is no user identity. The trust model is "anyone with the link can join."
* The CLI ([`bin/ringdrill.dart`](../../bin/ringdrill.dart)) must stay Flutter-free per [ADR-0005](./0005-cli-must-remain-flutter-free.md).
* Network telemetry is opt-in per [ADR-0006](./0006-sentry-behind-consent-gate.md).
* Offline must still work. A device that loses the network keeps running the current drill on its local clock and reconciles on reconnect.

## Considered options

* **Short polling with CDN-cached status objects and patch-style writes (chosen).** A small JSON status object per session in Netlify Blobs. A read function serves it with `Cache-Control: s-maxage=60` and ETag. A write function accepts slot-scoped patches and purges the CDN cache on each write. Clients poll every three seconds with `If-None-Match`.
* **Managed pub/sub service (Ably).** Sub-second latency, but pulls in a vendor, a credential and a native plugin on mobile.
* **Self-hosted WebSocket server.** Predictable cost and full control, but introduces ops overhead.
* **Long polling against Netlify Functions.** Burns the compute meter by reserving memory for the duration of the hold. Worse on Free plan than short polling.
* **Split transport, one for state and one for positions.** Doubles the consent gates and debug paths.

## Decision outcome

Chosen option: **short polling with CDN-cached session status and patch-style writes**, because it meets the three-second latency target with mandatory cache-purge, fits inside the Free plan at expected usage, and accommodates all three capabilities in a single status envelope with one function pair.

### Session model

A session is the unit of "everyone currently coordinating on the same plan." Sessions only exist for **published catalog plans**. Local plans are single-device by definition and are not synchronized through this transport.

The session key is derived from the catalog slug:

```
catalog:<slug>
```

Followers automatically poll when a catalog plan is opened, subject to consent.

Each device gets a participant ID, a nanoid persisted under `app:participantId:v1`. The ID is per-device, stable across restarts, and used both as the writer identity on patches and as the slot key in the `participants` map.

### Status object schema

The schema is locked here. Capability ADRs fill in slot semantics without adding new top-level fields.

```dart
@freezed
sealed class SessionStatus with _$SessionStatus {
  const factory SessionStatus({
    required String sessionKey,
    required int version,              // bumped server-side on every write
    required DateTime updatedAt,       // server-side wall clock at last write

    /// Exercise state. Owned by the session owner. Filled by ADR-0011.
    /// Null when no drill is active yet.
    SessionExerciseState? exercise,

    /// Team registry for this session. Owned by the session owner.
    /// Filled by ADR-0011.
    @Default([]) List<SessionTeam> teams,

    /// Participants currently connected, keyed by participantId.
    /// Each device owns its own slot.
    @Default({}) Map<String, SessionParticipant> participants,

    /// Latest raw position per broadcasting participant, keyed by participantId.
    /// Each entry carries the teamUuid the participant contributes to.
    /// Multiple participants checked in to the same team each get their own
    /// slot here. Aggregation into a single "team position" (centroid,
    /// staleness filtering, outlier rejection) is defined by ADR-0012.
    /// Filled by ADR-0012.
    @Default({}) Map<String, ParticipantPosition> positions,
  }) = _SessionStatus;
}

@freezed
sealed class SessionParticipant with _$SessionParticipant {
  const factory SessionParticipant({
    required String participantId,

    /// User-provided name shown to other participants in the UI. Optional.
    /// Set at check-in (or left null) and can be edited any time by
    /// patching one's own slot. Falls back to "Anonym" or similar in
    /// the UI when null.
    String? displayName,

    /// Team membership, by the local `Team.uuid` value. A teamUuid means
    /// "checked in as a member of that team, broadcasting
    /// participant_position for it." Null means "no team membership
    /// (observer or pure coordinator)." Independent of isCoordinator:
    /// a team member can also be a coordinator.
    String? checkedInTeamUuid,

    /// Coordinator role. When true, this device is authorized to write
    /// the `exercise` and `teams` slots. Self-declared by patching one's
    /// own participant slot. Multiple coordinators may exist in the same
    /// session. Trust model matches the rest of the patch protocol: the
    /// app trusts participants to self-select honestly.
    @Default(false) bool isCoordinator,

    /// When this participant joined the session. Client-supplied on the
    /// check-in patch, never changes after.
    required DateTime joinedAt,

    /// Server-maintained. Bumped on every patch the participant authors
    /// (participant updates, team_position updates, etc.). The UI treats
    /// stale values as "inactive but not removed." There is no separate
    /// heartbeat. Positions and other writes serve as the presence signal.
    required DateTime lastSeenAt,
  }) = _SessionParticipant;
}

@freezed
sealed class ParticipantPosition with _$ParticipantPosition {
  const factory ParticipantPosition({
    required String participantId,

    /// The team this participant contributes a position for, by the
    /// local `Team.uuid` value. Must match
    /// participants[participantId].checkedInTeamUuid at write time.
    /// Captured here so readers do not have to cross-reference the
    /// participants map to know which team a position belongs to (and
    /// so historical data remains interpretable if the participant later
    /// switches role).
    required String teamUuid,

    required double latitude,
    required double longitude,
    double? accuracyMeters,
    required DateTime reportedAt,
  }) = _ParticipantPosition;
}
```

`SessionExerciseState` and `SessionTeam` are placeholder freezed classes with empty bodies. ADR-0011 fills them in.

### Patch protocol

Writes are slot-scoped patches. A patch addresses one slot and is rejected if the writer is not authorized for that slot.

```json
{
  "patch": "participant",
  "participantId": "abc123",
  "data": { "displayName": "Bravo", "checkedInTeamUuid": "t_aB3kZ", "lastSeenAt": "2026-05-20T12:34:56Z" }
}
```

| Patch kind          | Targets                       | Authorized writer                                          |
|---------------------|-------------------------------|-------------------------------------------------------------|
| `participant`       | `participants[participantId]` | The device whose `participantId` matches the patch. The first such patch is the check-in (sets team role, optional `displayName`, and any other fields). Subsequent patches update `displayName`, team membership or coordinator role. A device can only patch its own slot. |
| `participant_leave` | `participants[participantId]` (delete) | The device whose `participantId` matches the patch. Used for explicit check-out. |
| `participant_position` | `positions[participantId]` | The device whose `participantId` matches the patch, provided their `participants[participantId].checkedInTeamUuid` is non-null. Multiple participants checked in to the same team each write their own `positions` slot. Aggregation into a single team position is defined by ADR-0012. |
| `exercise`          | `exercise`                    | Any device whose `participants[writerId].isCoordinator == true`. Multiple coordinators may exist; conflicts are resolved last-writer-wins. |
| `teams`             | `teams`                       | Any device whose `participants[writerId].isCoordinator == true`. |

The server bumps `participants[writer].lastSeenAt = now` on every patch authored by `writer`, including `team_position` writes. Position broadcasts therefore double as a presence signal. There is no separate heartbeat patch.

A device that closes the app or revokes consent sends a `participant_leave` patch to remove its slot cleanly. Devices that disappear without leaving (network loss, killed app, dead battery) are left in `participants` with a stale `lastSeenAt` until the daily cleanup or until they reconnect.

**Check-in always picks a team role and optionally a name.** The check-in UX asks the user up front whether they are joining as a member of a specific team or as an observer, and lets them enter a display name (or leave blank). The team role is encoded in the first `participant` patch as `checkedInTeamUuid` and the name as `displayName`. A team-member check-in immediately starts the `participant_position` broadcast loop on the client. An observer check-in does not. Both name and team can be changed later by patching one's own slot.

**Coordinator role is independent and opt-in.** Any participant can flip their own `isCoordinator` flag at any time by patching their own slot. Coordinators are authorized to write the `exercise` and `teams` slots. Multiple coordinators may exist concurrently. The UX surfaces who currently holds the role so participants can stay aware of each other's actions.

Switching roles mid-session (observer takes over as Bravo team leader, or a team member takes the coordinator role) is a normal `participant` patch. The client stops or starts the position broadcaster as needed.

All slot-scoped patches are validated at face value (the writer claims its identity) against the relevant participant slot. `exercise` and `teams` patches additionally require the writer's slot to have `isCoordinator == true`.

Server-side merge:

1. Read current status from the blob with the blob's ETag.
2. Validate the patch shape and authorization.
3. Apply the patch (last-writer-wins per slot).
4. Bump `version`, set `updatedAt = now`.
5. Write back with `If-Match: <etag>`. On 412, retry once after re-reading. After two failed attempts, return 409 to the client.
6. Purge the CDN cache for the read URL.
7. Return `{ version, updatedAt }` to the writer (so the writer can echo-suppress its own emission on the next poll).

Patch envelopes are around 200 bytes. The status object stays under 5 KB even with ten participants and ten teams.

### Endpoints

```
GET  /api/sessions/:key/status     → sessions-status-read.js
POST /api/sessions/:key/status     → sessions-status-write.js
```

`GET` reads the blob and returns:

```
Cache-Control: public, max-age=2, s-maxage=60, stale-while-revalidate=10
ETag: "<sha256-of-body>"
Content-Type: application/json
```

`s-maxage=60` is a fail-safe ceiling. In practice the cache is purged on every write, so the edge serves stale only during purge propagation (Netlify reports under one second in normal operation).

`POST` accepts a patch, validates, merges, writes, purges. Returns `{ version, updatedAt }` on success.

Client poll loop:

1. Initial GET without ETag, parse status, emit, remember ETag.
2. Every three seconds: GET with `If-None-Match: <lastEtag>`.
3. On 304: do nothing.
4. On 200 with new ETag: parse, diff slot-by-slot, emit changes.
5. On network error: exponential backoff up to 30 seconds, then keep retrying.

Worst-case latency is three seconds (poll) plus purge propagation (≤ one second). Typical case is under three seconds.

### Client wrapper

`lib/data/live_status_client.dart` exposes:

```dart
abstract class LiveStatusClient {
  Stream<SessionStatus> watch(String sessionKey, {Duration interval});

  /// Check in (first call, must include role via checkedInTeamUuid or null
  /// for observer) or update self (subsequent calls: change display name
  /// or switch role).
  Future<int> patchParticipant(String sessionKey, SessionParticipant participant);

  /// Check out. Removes the participant slot.
  Future<int> leaveParticipant(String sessionKey, String participantId);

  Future<int> patchParticipantPosition(String sessionKey, ParticipantPosition position);

  /// Authorized only when the device's own participant slot has
  /// isCoordinator == true. The server validates against that slot.
  Future<int> patchExercise(String sessionKey, SessionExerciseState exercise);
  Future<int> patchTeams(String sessionKey, List<SessionTeam> teams);

  Future<void> disconnect();
}
```

Each patch returns the new server `version` for echo-suppression. `HttpLiveStatusClient` uses `package:http` and stays Flutter-free, so the wrapper could be reused from the CLI per [ADR-0005](./0005-cli-must-remain-flutter-free.md).

`SessionStatus` and its slot types live in `lib/data/session_status.dart` as freezed sealed classes per [ADR-0002](./0002-freezed-models-with-extensions.md).

### Service layer

`LiveStatusService` in `lib/services/live_status_service.dart` owns the client lifecycle. It listens to `ProgramService` events to start and stop watching as the active plan changes, listens to the consent flag to disconnect on revocation, and exposes a `ValueListenable<SessionStatus?>` plus a stream for the UI.

### Consent gate

`app:liveConsent:v1` defaults to `false`. No polling, no traffic, no client instance until consent is granted. Exposed in the settings page alongside analytics consent. Wording must make clear that turning it off downgrades the app to single-device behavior.

## Free plan cost analysis

This analysis targets the **Netlify Legacy Free plan** that the project is on. Legacy Free has separate hard limits per meter (not a shared credit budget), and the binding meter for this design is **125 000 serverless function invocations per site per month**. Bandwidth (100 GB hard) and build minutes (300 hard) are not factors at the expected scale. All limits are hard caps with no overage billing.

### Cache miss rate is the lever

With `s-maxage=60` and purge-on-write, only the first GET after each cache invalidation hits the function. Subsequent GETs within the same window are CDN cache hits and do not count against the function meter. Per cache invalidation, the function is hit once per edge POP that has an active client. For a Norwegian audience the traffic typically lands on one or two POPs.

Function invocations per drill therefore scale with **writes**, not with poll volume:

```
invocations ≈ writes × (1 + popsWithClients)
```

For the cost model below we use two edge POPs, giving a 3x multiplier on writes.

### Baseline (no live transport)

Existing endpoints (`drills-upload`, `drills-head`, `market-feed`, `deep-link`, `drills-admin`) at expected traffic: ~5 000 invocations per month. Bandwidth for static assets is well under 1 GB per month. Build minutes consumed by ~4 production deploys per month: ~20.

Baseline ≈ **5 000 invocations per month** on the function meter. Headroom for live transport ≈ **120 000 invocations per month**.

### Per intensive drill weekend

Profile: 24 hours of active drill time over three days, 14 participants (10 team members + 4 staff), 5 active broadcasters (one per team, see assumption below). Position writes throttled to 15 seconds. No periodic heartbeat (presence is implicit, see [Patch protocol](#patch-protocol)).

```
Position writes:    5 broadcasters × 86 700s / 15s = 28 900
Check-in / role-switch writes (one-time per participant): ~30
State writes:                                              140
Check-out writes (one per participant at end):              14
                                                       -------
                                  Writes:               29 100

Reads past cache (2 POPs × writes):                     58 200
                                                       -------
                            Total invocations:          87 300
```

The model assumes **one active broadcaster per team**, typically the team leader's device. Other team members and instructors who check in to the same team appear in `participants` but do not broadcast their own position. The transport allows multiple broadcasters per team (each writes its own `positions[participantId]` slot, and ADR-0012 aggregates them), but the app UX nudges only one device per team to enable broadcast. If both members of every team broadcast, position writes double to ~58 000 and the cost roughly doubles to ~175 000 invocations per weekend, which would not fit on Legacy Free. ADR-0012 documents the UX guardrail.

Bandwidth for the same weekend: ~45 MB. Negligible against the 100 GB cap.

### Capacity per month

```
Headroom: 120 000 invocations
One intensive weekend ≈ 87 000 invocations
```

The plan therefore comfortably supports **one such weekend per month** with about 33 000 invocations headroom for additional smaller drills, dev/test traffic and unexpected bursts. Two intensive weekends in the same calendar month would push us over the cap (~175 000 invocations).

The math is sensitive to two things:

* **Position write frequency.** Going from 15-second to 5-second throttling would triple position writes to ~87 000, plus the cache-miss multiplier, sending us to ~260 000 invocations. The 15-second floor is mandatory under this design.
* **Number of edge POPs serving traffic.** A geographically dispersed audience (e.g., a published catalog plan with users on multiple continents) would multiply the reads-past-cache term. The estimate above assumes a regional audience and would need revisiting for a global one.

### Mitigations the design already includes

* **Adaptive polling.** Three seconds during active drills (between `exercise.startedAt` and `exercise.endedAt`), thirty seconds otherwise.
* **Background pause.** Polling stops when the app is backgrounded or hidden, resumes on foreground.
* **No periodic heartbeat.** Presence is implicit. Server bumps `lastSeenAt` on every patch the participant authors, so position broadcasts double as the presence signal. The UI marks a participant as inactive when `lastSeenAt` is older than 15 minutes. Stab and other observers who do not broadcast position will appear as inactive after 15 minutes from their last interaction. That is honest behavior, not a bug.
* **Position write throttling.** A `team_position` patch is sent only when the device has moved more than ten meters or fifteen seconds have elapsed since the last send.
* **Server-side rate limit.** The write function rejects more than one patch per session key per 500 ms.
* **Daily write cap.** `RINGDRILL_DAILY_WRITE_LIMIT` (default 50 000 writes/day across all sessions) returns 503 when exceeded.

### Behavior at the cap

Legacy Free has independent hard limits per meter. When the function-invocations meter is exhausted, functions stop responding (HTTP 5xx) but static assets and the CDN keep serving. Live transport goes dark, the rest of the app keeps working.

* No bill. No card on file, no overage, no charge.
* Static assets, deep links served from CDN cache, and the PWA shell keep working for installed users.
* The exercise math is deterministic and continues on each device's local clock. A drill in progress is unaffected on each device individually, only cross-device sync stops.
* Recovery is automatic at the start of the next billing cycle.

### Guardrails against runaway costs

1. Stay on Legacy Free plan. Hard caps per meter, no overage billing.
2. No payment method on the team account.
3. Do not migrate to the credit-based plan voluntarily. The switch is documented as irreversible, and credit-based bundles meters in a way that makes the runaway-cost scenarios harder to reason about.
4. Server-side rate limit and daily threshold cutoff in code, not in drift-prone configuration.
5. Weekly review of the Netlify usage dashboard during MVP, less often once stable. Netlify also sends notifications when approaching the limit.

If the model proves tight in production, the levers in order are: increase poll interval from 3s to 5s (cost: latency), increase heartbeat from 5min to 15min (cost: slower "who is here" UI updates), drop position write cadence (cost: jerkier position UI). Only after these are exhausted do we revisit the transport. ADR-0013 (planned) describes the alternative backend if and when that becomes necessary.

## Storage and lifecycle

Status objects live in Netlify Blobs, namespace `ringdrill-sessions`. Keys are `catalog/<slug>/status` and `plan/<programUuid>/status`. A scheduled function (added in a follow-up) deletes blobs whose `updatedAt` is older than 24 hours. Volume is small enough that orphans are not an operational concern at MVP scale.

## Out of scope

* The detailed shape of `SessionExerciseState` and `SessionTeam`, and the coordinator role lifecycle (ADR-0011).
* The UI for participant check-in, position broadcast and privacy controls (ADR-0012).
* Aggregation rules from per-participant `positions` into a single per-team display position (centroid, staleness threshold, outlier rejection when reports diverge wildly). All defined by ADR-0012.
* The alternative backend that takes over if Free-plan headroom is exhausted (ADR-0013, planned).

## Where the code lives

* `lib/data/live_status_client.dart` for the abstraction and HTTP implementation.
* `lib/data/session_status.dart` for the freezed envelope and slot types.
* `lib/services/live_status_service.dart` for the singleton that owns the client lifecycle.
* `lib/utils/app_config.dart` gains `keyLiveConsent = 'app:liveConsent:v1'` and `keyParticipantId = 'app:participantId:v1'`.
* `netlify/functions/sessions-status-read.js` and `sessions-status-write.js`.
* `netlify.toml` gets `/api/sessions/* -> /.netlify/functions/sessions-status-{read,write}`.

## Consequences

* Good: No new external service, one function pair, one storage backend, one consent flag.
* Good: All three capability ADRs build on a single status envelope. No schema fragmentation.
* Good: Per-slot authorization without a real auth system. Matches the existing trust model.
* Good: Cache-purge plus three-second polling meets the latency target for state, check-ins and positions alike.
* Good: Hard cap on Free plan means the worst outcome of a misconfiguration is downtime, not a bill.
* Bad: Function-invocations meter is binding on Legacy Free. Adaptive polling and the 15-second position throttle are mandatory, not optional. A misbehaving fork or stale client could push usage up.
* Bad: Per-drill function-invocation cost scales with the number of position broadcasters (one per team in the baseline assumption). Multiple broadcasters per team (e.g., team member plus instructors all enabling broadcast) multiply the cost proportionally. The app UX must nudge users toward a single broadcaster per team, and ADR-0012 documents that guardrail. Crowd-sized drills (50+ participants, 10+ broadcasters) are not viable on Legacy Free and need ADR-0013.
* Bad: Position updates do not benefit from edge caching because they invalidate the cache faster than any sensible TTL. The CDN absorbs idle traffic, not active position broadcast.
* Bad: Orphaned blobs accumulate until the cleanup job ships. Negligible at MVP volume.

## Pros and cons of the options

### Short polling with CDN-cached status objects (chosen)
* Good: No new service, one function pair, single envelope.
* Good: Fits Legacy Free plan at expected usage (one intensive weekend per month with margin). Hard cap protects against runaway costs.
* Good: Plain `package:http` on every platform.
* Bad: Function-invocations meter is binding on Legacy Free. Adaptive polling and the 15-second position throttle are mandatory.
* Bad: Three-second latency floor.

### Managed pub/sub service (Ably)
* Good: Sub-second latency, no polling.
* Bad: New vendor, new credential, native plugin on mobile.

### Self-hosted WebSocket server
* Good: Predictable cost, full control.
* Bad: Ops burden.

### Long polling against Netlify Functions
* Good: Lower poll count.
* Bad: Burns compute meter by reserving memory across the hold.

### Split transport
* Good: Could let positions scale independently.
* Bad: Two transports, two consent gates, two debug paths.

## Migration plan

1. Implement `LiveStatusClient`, `LiveStatusService`, the consent flag and the settings UI. No capability uses them yet.
2. Add the two Netlify Functions and the redirects in `netlify.toml`. Set `RINGDRILL_DAILY_WRITE_LIMIT` in env.
3. Verify in production that GET responses show CDN cache hits at the expected rate and that purge propagates within budget.
4. Verify the daily-write cutoff fires in staging.
5. Ship a release where the transport exists, consent defaults to off, and no capability uses it yet. Watch the Netlify usage dashboard for one week.
6. ADR-0010, 0011 and 0012 build on top.

## Links

* Related ADRs: [ADR-0002](./0002-freezed-models-with-extensions.md), [ADR-0004](./0004-no-third-party-state-management.md), [ADR-0005](./0005-cli-must-remain-flutter-free.md), [ADR-0006](./0006-sentry-behind-consent-gate.md), [ADR-0008](./0008-persistent-program-library-and-catalog.md)
* Planned follow-up ADRs: ADR-0010 (live catalog updates), ADR-0011 (synchronized exercise control), ADR-0012 (position and team check-in semantics), ADR-0013 (alternative backend)
* Related code: `lib/services/program_service.dart`, `lib/services/exercise_service.dart`, `lib/data/drill_client.dart`, `lib/data/program_repository.dart`, `lib/utils/app_config.dart`, `netlify.toml`, `netlify/functions/`
* External references: [Netlify Blobs](https://docs.netlify.com/build/data-and-storage/netlify-blobs/), [How credits work (Netlify docs)](https://docs.netlify.com/manage/accounts-and-billing/billing/billing-for-credit-based-plans/how-credits-work/), [Credit-based pricing plans (Netlify docs)](https://docs.netlify.com/manage/accounts-and-billing/billing/billing-for-credit-based-plans/credit-based-pricing-plans/), [HTTP conditional requests (MDN)](https://developer.mozilla.org/en-US/docs/Web/HTTP/Conditional_requests)
