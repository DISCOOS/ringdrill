---
status: accepted
date: 2026-05-20
deciders: ["@kengu"]
consulted: []
informed: []
---

# ADR-0012: Position sharing

## Context and problem statement

[ADR-0009](./0009-realtime-transport-and-session-model.md) carries per-participant positions in `SessionStatus.positions`, keyed by `participantId`. Any device whose `checkedInTeamUuid != null` may broadcast its own position by writing its own slot. This ADR specifies how those positions are captured, throttled, broadcast and rendered.

The product question this ADR settles: "where is each broadcasting participant on the map right now?" Each marker on the map corresponds to one device. Team membership is shown via color or label on the marker, looked up at render time from `SessionStatus.participants[id].checkedInTeamUuid`. There is no derived "team position" and no aggregation across multiple reporters. If two devices broadcast for the same team (e.g., a team member and an instructor shadowing them), they appear as two markers identified by `displayName` and the same team color.

Position data is more sensitive than the other patches in this design. Even with the general live-consent gate from ADR-0009, position broadcasting must be a separate, explicit opt-in, and the user must be able to see when they are broadcasting and pause it at any moment.

## Decision drivers

* The transport stores raw positions per participant (per ADR-0009). Display shows one marker per broadcaster, no synthetic team marker.
* Position writes have the highest cost-per-meter-of-app-quality on Legacy Free. The 15-second throttle from ADR-0009 mitigations is mandatory.
* Privacy. Continuous location broadcast is the most sensitive thing this app does. Explicit, granular consent and a visible "broadcasting now" state are mandatory.
* The CLI must stay Flutter-free per [ADR-0005](./0005-cli-must-remain-flutter-free.md). Position capture is platform-specific and lives in a Flutter-only service.
* Stations already use `LatLng` and `latlong2` (per the existing map code in `lib/views/map_view.dart`). Reuse the same types.

## Considered options

* **Per-participant markers (chosen).** Each broadcasting device draws as its own marker. Team membership is a visual annotation, not a data-aggregation operation.
* **Per-team aggregated markers (centroid of reporters).** Combine multiple reports into one synthetic marker per team. Loses information when reporters disagree, requires staleness and outlier thresholds, and obscures who is actually where.

## Decision outcome

Chosen option: **per-participant markers**, because each marker corresponds to a single source of truth (one device's GPS), the model is simpler to reason about, and disagreements between reporters become visible to the operator instead of being averaged away.

### Rendering

Pseudocode for the map view consuming the latest `SessionStatus`:

```dart
for (final pos in status.positions.values) {
  final participant = status.participants[pos.participantId];
  if (participant == null) continue;            // unknown participant
  final teamUuid = participant.checkedInTeamUuid;
  if (teamUuid == null) continue;               // observer, no marker
  final team = status.teams.firstWhere((t) => t.teamUuid == teamUuid);

  // Stale positions are dimmed but still shown so the operator can see
  // a last-known location. Threshold can be tuned in a later release.
  final isStale = now.difference(pos.reportedAt) > Duration(minutes: 2);

  drawMarker(
    at: LatLng(pos.latitude, pos.longitude),
    color: paletteFor(team.index),
    label: '${participant.displayName ?? l10n.anonymous} / ${team.name}',
    dimmed: isStale,
  );
}
```

The participant's current team is looked up via `checkedInTeamUuid` at render time, not stored on the position record. A participant who has just switched teams shows up under the new team immediately, before their next position write lands. There is no race window where a marker is mislabeled.

### Staleness

A position older than two minutes is rendered dimmed (or with a "Last seen" tooltip), not hidden. The map operator still benefits from "where was Bravo last seen" even if the broadcaster has dropped off. The threshold is a constant in code and can be tuned without an ADR.

### Capture and broadcast

A new `PositionBroadcastService` in `lib/services/position_broadcast_service.dart` owns the lifecycle.

Activation conditions, all required:

* General live consent on (`app:liveConsent:v1`, from ADR-0009).
* Position-specific consent on (`app:positionConsent:v1`, new in this ADR).
* This device's own `SessionParticipant.checkedInTeamUuid != null`.
* The app is foregrounded.

When all are true, the service subscribes to the platform geolocator stream and emits `participant_position` patches under the throttle rules below. Any of the conditions flipping off stops the stream and clears the local broadcast indicator.

Throttle rule (per ADR-0009): send a patch when either ten meters have been moved since the last patch or fifteen seconds have elapsed since the last patch, whichever comes first. The "moved" comparison uses the haversine distance between the new fix and the last sent fix.

The geolocator package is added to `pubspec.yaml`. Its import is contained to `position_broadcast_service.dart` and the platform permission handlers. No transitive import reaches the CLI.

### Privacy and consent

Two independent toggles:

* **Live consent** (`app:liveConsent:v1`, default off, from ADR-0009). Required for any session-status traffic.
* **Position consent** (`app:positionConsent:v1`, default off, new here). Required additionally for position broadcasts. Turning live consent off implicitly disables position broadcasting.

The check-in UX surfaces both. A user joining as a team member sees a prompt that explains: "Your phone's location will be shared with other participants in this session as long as you are checked in." They must explicitly accept before the broadcaster starts. Observers see no such prompt because they do not broadcast.

A persistent "broadcasting position" indicator is shown whenever the broadcaster is active. Tapping it opens a settings sheet with a one-tap "stop broadcasting now" action. Stopping the broadcaster does not check the user out of the team, it just freezes the broadcast. The participant's position slot ages naturally under the rendering staleness rule.

Background-pause matches the polling pause from ADR-0009. When the app is backgrounded or the tab is hidden, the broadcaster stops. It resumes on foreground if consent and team membership are still active.

The privacy text is localized into `app_en.arb` and `app_nb.arb` (per the [`l10n`](../../lib/l10n/app_en.arb) conventions).

### Position-slot cleanup

A device that checks out of a team or leaves the session leaves its position slot in place. The next render run reads `participant.checkedInTeamUuid == null` and skips the marker. The slot itself is removed by the daily cleanup. No explicit "expired" sentinel write is needed.

### UX guardrail on multiple broadcasters per team

The cost model in ADR-0009 assumes one active broadcaster per team. The transport allows more, but the UX must dampen the urge. Concretely:

* The check-in screen shows a list of teams. If a team already has an active broadcaster, the option is shown but labeled "1 broadcasting." A new user joining that team sees a confirmation dialog: "Bravo already has a broadcaster. Join anyway?" Default: no.
* The settings sheet for an active broadcaster shows "X people on this team are broadcasting" when X > 1, with a hint that one broadcaster is usually enough.

These are nudges, not hard limits. The user can override.

### Cost

Already covered by ADR-0009's cost model. This ADR does not change the position-write rate or introduce new endpoints. The 15-second throttle and the 10-meter movement floor are the levers and are baked into the broadcaster.

### Where the code lives

* `lib/services/position_broadcast_service.dart` for capture, throttle, and patch dispatch.
* `lib/utils/app_config.dart` gets `keyPositionConsent = 'app:positionConsent:v1'`.
* `lib/views/map_view.dart` consumes `SessionStatus.positions` and renders per-participant markers as described.
* `lib/views/session_check_in_screen.dart` (new) hosts the consent prompt for team-member check-in and the multi-broadcaster nudge.
* `lib/l10n/app_en.arb` and `app_nb.arb` gain the privacy strings.
* `pubspec.yaml` gains the `geolocator` dependency.

### Consequences

* Good: Each marker has one source of truth. No averaging, no thresholds, no synthetic positions.
* Good: Disagreements between reporters surface visually instead of being smoothed away. The operator can act on them.
* Good: Privacy is explicit and granular. Two consent toggles, a visible broadcast indicator, easy off switch.
* Good: Lookup chain `position → participant → team` is fully contained in the same `SessionStatus` object the client already polled. No extra round trips.
* Good: Switching teams takes effect immediately for the marker label and color, before the next position write lands.
* Bad: Multiple broadcasters for the same team produce multiple markers and can clutter the map. UX nudges dampen this.
* Bad: Adds the `geolocator` dependency. Native build surface grows slightly. Restricted to the broadcaster service so the CLI is unaffected.
* Bad: A malicious or buggy participant can broadcast a false position for a team they have checked in to. The trust model already accepts this for the rest of the design. UX exposes "who is reporting" via the marker label so other participants can verify off-app.
* Bad: Position data on the server lives for up to 24 hours under the existing blob cleanup window. Acceptable given the trust model, but worth stating.

## Pros and cons of the options

### Per-participant markers (chosen)
* Good: One marker, one source. Simple to reason about and to render.
* Good: Disagreements between reporters are visible to the operator.
* Bad: More markers when multiple broadcasters per team.

### Per-team aggregated markers
* Good: Cleaner map when many reporters per team.
* Bad: Averages away information, including disagreements that an operator should see.
* Bad: Requires staleness and outlier thresholds that are application-wide constants.

## Migration plan

1. Add the `geolocator` dependency to `pubspec.yaml`. Wire platform permissions in `android/`, `ios/` and the web manifest.
2. Implement `PositionBroadcastService` with the activation conditions and throttle.
3. Add `keyPositionConsent` to `AppConfig` and a settings toggle.
4. Build the check-in consent prompt and the persistent broadcasting indicator.
5. Wire `map_view.dart` to render per-participant markers using the `position → participant → team` lookup.
6. Add localized privacy strings to `app_en.arb` and `app_nb.arb`.
7. End-to-end test: one broadcaster per team, verify normal rendering. Two broadcasters on the same team, verify two markers with the same color. Broadcaster goes offline, verify marker dims after two minutes.

## Links

* Related ADRs: [ADR-0005](./0005-cli-must-remain-flutter-free.md), [ADR-0006](./0006-sentry-behind-consent-gate.md), [ADR-0009](./0009-realtime-transport-and-session-model.md), [ADR-0011](./0011-synchronized-exercise-control.md)
* Related code: `lib/services/live_status_service.dart`, `lib/data/session_status.dart`, `lib/views/map_view.dart`, `lib/utils/app_config.dart`, `lib/l10n/app_en.arb`, `lib/l10n/app_nb.arb`
* External references: [geolocator (pub.dev)](https://pub.dev/packages/geolocator), [latlong2 (pub.dev)](https://pub.dev/packages/latlong2)
