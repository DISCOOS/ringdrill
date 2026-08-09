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

### The native iOS sheet — not yet, and the order matters

**Apple works today through the same browser flow as Google and Microsoft.**
Nothing below is required for it to function; this section is about replacing
that browser sheet with the native Face ID one on iOS.

> **Do not add the entitlement before step 1 of the portal section above.**
> An entitlement has to be present in the *provisioning profile*, and the
> profile can only carry `com.apple.developer.applesignin` once the App ID has
> the capability. Add the key first and **every iOS build fails** to code-sign,
> with `Provisioning profile ... doesn't include the
> com.apple.developer.applesignin entitlement`. The entitlement is also inert
> until the app makes a native Apple call, so on its own it is a build break in
> exchange for nothing.

Correct order:

1. Enable **Sign in with Apple** on the App ID `app.ringdrill` (portal step 1).
2. Let Xcode regenerate the provisioning profile — open the project once, or
   `flutter build ios` with automatic signing.
3. *Then* add the entitlement and the native code path, together. The
   entitlement is two lines in the existing `ios/Runner/Runner.entitlements`:

```xml
<key>com.apple.developer.applesignin</key>
<array><string>Default</string></array>
```

4. Add the `sign_in_with_apple` package and branch on iOS, handing the
   resulting `identityToken` to `POST /api/auth/callback`. **The server is
   already ready for this** — `OAUTH_APPLE_AUDIENCES` exists so the bundle id
   is accepted alongside the Services ID, and the verifier already handles
   Apple sending `email_verified` as the string `"true"` rather than a boolean.

**Why bother at all**, given the browser flow works: App Store guideline 4.8
scrutiny is lowest when the native sheet is used, and an iPhone user offered a
browser where every other app shows Face ID notices. It is polish, not a
blocker — the web flow is a supported, documented Apple flow, which is what
Services IDs exist for.

On web and Android, Apple goes through the server-side flow regardless.

---

## Apple is not optional once you offer the others

App Store guideline 4.8: an app offering third-party login must also offer a
privacy-preserving alternative. Since the 2022 revision the guideline does not
name Sign in with Apple specifically — it asks for an option that limits
collection to name and email, **lets the user keep their email address
private**, and does not track for advertising. RingDrill's email magic link
fails the middle clause, because it goes to the person's real address. Apple's
private relay is what satisfies it.

Runtime configuration turns that into a *deployment* mistake rather than a code
one: set Google and Microsoft, forget Apple, and the app ships third-party login
without the required alternative. Two buttons render, everything looks correct,
and review rejects it weeks later.

**So the server refuses to advertise the others when Apple is missing.**
`GET /api/auth/providers` returns an empty list and logs the reason. The
failure mode is deliberately the safe one — no provider buttons, email still
works, and no combination that fails review can reach a user. Only enforced
when `AUTH_MODE=live`; a developer configuring Google alone to exercise the
flow is not shipping anything.

If the sign-in screen shows no buttons after you configured Google, this is
why. Check the function log.

Guidelines change — verify against the current text when you submit.

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

## Why `flutter_web_auth_2` and not the alternatives

The app needs exactly one capability: open a URL in a system browser and get
the callback back. The code exchange is ours, so anything bigger is a library
fighting the architecture.

| | Why not |
|---|---|
| **`flutter_appauth`** | The AppAuth SDK — excellent, and by the author of `flutter_local_notifications` which we already use. But it is built to *own* the flow: issuer and client id in the app, PKCE and the token exchange on-device. That is what the server exists to avoid. It also has no web support (`android, ios, macos`), and RingDrill ships web from the same codebase |
| **`oauth2_client`** | Same category — a client-side OAuth library for a problem we moved server-side |
| **`app_links` + `url_launcher`** | The real alternative, and worse in a specific way. `ASWebAuthenticationSession` is the only iOS API that both returns the callback URL *and* dismisses itself. `url_launcher`'s `externalApplication` leaves the app for Safari; its `inAppBrowserView` (SFSafariViewController) cannot return a custom-scheme callback or self-close. Either way you add `app_links`, hand-roll cancellation, and still have no answer for web |
| **`webview_flutter`** | Disqualified outright: Google blocks OAuth in embedded webviews, precisely so an app cannot present a fake login form |

`flutter_web_auth_2` covers `android, ios, linux, macos, web, windows`, and its
whole API is `authenticate(url:, callbackUrlScheme:)`. It also exposes
`preferEphemeral` — whether the session shares Safari cookies, which is the
difference between one-tap for an already-signed-in user and no cookie bleed
between accounts.

The costs, stated plainly: it is a community package rather than first-party,
and it is a native plugin across six platforms. Android needs the callback
activity in `AndroidManifest.xml` — build-time, but not secret, and it names
only our own `ringdrill://` scheme.

## A deliberate omission

**Android's native Google account picker** — the Play Services bottom sheet
listing accounts already on the device — is not used. It would need the
`google_sign_in` plugin and an Android client id in the build, which is what
this setup exists to avoid. The browser flow is one extra tap and completely
ordinary; revisit only if it proves to be a real friction point, and note that
it would be additive rather than a rewrite.
