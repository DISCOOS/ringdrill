---
status: accepted
date: 2026-05-20
deciders: ["@kengu"]
consulted: []
informed: []
---

# ADR-0001: Record architecture decisions

## Context and problem statement

RingDrill has grown into a Flutter application, a Dart CLI, and a Netlify backend. Several non-obvious choices have already been made (custom drill file format, Shorebird OTA, opt-in Sentry, flat `lib/views/`, pure-Dart `SimpleTimeOfDay`, no third-party state management library). Without a written record, the reasons for these choices live only in the maintainers' heads and in commit messages, which is brittle.

We are also starting to use AI coding agents to make changes. Agents are good at following written rules and bad at guessing intent. They need a place to read prior decisions and to record new ones when they propose changes that introduce new architectural assumptions.

## Decision drivers

* Future contributors (human and AI) need to know why the codebase looks the way it does.
* Decisions should be reviewable and overridable, not buried in chat logs or PR descriptions.
* The process must be lightweight enough that nobody dodges it.
* Agents must have a clear, machine-readable convention for proposing and recording decisions.

## Considered options

* Architecture Decision Records (ADRs) in the repo, MADR format.
* ADRs in an external wiki (Confluence, GitHub Wiki).
* No formal process, rely on commit messages and PR descriptions.

## Decision outcome

Chosen option: **ADRs in the repo using the [MADR](https://adr.github.io/madr/) format**, stored under `docs/adrs/`.

Each significant decision gets its own numbered markdown file. The index lives in [`docs/adrs/README.md`](./README.md). The template lives in [`docs/adrs/template.md`](./template.md).

### Consequences

* Good: Decisions are versioned with the code and reviewable through normal PRs.
* Good: Agents can both read the existing ADRs and write new `proposed` ones as part of a change set.
* Good: Superseded decisions remain visible, which makes the history of a choice traceable.
* Bad: Slight overhead per real decision. We accept this in exchange for the durability of the record.
* Bad: Risk of ADR rot if the index is not maintained. We accept this and treat index updates as part of the agent and human checklist.

## Pros and cons of the options

### ADRs in the repo (MADR)
* Good: Co-located with the code, no extra accounts or tooling.
* Good: Standard format, well-understood by tooling and agents.
* Bad: Requires discipline to write and to update the index.

### ADRs in an external wiki
* Good: Easier rich formatting and discussion threads.
* Bad: Decoupled from the code, easy to drift out of sync, requires separate access control.
* Bad: AI agents working in the repo cannot read or write it without extra integrations.

### No formal process
* Good: Zero overhead.
* Bad: Loses the "why" within a release cycle. Already biting us.

## Links

* Process: [`docs/adrs/README.md`](./README.md)
* Template: [`docs/adrs/template.md`](./template.md)
* Agent ruleset: [`AGENTS.md`](../../AGENTS.md)
* MADR spec: https://adr.github.io/madr/
