---
status: accepted
date: 2026-05-20
deciders: ["@kengu"]
consulted: []
informed: []
---

# 0002. Use freezed + json_serializable, with extensions for behavior

## Context and problem statement

RingDrill's domain models (`Program`, `Exercise`, `Station`, `Team`, `Session`, `SimpleTimeOfDay`) are touched by JSON serialization (import and export of `.drill` files, network upload to the backend), shared across the UI layer and the CLI, and held by long-lived services that emit stream events. They must be immutable, value-equal, and JSON round-trippable.

Hand-writing `copyWith`, `==`, `hashCode`, `toString`, `toJson` and `fromJson` for each model is repetitive and a source of subtle bugs (forgetting a field in `copyWith`, asymmetric `==`/`hashCode`, etc.). Some models (e.g. `Exercise`/`ExerciseMetadata`, `SimpleTimeOfDay`) also want sealed-class semantics for future union types.

## Decision drivers

* Models cross serialization boundaries (`.drill` files, HTTP, isolates) and must be JSON-clean.
* The CLI consumes the same models without Flutter (see [ADR-0005](./0005-cli-must-remain-flutter-free.md)).
* Behavior on models (validation, derived fields, indexing math) must be addable without re-running codegen.
* Sealed-class support for future union types.

## Considered options

* `freezed` + `json_serializable`, with method-style behavior added via Dart extensions on the freezed class.
* `equatable` plus manual `copyWith` and manual `toJson`/`fromJson`.
* Plain Dart classes with no immutability guarantees.
* `dart_mappable`.

## Decision outcome

Chosen option: **`freezed` + `json_serializable`, with behavior added in extensions**, because it gives us immutability, value equality, `copyWith`, sealed support and JSON in one declaration, and lets us add methods later without touching generated code.

Concretely:

* Every model in `lib/models/` is declared as `@freezed sealed class X with _$X { const factory X({...}) = _X; factory X.fromJson(...) => _$XFromJson(json); }`.
* Behavior lives in `extension XOn X on X { ... }` in the same file. Methods inside the freezed class body are reserved for the cases freezed allows (factory and `_` private constructor).
* `make build` regenerates `*.freezed.dart` and `*.g.dart`. Generated files are committed but never hand-edited.

### Consequences

* Good: One source of truth per model. Adding a field updates `==`, `hashCode`, `copyWith`, `toJson` and `fromJson` in one step.
* Good: Sealed classes are first-class, so future union types (e.g. multiple `ExerciseMetadata` variants) need no refactor.
* Good: Extensions can be added or removed without re-running codegen, so behavior iteration stays fast.
* Bad: Requires a build step (`make build`) after every model change. Agents that forget this produce code that does not compile.
* Bad: Larger PR diffs. Generated `*.freezed.dart` and `*.g.dart` files grow alongside the model.
* Bad: One additional concept (extensions) for new contributors to learn.

## Pros and cons of the options

### freezed + json_serializable + extensions (chosen)
* Good: Immutability, equality, `copyWith`, JSON, sealed all in one declaration.
* Good: Behavior in extensions keeps the freezed class body minimal.
* Bad: Codegen step required.

### Equatable + manual copyWith + manual JSON
* Good: No codegen.
* Bad: Every field change touches four hand-written methods. Bug-prone.
* Bad: No sealed-class support without extra plumbing.

### Plain Dart classes
* Good: Lowest tooling overhead.
* Bad: No immutability guarantees, no value equality, no `copyWith`.

### dart_mappable
* Good: Similar feature set to freezed with less boilerplate.
* Bad: Smaller ecosystem, less familiar to most contributors and agents. Would have to migrate from current freezed adoption.

## Links

* Related ADRs: [0003](./0003-simple-time-of-day.md), [0005](./0005-cli-must-remain-flutter-free.md)
* Related code: `lib/models/*.dart`
* Build target: `make build` (see [`Makefile`](../../Makefile))
