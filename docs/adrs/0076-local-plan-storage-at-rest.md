---
status: accepted
date: 2026-08-09
deciders: ["Kenneth Gulbrandsøy"]
consulted: []
informed: []
---

# ADR-0076: Protect local plan storage at rest, without an async read path

## Context and problem statement

A plan's staff roster is real people — names, phone numbers, and whatever else
somebody typed into a `director_notes` field.
[ADR-0072](./0072-staff-pii-and-account-sync.md) decided where that data may
travel, and `stripPiiFolders` enforces it at the catalog door, so the published
copy carries no roster. What ADR-0072 did not decide is how the *local* copy is
stored, and the answer turns out to be: in `SharedPreferences`, in plaintext,
in the same store as the onboarding flags.

This surfaced while asking a narrower question — now that
`flutter_secure_storage` is in the project for refresh tokens
([ADR-0024](./0024-account-and-identity-model.md)), should the rest of
`SharedPreferences` move too? For the settings the answer is plainly no: they
are onboarding flags and map preferences, nothing worth stealing, and moving
them would buy a platform-channel round trip per read in exchange for nothing.
But the same store also holds every plan, and that is a different question.

**The constraint that shapes everything here: reads must stay synchronous.**
`PlanService.listPlans()`, `loadPlan()` and `activePlan` are called from
`build()` methods throughout the app. Making them async would push a `Future`
into every widget that renders a plan — a change with a very large blast radius
and no user-visible benefit. `flutter_secure_storage` is async-only, which is
why "just move the plans there too" is not on the table.

## A second motivation, found while writing this

The ADR started as a privacy question. Reading the storage layer to answer it
turned up a performance one with the same fix, and it is the stronger of the
two.

**Every ordinary save rewrites every nested record of the plan.**
`PlanRepository._replaceNested` removes every `p*:<planUuid>:*` key and then
writes back every exercise, team, session, roleplay, staff member and staff
note — one `SharedPreferences` call each. Each of those calls is a
platform-channel round trip that rewrites the *entire* backing store, for every
plan, not just the one being edited. So the cost of one save is
`O(entities) × O(total stored bytes)`, and both factors grow with the plan.

That matches the reported symptom — lag that grows with plan size, during
editing — better than the first hypothesis, which was that building the
`.drill` archive before a push was to blame. Archive building happens in
`DrillFile.fromPlan`, and its call sites are publish, export and share; an
ordinary edit never zips. Zipping would explain lag *at publish*, not while
typing.

This is stated as a mechanism, not a measurement. It has not been profiled, and
it should be before anything is optimised for it — but it is the first place to
look, and it is the same code this ADR replaces.

## Decision drivers

* **Reads stay synchronous.** Non-negotiable. Writes may be async; they already
  are.
* **The realistic threat is backups and forensic access, not a rival app.** Both
  platforms already isolate app-private storage from other apps on an
  un-compromised device. What that isolation does *not* cover is a device
  backup, a rooted or jailbroken device, and physical extraction.
* **A drill runs with the phone locked in a pocket.** Exercise timers and local
  notifications mean the app is woken in the background while the device is
  locked. Any protection class that makes data unreadable while locked breaks
  the product.
* **Plans must not become unrecoverable.** Whatever is done must not silently
  cost somebody their work.
* **Proportionality.** Three plans in the live catalog and a handful of users.
  A control that costs a large refactor needs to buy more than a marginal
  improvement over what the OS already does.

## The thing that makes this tractable

`SharedPreferences` **already loads its entire contents into memory** when
`getInstance()` is awaited, and serves every subsequent read from that map.
That is *why* its reads are synchronous — not because the store is special, but
because hydration already happened.

`PlanService.init()` is already awaited in `main()` before `runApp()`, and every
accessor is gated on `_isReady`. So the app already has exactly the shape any
replacement needs: **one async hydration at startup, synchronous reads
afterwards.** Swapping the backing store is therefore not a read-path change at
all. That is the whole reason a real fix is affordable here.

## Considered options

* **A — Do nothing.** Rely on OS app-private storage and full-disk encryption.
* **B — Keep `SharedPreferences`, encrypt the plan values.** Ciphertext in the
  same store, key in the Keychain/Keystore, decrypt during `init()`.
* **C — Move plan storage to files, with platform protection and a backup
  policy.** Hydrate at `init()`; reads unchanged.
* **D — C, plus application-level encryption.**

## Decision outcome

Chosen option: **C**, because it is the only option that can actually apply the
controls the threat model calls for — and because `SharedPreferences` is
structurally the wrong place to try.

**One folder per plan, laid out like the archive.** `plans/<planUuid>/` with the
same shape a `.drill` has inside — `program.json`, `exercises/`, `teams/`,
`staff/` and the rest. Three things follow, and the third is why this shape
rather than one blob per plan:

1. **Export and publish become a zip of a directory**, not a serialisation pass
   that rebuilds every entry from the model.
2. **The layout is already the format**, so there is one structure to reason
   about instead of a storage shape and a wire shape that drift.
3. **A save touches only what changed.** The write amplification above exists
   because the storage unit is a key in a store shared by everything. With a
   file per entity under a folder per plan, editing one exercise writes one
   file, and no other plan is touched at all.

The decisive fact is that **the controls do not reach `SharedPreferences`.** On
iOS it is `NSUserDefaults`: a plist in `Library/Preferences` that the app does
not own the file handle for, cannot set a Data Protection class on, and which is
included in device backups. On Android it is an XML file that Auto Backup ships
to Google Drive unless excluded at the manifest level, and the exclusion is
per-file — so excluding it would take the settings with it. There is no version
of "harden the prefs file" that works on either platform.

Moving plans to a file the app owns makes three things possible that are
impossible today:

1. **A Data Protection class on iOS.** Specifically
   `NSFileProtectionCompleteUntilFirstUserAuthentication`, **not**
   `NSFileProtectionComplete`. Complete would make the file unreadable whenever
   the device is locked, and a drill runs with the phone locked in somebody's
   pocket while exercise timers fire — the app would fail to read the plan it is
   timing. UntilFirstUserAuthentication keeps the data encrypted until the first
   unlock after boot, which is the meaningful window for a lost or seized
   device, and readable thereafter including in the background.
2. **A deliberate backup decision** (see below), which today is made by default
   and in the wrong direction.
3. **Encryption later, behind the same seam**, if it is ever warranted — which
   is option D, deliberately deferred rather than rejected.

Option A is not chosen, but it is worth being honest about how much it already
does: on a device with a passcode, both platforms encrypt the filesystem, and
no other app can read RingDrill's container. The gap A leaves is backups and a
compromised device, and it is the backup half that is both the most likely and
the cheapest to close.

Option B was rejected because it inherits every `SharedPreferences` limitation
while adding a key to manage. It would encrypt the plan values inside a plist
that is still backed up and still has no protection class — so the ciphertext
travels to the backup, and the only thing standing between it and plaintext is
whether the Keychain key travelled too. That is a worse version of C with more
moving parts.

Option D is deferred. Once C is in place, application-level encryption is a
change to two functions rather than a change to the architecture, and it should
be decided against a threat that actually motivates it rather than pre-emptively.

### The backup question, which needs a decision rather than a default

This is the part with a genuine trade-off and no clearly correct answer, so it
is stated plainly rather than buried:

* **Exclude plans from backup** — a restored device comes back with no local
  plans. Catalog-sourced plans reinstall from their slug and anything exported
  survives, but a plan that was only ever local is gone. In exchange, the
  roster never leaves the device, including into an unencrypted local backup.
* **Include plans in backup** — restore works, and the roster is only as
  protected as the user's backup is. An encrypted iCloud or iTunes backup is
  fine; an unencrypted local one is not.

**Recommendation: include them, and revisit if D is ever adopted.** Losing
somebody's drill plan on a device restore is a concrete harm to every user;
backup exposure is a conditional harm to users who take unencrypted local
backups, which on current iOS is not the default path. If that judgement is
wrong, excluding is a one-line change — but it should be a decision, not a
default, which is why it is written down here either way.

### Consequences

* Good: staff PII gets a protection class it cannot have today, and the
  decision about backups is made rather than inherited.
* Good: **the read path does not change.** No `Future` reaches a `build()`
  method; `listPlans`, `loadPlan` and `activePlan` keep their signatures.
* Good: the seam this creates is where encryption goes if it is ever needed,
  so option D stops being a rewrite.
* Bad: `PlanRepository`'s storage layer is rewritten — the riskiest kind of
  change, because it owns everybody's data. It needs a migration that reads the
  old prefs keys, writes the new file, and only then clears the old, with the
  same copy-first-delete-last ordering as
  [the catalog re-key](../plans/catalog-rekey-migration.md).
* Good: the write path stops rewriting the world on every save — see the
  performance section above. This is a side effect of the layout, not a
  separate optimisation.
* Bad: hydration reads a directory tree at startup instead of one plist. At
  current plan counts this is noise, and it can become lazy per plan later —
  the shell is what the library list needs, and the nested entities only matter
  once a plan is opened.
* Neutral: settings stay in `SharedPreferences`, where they belong. This ADR
  deliberately does not move them.

## Pros and cons of the options

### A — Do nothing

* Good: no work, no migration, no risk to existing data.
* Good: already covers the most common threat — another app on the device.
* Bad: plans with real names and phone numbers travel into device backups with
  no protection class, and nothing in the app says so.
* Bad: leaves ADR-0072's care about where rosters travel stopping at the
  network boundary, which is not where the data actually lives.

### B — Encrypt inside `SharedPreferences`

* Good: no storage-layer rewrite.
* Bad: the file is still backed up and still has no protection class, so the
  ciphertext leaves the device regardless.
* Bad: adds key management for a control that the container placement then
  undermines.
* Bad: prefs values are strings; storing ciphertext there means base64 on top of
  encryption on top of JSON, for data that is already large.

### C — Files, protection class, explicit backup policy

* Good: the only option where the platform controls actually apply.
* Good: reads stay synchronous, because hydration already exists.
* Bad: rewrites the storage layer and needs a data migration.

### D — C plus encryption

* Good: protects against a compromised device after first unlock, which C does
  not.
* Bad: on a device where an attacker has that level of access, they can usually
  reach the key as well — the marginal gain is smaller than it appears.
* Bad: cannot be justified against a named threat today, and a control adopted
  without one tends to be the control nobody maintains.

## Follow-ups

* Decide the backup question above. It is the only open item that changes
  behaviour a user would notice.
* **Profile a large plan's save before optimising anything.** The mechanism
  above is read off the code, not measured. If it is confirmed, this ADR's
  layout fixes it without further work; if the lag turns out to be elsewhere —
  brief rendering, `computeContentHash`, widget rebuilds — that is worth
  knowing before designing around the wrong cause.
* **A delta protocol for `.drill` transfer is a separate question, and later.**
  Sending only changed entries would help publish and refresh over a slow link,
  and the folder layout makes the unit of change obvious. But it adds a
  negotiation to a wire format that currently has none, and it should not be
  built on the assumption that archive building is the bottleneck — see above.
  Measure the publish path first; if zipping is cheap and the upload is the
  cost, a delta protocol is the right answer, and if zipping is the cost,
  caching the archive against the plan's `contentHash` is a far smaller change.
* Say it in the UI once decided. If plans are excluded from backup, the app has
  to say so somewhere a person will read before they rely on it.
* Revisit per-plan files if plan counts grow enough for hydration to be felt at
  startup.

## Related

* [ADR-0072](./0072-staff-pii-and-account-sync.md) — where a roster may travel;
  this ADR covers where it rests.
* [ADR-0024](./0024-account-and-identity-model.md) — puts refresh tokens in
  `flutter_secure_storage`. That store stays for secrets and is not the answer
  here, because it is async-only.
* [`docs/data-retention.md`](../data-retention.md) — the server-side counterpart:
  what account deletion removes and what it keeps.
