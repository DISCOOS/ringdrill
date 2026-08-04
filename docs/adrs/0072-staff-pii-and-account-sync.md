---
status: proposed
date: 2026-08-04
deciders: ["kengu"]
consulted: []
informed: []
---

# ADR-0072: Strip staff PII on every upload path, and do not sync a roster until a later ADR earns it

## Context and problem statement

[ADR-0018](./0018-roleplayer-data-model.md) drew the PII boundary as a folder
boundary: role data lives in `roleplays/` and is publishable, the humans live in
`staff/` and are not, and `drills-upload.js` drops the folder before anything is
stored. That is the whole of the current privacy story, and it holds for one
structural reason — **publishing to the catalog is the only path that sends a
plan to our servers.** One destination, one strip, one place to get it wrong.

Accounts change that. [ADR-0024](./0024-account-and-identity-model.md) and
[ADR-0025](./0025-authorization-and-publish-policy.md) introduce an owning
Account, and the obvious next feature after "this plan is mine" is "…and I can
get it back on my other device". That is a *second* reason to send a plan to our
infrastructure, and it is one where dropping `staff/` looks like a bug rather
than a safeguard: a planner syncing their own plan expects the roster to come
with it.

Two things make this sharper than it was when ADR-0018 was written:

* **The roster grew.** DESIGN-011 widened `Actor` — the human cast to a markør —
  into `Staff`, *anyone* working the exercise, with a mandatory role and the
  contact details you need to reach them on the day. More people, more phone
  numbers, and most of them never touch the app.
* **The strip is one call site.** `stripPiiFolders`
  ([`drill-pii.js`](../../netlify/functions/lib/drill-pii.js)) is pure and
  well-tested, but only `drills-upload.js` calls it. Nothing structural stops a
  new endpoint that accepts archive bytes from skipping it, and a sync endpoint
  is exactly the kind of endpoint that would.

The decision this forces is not "how do we sync rosters safely". It is the
prior question: **does account sync carry staff PII at all, and what keeps the
catalog strip honest once a second upload path exists.**
[`../plans/account-rollout.md`](../plans/account-rollout.md) records this as
work to be done "when phase 3 or 5 gets close", with the opt-in question left
open. It is cheaper to answer now, because the answer decides whether phase 3
needs a consent surface.

## Decision drivers

* **The strip must not be able to rot.** The failure mode is silent: PII reaches
  a blob, nothing errors, no test fails, and we find out from someone else. A
  rule that depends on remembering to call a function has already failed once
  in this repo's history — the `actors` → `staff` denylist rename in
  `computeContentHash` (ADR-0018, "One trap worth recording") would have
  published real names with nothing failing.
* **The data subjects are not the user.** Someone enters a colleague's name and
  phone number. That colleague has rights over that data — access, correction,
  deletion — and no account, no relationship with us, and no way to exercise
  them today.
* **Nothing legal is in place.** There is no privacy statement covering
  server-side personal data, because until now there was none to cover. No
  stated legal basis, no retention window, no deletion path that reaches
  backups, no sub-processor list.
* **One maintainer.** Whatever is committed to has to be *operable*. A retention
  promise we cannot honour is worse than not storing the data.
* **Offline-first (ADR-0024).** A plan is fully usable with its roster on-device
  and nothing synced. Peer-to-peer `.drill` transfer already moves rosters
  between devices and is unaffected by anything here.
* **Accounts should not wait on a privacy programme.** Phases 1–5 protect
  *plans* from unauthorised writes. That is worth shipping on its own, and it
  does not need server-side rosters to be worth shipping.

## Considered options

### For whether account sync carries `staff/`

* **Option A — The strip is unconditional; no path syncs a roster (chosen).**
  Every endpoint that accepts `.drill` bytes drops `staff/`, catalog and future
  account sync alike. Rosters stay device-local and travel peer-to-peer. Server
  never holds staff PII, so none of the legal apparatus is on the critical path
  for accounts.
* **Option B — Sync carries the roster whenever the plan is account-owned.**
  The policy choice (`account`) implies the data choice. One less decision for
  the user.
* **Option C — Per-plan opt-in, with its own consent surface.** The owner turns
  roster sync on per plan, after being told what is stored and for how long.
* **Option D — Sync an encrypted roster the server cannot read.** Client-side
  key, opaque blob server-side.

### For how the strip is kept honest

* **Option E — Strip at the ingest boundary, enumerated by a test (chosen).**
  Reading archive bytes out of a request is one shared helper, the strip is
  inside it, and a test enumerates the functions that accept archive bytes and
  fails when one of them does not go through it.
* **Option F — Keep the per-endpoint call, add a code-review rule.** Status quo
  plus vigilance.
* **Option G — Validate after write.** A scheduled job scans stored blobs for
  `staff/` entries and alarms.

## Decision outcome

Chosen: **A (unconditional strip, no roster sync)** enforced by **E (strip at
the ingest boundary, with an enumerating test)**.

A wins because it is the only option that keeps the privacy story *structural*
rather than procedural, and because it decouples two things that were about to
become coupled for no good reason. Protecting a published plan from strangers
and storing a colleague's phone number on a server are unrelated features that
happen to arrive in the same release train. B couples them silently — a user
picking `account` to stop strangers editing their plan has not thereby agreed
to us storing their team's contact details, and would have no reason to expect
it. C is the right *eventual* shape but pays the full legal cost up front for a
feature nobody has asked for yet. D is genuinely attractive and defers the legal
question by making the data unreadable to us, but key management across devices
(and key loss = roster loss) is a larger project than the roster is worth today.

E wins because F is what we have now and its failure mode is invisible. G finds
the leak after it has happened, which for personal data is too late — worth
adding later as a belt-and-braces check, not as the mechanism.

**This answers the rollout plan's open question directly: staff PII sync is
neither opt-in nor implied. It does not exist.** Phase 3 and phase 5 need no
consent surface, no privacy statement, and no data-subject tooling, because
nothing they ship sends a roster anywhere.

### What "unconditional" means concretely

The rule is a property of *accepting a `.drill` archive over HTTP*, not a
property of the publish endpoint:

* Any Netlify function that reads archive bytes from a request body obtains them
  through the shared ingest helper, and that helper applies `stripPiiFolders`
  before returning them. There is no way to get raw request bytes and skip it
  short of writing a new reader.
* `PII_FOLDERS` stays the single list, and keeps stripping **both** `actors/`
  and `staff/` permanently, for the deploy-cadence reason DESIGN-011 already
  recorded.
* A test enumerates `netlify/functions/*.js`, identifies those that read a
  request body as archive bytes, and asserts each one routes through the helper.
  It is a coarse test on purpose: it fails on a *new* endpoint written by
  someone who has not read this ADR, which is the case that matters.

Nothing about the client changes. The app keeps `staff/` in locally stored and
exported archives; peer-to-peer transfer (USB, AirDrop, email) is out of scope
here as it always has been.

### When a roster does need to reach a server

This ADR does not forbid roster sync forever; it removes it from the account
rollout's critical path. A later ADR may introduce it, and inherits these
preconditions — all of them, before any code:

1. A published privacy statement naming what personal data is stored, the legal
   basis, where it is hosted, and the retention window.
2. A deletion path that actually deletes: plan deletion removes the roster
   server-side, and the stated window covers backups.
3. An answer for data subjects who are not users — how a person on someone
   else's roster asks what is held about them, corrects it, or has it removed.
4. Data residency settled (EU), and a sub-processor list covering hosting,
   backups and any support tooling that can read the data.
5. Per-plan opt-in (Option C's shape), never implied by a policy choice.

Until all five hold, the strip stays unconditional. If sync ships before them,
this ADR is superseded, not quietly outgrown.

### Relationship to ADR-0018

This amends [ADR-0018](./0018-roleplayer-data-model.md)'s PII boundary, which is
written as though the catalog were the only destination. The boundary itself is
unchanged — `staff/` is PII and does not leave the device through our servers.
What changes is its scope: it binds every upload path, not the publish endpoint.
ADR-0018 keeps its status; this ADR is the amendment of record.

### Consequences

* Good: The account rollout stops being blocked on a privacy programme. Phases
  1–5 ship without a privacy statement covering server-side rosters, because
  there are none.
* Good: The strip becomes structural. A new endpoint cannot forget it without
  failing a test, which is the same class of protection the folder boundary
  gives the model.
* Good: One less decision in the phase 3 publish dialog. The rollout plan's
  open question closes without a UI.
* Good: The legal preconditions are written down while the reasons for them are
  fresh, rather than reconstructed under delivery pressure later.
* Bad: "Get my plan back on a new device" restores the plan without its roster.
  For a planner who has entered thirty people, that is a real gap, and the
  honest answer for now is "export the `.drill` and move it yourself".
* Bad: The enumerating test is heuristic. It recognises today's shape of
  "reads archive bytes"; a sufficiently different endpoint could evade it.
  It narrows the failure mode rather than closing it.
* Bad: Deferring encrypted sync (Option D) means that when roster sync is
  finally wanted, the cheap version is server-readable and carries the whole
  legal cost. The technically better answer stays unbuilt.

## Pros and cons of the options

### A. Unconditional strip, no roster sync (chosen)

* Good: Server never holds staff PII. Nothing to state, retain, or delete.
* Good: One rule, no per-plan state, no consent surface, no way for a user to
  be surprised by what got uploaded.
* Bad: Sync is visibly incomplete — the roster is the one thing that does not
  come back.

### B. Roster syncs whenever the plan is account-owned

* Good: Zero UI. Sync does what a user naively expects.
* Bad: Couples a *security* choice to a *privacy* consequence the user was
  never shown. Choosing `account` to keep strangers out is not consent to
  store a colleague's phone number.
* Bad: Puts the full legal apparatus on phase 3's critical path.

### C. Per-plan opt-in with its own consent surface

* Good: Explicit, revocable, and the right long-term shape.
* Bad: Needs the privacy statement, retention and deletion story *before* the
  toggle can honestly be shown. Same critical-path cost as B, plus UI.

### D. Client-encrypted roster, opaque to the server

* Good: Sidesteps most of the legal question — we hold ciphertext.
* Bad: Cross-device key distribution and key loss (roster gone, unrecoverably)
  are a larger project than the feature.
* Bad: "We cannot read it" still needs stating publicly to be worth anything.

### E. Strip at the ingest boundary, enumerated by a test (chosen)

* Good: The unsafe path stops being reachable by accident.
* Good: Fails for the person most likely to get it wrong — someone adding an
  endpoint who has not read ADR-0018.
* Bad: Heuristic. Recognises a shape, not an intent.

### F. Per-endpoint call plus a review rule

* Good: No work.
* Bad: This is the status quo, and its failure mode is silent.

### G. Post-write scanning

* Good: Catches whatever the ingest rule misses.
* Bad: Detects a disclosure that already happened. Right as a second line, wrong
  as the first.

## Links

* Related ADRs:
  [ADR-0006](./0006-sentry-behind-consent-gate.md),
  [ADR-0008](./0008-persistent-program-library-and-catalog.md),
  [ADR-0014](./0014-server-assigned-drill-version.md),
  [ADR-0018](./0018-roleplayer-data-model.md) — amended by this ADR,
  [ADR-0024](./0024-account-and-identity-model.md),
  [ADR-0025](./0025-authorization-and-publish-policy.md)
* Related designs:
  [DESIGN-011](../design/011-person-with-role-and-roster-model.md) — widened
  `Actor` to `Staff` and grew what the roster holds.
* Related plans:
  [`account-rollout.md`](../plans/account-rollout.md) — closes its open
  question on staff PII sync.
* Related code:
  `netlify/functions/lib/drill-pii.js` (`PII_FOLDERS`, `stripPiiFolders`),
  `netlify/functions/drills-upload.js` (today's only call site),
  `lib/models/plan.dart` (`computeContentHash` denylist),
  `lib/data/drill_file.dart` (writes `staff/` locally, unaffected)
