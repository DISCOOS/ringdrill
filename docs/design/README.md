# Design Docs

This directory holds UX and UI design documents for RingDrill features that span multiple screens or introduce a new interaction model. Each design doc captures the intent of a design before it is implemented, so reviewers and future contributors can see *what* we are trying to build and *why* before reading the code that does it.

A design doc is not an ADR. ADRs record architectural decisions that constrain the codebase; design docs describe how a user-facing feature is intended to look and behave. The two formats reference each other when relevant: an ADR can lock in a UX direction, and a design doc can cite an ADR for the constraints it works within.

## Index

| ID         | Title                                                   | Status   | Started    |
|------------|---------------------------------------------------------|----------|------------|
| DESIGN-001 | [Exercise Player](./exercise-player.md)                 | Accepted | 2026-05-23 |
| DESIGN-002 | [Stations tab](./stations-tab.md)                       | Accepted | 2026-05-23 |
| DESIGN-003 | [RolePlays tab](./roleplays-tab.md)                     | Accepted | 2026-05-23 |
| DESIGN-004 | [Exercise brief template](./brief-template.md)          | Draft    | 2026-05-25 |

## Folder layout

```
docs/design/
├── README.md               (this file)
├── exercise-player.md      (one design doc per feature)
├── stations-tab.md
└── mockups/                (standalone HTML mockups referenced by docs)
    ├── coordinator-lag.html
    ├── coordinator-oversikt.html
    ├── coordinator-poster.html
    ├── mini-player.html
    ├── observer-lag.html
    ├── observer-post.html
    └── wide-screen.html
```

Each design doc lives at the top level. Visual mockups are saved as standalone HTML files under `mockups/`, so they can be opened directly in a browser without a build step. Mockups use the same Tabler icon font and CSS variables as the in-app Cowork-style preview, but adapted to work offline against the CDN.

## When to write a design doc

Write one when:

* A change introduces a new interaction model (a new screen pattern, navigation model, or component family) that will affect multiple screens.
* The team needs to align on UX before code is written, especially if there are competing options.
* A new feature is large enough that the rationale for *why* the UI is shaped a certain way is not obvious from looking at the final implementation.

Do not write a design doc for:

* Routine UI tweaks (button label, copy, color, spacing).
* Bug fixes or visual regressions.
* One-off screens that fit cleanly inside an existing pattern.

## How to add a design doc

1. Pick the next free DESIGN-NNN number from the index.
2. Create `nnn-short-kebab-case-title.md` at the top level (or just `kebab-case-title.md` if numbering feels heavy for the first few entries).
3. Use the structure: rationale, anatomy, component specs, behavior, deferred decisions, implementation notes.
4. If you produce mockups, save them as standalone HTML in `mockups/` and link them from the doc.
5. Update the index table above.

## Status values

* `Draft` — under active iteration with stakeholders. Mockups may still change.
* `Accepted` — the design has been signed off and is ready for implementation. Code can be written against it.
* `Implemented` — the design has shipped. Doc is kept for historical context.
* `Superseded` — replaced by a later design doc. Link forward to the new one.
