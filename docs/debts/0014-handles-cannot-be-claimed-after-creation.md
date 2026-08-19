---
status: resolved
severity: medium
discovered: 2026-08-19
resolved: 2026-08-19
related_adrs: ["ADR-0074", "ADR-0024"]
---

# DEBT-0014: A handle can only be claimed while creating an organisation

> **Resolved 2026-08-19.** `PATCH /api/accounts/:id` claims or changes a
> handle, owner-only, through `renameHandle` — which claims when there is none
> and retires the old one as a redirecting tombstone when there is. The
> description below is what was wrong.

## What

`POST /api/accounts` is the only place an account handle can be set — when an
organisation is created, or when a personal account is upgraded into one. There
is no route that claims, changes or releases a handle on an account that already
exists.

Two consequences follow, and neither is intended:

* **A personal account can never have a handle.** It is created with
  `handle: null`, and the only path to one is ceasing to be a personal account.
* **An organisation can never rename its handle**, although `renameHandle`
  already retires the previous one as a tombstone that redirects — the exact
  behaviour [ADR-0074 §2](../adrs/0074-catalog-entry-as-distinct-object.md) designed for a
  rename. The machinery is built and unreachable.

## Where

* [`netlify/functions/accounts.js`](../../netlify/functions/accounts.js) —
  `createOrganisation` reads `body.handle`; the only `PATCH` under `/accounts`
  is `members/:userId` for a role change.
* [`netlify/functions/lib/identity.js`](../../netlify/functions/lib/identity.js) —
  `claimHandle` is atomic (`onlyIfNew`); `renameHandle` wraps it and writes the
  redirecting tombstone. Only `upgradeToOrganisation` reaches either.
* [`netlify/functions/lib/catalog.js`](../../netlify/functions/lib/catalog.js) —
  `resolveNamespace` falls back to the account id, which is why a handle-less
  account can publish at all.

## Why it is debt

A handle is **optional for publishing and effectively required for being shared
with**. `resolveNamespace` falls back to the account id, so a handle-less account
publishes fine at `/d/a_x7k2h9/winter-drill`. But the publish dialog names a
grantee by handle and resolves it through `lookupHandle`, which resolves handles
and not ids — so an account with no handle can publish plans and cannot be named
as the account to share one *with*.

That makes the missing route the thing standing between a personal account and
1:1 cooperation, which [DESIGN-015 §5.10](../design/015-accounts-and-iam.md)
establishes needs no organisation and no membership. The design's Details
section (§5.9) offers *Claim* on exactly this route.

The rename half is a smaller cost but a sharper one: an organisation that
outgrows its first handle has no way to change it, and the redirect machinery
that would make that safe is already written and tested.

## Suggested fix

`PATCH /api/accounts/:accountId` taking `{handle}`, owner-only, calling
`renameHandle(account.handle, handle, accountId, stores)` — which claims when
there is no previous handle and retires the old one as a redirecting tombstone
when there is, so one route serves both. `validateHandle` and the `taken`/`reserved`/
`invalid_format` reasons already exist and map onto the 409/400 the create route
uses.

Worth deciding at the same time, because the API shape depends on it: whether
releasing a handle back to null is allowed. A retired handle is tombstoned
rather than freed, so "release" and "rename" are the same operation with a
different target, and neither returns the name to the pool.

## Links

* Related ADRs: [ADR-0074](../adrs/0074-catalog-entry-as-distinct-object.md), [ADR-0024](../adrs/0024-account-and-identity-model.md)
* Related design: [DESIGN-015 §5.9, §5.10](../design/015-accounts-and-iam.md)
* Related code: `netlify/functions/accounts.js`, `netlify/functions/lib/identity.js`
