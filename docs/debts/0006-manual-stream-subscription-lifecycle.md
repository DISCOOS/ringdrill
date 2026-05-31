---
status: open
severity: medium
discovered: 2026-05-31
resolved: null
related_adrs: []
---

# DEBT-0006: Manual `StreamSubscription` lifecycle is leak-prone

## What

Each screen that listens to a service stream re-implements the same lifecycle by hand: a `List<StreamSubscription>` field, `add(stream.listen(...))` in `initState`, and a `for` loop that cancels in `dispose`. Forgetting a `cancel` leaks a listener onto a long-lived broadcast singleton.

## Where

* `lib/views/coordinator_screen.dart` (field line 66, cancel loop line 1326)
* `lib/views/main_screen.dart` (field line 463, cancel loop line 569)
* `lib/views/stations_view.dart` (subscription field line 60, cancel line 828)
* The same shape recurs in other stateful views that listen to `ProgramService`/`ExerciseService`/`NotificationService`.

## Why it is debt

All service streams are broadcast singletons that live for the whole app session, so a missed `cancel` is a real leak that survives screen disposal and can fire `setState` after unmount. The repeated `if (mounted) setState(...)` guard around every handler is the same boilerplate copied everywhere. This is an easy-to-misuse pattern, which the register rates as medium.

## Suggested fix

Introduce a `SubscriptionBagMixin` (or similar) exposing `listen(stream, onData)` that registers the subscription and cancels all of them automatically on `dispose`. Optionally fold in a `mountedSetState(...)` helper so handlers stop repeating the `mounted` guard.

## Links

* Related ADRs: none
* Related code: `lib/views/coordinator_screen.dart`, `lib/views/main_screen.dart`, `lib/views/stations_view.dart`, `lib/services/*`
