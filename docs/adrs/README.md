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
| ADR-0027 | [Unify all bottom sheets behind two showRingdrillSheet variants](./0027-unified-bottom-sheet-chrome.md) | Accepted |
| ADR-0028 | [Group `lib/views/` by feature and distribute shared domain widgets](./0028-feature-first-views-layout.md) | Accepted |
| ADR-0029 | [Surface a live mini player via ActivityKit on iOS and a foreground service notification on Android](./0029-live-activity-and-foreground-service.md) | Accepted |
| ADR-0030 | [Adopt a Material 3 master/detail layout on medium and expanded viewports, promote forms to modal dialogs and anchor the drill mini-player to the master column](./0030-wide-screen-master-detail-layout.md) | Accepted |
| ADR-0031 | [Row edit affordances use swipe and long-press; pencil reserved for AppBar](./0031-row-edit-affordances.md) | Accepted |
| ADR-0032 | [Prefix every program-scoped path with `/program/:uuid/` and drive activation from the URL](./0032-program-scoped-routing.md) | Accepted |
| ADR-0033 | [Adopt a selective platform-adaptive UI layer on iOS, keeping Material as the base](./0033-platform-adaptive-ui-on-ios.md) | Accepted |
| ADR-0034 | [Centralise numbering in one module and make number formats configurable per plan](./0034-configurable-numbering-formats.md) | Accepted |
| ADR-0035 | [Give exercises an explicit order field and user-driven reordering](./0035-exercise-ordering.md) | Accepted |
| ADR-0036 | [Extract a shared reorder section and let stations be reordered in the Stations segment and coordinator](./0036-shared-reorder-and-station-ordering.md) | Accepted |
| ADR-0037 | [Size text for legibility on iOS: tighten the baseline type scale and clamp scaling at 1.3](./0037-text-sizing-and-legibility.md) | Accepted |
| ADR-0038 | [Gate first-launch consent and rationale behind a four-stage onboarding](./0038-notification-consent-flow.md) | Accepted |
| ADR-0039 | [Split the site, PWA and API across separate origins](./0039-site-pwa-api-origins.md) | Accepted |
| ADR-0040 | [Extend the catalog feed schema with description, exercise count, author and access policy](./0040-catalog-feed-schema-extension.md) | Accepted |
| ADR-0041 | Brief pre-rendering port from Dart to Node (reserved, referenced by [ADR-0039](./0039-site-pwa-api-origins.md)) | Reserved |
| ADR-0042 | [Centralise build-time feature flags with sunset telemetry](./0042-feature-flags-and-sunset-telemetry.md) | Accepted |
| ADR-0043 | [Tags live in the `.drill` format and publish is last-write-wins](./0043-tags-in-drill-format.md) | Accepted |
| ADR-0044 | [Render the shareable preview on the site and expose plan meta as JSON](./0044-render-preview-on-site.md) | Accepted |
| ADR-0045 | [Drill library bundle format for multi-program export and import](./0045-drill-library-bundle-format.md) | Accepted |
| ADR-0046 | [Plan-scoped variables with cascading value overrides](./0046-plan-variables.md) | Accepted |
| ADR-0047 | [Station-scoped scenario locations and persons, and RolePlay portrays a Person](./0047-scenario-locations-and-persons.md) | Accepted |
| ADR-0048 | [Extract a Flutter-free field resolver from BriefRenderer](./0048-flutter-free-field-resolver.md) | Accepted |
| ADR-0049 | [Selectors adapt to window size behind one picker primitive — bottom sheet on compact, dialog on medium/expanded](./0049-adaptive-selector-surface.md) | Accepted |
| ADR-0050 | [Per-output-format chip formatting via a ChipFormatter strategy](./0050-per-output-format-chip-formatting.md) | Accepted |
| ADR-0051 | [Single `MapConfig.fitFor` camera-fit helper for every map surface](./0051-single-map-camera-fit-helper.md) | Accepted |
| ADR-0052 | [Map and brief viewer overlays adapt to window size like ADR-0049's selectors](./0052-map-and-brief-viewer-surface-adapts-to-window-size.md) | Accepted |
| ADR-0053 | [`MapView` owns its default camera fit, centring and marker construction](./0053-mapview-self-computed-default-fit.md) | Accepted |
| ADR-0054 | [Consistent map interactivity on medium/expanded windows, via a built-in `MapView.withFullscreen` command](./0054-map-interactivity-and-fullscreen-command.md) | Proposed |
| ADR-0055 | [Dual-accept `programId`/`planId` at the Netlify API boundary, with Sentry-tracked deprecation](./0055-programid-planid-wire-back-compat.md) | Accepted |
| ADR-0056 | [One drill player with peer modes — exercise, station, roleplay, team](./0056-player-modes-exercise-station-roleplay.md) | Accepted |
| ADR-0057 | [Editing is gated on the device's role, and frozen on a running exercise](./0057-role-gated-editing.md) | Accepted |
| ADR-0058 | [Introduce a source format compiled to `.drill` by a Flutter-free CLI](./0058-source-format-and-plan-compiler.md) | Accepted |
| ADR-0059 | [Normalize legacy `.drill` archives through an ordered migration ladder](./0059-drill-schema-migration-ladder.md) | Accepted |
| ADR-0060 | [Serve the MCP server remotely as a Netlify function, with the compiler cross-compiled to JavaScript](./0060-remote-mcp-server.md) | Accepted |
| ADR-0061 | [Accept a UTM string wherever the source format takes a position](./0061-utm-coordinate-input-in-source-format.md) | Accepted |
| ADR-0062 | [Express a non-uniform exercise as a mode plus station durations](./0062-authored-rounds-for-non-uniform-exercises.md) | Accepted |
| ADR-0063 | [Give every staff role its own brief audience, and declare each field's audiences on the field](./0063-per-field-brief-visibility.md) | Accepted |
| ADR-0064 | [Cut the document out of the authoring loop, and stop over-answering](./0064-mcp-payload-economy.md) | Accepted |
| ADR-0065 | [Ship the authoring conventions over MCP, not only as a local skill](./0065-authoring-guidance-over-mcp.md) | Accepted |
| ADR-0066 | [A team scope for cross-reference tokens](./0066-team-scope-for-cross-reference-tokens.md) | Rejected |
| ADR-0067 | [Give tokens a searchable browser sheet, and leave the caret menu as the fast path](./0067-token-browser-sheet.md) | Accepted |
| ADR-0068 | [Decide whether a cascaded field resolves in the borrowing scope](./0068-cascaded-fields-and-scoped-overrides.md) | Accepted |
| ADR-0069 | [Render the brief through a lazy viewport, and navigate it without relying on mounted headings](./0069-lazy-brief-viewport.md) | Accepted |
| ADR-0070 | [Deliver a built archive by handle, not through the transcript](./0070-build-artifact-delivery.md) | Accepted |
| ADR-0071 | [Report a modelling shortcut, instead of only advising against it](./0071-modelling-shortcut-diagnostics.md) | Accepted |
| ADR-0072 | [Let a roster reach the account that owns the plan, and keep the catalog stripped](./0072-staff-pii-and-account-sync.md) | Accepted |
| ADR-0073 | [Select the auth backend by mode, and ship a mock adapter for dev and test](./0073-auth-mode-and-adapters.md) | Accepted |
| ADR-0074 | [A catalog entry is a distinct object, identified by `(namespace, slug)` and defined by an allowlist](./0074-catalog-entry-as-distinct-object.md) | Accepted |
| ADR-0075 | [Send mail through a provider adapter, and keep templates and events on our side](./0075-mail-provider-adapter.md) | Accepted |
| ADR-0076 | [Protect local plan storage at rest, without an async read path](./0076-local-plan-storage-at-rest.md) | Accepted |
| ADR-0077 | [Reverse indexes for per-user lookups in the blob store](./0077-reverse-indexes-for-per-user-lookups.md) | Proposed |

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
* `reserved` -- the number is held for a planned ADR that has been named in another ADR's `Future ADRs referenced` section but not yet written. Replaced by a real status when the ADR is drafted.
* `deprecated` -- no longer recommended, but not actively replaced.
* `superseded by ADR-NNNN` -- replaced by another ADR.

## Agents

Coding agents (Claude Code, Codex, Cursor, etc.) should add an ADR file as part of the same change set whenever the change would otherwise quietly introduce a new architectural assumption. Default status is `proposed`. An agent may set the status directly to `accepted` only when the user explicitly instructs it to do so in the same conversation; otherwise the maintainer reviews and accepts the ADR through a normal PR. See [`../../AGENTS.md`](../../AGENTS.md) for the full agent ruleset.
