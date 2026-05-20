---
status: accepted
date: 2026-05-20
deciders: ["@kengu"]
consulted: []
informed: []
---

# 0004. Do not adopt a third-party state-management library

## Context and problem statement

RingDrill's runtime state is modest: a handful of singleton services (`ProgramService`, `ExerciseService`, `NotificationService`) that own domain state and emit stream events, plus `shared_preferences` for user settings, plus per-screen widget state. The UI is a small number of screens with mostly local interactions. Most "state" is actually owned by an immutable freezed model loaded from a `.drill` file or persisted in `shared_preferences`.

Flutter contributors with a "best practices" reflex often reach for Riverpod, Bloc or Provider by default. These libraries are excellent for large reactive UIs, but they add a dependency, a runtime, a learning surface, and an upgrade obligation. We need to be explicit about whether that cost is justified here.

## Decision drivers

* App size and cold-start time matter (mobile app and PWA both ship the same code).
* The state graph is shallow: services own state, widgets observe streams.
* Most domain state is persisted (drill files, settings), not held in-memory across many widgets.
* Smaller dependency surface means less ongoing upgrade churn.
* Onboarding cost should stay low: idiomatic Flutter only.

## Considered options

* Plain `ChangeNotifier`/streams plus `shared_preferences` (current).
* Riverpod.
* Bloc.
* Provider.

## Decision outcome

Chosen option: **plain Flutter primitives**. Services are constructed as singletons in `lib/main.dart`. They expose `Stream`s and `ValueNotifier`s. Widgets consume via `StreamBuilder`, `ValueListenableBuilder` and `setState`.

This is a deliberate non-adoption decision, not a "we haven't gotten around to it" placeholder. Agents proposing to introduce a state-management library must supersede this ADR with a new one explaining what changed.

### Consequences

* Good: Smaller dependency graph and smaller release artifacts.
* Good: Zero state-mgmt-library upgrade cycles, no breaking-change migrations.
* Good: Any Flutter developer can read the codebase without learning a project-specific abstraction.
* Good: Encourages keeping state where it belongs (services for shared state, widgets for ephemeral UI state).
* Bad: Some boilerplate that Riverpod or Bloc would have removed (manual subscription management, manual disposal).
* Bad: If the UI grows into a many-screen reactive system with widespread shared state, this ADR will need to be revisited.

## Pros and cons of the options

### Plain primitives (chosen)
* Good: No new abstractions, smallest footprint, no upgrade churn.
* Bad: Boilerplate scales linearly with reactive surface.

### Riverpod
* Good: Compile-safe providers, good ergonomics, active community.
* Bad: A non-trivial mental model, a runtime, and a recurring upgrade cost (1.x to 2.x to 3.x have all required code changes).

### Bloc
* Good: Strong opinions, separates intent from state.
* Bad: Heavier boilerplate than even plain primitives for our scale. Best fit for large teams.

### Provider
* Good: Simple, widely used.
* Bad: Effectively wraps what we already do with `ChangeNotifier`. Adds a dependency for marginal gain.

## Links

* Related code: `lib/services/*.dart`, `lib/main.dart` (service bootstrapping)
* Related ADRs: [0002](./0002-freezed-models-with-extensions.md) (models are immutable freezed values, which removes most "reactive shared state" pressure)
