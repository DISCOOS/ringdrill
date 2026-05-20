---
status: accepted
date: 2026-05-20
deciders: ["@kengu"]
consulted: []
informed: []
---

# ADR-0005: The Dart CLI must remain free of Flutter imports

## Context and problem statement

`bin/ringdrill.dart` is an admin CLI for the RingDrill Netlify backend. It is installed with `dart pub global activate -s path .` (see `executables: ringdrill: ringdrill` in `pubspec.yaml`) and is expected to run on machines that do not have the Flutter SDK installed: CI runners, ops laptops, server hosts, container images.

Importing anything from `package:flutter/*` (or transitively from a file that does) would force every user of the CLI to install the Flutter SDK. This would slow CLI startup, balloon the install footprint, and break the use case of running the CLI on Flutter-less hosts.

## Decision drivers

* CLI must install and run with only the Dart SDK.
* CLI startup must stay fast (no Flutter engine bootstrapping).
* Code sharing between app and CLI must not silently re-import Flutter.

## Considered options

* Keep the CLI strictly Flutter-free, with shared code split between Flutter-free layers (`lib/data/`, `lib/models/`, `lib/utils/`) and Flutter-bound layers (`lib/views/`, `lib/services/`, `lib/web/`, `lib/main.dart`).
* Ship the CLI as a separate Flutter app target.
* Maintain a separate package for shared, Flutter-free code (e.g. `packages/ringdrill_core`).

## Decision outcome

Chosen option: **keep the CLI strictly Flutter-free**, with the existing in-repo split. `bin/ringdrill.dart` and any file it imports (today only `lib/data/drill_client.dart`) must not import `package:flutter/*`. Code that the CLI needs lives in the Flutter-free layers; everything UI-bound stays in the Flutter-bound layers.

Concretely:

* `lib/models/`, `lib/data/`, `lib/utils/` must remain Flutter-free.
* `lib/views/`, `lib/services/`, `lib/web/`, `lib/main.dart` may use Flutter freely.
* Anything in the Flutter-bound layers that the CLI needs must be refactored down into the Flutter-free layers before the CLI imports it.

### Consequences

* Good: `dart pub global activate` works on hosts without a Flutter install.
* Good: CLI starts in tens of milliseconds, no Flutter engine warm-up.
* Good: Forces a clean separation between domain code and UI code, which helps tests and future reuse.
* Bad: Cannot reuse Flutter widgets, themes, or `TimeOfDay` in the CLI (see [ADR-0003](./0003-simple-time-of-day.md) for the time type that this co-decides).
* Bad: Easy to break by accident through an indirect import. We rely on review discipline and `flutter analyze` until a CI check guards `bin/`.

## Pros and cons of the options

### Flutter-free CLI in the same repo (chosen)
* Good: One repo, one `pubspec.yaml`, no duplication.
* Good: Shared code lives next to its consumers.
* Bad: Discipline required to prevent accidental Flutter imports.

### CLI as a separate Flutter app target
* Good: No discipline required, Flutter is a given.
* Bad: Forces Flutter on every CLI user, defeating the purpose.

### Separate `ringdrill_core` package
* Good: Hard boundary enforced by package manifests.
* Bad: Repo and tooling overhead disproportionate for the current code size.
* Bad: Cross-package version coordination.

Revisit this option if the Flutter-free layer grows much larger or if we want to publish it.

## Links

* Related code: `bin/ringdrill.dart`, `lib/data/drill_client.dart`
* Related ADRs: [ADR-0003](./0003-simple-time-of-day.md)
* Operating rule (in [`AGENTS.md`](../../AGENTS.md)): "CLI must stay Flutter-free."
