# Setting up identity providers

Step-by-step for registering Apple, Google and Microsoft, and the exact
environment variables to set afterwards. Follow it top to bottom; each provider
is independent, and one that is not configured is simply absent from the
sign-in screen.

Companion to [ADR-0024](./adrs/0024-account-and-identity-model.md) (which
providers, and why not BankID) and
[DESIGN-015 §3.2](./design/015-accounts-and-iam.md) (the sign-in screen).

## The rule this setup exists to keep

**Nothing security-relevant goes into a native or web build.** Client ids,
client secrets and redirect URIs live in Netlify environment variables and are
read at runtime. The app asks `GET /api/auth/providers` for what exists and for
the URL to open.

That is not merely tidier. Because the authorization code is exchanged on our
server, these are **confidential clients** — registrations that hold a secret.
An app using a provider's native SDK can only ever be a *public* client, which
is a weaker registration type. Doing it this way buys a stronger one.

So when a provider console asks what kind of application this is, the answer is
almost always **web application**, even though the sign-in happens on a phone.

## What the user sees

Worth knowing before you test it, so nothing looks wrong:

1. They tap *Continue with Google*.
2. A **system browser sheet** opens on **accounts.google.com** — the real
   domain, the real page. On iOS, iOS first asks *"RingDrill wants to use
   google.com to sign in"*; that prompt is from the OS, not from us.
3. They sign in there and consent.
4. The sheet closes and they are back in RingDrill, signed in.

Between 3 and 4 the browser passes through `api.ringdrill.app` for a moment.
That is our callback doing the code exchange, and it is invisible unless the
network is slow.

## Common values

You will be asked for these repeatedly:

| | Value |
|---|---|
| Redirect URI | `https://api.ringdrill.app/api/auth/callback/<provider>` |
| iOS bundle id | `app.ringdrill` |
| Android package | `org.discoos.ringdrill` |
| Web origin | `https://ringdrill.app` |

**Note the bundle id and the Android package differ.** That is historical and
correct; using the wrong one is the most common setup mistake here.

---

## Google

1. **Google Cloud console** → *APIs & Services* → *Credentials*.
2. Configure the **OAuth consent screen** first if it has never been done:
   *External*, app name *RingDrill*, support email, and the
   `.../auth/userinfo.email` + `openid` scopes. Publish it, or only test users
   can sign in.
3. *Create credentials* → *OAuth client ID* → **Web application**.
   - Authorised redirect URI:
     `https://api.ringdrill.app/api/auth/callback/google`
   - No JavaScript origins are needed — the browser never posts to us directly.
4. Copy the **client ID** and **client secret**.

```
OAUTH_GOOGLE_CLIENT_ID=<the web client id>
OAUTH_GOOGLE_CLIENT_SECRET=<the web client secret>
```

You do **not** need separate iOS and Android client IDs. Those exist for the
native SDKs, which this design does not use. (If a native Android picker is
ever added — see the note at the end — that is when an Android client id, and
its release SHA-1 fingerprint, become necessary.)

---

## Microsoft

1. **Entra admin centre** → *App registrations* → *New registration*.
2. Name *RingDrill*. For *Supported account types* choose
   **Accounts in any organizational directory and personal Microsoft accounts**
   — that is the `common` authority, and it is what makes both a work login and
   an `@outlook.com` login work.
3. *Redirect URI* → platform **Web** →
   `https://api.ringdrill.app/api/auth/callback/microsoft`.
   Web, not "Mobile and desktop", because the code is exchanged by our server.
4. *Certificates & secrets* → *New client secret*. **Copy it immediately** —
   Entra shows it once. Note the expiry and set a reminder; a silently expired
   secret looks exactly like a broken sign-in.
5. *API permissions* → Microsoft Graph → delegated → `openid`, `email`,
   `profile`. Grant admin consent if your tenant requires it.

```
OAUTH_MICROSOFT_CLIENT_ID=<Application (client) ID>
OAUTH_MICROSOFT_CLIENT_SECRET=<the client secret value, not its id>
```

**Why no tenant id.** The registration is multi-tenant, so tokens arrive from
`https://login.microsoftonline.com/<tenant>/v2.0` — a different issuer per
customer. The server verifies the issuer against the token's own signed `tid`
claim rather than against a configured value, so there is nothing to set here.

---

## Apple

Apple is the fiddliest of the three, and the only one where the app also needs a
build-time change.

### Developer portal

1. **Certificates, Identifiers & Profiles** → *Identifiers* → your App ID
   `app.ringdrill` → enable the **Sign in with Apple** capability. Save.
2. *Identifiers* → **+** → **Services IDs**. This is the "client id" for the web
   flow — it is a separate thing from the App ID and cannot be the same string.
   - Description: *RingDrill Web*
   - Identifier: something like `app.ringdrill.web` — **write it down**, it is
     `OAUTH_APPLE_CLIENT_ID`.
3. Configure that Services ID → *Sign in with Apple*:
   - Primary App ID: `app.ringdrill`
   - Domains: `api.ringdrill.app`
   - Return URL: `https://api.ringdrill.app/api/auth/callback/apple`
4. *Keys* → **+** → enable **Sign in with Apple**, choose the primary App ID,
   and download the **`.p8`** file. It downloads **once**. Note the **Key ID**
   and your **Team ID**.

### Environment

Apple does not issue a static client secret. It expects a short-lived JWT signed
with the `.p8` key — the server generates it, which is why the key goes in the
environment rather than anywhere near a build.

```
OAUTH_APPLE_CLIENT_ID=app.ringdrill.web
OAUTH_APPLE_TEAM_ID=<Team ID>
OAUTH_APPLE_KEY_ID=<Key ID>
OAUTH_APPLE_PRIVATE_KEY=<contents of the .p8, newlines included>
# The native iOS sheet presents the bundle id as its audience, not the
# Services ID, so both are valid audiences.
OAUTH_APPLE_AUDIENCES=app.ringdrill
```

The server mints that assertion per exchange, signed ES256 with the key above,
five-minute lifetime. There is nothing further to configure — and note what the
design buys here: a key that must be *signed with* cannot be lifted out of a
build and replayed, because what it produces expires.

### The one build-time change

Sign in with Apple stays **native on iOS**: the Face ID sheet rather than a
browser. It needs the *Sign in with Apple* capability added in Xcode
(`ios/Runner`), which writes an entitlement. That entitlement and the bundle id
are the only provider-related things in any build — and neither is security
information.

The reason is App Store guideline 4.8 and plain user expectation: an iPhone user
offered a browser sheet where every other app shows the native one notices, and
review notices too. On web and Android, Apple goes through the same server-side
flow as everyone else.

---

## Turning it on

1. Set the variables in **Netlify** → *Site configuration* → *Environment
   variables*. Set them for **all deploy contexts** you want sign-in in.
2. Redeploy — Netlify reads environment variables at function start.
3. Check discovery:

```bash
curl -s https://api.ringdrill.app/api/auth/providers | jq '.providers[].id'
```

Anything you configured should be listed. A provider that is missing has no
client id set — that is the only reason it can be absent.

4. Sign in from the app, or open an `authorizeUrl` from that response in a
   browser and confirm it lands on the provider's page.

## When something is wrong

The callback always redirects back into the app with an `error` parameter
rather than leaving a blank page inside the sign-in sheet. The value tells you
where it stopped:

| `error` | Meaning |
|---|---|
| `unknown_state` | The authorization expired (10 min) or was already used |
| `unknown_provider` | The redirect URI names a provider that is not configured |
| `code_exchange_failed` | The provider rejected the exchange — usually a wrong secret or a redirect URI that does not match the registration **exactly** |
| `bad_audience` | The token was minted for a different client id |
| `bad_issuer` | Wrong provider, or a Microsoft token whose tenant does not match its issuer |
| `bad_nonce` | The token does not belong to the authorize request we started |
| `expired` | Clock skew beyond two minutes, or a very slow sign-in |

`code_exchange_failed` is the one you will actually hit, and it is nearly always
the redirect URI: providers compare it character for character, including the
trailing slash and `http` versus `https`.

## Rotating or removing a provider

Change the variable and redeploy. No app release, no App Store review. Removing
the client id removes the button.

A provider disappearing does not sign anybody out — sessions are ours, not the
provider's. It only stops new sign-ins through that button, and somebody whose
only identity was that provider will need another way in. Worth checking
`identities/` before removing one in anger.

## A deliberate omission

**Android's native Google account picker** — the Play Services bottom sheet
listing accounts already on the device — is not used. It would need the
`google_sign_in` plugin and an Android client id in the build, which is what
this setup exists to avoid. The browser flow is one extra tap and completely
ordinary; revisit only if it proves to be a real friction point, and note that
it would be additive rather than a rewrite.
