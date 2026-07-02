# Tech Debt Register

This directory tracks known compromises, orphaned code, and "we'll come back to this" decisions in RingDrill. Each file captures one debt item: what it is, where it lives, why it is debt, and a starting point for fixing it.

A debt entry is not an ADR. ADRs record decisions and their consequences. Debt entries record known shortcomings that exist because of a decision (or in spite of one) and that we have chosen not to fix yet. The two formats reference each other: an ADR can accept a debt; a debt can point at the ADR that explains why it exists.

## Index

| ID        | Title                                                          | Severity | Status | Discovered |
|-----------|----------------------------------------------------------------|----------|--------|------------|
| DEBT-0001 | [Orphan HTTPS App-Link for `/o` path](./0001-orphan-https-app-link-for-o-path.md) | Low      | Resolved | 2026-05-22 |
| DEBT-0002 | [Coordinator screen not on `ExpandableTile` + `LiveAccent`](./0002-coordinator-screen-not-on-expandable-tile.md) | Medium | Resolved | 2026-05-31 |
| DEBT-0003 | [Duplicated SnackBar notice idiom](./0003-duplicated-snackbar-idiom.md) | Low | Open | 2026-05-31 |
| DEBT-0004 | [Duplicated destructive-confirm dialog](./0004-duplicated-destructive-confirm-dialog.md) | Low | Resolved | 2026-05-31 |
| DEBT-0005 | [Repeated context lookups, no shared extension](./0005-repeated-context-lookups-no-extension.md) | Low | Open | 2026-05-31 |
| DEBT-0006 | [Manual `StreamSubscription` lifecycle is leak-prone](./0006-manual-stream-subscription-lifecycle.md) | Medium | Resolved | 2026-05-31 |
| DEBT-0007 | [`ProgramService` is a god class](./0007-program-service-god-class.md) | Medium | Open | 2026-05-31 |
| DEBT-0008 | [ADR-0028 feature-folder refactor not executed](./0008-feature-folder-refactor-not-executed.md) | Low | Open | 2026-05-31 |
| DEBT-0009 | [`main_screen.dart` mixes routing and shell](./0009-main-screen-mixes-routing-and-shell.md) | Low | Open | 2026-05-31 |
| DEBT-0010 | [Global service singletons hinder testability](./0010-global-service-singletons-hinder-testability.md) | Medium | Open | 2026-05-31 |
| DEBT-0011 | [ADR-0039 post-cutover cleanup](./0011-adr-0039-post-cutover-cleanup.md) | Medium | Resolved | 2026-07-02 |

## When to write a debt entry

Write one when:

* You knowingly leave code in a state that works for the current case but will trip up a future contributor (orphan declarations, misleading names, dead branches, partial migrations).
* An ADR accepts a known compromise and you want it tracked so it does not get forgotten.
* You find an inconsistency that is not urgent enough to fix in the same change set but is worth recording so the next person does not have to rediscover it.

Do not write a debt entry for:

* Active bugs (file an issue or fix it).
* Routine refactors planned for the next sprint (use a task tracker).
* Code style preferences (use a linter).

## How to add a debt entry

1. Pick the next number. Look at existing files in this folder and add one.
2. Copy [`template.md`](./template.md) to `NNNN-short-kebab-case-title.md`.
3. Fill in the frontmatter and sections. Default status is `open`.
4. Update the index table above.
5. If an ADR is the source of the debt, link both directions: the ADR mentions the debt in its `Consequences` section, the debt links back via `related_adrs`.

## Status values

* `open` — known and not actively being worked on.
* `scheduled` — assigned to upcoming work; expect a resolution date soon.
* `resolved` — fixed. Set the `resolved:` frontmatter date. Keep the file in place for traceability.
* `wontfix` — deliberately not fixing. Explain why in the entry.

## Severity values

* `low` — no user-visible impact, no operational risk; the cost is mostly cognitive load for contributors.
* `medium` — risk of incorrect future changes (misleading code, easy-to-misuse APIs) or minor user-visible cost.
* `high` — concrete risk of correctness, data loss, security, or significant maintenance burden.

## Agents

Coding agents may add debt entries when they spot a known compromise during other work. Use the same template and default to `status: open`, `severity: low` unless evidence supports a higher rating.
