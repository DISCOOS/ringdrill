---
id: DESIGN-015
title: Accounts and IAM — sign-in, recovery, account pages and member management
status: Proposed
started: 2026-08-05
owners: ["kengu"]
related_code:
  - lib/services/plan_service.dart
  - lib/data/plan_repository.dart
  - lib/data/drill_client.dart
  - lib/services/app_user_role.dart
  - lib/services/edit_permissions.dart
  - lib/views/library_view.dart
related_designs:
  - 006-program-tab-consolidation.md
  - 007-onboarding-and-help.md
  - 011-person-with-role-and-roster-model.md
related_adrs:
  - 0024-account-and-identity-model.md
  - 0025-authorization-and-publish-policy.md
  - 0057-role-gated-editing.md
  - 0063-per-field-brief-visibility.md
  - 0072-staff-pii-and-account-sync.md
---

# Accounts and IAM — sign-in, recovery, account pages and member management

> This document is in English. Model and field names are English; Norwegian
> strings are the `nb` labels the app ships. **Status: Proposed.** The model is
> settled by [ADR-0024](../adrs/0024-account-and-identity-model.md) and
> [ADR-0025](../adrs/0025-authorization-and-publish-policy.md); this document
> decides what the user sees and does, and flags four calls that are still open.

## TL;DR

Signing in is optional and stays optional. It buys one thing — **nobody changes
your published plan without you** — and it must not become a wall in front of
planning, reading the catalog, or running a drill. The surface is small: one
sign-in screen with three providers, one account page that grows a members list
when a second person is invited, and a recovery path for the situations that
replace "forgot my password" in a world with no passwords.

The two things most likely to go wrong are not screens. They are **two role
vocabularies that must never be presented as one setting** (§7), and **an
account page that has to say plainly what an account holds** now that a roster
can travel with a plan (§8).

## 1. What this designs, and what it does not

**In scope:** sign-in and provider linking; account recovery; the personal
account page; the personal→organisation upgrade; the organisation account page;
invite, accept, change role, remove and leave; the active-account switcher; how
all of it lays out on phone, wide screen and web.

**Out of scope:** the authorisation matrix itself (ADR-0025), the storage model
(ADR-0024), roster sync (ADR-0072 — the account page must *describe* what an
account holds, but sync ships later), and the CLI's `login` beyond one note in
§3.5.

**Not gated by sign-in, and this is load-bearing:** creating and editing plans,
importing and exporting `.drill` files, browsing and installing from the
catalog, running an exercise, joining a session, everything in the brief. A
person can use RingDrill for a full exercise and never see an account.

## 2. The model on one screen

| Entity | What it is | User-visible as |
|---|---|---|
| `User` | A person | "Deg" — name, email, linked sign-in methods |
| `Identity` | One provider login (`email`, `apple`, `google`) | Rows under "Innloggingsmetoder" |
| `Account` | What owns plans | "Konto" — personal or organisation |
| `Member` | (User, role) on an account | Rows in the members list |

A `User` may be a member of several `Account`s. A personal account is created
automatically at first sign-in and has exactly one member. An organisation
account is created by inviting a second person (§6.2) or explicitly.

**A note on the shape, because it differs from the obvious reference.** In GCP,
identity lives outside IAM entirely, the *resource hierarchy* is
Organization → Folder → Project, and authorisation is `{role, members[]}`
bindings attached to a node and inherited downward. RingDrill's `Member` is
exactly an org-node binding, and ADR-0025's per-plan `accessPolicy` is exactly a
leaf-resource policy — the same two-level shape. The deliberate difference is
that **GCP has no personal-account type**: a personal Google Account owns
projects with no Organization node at all, and the org appears only when a
domain does. ADR-0024 instead models the single-person case as a degenerate
organisation, which buys a uniform `accountId` on every plan and one code path
for ownership. The cost is that "your personal account" is a thing the UI has to
explain at all, which is why §5.1 works hard to make it nearly invisible until
it matters.

## 3. Sign-in

### 3.1 Entry points

Three, and no more:

1. **Drawer tile.** "Logg inn" above "Innstillinger". After sign-in it becomes
   the user's name with the active account beneath it.
2. **Library hint.** One dismissible line at the top of "Mine planer":
   *"Logg inn for å sikre planene dine."* Dismissed state persists. It does not
   reappear.
3. **At the moment it is needed.** Publishing a plan while signed out shows the
   publish dialog with a signed-out notice, not a blocking gate: the user can
   still publish anonymously (the catalog's wiki model,
   [ADR-0008](../adrs/0008-persistent-program-library-and-catalog.md)), and the
   notice explains what signing in would add. This is the entry point that will
   actually convert, and it is the one that must not feel like a paywall.

There is no sign-in step in onboarding
([DESIGN-007](./007-onboarding-and-help.md)). A first-run user has no plan worth
protecting yet.

### 3.2 Provider choice

Ordered by platform so the native option is first, per
[ADR-0024](../adrs/0024-account-and-identity-model.md):

| Platform | Order |
|---|---|
| iOS, macOS | Apple, Google, e-post |
| Android | Google, Apple, e-post |
| Web, Windows, Linux | Google, e-post, Apple |

E-post is always present and always last of the "big" two, because it is the
fallback that works when a provider account is unavailable — which is the whole
of §4.

The screen is one column: title, one line of purpose (*"Innlogging brukes til å
sikre planene du publiserer. Du kan bruke RingDrill uten å logge inn."*), the
provider buttons, and a text link to *"Hva lagres om meg?"* that opens §8's
explanation. No password field exists anywhere in the app.

### 3.3 The magic-link flow, and its one hard problem

Enter email → *"Vi har sendt en lenke til kari@example.com. Åpne den på denne
enheten."* → tap link → signed in.

The hard part is that **the link may open in a different browser or on a
different device than the one waiting for it.** Mail apps have their own web
views; a user reads mail on the phone and started sign-in on the desktop. Three
mitigations, in order of preference:

1. **Show a 6-character code alongside the link.** The waiting screen has a code
   field. If the link opens somewhere useless, the user types the code where
   they started. Same single-use token, two ways to redeem it.
2. **The link page works standalone.** Opening the link in any browser completes
   sign-in *there* and says so, rather than failing with "start again".
3. **The waiting screen never blocks.** Back always works, and returning to it
   later re-offers the code field for the remaining validity (10 minutes, per
   the rollout plan's threat model).

Codes and links are single-use and expire together. Rate-limited per email
address; the copy on repeated requests is the same regardless of whether the
address has an account, so the screen never discloses who has one.

### 3.4 Linking a second provider

Automatic on verified-email match (ADR-0024's step 2), and the user is *told*
after the fact rather than asked before: *"Vi koblet Google-innloggingen din til
kontoen du allerede har (kari@example.com)."* Shown once, on the first sign-in
after the link. Silence here would be worse — a user who signs in with a
different button and lands in the same account should be told why.

Unverified emails never auto-link. They create a separate `User`, and the
account page offers *"Koble til en annen innloggingsmetode"* for manual linking.

### 3.5 CLI

`ringdrill login` runs the same email flow with the code path from §3.3 as the
primary affordance, since a terminal has no browser callback worth relying on.
Out of scope beyond that; see ADR-0024 and rollout phase 6.

### 3.6 Signing out

*"Logg ut"* on the account page, with a confirm that states the one thing users
will worry about: **local plans stay on the device.** Signing out does not
delete, unpublish, or hide anything. Tokens are cleared, the drawer returns to
"Logg inn", and every plan in Library is exactly where it was.

## 4. Account recovery — what replaces "forgot my password"

There are no passwords, so there is nothing to reset. There are four situations
that actually occur, and each needs a different answer. The recovery entry point
is one link on the sign-in screen: *"Får du ikke logget inn?"*

### 4.1 "I can't receive the magic link"

Most common and least dramatic. If another `Identity` is linked to the same
`User`, the answer is *use it*: the recovery screen lists the sign-in methods
that exist for that address without revealing whether the address has an account
at all — it says *"Hvis kari@example.com har en konto, kan den også ha Apple-
eller Google-innlogging. Prøv disse."* Generic on purpose.

If email is the only identity, the honest answer is that we cannot help without
identity-proofing, and we are not going to build identity-proofing. Which makes
§4.4 the real mitigation.

### 4.2 "My Apple relay address stopped forwarding"

Apple's Hide-my-email relay survives at Apple but does not accept mail from
arbitrary senders, and a user can disable forwarding per app. ADR-0024 flags
this as a known bad consequence. Design response:

* At sign-in with Apple, if the relay is used, prompt once — not as a wall — to
  *"Legg til en e-postadresse du kan nå"*, explaining it is used only for
  recovery.
* If forwarding is later broken, Apple sign-in itself still works. The relay
  only matters for the email path, so this degrades to §4.1 with Apple as the
  surviving identity.

### 4.3 "I lost the device that was signed in"

Not a recovery problem — sign in again on the new device. The design response is
a **sessions list** on the account page: device label, last used, and *"Logg ut
denne enheten"*. This is also the answer to "my phone was stolen", and it is the
one place where refresh-token rotation
([ADR-0025](../adrs/0025-authorization-and-publish-policy.md)) becomes visible:
a session that was invalidated by replay detection shows as ended, with a plain
explanation.

### 4.4 "I'm the only owner of an organisation and I can't get in"

The one that actually loses data. An organisation whose sole `owner` cannot sign
in is unrecoverable without support intervention, and its members keep read
access while nobody can change policy or membership.

**The design answer is prevention, and it belongs on the members screen, not in
recovery.** An organisation with exactly one owner shows a persistent, low-key
advisory: *"Denne organisasjonen har én eier. Legg til en til, så mister dere
ikke tilgangen hvis noen blir utilgjengelig."* Not a modal, not blocking,
dismissible per organisation but re-shown when membership changes.

When it happens anyway: a support path (email) with the honest caveat that
verification is manual and slow. No self-service ownership transfer, because
self-service ownership transfer is a takeover mechanism.

## 5. Account pages

### 5.1 Personal — nearly invisible

For a single planner, an account is bookkeeping. The personal account page is
therefore short: name, email, linked sign-in methods, sessions, *"Opprett
organisasjon"*, *"Logg ut"*, *"Slett konto"*. No members list, no role, no
account switcher (ADR-0024: the switcher is hidden when the user has one
account).

The page states what the account holds (§8), because that sentence has to exist
somewhere and this is where a user looks for it.

### 5.2 Upgrading to an organisation

ADR-0024 says inviting a second person upgrades a personal account to an
organisation *after explicit confirmation*. The confirmation must say what
changes, in these terms:

* The account gets a name of its own (defaulting to the user's, editable).
* Plans owned by it stay owned by it — nothing moves, nothing republishes.
* The invited person will be able to *(role-dependent)* publish updates to those
  plans.
* It cannot be undone by removing the member. The account stays an organisation.

That last point is the one users get wrong, so it is stated before the action
rather than discovered after.

**Alternative offered on the same sheet:** *"Opprett en ny organisasjon i
stedet"*, which leaves the personal account alone and starts empty. A user who
wants to share one plan with one colleague usually wants the upgrade; a user
setting up for a whole hjelpekorps usually wants the fresh organisation. Both
are one tap.

### 5.3 Organisation

Adds: the organisation name (editable by owners), the members list (§6), and the
single-owner advisory from §4.4. Everything else is the same page.

### 5.4 The active-account switcher

Appears in the drawer under the user's name only when the user belongs to more
than one account. It sets the account that new publishes are claimed for, and it
is sent per request as `X-Active-Account` (ADR-0025), so switching is instant
and needs no re-authentication.

**It must be visible at publish time.** The publish dialog names the account it
will publish to, and that line is tappable to switch. A user who publishes to
the wrong account discovers it at the worst possible moment otherwise.

### 5.5 Wide screen and web

Follows the existing master/detail model
([ADR-0030](../adrs/0030-wide-screen-master-detail-layout.md)): Settings is the
master list, "Konto" a detail pane. The members list becomes a two-pane layout
of its own — members in the list, the selected member's roles and actions in the
detail pane — rather than the bottom sheet used on phone
([ADR-0027](../adrs/0027-unified-bottom-sheet-chrome.md)). Forms promote to
dialogs, per ADR-0030.

On iOS and macOS the page uses the platform-adaptive chrome from
[ADR-0033](../adrs/0033-platform-adaptive-ui-on-ios.md). Sign in with Apple uses
the native button; nothing else about the flow changes per platform.

## 6. Member management

### 6.1 Roles, and exactly what each may do

Three, from ADR-0024, and the page must describe them in terms of consequences
rather than names:

| Role | `nb` | May |
|---|---|---|
| `owner` | Eier | Everything an editor may, plus: change a plan's access policy, invite and remove members, change roles, rename the organisation |
| `editor` | Redaktør | Publish updates to the account's plans |
| `viewer` | Leser | Read the account's plans. No publishing |

The role picker shows the one-line consequence under each name. "Redaktør" means
nothing on its own; *"Kan publisere oppdateringer til planene"* means something.

### 6.2 Inviting

By email address, with the role chosen at invite time. Three states follow:

* **Invited** — `acceptedAt == null`. The row shows the address, the chosen
  role, and *"Invitert 3. august"*, with *"Send på nytt"* and *"Trekk tilbake"*.
* **Accepted** — a normal member row.
* **Bounced or expired** — surfaced on the row, not hidden in a log.

> **Correction to the rollout plan.** Phase 5 of
> [`../plans/account-rollout.md`](../plans/account-rollout.md) says an invite
> "creates a Member with role `pending` until the invitee signs in and accepts".
> That is wrong against ADR-0024's model, where `Member` carries `role` *and*
> `invitedAt`/`acceptedAt`. Pending is a **state** (`acceptedAt == null`), not a
> role — the role is already decided at invite time and does not change on
> acceptance. Making it a role would mean a fourth `MemberRole` value that no
> permission rule ever names, which is exactly the shape that got `other` its
> "carries no rights" warning in DESIGN-011.

Inviting an address that has no `User` yet is normal and must work: the invite
is addressed to the email, and the `Member` binds when that person first signs
in with a verified identity for it.

### 6.3 Changing a role, removing, leaving

* **Change role** — bottom sheet on phone, detail pane on wide. Takes effect on
  the member's next request; no re-login.
* **Remove** — confirm names what the person loses (*"Kari mister tilgang til
  planene i organisasjonen. Planer hun har lastet ned blir liggende på hennes
  egen enhet."*). That second sentence is not optional: it is true, and users
  will assume otherwise.
* **Leave** — a member may remove themselves. An owner may not leave if they are
  the last owner; the button explains why and offers *"Gjør noen andre til
  eier først"*.

**Invariant, enforced server-side and reflected in the UI:** an organisation
always has at least one `owner`. The last owner's role picker has "Eier" locked
with a reason, rather than showing an option that will fail.

## 7. Two role vocabularies, and why they must never merge

This is the highest-risk part of the design.

The app already has `StaffRole` — `{director, instructor, actor, other}`,
Norwegian *øvelsesleder / veileder / markør / annet* — which does two jobs
([DESIGN-011](./011-person-with-role-and-roster-model.md),
[ADR-0057](../adrs/0057-role-gated-editing.md)): it is a person's role on the
roster, and it is *this device's* role, gating which edit affordances appear.

`MemberRole` — `{owner, editor, viewer}` — is a completely different axis: what
a signed-in user may do to *plans owned by an account*, enforced by the server.

They are independent, and both are true at once. A person can be `viewer` on
the organisation and `director` on the exercise: they may not publish, and they
may edit everything locally. Nothing about that is contradictory, but it reads
as a contradiction if the two ever appear as one "role" setting.

Design rules, non-negotiable:

1. **Different surfaces.** `StaffRole` lives on the roster and in the drawer's
   role switcher. `MemberRole` lives only on the account page. Neither surface
   mentions the other's values.
2. **Different words in `nb`.** *Rolle* is already spent on `StaffRole`. The
   members list uses *Tilgang* for the `MemberRole` column, and the role picker
   is titled *"Tilgang i organisasjonen"*.
3. **Never derived from each other.** No rule anywhere maps `owner`→`director`
   or back. They answer different questions.
4. The account page carries one explanatory line: *"Tilgang gjelder planer i
   organisasjonen. Rollen din under en øvelse settes i menyen."*

There is a third axis already in the codebase —
[ADR-0063](../adrs/0063-per-field-brief-visibility.md)'s per-field brief
visibility, which decides which *fields* a given audience sees within a plan
that a device already has. Three axes is the real number, and the account page
should not pretend otherwise.

## 8. What an account holds — the sentence that has to exist

[ADR-0072](../adrs/0072-staff-pii-and-account-sync.md) settles that a plan's
roster — real names, phone numbers — travels into the scope of the account that
owns the plan, while the public catalog stays stripped. The account page is
where that becomes something a user can act on. Under *"Hva lagres om
kontoen?"*:

* What the account holds: plans, and for plans synced to the account, the staff
  roster entered for them.
* Who can see it: members of this organisation. Explicitly **not** other
  accounts a plan has been shared with, and **not** anyone in the public
  catalog — a published plan never carries the roster.
* That entering someone else's name and number makes them a data subject, with
  a link to the privacy statement.

**Sequencing note.** Roster sync ships after rollout phase 5 against ADR-0072's
entry criteria. Until then this section describes plans only, and the roster
sentence is absent rather than aspirational. The heading exists from the first
account release so there is one obvious place for it to grow.

### 8.1 Open call — does a `viewer` see the roster?

ADR-0072 ties roster visibility to **account membership**, not to `MemberRole`.
Read literally, a `viewer` — someone admitted to the organisation with no
publishing rights — receives the roster with the plan.

That is defensible (they were admitted to the organisation; the roster is the
duty list for an exercise they are presumably working) and it keeps the rule to
one axis. The alternative is roster visibility keyed on role, which introduces a
fourth axis on top of §7's three.

**Recommendation: keep it to membership.** But it is a deliberate call about
personal data, it is invisible in the code once written, and it should be made
explicitly rather than inherited from an implementation detail. Flagged for
decision before the sync work starts.

## 9. States that are easy to forget

* **Offline.** Every account screen is read-only offline, showing cached values
  with one banner. Sign-in itself is unavailable and says so plainly.
* **Token expiry mid-session.** Refresh is silent. A refresh that fails returns
  the user to signed-out state *without* losing anything local, and the drawer
  explains rather than just reverting.
* **Slow invite.** The invite row appears immediately in `Invited` state; the
  send is optimistic and shows failure on the row.
* **Plans published before signing in.** They remain `anon`-owned and are not
  claimed. Library shows the fork affordance (rollout phase 3) rather than
  implying they became yours. The account page does not list them.
* **Deleting the account.** Removes `User`, `Identity` rows, memberships and
  account-scoped data. Published catalog plans are **not** deleted, because
  other people have installed them; the confirm says so.

## 10. Mockups

| File | Shows |
|---|---|
| [`mockups/auth-signin.html`](./mockups/auth-signin.html) | Provider choice, magic-link waiting screen with code fallback, linked-provider notice |
| [`mockups/auth-recovery.html`](./mockups/auth-recovery.html) | The four §4 situations, and the single-owner advisory |
| [`mockups/account-personal.html`](./mockups/account-personal.html) | Drawer signed-in state, personal account page, upgrade-to-organisation sheet |
| [`mockups/account-organisation.html`](./mockups/account-organisation.html) | Members list with pending invite, role picker, remove confirm, invite form |
| [`mockups/account-wide.html`](./mockups/account-wide.html) | Wide-screen and web master/detail layout for Settings → Konto |

## 11. Open questions

1. **Does a `viewer` see the roster?** §8.1. Recommendation: yes, keep visibility
   on membership. Needs an explicit decision before sync work.
2. **Organisation naming in `nb`.** "Organisasjon" is settled for the model and
   the account type, but not every group of people running a drill is an
   organisation. The *invite* copy can stay team-shaped
   (*"Inviter noen til å samarbeide"*) without reintroducing the `Team`
   collision. Worth a copy pass with a real user.
3. **Does an organisation need a member limit?** No product reason yet; a soft
   cap is cheap abuse insurance if invites are ever public-facing.
4. **Sessions list scope.** §4.3 lists devices for the `User`. Whether an owner
   can see or end *other members'* sessions is an admin capability with a
   surveillance smell. Recommendation: no.
