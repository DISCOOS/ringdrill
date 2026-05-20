# Architecture Decision Records (ADRs)

This directory holds the architecture decision records for RingDrill. Each ADR captures one significant decision: the context that forced the choice, the options considered, what was chosen, and the consequences.

We use the [MADR](https://adr.github.io/madr/) format. See [`template.md`](./template.md) for the structure.

## Index

| #    | Title                                                    | Status   |
|------|----------------------------------------------------------|----------|
| 0001 | [Record architecture decisions](./0001-record-architecture-decisions.md) | Accepted |

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

When an ADR is replaced, mark the old one `status: superseded by [NNNN](./NNNN-...)` and leave the file in place. Never delete an ADR.

## Status values

* `proposed` -- under discussion, not yet binding.
* `accepted` -- in force.
* `deprecated` -- no longer recommended, but not actively replaced.
* `superseded by NNNN` -- replaced by another ADR.

## Agents

Coding agents (Claude Code, Codex, Cursor, etc.) should add an ADR file as part of the same change set whenever the change would otherwise quietly introduce a new architectural assumption. Default status is `proposed`. An agent may set the status directly to `accepted` only when the user explicitly instructs it to do so in the same conversation; otherwise the maintainer reviews and accepts the ADR through a normal PR. See [`../../AGENTS.md`](../../AGENTS.md) for the full agent ruleset.
