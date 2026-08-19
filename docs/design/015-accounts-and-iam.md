---
id: DESIGN-015
title: Accounts and IAM — sign-in, recovery, account pages and member management
status: Accepted
started: 2026-08-05
accepted: 2026-08-05
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

> This document and its mockups are in English, per
> [`AGENTS.md`](../../AGENTS.md) rule 12. `nb` wording appears only where the
> Norwegian word choice is itself the decision (§7). **Status: Accepted** (2026-08-05). The model is
> settled by [ADR-0024](../adrs/0024-account-and-identity-model.md) and
> [ADR-0025](../adrs/0025-authorization-and-publish-policy.md); this document
> decides what the user sees and does. It also **amends ADR-0024's
> `MemberRole`** to `{owner, member, guest}` — see §6.1.

## TL;DR

Signing in is optional and stays optional. **No account is the normal state of
an install, not a step someone has yet to complete.** Signing in buys one thing
— nobody changes your published plan without you — and it must not become a
wall in front of planning, reading the catalog, or running a drill. The surface is small: one
sign-in screen with four providers, one account page that grows a members list
when a second person is invited, and a recovery path for the situations that
replace "forgot my password" in a world with no passwords.

The two things most likely to go wrong are not screens. They are **two role
vocabularies that must not be conflated** (§7) — solved by scoping `MemberRole`
to the account side so nothing about it implies a `StaffRole` — and **an account
page that has to say plainly what an account holds** now that a roster can
travel with a plan (§8).

One rename escapes the account surface entirely and touches every user: the
plan selector's *Online* tab becomes *Public*, because once an account tab is
also on the network, "online" stops distinguishing anything (§5.7).

## 1. What this designs, and what it does not

**In scope:** sign-in and provider linking; account recovery; opting in and
out; the personal account page; the personal→organisation upgrade; the
organisation account page; invite, accept (including by someone with no
account yet), change role, remove and leave; the
active-account switcher; the publish dialog; the fourth tab this adds to the
plan selector; how all of it lays out on phone, wide screen and web.

**Out of scope:** the authorisation matrix itself (ADR-0025), the storage model
(ADR-0024), roster sync (ADR-0072 — the account page must *describe* what an
account holds, but sync ships later), and the CLI's `login` beyond one note in
§3.6.

**Not gated by sign-in, and this is load-bearing:** creating and editing plans,
importing and exporting `.drill` files, browsing and installing from the
catalog, running an exercise, joining a session, everything in the brief. A
person can use RingDrill for a full exercise and never see an account.

## 2. The model on one screen

| Entity | What it is | User-visible as |
|---|---|---|
| `User` | A person | "You" — name, email, linked sign-in methods |
| `Identity` | One provider login (`email`, `apple`, `google`, `microsoft`) | Rows under "Sign-in methods" |
| `Account` | What owns plans | "Account" — personal or organisation |
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
explain at all, which is why §5.2 works hard to make it nearly invisible until
it matters.

### 2.1 Sharing has exactly two shapes, and no third

**A `guest` is an authenticated user.** There is no anonymous guest: being a
guest means holding an `Identity`, which means having a `User`, which means
having a personal `Account` of your own. Admitting a guest to your organisation
is admitting *a person who signed in*, and the sign-in is theirs, not something
you provision for them.

That constrains the sharing model to two shapes, which is worth stating plainly
because designers and users both keep reaching for a third:

| Who you want to reach | How | What they need |
|---|---|---|
| Me, or my group | Members of the owning account (`owner`, `member`) | To sign in |
| One named outsider | Add them as `guest` | To sign in — they get their own personal account |
| Another group | `AccessPolicy.shared` to their account | An account of their own |
| Anyone at all | `AccessPolicy.public`, via the catalog | Nothing |

**There is no "secret link for one person who will not sign in".** If the person
will not authenticate, the only server-side option is `public` — the plan is in
the catalog and anyone can read it. Designing a fourth tier of unauthenticated
per-person sharing would mean bearer URLs, which are credentials that leak
through browser history, chat logs and screenshots, for a case the two existing
shapes already cover.

The escape hatch for "give it to one person without publishing it" is the one
that already exists and needs no account at all: **hand them the `.drill`
file.** Peer-to-peer transfer is untouched by any of this, and it is also the
only path that carries the staff roster to someone outside the account
([ADR-0072](../adrs/0072-staff-pii-and-account-sync.md)).

## 3. Sign-in

### 3.1 Entry points

Three, and no more:

1. **Drawer tile.** "Sign in" above "Settings". After sign-in it becomes
   the user's name with the active account beneath it.
2. **Library hint.** One dismissible line at the top of "My plans":
   *"Sign in to protect your plans."* Dismissed state persists. It does not
   reappear.
3. **At the moment it is needed.** Publishing a plan while signed out shows the
   publish dialog with a signed-out notice, not a blocking gate: the user can
   still publish anonymously (the catalog's wiki model,
   [ADR-0008](../adrs/0008-persistent-program-library-and-catalog.md)), and the
   notice explains what signing in would add. This is the entry point that will
   actually convert, and it is the one that must not feel like a paywall.

   ADR-0025's authorisation matrix originally required an authenticated user
   for *any* new slug, which would have made this entry point a gate after all.
   It was amended on 2026-08-05 to keep anonymous new-slug publishing — what
   makes §5.1's "no account is a finished state" true all the way through the
   one flow where it would otherwise quietly stop being true.

There is no sign-in step in onboarding
([DESIGN-007](./007-onboarding-and-help.md)). A first-run user has no plan worth
protecting yet.

### 3.2 Provider choice

Ordered by platform so the native option is first, per
[ADR-0024](../adrs/0024-account-and-identity-model.md):

| Platform | Order |
|---|---|
| iOS, macOS | Apple, Google, Microsoft, email |
| Android | Google, Microsoft, Apple, email |
| Windows | Microsoft, Google, Apple, email |
| Web, Linux | Google, Microsoft, Apple, email |

**Implemented in `orderProvidersForPlatform`** (`lib/services/auth_service.dart`),
not on the server: the list of *which* providers exist is a deployment fact, but
the order is a platform fact, and the server has no business inferring the
platform from a user agent. Mockups:
[`auth-signin-platforms.html`](./mockups/auth-signin-platforms.html).

**The iOS row is a requirement, not a preference.** Apple's guidelines say Sign
in with Apple must be displayed at least as prominently as the alternatives —
first position satisfies that, last does not, and getting it wrong is a review
rejection. The other rows are judgements about which account the device is
likely to already hold. The web row is checked *before* the platform, because a
web build still reports a host platform (Safari says iOS) and a browser on a
Mac must not be ordered as a native Apple client.

A provider not named in a row lands at the end rather than disappearing, so
adding one later — §3.2 reserves Feide and Vipps — is additive.

Email is always present and always last, because it is the fallback that works
when a provider account is unavailable — which is the whole of §4.

**`email` is not a droppable provider**, and the reason is infrastructure
rather than preference. A transactional mail channel is required whether or not
anyone signs in with it:

* **Invitations** (§6.2, §6.4) go to an address that may have no account yet.
  There is no other way to reach that person.
* **Verifying a second address** is the fix for the Apple-relay duplicate
  (§3.5), and verification means sending mail.
* **Bounce handling** — §6.2 renders "Email bounced" as a state on the member
  row, which comes from the provider's webhook.
* Security notices (refresh-token replay, §4.3) and deletion confirmation
  (§5.1) both want a channel that is not the app.

Given the channel exists, `email` as a *sign-in* provider costs one endpoint
and one screen, and buys the guideline 4.8 fallback, the recovery path, and the
only remedy for a relay-address duplicate. There is no password anywhere in
this: `email` means a magic link with a code fallback (§3.3).

**Microsoft covers both flavours** through one adapter: personal
(outlook.com) and work/school (Entra ID — `@rodekors.org`,
`@folkehjelp.no`). A volunteer signing in with their korps address is the case
that motivates it ([ADR-0024](../adrs/0024-account-and-identity-model.md),
amended 2026-08-05).

**Four buttons is the ceiling for a flat list.** At four the screen stays a
single column with no disclosure. A fifth provider — `feide` or `vipps` are the
reserved candidates — turns this into the top three plus *"More ways to sign
in"*, with email still directly visible because recovery depends on it. Stating
the threshold now means the next provider does not quietly make this screen
worse.

The screen is one column: title, one line of purpose (*"Signing in protects the
plans you publish. You can use RingDrill without signing in."*), the
provider buttons, and a text link to *"Hva lagres om meg?"* that opens §8's
explanation. No password field exists anywhere in the app.

### 3.3 The magic-link flow, and its one hard problem

Enter email → *"We sent a link to kari@example.com. Open it on this device."* →
tap link → signed in.

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

### 3.5 Signing in on a device whose native provider is not the one you used

Someone signs up on the web with Google, then installs the iOS app, where §3.2
puts Apple first. Three things can happen and only the last is a problem — but
it is a bad one, so it gets designed rather than discovered.

**She taps Google.** It works. On iOS this runs through
`ASWebAuthenticationSession`, the system browser sheet, which shares cookies
with Safari — already signed into Google there, and it is one tap. Apple does
not restrict this: guideline 4.8 requires an equivalent option to be *offered*,
not that Apple's be used. This is the common case and it needs no design.

**She taps Apple, and her Apple ID carries her real address.** Verified-email
match (§3.4) links the new Apple identity to the User she already has, and she
is told after the fact. Works.

**She taps Apple with Hide My Email.** Apple returns
`xyz@privaterelay.appleid.com` — *verified*, and permanently different from her
Google address. Step 2 cannot match, step 3 fires, and she gets **a second User
with a second personal account and none of her plans**. Two Apple specifics
make it worse: the relay address will never equal her real one, and Apple
returns the real email **only on first authorization** — every later sign-in
gives the subject alone, so a missed capture cannot be recovered from Apple.

The response, in order of when it applies:

1. **Ask the relay user for a reachable address, and verify it.** §4.2 already
   prompts for this once, framed as recovery. It is doing double duty: a
   *verified* second address is exactly the key step 2 needs, so verifying it
   turns a would-be duplicate into a link. This is the main fix, and it is the
   reason the `email` provider is not optional — without a channel to verify a
   second address, case three has no remedy at all.
2. **Recognise the shape and offer, once, without blocking.** A brand-new User,
   created via Apple, with a relay address and zero plans is the highest-risk
   duplicate we can detect. Say so plainly — *"Used RingDrill before? Add the
   address you used and we will connect them."* — as a dismissible line, not a
   wall. A genuinely new user dismisses it and never sees it again.
3. **Never merge on a guess.** No heuristic joins two accounts automatically.
   Two accounts is confusing; silently merging the wrong two is worse, and
   there is no undo.

**Be honest about what is left over.** If somebody does end up with two
accounts, **there is no merge in this release.** Linking the identity makes
future sign-ins converge on one of them, but plans already published under the
other stay there; moving them means exporting and importing `.drill` files. An
account-merge flow is a real feature with real edge cases (two personal
accounts, memberships on both, published slugs on both) and inventing it before
anyone has hit the problem is the wrong order.

### 3.6 CLI — device authorization, not a second magic link

**Ships after the account release**, not in it. Designed here so the two new
endpoints it needs are known before the auth surface is built.

An earlier draft had `ringdrill login` run the §3.3 email flow with the code as
the primary affordance. That works, and it is worse than it looks: it forces an
email round-trip even when the person is already signed in in their browser, it
gives the CLI the *same* session as the app with no separate consent and no
separate revocation, and it never shows the user what they are authorising.

The right shape is the **device authorization grant**
([RFC 8628](https://www.rfc-editor.org/rfc/rfc8628)) — the flow every CLI that
talks to a hosted service already uses, and the one users recognise:

```
$ ringdrill auth login

  Open  https://ringdrill.app/auth/device
  Code  WDJB-MDQN

  Waiting…
```

1. `POST /api/auth/device/start` returns a `device_code` (secret, kept by the
   CLI), a short `user_code` for the human to type, a `verification_uri`, an
   `expires_in` and a poll `interval`.
2. The CLI prints both, and opens the browser when stdout is a TTY.
3. The browser side reuses whatever session already exists — Apple, Google or
   email (§3.2). Nobody signs in twice.
4. A **consent screen** states what is being granted, to which accounts, and
   under what device label.
5. `POST /api/auth/device/token` is polled with the `device_code` —
   `authorization_pending`, `slow_down`, then tokens.
6. Tokens land in `$XDG_CONFIG_HOME/ringdrill/credentials.json`
   ([ADR-0024](../adrs/0024-account-and-identity-model.md)).

Why this beats the email flow on three counts that matter:

* **No second authentication.** The browser is already signed in. The email
  flow would make a signed-in user prove themselves again to a device standing
  right next to them.
* **Consent is explicit and visible.** This is the step the email flow has no
  place for, and it is the whole reason a user should feel safe pasting a code.
* **The CLI becomes a separately revocable session.** It appears in Account →
  Devices (§4.3) as "RingDrill CLI · kengu-mbp", signed out on its own without
  touching the phone. A shared session cannot offer that.

**The phishing case, which RFC 8628 §5.4 names and which the consent screen has
to answer.** An attacker starts their own device flow and talks a victim into
approving *their* code. The mitigation is that the browser **echoes the code
back** and asks the user to confirm it matches the terminal in front of them.
The user typed it, so a mismatch is visible; without the echo it is not.

**Scope is all-or-nothing, deliberately.** ADR-0024 has no scope system: an
access token carries the user's accounts and roles, so the CLI acts as the
user. The consent screen must therefore say that plainly rather than imply a
narrower grant — it lists the accounts and says the CLI can do what you can do.
Per-scope grants ("publish only", "one account only") fit later without a model
change and are not worth inventing before someone needs them.

**CI does not use this flow.** It is interactive by construction. Automation
keeps a long-lived personal token in `RINGDRILL_ACCESS_TOKEN`, which is what
replaces `RINGDRILL_ADMIN_TOKEN` — see the rollout plan.

### 3.7 Signing out

*"Logg ut"* on the account page, with a confirm that states the one thing users
will worry about: **local plans stay on the device.** Signing out does not
delete, unpublish, or hide anything. Tokens are cleared, the drawer returns to
"Sign in", and every plan in Library is exactly where it was.

## 4. Account recovery — what replaces "forgot my password"

There are no passwords, so there is nothing to reset. There are four situations
that actually occur, and each needs a different answer. The recovery entry point
is one link on the sign-in screen: *"Trouble signing in?"*

### 4.1 "I can't receive the magic link"

Most common and least dramatic. If another `Identity` is linked to the same
`User`, the answer is *use it*: the recovery screen lists the sign-in methods
that exist for that address without revealing whether the address has an account
at all — it says *"If kari@example.com has an account, it may also have Apple
or Google sign-in. Try those."* Generic on purpose.

If email is the only identity, the honest answer is that we cannot help without
identity-proofing, and we are not going to build identity-proofing. Which makes
§4.4 the real mitigation.

### 4.2 "My Apple relay address stopped forwarding"

Apple's Hide-my-email relay survives at Apple but does not accept mail from
arbitrary senders, and a user can disable forwarding per app. ADR-0024 flags
this as a known bad consequence. Design response:

* At sign-in with Apple, if the relay is used, prompt once — not as a wall — to
  *"Add an email address you can reach"*, explaining it is used only for
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
advisory: *"This organisation has one owner. Add another, so access is not lost
if someone becomes unavailable."* Not a modal, not blocking,
dismissible per organisation but re-shown when membership changes.

When it happens anyway: a support path (email) with the honest caveat that
verification is manual and slow. No self-service ownership transfer, because
self-service ownership transfer is a takeover mechanism.

## 5. Accounts in the UI

### 5.1 The default is no account, and it stays the default

**No account is the normal state of a RingDrill install, not a state on the way
to a real one.** A person can plan, run, brief, import, export and install from
the catalog forever without signing in, and nothing in the UI should imply they
are missing a step. No badge on the drawer, no "complete your setup", no
counting an account as onboarding progress
([DESIGN-007](./007-onboarding-and-help.md) ends without one).

**Opting in is one act, not two.** Signing in *is* getting a personal account —
ADR-0024 creates it automatically at first sign-in — so the UI must never
present "sign in" and "create an account" as separate decisions or separate
screens. It must, however, *say* that this is what happens, on the sign-in
screen itself: *"We create a personal account for you. It owns the plans you
publish."* A thing created silently on your behalf is worse than a thing you
were told about.

**Opting out has two levels, and they are not the same:**

* **Sign out** — tokens cleared, local plans untouched, account still exists.
  Reversible by signing in again. §3.6.
* **Delete account** — `User`, `Identity` rows, memberships and account-scoped
  data are removed. Plans already published to the catalog are **not** deleted,
  because other people have installed them; the slug survives with its owner
  reference dropped. The confirm says exactly that, because "delete my account"
  reasonably sounds like it should unpublish, and it does not.

The `guest` role does not weaken any of this, but it does have a consequence
worth stating where people will look for it — see §2.1.

### 5.2 Personal — nearly invisible

For a single planner, an account is bookkeeping. The personal account page is
therefore short: name, email, linked sign-in methods, sessions, *"Opprett
organisasjon"*, *"Logg ut"*, *"Slett konto"*. No members list, no role, no
account switcher (ADR-0024: the switcher is hidden when the user has one
account).

The page states what the account holds (§8), because that sentence has to exist
somewhere and this is where a user looks for it.

### 5.3 Upgrading to an organisation

ADR-0024 says inviting a second person upgrades a personal account to an
organisation *after explicit confirmation*. The confirmation must say what
changes, in these terms:

* The account gets a name of its own (defaulting to the user's, editable).
* Plans owned by it stay owned by it — nothing moves, nothing republishes.
* The invited person joins as `member` and can publish updates to those plans.
  `guest` is offered on the same sheet for someone who should only read.
* It cannot be undone by removing the member. The account stays an organisation.

That last point is the one users get wrong, so it is stated before the action
rather than discovered after.

**Alternative offered on the same sheet:** *"Opprett en ny organisasjon i
stedet"*, which leaves the personal account alone and starts empty. A user who
wants to share one plan with one colleague usually wants the upgrade; a user
setting up for a whole hjelpekorps usually wants the fresh organisation. Both
are one tap.

### 5.4 Organisation

Adds: the organisation name (editable by owners), the members list (§6), and the
single-owner advisory from §4.4. Everything else is the same page.

### 5.5 The active-account switcher

Appears in the drawer under the user's name only when the user belongs to more
than one account. It sets the account that new publishes are claimed for, and it
is sent per request as `X-Active-Account` (ADR-0025), so switching is instant
and needs no re-authentication.

**It must be visible at publish time.** The publish dialog names the account it
will publish to, and that line is tappable to switch. A user who publishes to
the wrong account discovers it at the worst possible moment otherwise.

### 5.6 Wide screen and web

Follows the existing master/detail model
([ADR-0030](../adrs/0030-wide-screen-master-detail-layout.md)): Settings is the
master list, "Account" a detail pane. The members list becomes a two-pane layout
of its own — members in the list, the selected member's roles and actions in the
detail pane — rather than the bottom sheet used on phone
([ADR-0027](../adrs/0027-unified-bottom-sheet-chrome.md)). Forms promote to
dialogs, per ADR-0030.

On iOS and macOS the page uses the platform-adaptive chrome from
[ADR-0033](../adrs/0033-platform-adaptive-ui-on-ios.md). Sign in with Apple uses
the native button; nothing else about the flow changes per platform.

### 5.7 The plan selector grows a fourth tab

`showOpenPlanDialog` ([`library_view.dart`](../../lib/views/library_view.dart))
is today `LibraryTab { myPlans, online, fromFile }` — *My plans* / *Online* /
*New from file*. Accounts add a source that is neither local nor public, so the
enum becomes:

| Tab | `nb` | `en` | Holds |
|---|---|---|---|
| `myPlans` | Mine planer | My plans | On this device |
| `account` | Konto | Account | Owned by the active account. Written by its members, not visible to strangers |
| `public` | Offentlig | Public | The open catalog. Anyone can read; `public`-policy plans anyone can write |
| `fromFile` | Ny fra fil | New from file | Import a `.drill` |

Two decisions in that table.

**`online` is renamed to `public`, and the label changes with it.** *Online*
(`nb` *På nett*) described *where the plan lives*, which stops distinguishing
anything the moment the account tab is also on the network. *Public* (`nb`
*Offentlig*) describes **who can read it**, which is the question a user is
actually asking when they pick between the two tabs. The rename is the honest one, and it is worth the churn precisely
because the old word becomes ambiguous rather than merely imprecise.

**The account tab does not exist until there is an account.** A signed-out
user sees exactly today's three tabs, in today's order, with one renamed. This
is not only §5.1's principle applied consistently — it also solves the crowding,
because four tabs of Norwegian labels on a 375 pt phone is genuinely tight and
most installs will never see the fourth. When the user belongs to more than one
account, the tab follows the active account (§5.5) rather than multiplying.

**Backend consequence.** The account tab needs "list plans owned by account X,
published or not", which no endpoint provides — `market-feed` filters on
`published` and is public by design. That is a new authenticated endpoint,
`GET /api/accounts/:id/plans`, now listed in
[`../plans/account-rollout.md`](../plans/account-rollout.md). Until it exists
the tab is not shown, which the "no account, no tab" rule already produces for
free.

### 5.8 The publish dialog carries three decisions

More design lands on this one screen than on any other, and it is scattered
across three sections above. Collected here because it is built once:

1. **It is sign-in entry point 3 (§3.1), and must not read as a paywall.**
   Signed out, *Publish* is the primary action and *Sign in first* is the
   alternative below it. The explanation is one plain line — you are not signed
   in, so open-to-everyone is the only option, and signing in would let you keep
   the plan to yourself. No warning colour, no lock icon, no interstitial.
   Anonymous publishing is a supported workflow
   ([ADR-0025](../adrs/0025-authorization-and-publish-policy.md), amended
   2026-08-05), not a degraded one.
2. **It names the account it will publish to** (§5.5), under *Publishes to*,
   with a *Switch* affordance when the user belongs to more than one. A person
   who publishes to the wrong account otherwise finds out afterwards.
3. **It holds the access policy, under *Sharing* — not *Tilgang*.** §7 reserves
   *Tilgang* for a person's standing in an account; using it here as well would
   put a plan's write policy and a member's role under one word. The dialog is
   choosing how the *plan* is shared. Options are phrased as consequences, not
   as policy names: *Only my account* / *Red Cross Bergen only* / *Shared with
   other accounts* / *Open to everyone*.

**One line that belongs here and nowhere else.** *"Staff details are never
published."* The publish dialog is the exact moment a user wonders whether the
phone numbers they typed are about to become public, and it is the only screen
where answering costs nothing. In an organisation it extends to the half people
get wrong — *the roster stays inside the organisation; a shared account gets the
plan, not the people*
([ADR-0072](../adrs/0072-staff-pii-and-account-sync.md)).

### 5.9 One form, sections by role

§5.2 and §5.4 describe two pages that are mostly the same page — "everything
else is the same page", as §5.4 puts it. Building them that way produced one
screen editing two different records at once: **the user** (full name, nickname,
phone, devices) and **the account** (name, handle, members, plans). On a
personal account those coincide, so the screen can pretend to be one thing; on
an organisation they do not, and the page ends up branching on account type in a
dozen places.

The form is therefore **section-navigated** ([DESIGN-008](./008-plan-variables-and-section-navigated-editor.md)),
like the five entity editors — a rail of sections on medium and expanded, the
same sections as a navigated list on compact (ADR-0030) — and the section list
depends on the reader:

| Section | Edits | Shown to | Editable by |
|---|---|---|---|
| Details | the account | everybody in the account | owners |
| Members | the account | **an organisation's** members | owners |
| Sharing | the account's published plans | everybody in the account | anyone who may publish |
| *— divider —* | | | |
| Profile | the user | everybody, in every account | the user |
| Devices | the user | everybody | the user |

**No trailing chevron on a section row.** The compact list is `ListTile`s with
a leading icon, a title and a subtitle; the current section carries
`Icons.check` and nothing else is decorated. The five chevrons in the app are
navigation *buttons* — the section-form's own next control, a field's picker —
not a mark meaning "this row is tappable", which every row in a list already is.

**The rail is grouped, and the divider is load-bearing.** The account's
sections come first, then a rule, then the user's. Without it "Profile" sits in
a list headed by an organisation's name and reads as something that
organisation owns — which is exactly the confusion that made this form look
like two screens in the first place. The order follows the header: this is the
account, and you are also here.

The mockups for this section are
[`mockups/account-sections.html`](./mockups/account-sections.html) and
[`mockups/account-personal-upgrade.html`](./mockups/account-personal-upgrade.html),
generated like the rest of the DESIGN-015 family. Where a drawing and this text
disagree, this text is the record.

#### Deleting, which is two different actions

**Delete lives at the bottom of Details**, below everything else and visibly
apart from it — the account's own section, which both kinds of account have.
Not its own rail entry: a section whose only content is a destructive button is
a trap in a list people scan, and it would sit next to Profile where a mis-tap
is expensive.

What it destroys depends on the account, and the label has to say so rather
than leaving one word to mean both:

| | Label | What goes | What survives |
|---|---|---|---|
| Personal | **Delete account and profile** | the account *and the user behind it* — profile, sessions, memberships | published plans, which other people have installed; they lose their owner reference (§5.1) |
| Organisation | **Delete organisation** | the organisation and its memberships | every member's own profile and account; published plans, orphaned as above |

`deleteAccount` already implements both halves — "delete an account, and, for a
personal one, the user behind it". The interface's job is to say which one is
about to happen, because "Delete account" on a personal account is an
understatement: it deletes *you*.

**An organisation with one owner is refused, not warned.** §4.4's advisory is
the prevention; the delete path already returns the organisations that would be
stranded so they can be named rather than counted.

**On medium and expanded it is a dialog, not a page.** `openFormSurface` routes
the form through `showRingdrillFormDialog`, which caps it at **720 wide and 88%
of the viewport height** with a 24px inset — so on a 1280×800 window the whole
thing is 720×704, with the app visible behind it. Worth stating because it is
easy to design this as a full-bleed screen and end up with a rail and a body
that only work at twice the width they get.

**The header is two lines**: `Account`, then `Personal` or
`Red Cross Bergen (red-cross-bergen)`. One line — "Account · Red Cross Bergen"
— reads as a breadcrumb to somewhere else, and the two lines answer different
questions: what this form is, and which account it is pointed at. Only the
second changes.

**Details is on every account, personal included.** It is where the handle is
claimed (below), and it is where a personal account becomes an organisation —
an explicit action on the section that already describes the account, rather
than a consequence of inviting somebody.

**Details is never hidden from a member.** The account's name and handle are
what a member tells somebody else in order to be shared with (§5.8) — read-only
for them, editable by an owner. Only the *editing* is a role question; the fact
of the account is not.

**Members arrives with the organisation, not before it.** A personal account
has nobody to list, and a section holding one person with an Invite button
would say the account is already something it is not. The upgrade is therefore
an action in **Details** — "Make this an organisation" — which opens §5.3's
sheet.

### 5.10 Sharing, which is not membership

**Sharing a plan with another account does not make anybody a member, and does
not convert a personal account into an organisation.** The two mechanisms are
unrelated and always were: membership is who is *in* an account, and
`accessPolicy: shared` is a grant on *one plan* to named accounts. Nothing in
`drills-policy.js` or `authorize.js` checks account type, so any account can
grant any other account access to a plan.

**Every account shares.** Two organisations running a joint exercise is the
case that will certainly happen — a hjelpekorps and the local rescue dogs
staffing the same day — and two personal accounts cooperating 1:1 is the
smallest version of the same thing. The mechanism is identical and neither
side's account type changes, so the section belongs on every account rather
than being an organisation feature or a personal-account consolation.

That is the section's job. Publishing is the only place a grant can currently
be made, and `setAccessPolicy` has exactly one caller in the app, so once a plan
is out there is no way to see who it was shared with, revoke one, or narrow a
plan back from public. Sharing lists the account's published plans with their
policy and grantees, and changes them in place.

Deliberately not a second plan browser: the library's account tab already lists
and opens an account's plans (§5.7). This section answers "how open is each of
these, and who did we grant it to", which nothing answers today.

**Sections a role cannot use are absent, not disabled.** A greyed-out "Members"
invites the question "why can I not?", which is a support conversation about
somebody else's role — and the screen cannot answer it.

**Profile is the same record wherever it is reached from.** Somebody in three
accounts sees their profile in three places, editing one thing. That is the
cost of a single form, and it is the right way round: the alternative is a
separate profile screen, which makes "change my phone number" a different
journey depending on which account happens to be active.

**Details holds two names, and they must not both be called one.** The
*account name* is the display name — "Red Cross Bergen", or the person's own on
a personal account. The *account handle* is `red-cross-bergen`. Labelling both
"name" is the confusion this section is most likely to produce, and the app
already says "Account handle" in the publish dialog (`publishSharedHandleLabel`),
so that is the term.

The handle carries an explanation, because nothing about the field says what it
is for: it is the short name in the plans' web addresses
(`ringdrill.app/d/red-cross-bergen/lsor-eidene-2026`) and the name you give
another account so they can share a plan *with* you (§5.10). It also carries an
action on the field row itself, and **only its label changes with the state**:
*Copy* once a handle is claimed — handing it over is what it is for, and the
next thing anybody does with it is paste it into a message — and *Claim* while
there is none. One row, one place to look, whichever state the account is in.

**Claiming one is the same act on both kinds of account**, and optional on
both: one field, first-come, globally unique, changeable with the old name
tombstoned so shared links keep resolving (ADR-0074 §2). A personal account is
not a lesser case here — it is the case that most needs a handle, because
claiming one is what lets a colleague name it when sharing a plan.

**Optional for publishing, required for being shared with.** `resolveNamespace`
falls back to the account id, so an account with no handle publishes perfectly
well at `/d/a_x7k2h9/winter-drill`. But the publish dialog names a grantee by
handle and resolves it through `lookupHandle`, which resolves handles and not
ids — so a handle-less account can publish and cannot be named as the account
to share *with*. That asymmetry, not tidiness, is the reason to claim one, and
it is what the section's explanation should say.

**Unclaimed, the row offers Claim and copies nothing.** Copying the account id
would hand somebody an opaque internal identifier to paste into a message as if
it were a name — the unreadable outcome a handle exists to remove — and it would
not even serve the purpose they copied it for, since a grantee cannot be named
by id.

> **Not yet buildable.** A handle can currently only be claimed while an
> organisation is created or upgraded; there is no route for an existing
> account, so neither Claim nor a rename can be implemented as drawn. See
> [DEBT-0014](../debts/0014-handles-cannot-be-claimed-after-creation.md).

**The handle does not wait for the upgrade.** A personal account is created
with `handle: null` and publishes perfectly well without one — `resolveNamespace`
falls back to the account id, so a plan lands at `/d/a_x7k2h9/winter-drill`.
That works, and it is not a name anybody can pass on — and the handle is also
what somebody else types to share a plan *with* this account (§5.8), so every
account that publishes wants one. Details offers it suggested from the name and claimed
explicitly.

It cannot be *derived* from the nickname. A nickname is display text and two
people may share one; a handle is a globally unique claim, taken first-come and
atomically, changeable, with the old one tombstoned so links already shared keep
resolving (ADR-0074 §2) — the same model as a handle on any social network.
Deriving one silently would fail for the second Kari and hand the first a name
she never chose.


## 6. Member management

### 6.1 Roles, and exactly what each is for

**`MemberRole` is `{owner, member, guest}`, and it gates two things — neither of
which is "may you work on the plans".** This amends ADR-0024's original
`{owner, editor, viewer}`; the reasoning is recorded there.

| Role | Label (`en` / `nb`) | Publishes | Sees the roster | Administers |
|---|---|:--:|:--:|:--:|
| `owner` | Owner / Eier | ✔ | ✔ | ✔ |
| `member` | Member / Medlem | ✔ | ✔ | — |
| `guest` | Guest / Gjest | ✔ | — | — |

**Everyone admitted to the account can publish its plans.** The account
protects a plan from *strangers*; someone the account deliberately added is not
a stranger, and routing their work through a colleague with the publish button
buys nothing but friction.

That leaves the role two jobs:

1. **`owner` administers.** Invites, removes, changes roles, renames the
   organisation, changes a plan's access policy.
2. **`guest` is outside the group for personal-data purposes.** A guest works
   on the plans and does not see the staff roster (§8.1).

`guest` is therefore a *personal-data* tier, not a capability tier, and that is
its whole reason to exist: someone from a neighbouring korps helping you build
a plan can edit it and publish it, and does not get your people's names and
phone numbers. One question, one answer, nothing to misremember.

The role picker shows the consequence under each name, because a role name
alone never carries its own meaning:

* **Owner** — *"Manages members and access, plus everything a member can do."*
* **Member** — *"Reads and publishes the plans, and sees the staff roster."*
* **Guest** — *"Reads and publishes the plans, but does not see the roster."*

…under a single line that stops the picker reading as a permission ladder:
*"Alle du legger til kan jobbe med planene. Forskjellen er om de ser stablista —
navnene og telefonnumrene til folkene deres."*

A fourth tier between owner and member — an *admin* who manages people but
cannot delete the account — fits the model without a change and is not added
now, because at one-organisation-per-hjelpekorps scale there is nobody to be it.

### 6.2 Inviting

By email address, with the role chosen at invite time. Three states follow:

* **Invited** — `acceptedAt == null`. The row shows the address, the chosen
  role, and *"Invited 3 August"*, with *"Send again"* and *"Withdraw"*.
* **Accepted** — a normal member row.
* **Bounced or expired** — surfaced on the row, not hidden in a log.

> **Pending is a state, not a role.** An earlier draft of
> [`../plans/account-rollout.md`](../plans/account-rollout.md) said an invite
> "creates a Member with role `pending`". That is wrong against ADR-0024's
> model, where `Member` carries `role` *and* `invitedAt`/`acceptedAt`: the role
> is decided at invite time and does not change on acceptance. Making it a role
> would mean a fourth `MemberRole` value that no permission rule ever names —
> exactly the shape that got `other` its "carries no rights" warning in
> DESIGN-011. The plan no longer says it.

Inviting an address that has no `User` yet is normal and must work: the invite
is addressed to the email, and the `Member` binds when that person first signs
in with a verified identity for it.

### 6.3 Changing a role, removing, leaving

* **Change role** — bottom sheet on phone, detail pane on wide. Takes effect on
  the member's next request; no re-login. **Demotion is not a way to withdraw
  trust.** Moving someone from `member` to `guest` takes away their view of the
  roster and nothing else; they still publish. For someone who should no longer
  be working on the plans at all, the action is *Remove*, and the UI must not
  offer demotion as a softer alternative.
* **Remove** — confirm names what the person loses (*"Kari loses access to
  the organisation's plans. Plans she has already downloaded stay on her own
  device."*). That second sentence is not optional: it is true, and users will
  assume otherwise.
* **Leave** — a member may remove themselves. An owner may not leave if they are
  the last owner; the button explains why and offers *"Make someone else an
  owner first"*.

**Invariant, enforced server-side and reflected in the UI:** an organisation
always has at least one `owner`. The last owner's role picker has "Owner" locked
with a reason, rather than showing an option that will fail.

### 6.4 Accepting an invitation, with no account yet

§6.2 says the model handles an invite to an address with no `User`. This is the
flow, because "it binds when they sign in" leaves four questions whose default
answers are all wrong.

**The email.** Names the person inviting, the organisation, and the role, then
one button. It is the only unsolicited mail RingDrill sends, so it says why it
arrived and how to make it stop.

**The link is not a credential.** `ringdrill.app/invite/<token>` — single-use,
expiring, and it grants *nothing* on its own. Following it identifies which
invitation is being answered; **accepting it still requires signing in.**

That distinction is what reconciles this with §2.1, where unauthenticated
per-person bearer URLs were rejected for sharing plans. A plan-sharing link
would hand over content to whoever holds it. An invite link hands over the
right to *answer an invitation already addressed to an email address*, and a
forwarded one gets the recipient a sign-in prompt they cannot satisfy.

**The invited address is the one that binds.** Acceptance requires the
signed-in User to hold a verified identity for the address the invite was sent
to. Someone invited at `ola@example.com` who signs in with a Google account at
another address is told exactly that, and given both remedies: sign in with the
invited address, or ask the owner to re-invite the one they actually use. The
alternative — binding to whoever opens the link — turns a forwarded email into
account access.

**A first-run invitee is the one exception to "no sign-in in onboarding".**
§3.1 keeps sign-in out of onboarding because a first-run user has no plan worth
protecting. An invitee is the opposite case: they arrived *because* somebody
wants them in an account, so the invitation is the context that makes signing
in make sense. Following an invite link on a fresh install goes **sign-in
first**, then a shortened onboarding, then straight into the organisation's
plans. It must not dump them at a generic first-run screen with the invitation
forgotten.

**On mobile it behaves like an install link.** Universal-link handling per
[ADR-0015](../adrs/0015-shareable-install-links.md): opens the app when
installed, the web page otherwise, and the web page can complete the whole
flow. Accepting on the web and opening the app later just works, because the
membership is server-side.

**States the landing page has to render**, none of which are the happy path:
already accepted; withdrawn by the owner; expired; the organisation was
deleted; and signed in as the wrong person. Each says what happened and what to
do, rather than a generic failure.

## 7. Two role vocabularies, kept apart by the model rather than by the UI

This is the highest-risk part of the design, and the fix is structural.

The app already has `StaffRole` — `{director, instructor, actor, other}`,
Norwegian *øvelsesleder / veileder / markør / annet* — which does two jobs
([DESIGN-011](./011-person-with-role-and-roster-model.md),
[ADR-0057](../adrs/0057-role-gated-editing.md)): it is a person's role on the
roster, and it is *this device's* role, gating which edit affordances appear.

`MemberRole` answers a different question entirely: **what is your standing in
the account.** Who administers it, who is in it, who was let in to look.

**It says nothing about what you do on an exercise, and that is a property of
the model, not a rule about screens.** No `MemberRole` value implies, permits,
constrains or derives a `StaffRole`, in either direction. A `guest` may be the
*øvelsesleder* running the drill. An `owner` may be `other` on the roster and
have no edit rights at all. Both are ordinary, not edge cases.

An earlier draft of this section stated that as a UI-presentation rule — keep
them on separate screens, use different words. That was too weak. A
presentation rule survives exactly as long as everyone remembers it, and the
first person to add a "role" dropdown that offers both sets breaks it silently.
Scoping `MemberRole` to the account side makes the separation something the
model enforces, and the UI rules below are then consequences rather than
discipline:

1. **Different surfaces.** `StaffRole` lives on the roster and in the drawer's
   role switcher. `MemberRole` lives only on the account page.
2. **Different words in `nb`.** *Rolle* is spent on `StaffRole`. The members
   list uses *Tilgang*, and the picker is titled *"Tilgang i organisasjonen"*.
3. **No mapping function exists.** Not `owner`→`director`, not the reverse, not
   a default, not a suggestion at invite time.
4. One explanatory line on the account page: *"Access applies to the
   organisation's plans. Your role during an exercise is set in the menu."*
   (`nb`: *"Tilgang gjelder planer i organisasjonen. Rollen din under en øvelse
   settes i menyen."*)

There is a third axis already in the codebase —
[ADR-0063](../adrs/0063-per-field-brief-visibility.md)'s per-field brief
visibility, which decides which *fields* a given audience sees within a plan a
device already has. Three axes is the real number, and the account page should
not pretend otherwise.

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

**Sequencing note.** Roster sync is not in the account release; it ships
separately against ADR-0072's entry criteria. Until then this section describes plans only, and the roster
sentence is absent rather than aspirational. The heading exists from the first
account release so there is one obvious place for it to grow.

### 8.1 Members see the roster. Guests do not.

ADR-0072 ties roster visibility to **being in the account**, and §6.1's
`{owner, member, guest}` is what makes that a usable line rather than an open
question:

* **`owner` and `member` see the roster.** They are the group running the
  exercise. The duty list is what they are collaborating on.
* **`guest` does not.** A guest was admitted to read the plan, not to join the
  group. Someone else's colleagues' phone numbers are not part of "have a look
  at our plan".

This is not a fourth axis. It is the same membership axis with the outsider tier
named honestly, which is most of why `viewer` became `guest` — under the old
vocabulary, "does a viewer see the roster?" had no principled answer, because
`viewer` described a capability and the question is about belonging.

Since every role publishes (§6.1), **this is the only thing `guest` withholds**,
which makes the tier easy to explain and easy to choose correctly: the question
at invite time is not "how much should this person be allowed to do" but "should
this person have our people's phone numbers".

The `AccessPolicy.shared` case follows from the same rule and needs no separate
one: a member of the *grantee* account is not in the *owning* account, so they
get the plan and not the roster (ADR-0072 §4).

Withholding stays a **read-time projection**, never a write-time strip. Changing
someone from `member` to `guest`, or removing them, must not touch the stored
plan. Their next request simply returns less.

## 9. States that are easy to forget

* **Offline.** Every account screen is read-only offline, showing cached values
  with one banner. Sign-in itself is unavailable and says so plainly.
* **Token expiry mid-session.** Refresh is silent. A refresh that fails returns
  the user to signed-out state *without* losing anything local, and the drawer
  explains rather than just reverting.
* **Slow invite.** The invite row appears immediately in `Invited` state; the
  send is optimistic and shows failure on the row.
* **Plans published before signing in.** They remain `anon`-owned and are not
  claimed. Library shows the fork affordance rather than
  implying they became yours. The account page does not list them.
* **Deleting the account.** Removes `User`, `Identity` rows, memberships and
  account-scoped data. Published catalog plans are **not** deleted, because
  other people have installed them; the confirm says so.

## 10. Mockups

Generated by [`tools/generate_design_mockups.py`](../../tools/generate_design_mockups.py) — edit the generator, not the HTML. Copy is `en` (`AGENTS.md` rule 12).

| File | Shows |
|---|---|
| [`mockups/auth-signin.html`](./mockups/auth-signin.html) | Provider choice, magic-link waiting screen with code fallback, linked-provider notice |
| [`mockups/auth-recovery.html`](./mockups/auth-recovery.html) | The four §4 situations, and the single-owner advisory |
| [`mockups/account-personal.html`](./mockups/account-personal.html) | Drawer signed-in state, personal account page, upgrade-to-organisation sheet |
| [`mockups/account-organisation.html`](./mockups/account-organisation.html) | Members list with pending invite, role picker, remove confirm, invite form |
| [`mockups/account-wide.html`](./mockups/account-wide.html) | Wide-screen and web master/detail layout for Settings → Account |
| [`mockups/account-sections.html`](./mockups/account-sections.html) | §5.9 — the sectioned account form seen by an owner and by a member who is not one |
| [`mockups/account-personal-upgrade.html`](./mockups/account-personal-upgrade.html) | §5.9 with §5.3 — a personal account's Members section, and Invite as the upgrade |
| [`mockups/library-tabs.html`](./mockups/library-tabs.html) | The plan selector without an account (three tabs, as today) and with one (four tabs, `Account` added, `Online` → `Public`) |
| [`mockups/publish-dialog.html`](./mockups/publish-dialog.html) | Publish dialog signed out (not a gate), on a personal account, and republishing from an organisation |
| [`mockups/invite-accept.html`](./mockups/invite-accept.html) | The invitation email, the landing page for someone with no account, and the wrong-address case |
| [`mockups/cli-auth.html`](./mockups/cli-auth.html) | `ringdrill auth login`: terminal output, the browser consent screen with the code echoed back, and the signed-in result |

## 11. Open questions

1. **Does an `owner` need to be distinguishable from an *admin*?** §6.1 leaves
   one tier where a bigger organisation would have two — someone who manages
   people but cannot delete the account or transfer ownership. No model change
   needed to add it later; the question is only whether anyone wants it.
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
