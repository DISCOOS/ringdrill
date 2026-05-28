---
status: accepted
date: 2026-05-28
deciders: ["@kengu"]
consulted: []
informed: []
---

# ADR-0029: Surface a live mini player via ActivityKit on iOS and a foreground service notification on Android

## Context and problem statement

The drill mini player ([DESIGN-001](../design/exercise-player.md)) only exists while the app is in the foreground. A coordinator running a SAR drill keeps the phone in a pocket and looks at the lock screen between rounds. They cannot see phase, round or remaining time without unlocking.

[ADR-0011](./0011-synchronized-exercise-control.md) already gives every device a deterministic `ExerciseEvent` stream from [`ExerciseService`](../../lib/services/exercise_service.dart). What is missing is a per-platform lock-screen surface fed by that stream. This ADR scopes only that active-drill surface. A home-screen widget for the idle state is a separate decision.

The two platforms require different primitives. iOS 16.1+ uses ActivityKit (lock screen plus Dynamic Island). Android lock-screen presence is a foreground service notification, not an `AppWidget` — lock-screen widgets were removed in Android 5.0.

## Decision drivers

* Visible on the lock screen without unlocking, on both platforms.
* Reuses `ExerciseService` math. No second clock.
* Coordinator state changes from [ADR-0011](./0011-synchronized-exercise-control.md) must reach followers' lock screens, not only the coordinator's.
* CLI stays Flutter-free per [ADR-0005](./0005-cli-must-remain-flutter-free.md).
* Notification permission may be denied. The drill must keep working.

## Considered options

* **A. Status quo.** Rejected. Leaves the coordinator blind on the lock screen.
* **B. Plain `flutter_local_notifications` on both platforms.** Rejected. Not the right primitive on iOS — no Dynamic Island, no lock-screen-resident live surface, strict update rate limits.
* **C. ActivityKit on iOS + foreground service with `CallStyle` notification on Android (chosen).**
* **D. APNs-driven Live Activities from the backend.** Rejected for v1. The transport in [ADR-0009](./0009-realtime-transport-and-session-model.md) already delivers state within three seconds. Defer until the local-update path proves insufficient.

## Decision outcome

Chosen: **C**. Each platform's idiomatic primitive, driven by a single Dart bridge.

### Surface fields

Both platforms render the same fields per event: exercise name, phase label, current round / total, remaining `mm:ss`. A `STOP` affordance is rendered only when this device is in coordinator mode per [ADR-0011](./0011-synchronized-exercise-control.md).

### iOS

* Minimum target rises to iOS 16.1 if not already there.
* Live Activity starts when `ExerciseService` enters `running`, ends on `done`.
* `Activity.update(...)` per `ExerciseEvent`. ActivityKit allows ~1/sec, more than enough.
* Dynamic Island presents the standard compact / expanded / minimal trio.
* `STOP` is a `LiveActivityIntent` (iOS 17+). On 16.1–16.x the action is hidden and stop requires foregrounding the app.
* No APNs in v1.

### Android

* New `LiveDrillService` of type `FOREGROUND_SERVICE_TYPE_SPECIAL_USE` (subtype `ringdrill_live_drill`) on Android 14+, `FOREGROUND_SERVICE_TYPE_NONE` below.
* `NotificationCompat.CallStyle.forOngoingCall(...)` on Android 12+, `DecoratedCustomViewStyle` with `RemoteViews` below. `CallStyle` rather than `MediaStyle` because the drill is not media playback and the "ongoing event with a hangup" framing fits.
* `STOP` is the `declineIntent`. Updates throttled to 1/sec.

### Dart bridge

New `lib/services/live_session_presenter.dart` subscribes to `ExerciseService.events` and a single method channel `app.ringdrill/live_session` with `start` / `update` / `stop`. Coordinator state comes from `LiveStatusService`. A platform-side event channel routes a stop tap into `ExerciseService.stop()`, which on coordinators also broadcasts the stop patch per [ADR-0011](./0011-synchronized-exercise-control.md).

The presenter is started from `main.dart` after `ExerciseService` is constructed. Its lifecycle follows `ExerciseService`, not app foreground state.

### Where the code lives

* `lib/services/live_session_presenter.dart` (new).
* `ios/Runner/LiveActivity/` — `ActivityAttributes`, SwiftUI widget bundle, `FlutterMethodChannel` handler.
* `android/app/src/main/kotlin/.../live/` — service, notification builder, `MethodChannel` handler.
* `ios/Runner/Info.plist`: `NSSupportsLiveActivities = true`.
* `android/app/src/main/AndroidManifest.xml`: `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_SPECIAL_USE`, `POST_NOTIFICATIONS`, plus the `<service>` entry.

### Permission UX

Mirrors the existing prompt in [`NotificationService`](../../lib/services/notification_service.dart). Denial is recorded and not re-asked that session. The in-app mini player is unaffected.

### Consequences

* Good: lock-screen visibility on both platforms with the idiomatic primitive.
* Good: reuses `ExerciseEvent` and `ExerciseService.mirror`. The lock-screen surface cannot disagree with the in-app surface.
* Good: coordinator broadcasts reach followers' lock screens for free.
* Bad: two platform implementations.
* Bad: Android 14 `specialUse` subtype requires Play Console justification at next release.
* Bad: iOS Live Activities require a `staleDate`. Drills are short enough that setting it past the projected end is trivial.
* Bad: `LiveActivityIntent` requires iOS 17. Coordinators on 16.1–16.x must foreground the app to stop.

### Out of scope

* Home-screen widget (idle state).
* macOS — ActivityKit is iOS/iPadOS only.
* Apple Watch complication.
* APNs-driven updates — revisit if option D's preconditions appear.

## Migration plan

1. Stub `LiveSessionPresenter` that logs events. Wire into `main.dart`.
2. Android side: service, notification builder, manifest entries, permission prompt.
3. iOS side: `ActivityAttributes`, widget bundle, `Info.plist` flag.
4. Stop event channel routed into `ExerciseService.stop()`.
5. Test: start, jump, stop, network drop and reconnect, coordinator handover, permission denied.
6. Submit Play Console justification for `FOREGROUND_SERVICE_TYPE_SPECIAL_USE`.

## Links

* Related ADRs: [ADR-0005](./0005-cli-must-remain-flutter-free.md), [ADR-0009](./0009-realtime-transport-and-session-model.md), [ADR-0011](./0011-synchronized-exercise-control.md), [ADR-0021](./0021-ios-bundle-identifier-app-ringdrill.md).
* Related design: [DESIGN-001 Exercise Player](../design/exercise-player.md).
* Related code: `lib/services/exercise_service.dart`, `lib/services/live_status_service.dart`, `lib/services/notification_service.dart`, `lib/main.dart`.
* External: [ActivityKit](https://developer.apple.com/documentation/activitykit), [Android foreground service types](https://developer.android.com/about/versions/14/changes/fgs-types-required), [`NotificationCompat.CallStyle`](https://developer.android.com/reference/androidx/core/app/NotificationCompat.CallStyle).
