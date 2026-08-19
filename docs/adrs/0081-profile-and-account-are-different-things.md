---
status: rejected
date: 2026-08-19
deciders: ["kengu"]
consulted: []
informed: []
---

# ADR-0081: Separate a person's profile from the accounts they act in

> **Rejected, 2026-08-19, in favour of a design refinement.** The observation
> below stands — the account page edits two records, and on an organisation
> they come apart — but the answer is not two screens. It is one form whose
> *sections* depend on the reader: Profile always, editing the user; Details
> and Members for an owner, editing the account. That needs no new boundary,
> no new vocabulary and no new ownership rule, so it is not an architectural
> decision: it is written up as
> [DESIGN-015 §5.9](../design/015-accounts-and-iam.md), where §5.4 had already
> said "everything else is the same page".
>
> Keeping the split would also have made the personal→organisation upgrade a
> journey between two screens, when it is a step inside one — DESIGN-015 §5.3
> puts it on Invite, which the single form already has.
>
> Left in place rather than deleted: the conflation it names is real, and the
> next person to notice it should find the answer rather than rediscover the
> question.

## Context and problem statement

[ADR-0024](./0024-account-and-identity-model.md) gives every user a personal
account, for a structural reason: a plan is owned by an account, so a person
publishing alone still needs one. That decision is sound and is not what this
ADR revisits. What it did not decide is how the *user interface* should talk
about it — and the answer the app arrived at by default is that a personal
account is a thing the user manages, presented on the same screen, in the same
words, as an organisation.

The two are not the same thing, and the code already says so. The fields on the
account page are written to two different records:

* **The user**: display name, nickname, phone, email, devices
  ([`updateUserNames`](../../netlify/functions/lib/identity.js) writes
  `user.displayName`, `user.nickname`, `user.phone`).
* **The account**: handle, type, members, owned plans.

On a personal account these coincide — it is created carrying the user's own
display name, and a change to that name is mirrored into it — so one screen can
pretend to be both. On an organisation they do not, which is why
`account_page.dart` branches on `isOrganisation` in seven places: devices only
for personal, the single-owner warning only for organisations, a different
title, a different owner section.

Three symptoms, in ascending order of how much they cost:

1. **The title has no honest answer.** "My account" for a personal one and the
   bare display name for an organisation meant three surfaces — the page, the
   drawer row and the publish dialog — identified the same account three
   different ways. Naming both by kind and handle fixed the inconsistency and
   left the conflation: "Personal account" names a container whose contents are
   almost entirely the user's own profile.
2. **The members section renders on a personal account**, where inviting
   somebody silently upgrades it to an organisation. The one section that is
   purely about an *account* appears on the screen that is mostly about a
   *person*, and using it changes what that screen is.
3. **It blocks what comes next.** An organisation will grow data that is not
   anybody's profile — a default roster, standing contact details, branding on
   a brief, its own settings. Every one of those has nowhere to go on a screen
   whose shape is "you, plus some account fields".

## Decision drivers

* **The user should not have to learn that they have a personal account.** It
  exists so ownership is uniform. Anything the interface says about it is
  vocabulary bought for an implementation detail.
* **An organisation is a thing several people share**, and its screen has to
  make sense to a member who is not its owner and never edits a profile on it.
* **The split is already in the data.** A UI that follows the record boundary
  needs no rule to remember; one that straddles it needs a branch per section,
  which is what is there now.
* **Do not invent a layout.** The app has a house pattern for an editor with
  several sections, and a second one would be a third answer to a solved
  question.
* **No migration.** Personal accounts keep existing exactly as they are; this
  is about which screen shows what.

## Considered options

* **A: Two screens, one shape.** A *Profile* screen for the person and an
  *Organisation* screen for each organisation, both built on the existing
  [`SectionNavigatedForm`](../../lib/views/widgets/section_navigated_form.dart)
  (DESIGN-008): a section list that is a master pane on medium/expanded and a
  navigated list on compact. Profile sections: name and contact details,
  devices, delete. Organisation sections: details (name, handle), members,
  plans, delete. The personal account stops being a UI concept. (chosen)
* **B: Keep one screen, hide the wrong half.** Continue branching on
  `isOrganisation`, adding a branch per new section. No new screens, and every
  future organisation-only feature costs another conditional on a screen that
  also edits somebody's phone number.
* **C: Two screens, bespoke layouts.** Same split as A, laid out by hand per
  screen. Cheaper today for two screens that will not resemble each other, and
  a third pattern for readers to learn.
* **D: Rename only.** Title the personal one "Profile" and change nothing else.
  Honest about what the page mostly edits, and leaves a members section under a
  heading that says "Profile".

## Decision outcome

Chosen option: **A**, because it moves the boundary in the interface to where
the boundary already is in the data, and because the pattern it needs exists.

### The rule

> **A profile belongs to a person; an account is a thing that owns plans. The
> interface names an account only when there is more than one person in it.**

Concretely:

* **Profile** is reached from the drawer's identity row. It edits the *user*
  record and nothing else. It is the only place a personal account is visible,
  and it does not call itself an account.
* **An organisation** is reached from the account switcher and the library's
  account tab. It edits the *account* record. A member who is not an owner sees
  it read-only rather than seeing a different screen.
* **The personal account keeps existing** — unchanged, still owning plans, still
  the default publish destination. It simply stops appearing as a thing to
  manage.
* **Both use `SectionNavigatedForm`**, so they inherit the master/detail
  behaviour the entity editors already have (ADR-0030's split at
  `WindowSizeClass.hasMasterDetail`), including the save-in-the-AppBar
  convention.

### Consequences

* Good: every organisation-only feature — a default roster, standing contacts,
  brief branding — has an obvious home, and adding one costs a section rather
  than a conditional.
* Good: the seven `isOrganisation` branches on the account page go away with
  the screen that needed them.
* Good: "invite somebody" stops being an action that silently changes what the
  screen you are on is. Upgrading a personal account to an organisation becomes
  an explicit step with somewhere to live.
* Bad: two screens where there was one, and a person who belongs to an
  organisation now has two places to visit rather than one.
* Bad: the work is not only a split. Devices, delete-account and the
  upgrade-to-organisation flow each have to be reassigned deliberately —
  "delete" means two different things on the two screens, and getting that
  wrong deletes the wrong thing.
* Bad: it invalidates the vocabulary just shipped. "Personlig konto" in the
  drawer and the page title becomes "Profil", which is a second change of words
  for anyone who saw the first.
* Neutral: no data migration, no API change. `GET /api/auth/me` already returns
  the user and the accounts separately.

## Pros and cons of the options

### Option A: two screens, one shape (chosen)

* Good: follows the record boundary, so there is no rule to remember.
* Good: reuses a pattern with five existing call sites.
* Bad: the largest change of the four.

### Option B: keep one screen

* Good: nothing to do today.
* Bad: the cost is paid per feature, forever, on the screen most likely to be
  edited by somebody who does not know why the branches are there.

### Option C: bespoke layouts

* Good: fastest way to two screens.
* Bad: a third layout idiom, and the one thing DESIGN-008 exists to prevent.

### Option D: rename only

* Good: one line, honest about today.
* Bad: leaves the members section under "Profile", which is worse than the
  inconsistency it fixes.

## Links

* [ADR-0024: Account and identity model](./0024-account-and-identity-model.md) — why a personal account exists at all.
* [ADR-0030: Wide-screen master/detail layout](./0030-wide-screen-master-detail-layout.md) — the split `SectionNavigatedForm` follows.
* [ADR-0072: Staff PII and account sync](./0072-staff-pii-and-account-sync.md) — the roster is account data, and one of the first things an organisation screen will want.
