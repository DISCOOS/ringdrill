# Architecture Decision Records (ADRs)

This directory holds the architecture decision records for RingDrill. Each ADR captures one significant decision: the context that forced the choice, the options considered, what was chosen, and the consequences.

We use the [MADR](https://adr.github.io/madr/) format. See [`template.md`](./template.md) for the structure.

## Index

| ID       | Title                                                                                                    | Status   |
|----------|----------------------------------------------------------------------------------------------------------|----------|
| ADR-0001 | [Record architecture decisions](./0001-record-architecture-decisions.md)                                 | Accepted |
| ADR-0002 | [Use freezed + json_serializable, with extensions for behavior](./0002-freezed-models-with-extensions.md) | Accepted |
| ADR-0003 | [Use a pure-Dart SimpleTimeOfDay for serializable time values](./0003-simple-time-of-day.md)             | Accepted |
| ADR-0004 | [Do not adopt a third-party state-management library](./0004-no-third-party-state-management.md)         | Accepted |
| ADR-0005 | [The Dart CLI must remain free of Flutter imports](./0005-cli-must-remain-flutter-free.md)               | Accepted |
| ADR-0006 | [Sentry telemetry is gated behind opt-in analytics consent](./0006-sentry-behind-consent-gate.md)        | Accepted |
| ADR-0007 | [.drill files are versioned ZIP archives of JSON parts](./0007-drill-file-format.md)                     | Accepted |
| ADR-0008 | [Persistent program library with active plan and shared catalog](./0008-persistent-program-library-and-catalog.md) | Accepted |
| ADR-0009 | [Short polling with CDN-cached session status as live transport](./0009-realtime-transport-and-session-model.md) | Accepted |
| ADR-0010 | [Live catalog updates via HEAD polling with CDN cache](./0010-live-catalog-updates.md) | Accepted |
| ADR-0011 | [Synchronized exercise control with coordinator-driven state](./0011-synchronized-exercise-control.md) | Accepted |
| ADR-0012 | [Position sharing](./0012-position-sharing-and-team-aggregation.md) | Accepted |
| ADR-0013 | [Local end-to-end catalog testing via netlify dev, CLI seeding and a build-time base URL](./0013-local-catalog-testing.md) | Accepted |
| ADR-0014 | [Server-controlled drill upload contract](./0014-server-assigned-drill-version.md) | Accepted |
| ADR-0015 | [Shareable install links open the plan in the app via `ringdrill.app/i/<slug>`](./0015-shareable-install-links.md) | Accepted |
| ADR-0016 | [PWA update strategy: `no-cache` entry points, resilient SW detection, and an in-app last resort](./0016-pwa-cache-strategy.md) | Accepted |
| ADR-0017 | [Decouple number of stations from number of rounds in exercise setup](./0017-decouple-stations-from-rounds.md) | Accepted |
| ADR-0018 | [Introduce RolePlay and Actor entities, persist schema 1.1 in metadata](./0018-roleplayer-data-model.md) | Accepted |
| ADR-0019 | [Roleplayer as a third session participant role](./0019-roleplayer-participant-role.md) | Accepted |
| ADR-0020 | [Reduce map label and marker clutter via clustering, a unified marker spec, zoom-gated labels and per-layer visibility toggles](./0020-map-label-and-marker-clutter.md) | Accepted |
| ADR-0021 | [Use `app.ringdrill` as the iOS and macOS bundle identifier and keep `org.discoos.ringdrill` on Android](./0021-ios-bundle-identifier-app-ringdrill.md) | Accepted |
| ADR-0022 | [Store long-form markdown content as `.md` files in the drill archive](./0022-markdown-content-as-files.md) | Accepted |
| ADR-0023 | [Render the Brief view with a dedicated `BriefTheme` token set inspired by docs-site typography, independent of Material `ColorScheme`](./0023-brief-theme-tokens.md) | Accepted |
| ADR-0024 | [Introduce Account, User and Identity as separate entities](./0024-account-and-identity-model.md) | Accepted |
| ADR-0025 | [Authorise catalog writes against Account, with per-plan access policy](./0025-authorization-and-publish-policy.md) | Accepted |
| ADR-0026 | [Sheet-based context navigation with replace-semantics for detail surfaces](./0026-sheet-based-context-navigation.md) | Accepted |

## When to write an ADR

Write an ADR when you make a decision that:

* Changes the shape of the codebase, the build, the release process or the backend contract.
* Locks in a technology choice (a new package, a new service, a new file format, a new platform target).
* Reverses or significantly modifies an earlier ADR.
* You would expect a future contributor to ask "why was it done this way?" about.

You do not need an ADR for routine refactors, bug fixes, dependency upgrades that do not change behavior, or small UI tweaks.

## How to add an ADR

1. Pick the next number. Look at the existing files in this folder and add one.
2. Copy [`template.md`](./template.md) to `NNNN-short-kebab-case-title.md`.
3. Fill it in. Start with `status: proposed` if you want review before merging, or `status: accepted` if the decision is already final and you are documenting it.
4. Update the index table above.
5. Link related ADRs from the new file's `## Links` section.

When an ADR is replaced, mark the old one `status: superseded by ADR-NNNN` and link to the replacement in its `## Links` section. Leave the old file in place. Never delete an ADR.

## Status values

* `proposed` -- under discussion, not yet binding.
* `accepted` -- in force.
* `deprecated` -- no longer recommended, but not actively replaced.
* `superseded by ADR-NNNN` -- replaced by another ADR.

## Agents

Coding agents (Claude Code, Codex, Cursor, etc.) should add an ADR file as part of the same change set whenever the change would otherwise quietly introduce a new architectural assumption. Default status is `proposed`. An agent may set the status directly to `accepted` only when the user explicitly instructs it to do so in the same conversation; otherwise the maintainer reviews and accepts the ADR through a normal PR. See [`../../AGENTS.md`](../../AGENTS.md) for the full agent ruleset.
