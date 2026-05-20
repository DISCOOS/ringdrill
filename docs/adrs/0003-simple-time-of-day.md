---
status: accepted
date: 2026-05-20
deciders: ["@kengu"]
consulted: []
informed: []
---

# ADR-0003: Use a pure-Dart `SimpleTimeOfDay` for serializable time values

## Context and problem statement

Drill programs encode start times, schedule slots and rotation breakpoints as 24-hour wall-clock times. These values are stored in `.drill` files, sent to the Netlify backend, parsed by the CLI, and rendered by the Flutter UI.

Flutter's `TimeOfDay` is convenient inside widgets but has two properties that disqualify it for our model layer:

1. It is not JSON-serializable. `json_serializable` cannot round-trip it without a custom converter.
2. It lives in `package:flutter`, which would force any code that touches schedule data (CLI, data layer, future isolates) to depend on Flutter. This contradicts [ADR-0005](./0005-cli-must-remain-flutter-free.md).

Wall-clock times in our data layer must be representable on any platform, by any tool, without pulling in Flutter or writing custom serializers.

## Decision drivers

* Must be JSON-serializable through `json_serializable` with no custom converter.
* Must be usable from non-Flutter code (CLI, future isolates, possibly server-side tools).
* Must compose cleanly with `freezed` (see [ADR-0002](./0002-freezed-models-with-extensions.md)).
* Must round-trip exactly. No timezone surprises, no DST drift.

## Considered options

* A custom `SimpleTimeOfDay` freezed class with `hour` and `minute` fields.
* Wrap Flutter's `TimeOfDay` with custom `toJson`/`fromJson` converters in every model.
* Use `DateTime` and ignore the date portion.
* Store times as ISO-8601 `HH:mm` strings.

## Decision outcome

Chosen option: **a custom `SimpleTimeOfDay` defined in `lib/models/exercise.dart`**, because it is the only option that is simultaneously JSON-serializable, Flutter-free and exact, and it composes naturally with the rest of the freezed model layer.

The type carries `hour` (0-23) and `minute` (0-59), provides `inMinutes`, `fromMinutes`, `compareTo` and a `HH:mm` `toString`, and is converted to and from Flutter's `TimeOfDay` only at the UI boundary (helpers live in `lib/utils/time_utils.dart`).

### Consequences

* Good: Works in the CLI, in pure-Dart tests, and on every Flutter platform.
* Good: Plays cleanly with freezed and `json_serializable` (no custom converters).
* Good: JSON is compact and self-descriptive (`{"hour": 9, "minute": 30}`).
* Good: No timezone or DST ambiguity.
* Bad: One extra type for contributors to learn.
* Bad: Conversions to and from `TimeOfDay` are needed in the UI layer. Centralized in `time_utils.dart` to keep it manageable.

## Pros and cons of the options

### Custom SimpleTimeOfDay (chosen)
* Good: Pure-Dart, JSON-clean, freezed-friendly.
* Bad: Slight duplication of an existing Flutter type.

### Wrap Flutter's TimeOfDay
* Good: Reuses an existing type.
* Bad: Pulls Flutter into the data layer and the CLI. Disqualifying.
* Bad: Custom converters needed on every model field.

### DateTime with the date portion ignored
* Good: Existing type, JSON-serializable.
* Bad: Carries date and timezone information that has no meaning here, inviting bugs.
* Bad: Two `DateTime`s for the same wall-clock time can compare unequal due to date or zone differences.

### ISO-8601 `HH:mm` string
* Good: Compact JSON.
* Bad: All comparisons and arithmetic require parsing on every access.
* Bad: Easy to store malformed strings, no compile-time guarantee.

## Links

* Related ADRs: [ADR-0002](./0002-freezed-models-with-extensions.md), [ADR-0005](./0005-cli-must-remain-flutter-free.md)
* Related code: `lib/models/exercise.dart` (`SimpleTimeOfDay`), `lib/utils/time_utils.dart` (`TimeOfDayX`)
