import { appOrigin, corsPreflight, withCors } from "./lib/shared.js";
import { authenticate, AUDIENCE, ISSUER, logAuthMode, signJwt, resolveMode, AUTH_MODES } from "./lib/auth/index.js";
import {
    ACCESS_TTL_S, createSession, endSessionOwnedBy, redeemChallenge, rotateSession, sessionsOf, startChallenge,
} from "./lib/auth/session.js";
import {
    defaultStores, getUser, membershipsOf, normalizeEmail, NS, resolveIdentity, sweepExpired,
    updateUserNames,
} from "./lib/identity.js";
import { offerableProviders, providerConfig } from "./lib/auth/providers.js";
import {
    exchangeCode, putHandoff, redeemAuthorization, redeemHandoff, startAuthorization,
} from "./lib/auth/oauth.js";
import { createMailer, sendTemplate } from "./lib/mail/index.js";
import { createStartEmailLimiter } from "./lib/auth/start-email-limit.js";
import { getStore } from "@netlify/blobs";

/**
 * The auth surface: start-email, callback, refresh, logout, me (ADR-0024).
 *
 * One function rather than five, because they share the token minting and the
 * membership lookup, and splitting them would mean five copies of the claim
 * assembly — the one part where a mistake is a security bug rather than a 500.
 */

const CHALLENGES_NS = "auth-challenges";
const strong = { consistency: "strong" };

const json = (body, status = 200, headers = {}) =>
    new Response(JSON.stringify(body), {
        status,
        headers: { "content-type": "application/json", ...headers },
    });

/**
 * Assemble the access-token claims (ADR-0025's shape).
 *
 * `acts` and `roles` come from stored memberships every time a token is minted,
 * so a role change takes effect on the next refresh rather than needing a
 * sign-out. That is the whole reason the token carries the map instead of the
 * server looking it up per request.
 */
async function mintAccessToken({ user, env, now, stores }) {
    const { accounts, roles } = await membershipsOf(user.id, stores);
    const issuedAt = Math.floor(now() / 1000);
    const claims = {
        iss: ISSUER,
        aud: AUDIENCE,
        sub: user.id,
        // The first account is the default active one. A client that wants
        // another sends X-Active-Account, which is validated against `acts`.
        act: accounts[0] ?? null,
        acts: accounts,
        roles,
        iat: issuedAt,
        exp: issuedAt + ACCESS_TTL_S,
        jti: `${issuedAt}-${Math.random().toString(36).slice(2, 10)}`,
    };
    // **Mint what this mode can verify.** Under AUTH_MODE=mock the adapter
    // accepts only `test.` tokens, so signing here would have the server issue
    // credentials it then rejects — and would need the signing key that
    // ADR-0073 promises mock does without. Minting the mock format keeps the
    // loop closed and keeps dev free of key material entirely.
    if (resolveMode(env) === AUTH_MODES.MOCK) {
        const { mintTestToken } = await import("./lib/auth/mock.js");
        return { ok: true, accessToken: mintTestToken(claims), accounts, roles, expiresIn: ACCESS_TTL_S };
    }
    const key = env.AUTH_SIGNING_KEY_PRIVATE;
    if (!key) return { ok: false, reason: "no_signing_key" };
    return { ok: true, accessToken: signJwt(claims, key), accounts, roles, expiresIn: ACCESS_TTL_S };
}

function publicUser(user) {
    return {
        id: user.id,
        displayName: user.displayName,
        // Empty until the person fills it in. Sent as "" rather than omitted so
        // a client can tell "not set yet" from "this build does not know about
        // it" — the first is a prompt to show, the second is not.
        nickname: user.nickname ?? "",
        email: user.primaryEmail,
    };
}

export function createHandler({
    env = process.env,
    now = Date.now,
    stores = defaultStores,
    challengeStore = () => getStore(CHALLENGES_NS, strong),
    sessionStore = () => getStore(NS.SESSIONS, strong),
    // The `<userId>/<sessionId>` reverse index. Every session call site passes
    // it; without one they silently fall back to walking every session in the
    // store, which is the O(all users) read this store layout exists to remove.
    sessionIndexStore = () => getStore(NS.SESSION_INDEX, strong),
    mailer = null,
    // The abuse bound on start-email (ADR-0079). Built lazily so constructing a
    // handler never touches Blobs.
    startEmailLimiter = null,
} = {}) {
    let limiter = startEmailLimiter;
    const limitSend = () => (limiter ??= createStartEmailLimiter());
    return async function (request) {
        const preflight = corsPreflight(request);
        if (preflight) return preflight;

        const { pathname } = new URL(request.url);
        const route = pathname.replace(/^.*\/(?:\.netlify\/functions\/auth|api\/auth)\/?/, "");

        // `callback/<provider>` is where a provider redirects the *browser*.
        // Matched before the switch because the provider id is part of the path.
        const providerRedirect = route.match(/^callback\/([a-z]+)$/);
        if (providerRedirect && (request.method === "GET" || request.method === "POST")) {
            try {
                return withCors(request, await providerCallback(request, providerRedirect[1]));
            } catch (err) {
                console.error("[auth] provider callback", err);
                return withCors(request, bounceToApp(null, { error: "internal" }));
            }
        }

        try {
            switch (`${request.method} ${route}`) {
                case "POST start-email": return withCors(request, await startEmail(request));
                case "POST callback": return withCors(request, await callback(request));
                case "POST refresh": return withCors(request, await refresh(request));
                case "POST logout": return withCors(request, await logout(request));
                case "POST sessions/revoke": return withCors(request, await revokeSession(request));
                case "GET me": return withCors(request, await me(request));
                case "PATCH me": return withCors(request, await updateMe(request));
                case "GET providers": return withCors(request, await listProviders(request));
                default: return withCors(request, json({ error: "not_found" }, 404));
            }
        } catch (err) {
            console.error("[auth]", err);
            return withCors(request, json({ error: "internal" }, 500));
        }
    };

    async function startEmail(request) {
        const body = await request.json().catch(() => ({}));
        const email = normalizeEmail(body.email);
        // Deliberately permissive: the address is proved by the round-trip, so
        // validating shape here only rejects unusual-but-valid addresses.
        if (!email || !email.includes("@")) return json({ error: "invalid_email" }, 400);
        const locale = body.locale === "nb" ? "nb" : "en";

        // An abandoned challenge holds the address of somebody who may never
        // have had an account at all, and was only ever removed if a later
        // caller happened to try it. Swept on every start.
        await sweepExpired(challengeStore(), { now });

        const { challengeId, code, expiresInMs } = await startChallenge(challengeStore(), { email, locale, now });

        // Under AUTH_MODE=mock the code comes back in the body, so the flow
        // can be completed without reading the mail at all (ADR-0073). Never in
        // live: the response would be the credential.
        const mocked = resolveMode(env) === AUTH_MODES.MOCK;

        // **The limit suppresses the send, never the response** (ADR-0079).
        // This endpoint answers identically for an address that has an account
        // and one that does not, and a visible 429 would undo that: it would
        // tell a caller which addresses are being mailed. So a refusal costs
        // exactly one thing, the mail, and is logged rather than returned.
        //
        // Not applied under mock, which is a developer's own machine and cannot
        // load in production (ADR-0073's CONTEXT guard). Three sign-ins an hour
        // is the right bound for a stranger and the wrong one for someone
        // testing the flow.
        const gate = mocked ? { allowed: true } : await limitSend().allowSend({ email, headers: request.headers });
        if (!gate.allowed) {
            // Visible to us even though it is invisible to the caller — this is
            // the only signal that somebody is working through addresses.
            console.warn(`[auth] start-email suppressed by ${gate.reason} limit`);
        }

        // The mail goes through whatever MAIL_PROVIDER selects — the two are
        // separate seams, and mock does not imply a mail adapter. Locally that
        // is MAIL_PROVIDER=console (see `make netlify-dev`), which prints the
        // message instead of delivering it. Leaving it at the default answers
        // 500 here, because Resend refuses to boot with no key.
        let sent = null;
        if (gate.allowed) {
            const send = mailer ?? createMailer({ env });
            const url = `${appOrigin(env)}/s/${encodeURIComponent(challengeId)}/${encodeURIComponent(code)}`;
            sent = await sendTemplate(send, {
                to: email, template: "signIn", locale,
                params: { code, url, minutes: Math.round(expiresInMs / 60000) },
                idempotencyKey: challengeId,
            });
        }

        return json({
            challengeId,
            expiresInMs,
            // Same shape either way, so a client needs no branch for the mode.
            ...(mocked ? { code, mailPreview: sent?.message ?? null } : {}),
        });
    }

    /**
     * Which providers are usable, and the URL to open for each.
     *
     * The whole reason this endpoint exists: a client id belongs to a
     * deployment, not to a build. Asking at runtime means adding, removing or
     * rotating a provider is a config change, and no app ships believing in a
     * provider nobody configured.
     *
     * Nothing secret is in the response. The authorize URL carries the client
     * id — which is public by construction, it travels in the redirect the
     * browser makes anyway — and never the secret.
     */
    async function listProviders(request) {
        const origin = env.PUBLIC_API_ORIGIN || new URL(request.url).origin;
        const providers = [];
        // Not `configuredProviders` — see `offerableProviders` for why a
        // deployment missing Apple offers nothing rather than offering the
        // rest.
        const offerable = offerableProviders(env, {
            live: resolveMode(env) === AUTH_MODES.LIVE,
        });
        for (const provider of offerable) {
            const started = await startAuthorization(challengeStore(), provider, {
                redirectUri: `${origin}/api/auth/callback/${provider.id}`,
                now,
            });
            providers.push({
                id: provider.id,
                label: provider.label,
                authorizeUrl: started.authorizeUrl,
            });
        }
        return json({ providers }, 200, { "cache-control": "no-store" });
    }

    /**
     * Where the provider sends the browser back.
     *
     * Answers a **redirect**, never JSON: a human is looking at this, in a
     * browser, and the only useful thing to do is put them back in the app.
     * Failures bounce too, with a reason — leaving somebody on a blank error
     * page inside a sign-in sheet gives them nothing to do.
     */
    async function providerCallback(request, providerId) {
        // Apple form-posts its response; everyone else uses query parameters.
        const url = new URL(request.url);
        let params = url.searchParams;
        if (request.method === "POST") {
            params = new URLSearchParams(await request.text());
        }

        if (params.get("error")) {
            // The person pressed cancel, most often. Not an error worth a log.
            return bounceToApp(null, { error: params.get("error") });
        }

        const redeemed = await redeemAuthorization(challengeStore(), params.get("state"), { now });
        if (!redeemed.ok) return bounceToApp(null, { error: redeemed.reason });

        const provider = providerConfig(redeemed.pending.provider, env);
        // The path segment is not trusted to name the provider — the parked
        // authorization does. Otherwise a valid `state` could be redeemed
        // against a different provider's configuration.
        if (!provider || provider.id !== providerId) {
            return bounceToApp(null, { error: "unknown_provider" });
        }

        const exchanged = await exchangeCode(provider, {
            code: params.get("code"),
            redirectUri: redeemed.pending.redirectUri,
            verifier: redeemed.pending.verifier,
            nonce: redeemed.pending.nonce,
            now,
        });
        if (!exchanged.ok) return bounceToApp(null, { error: exchanged.reason });

        const resolved = await resolveIdentity({
            provider: exchanged.identity.provider,
            subject: exchanged.identity.subject,
            email: exchanged.identity.email,
            emailVerified: exchanged.identity.emailVerified,
            displayName: exchanged.identity.displayName,
        }, stores);
        if (!resolved.ok) return bounceToApp(null, { error: resolved.reason });

        const issued = await issueTokens(resolved.user, {
            deviceLabel: params.get("device_label"),
            linked: resolved.linked,
            created: resolved.created,
        });
        if (issued.status !== 200) return bounceToApp(null, { error: "issue_failed" });

        // The session is parked and collected over TLS rather than travelling
        // in the redirect URL, which would put it in browser history and in
        // whatever the OS logs for a custom-scheme launch.
        const handoff = await putHandoff(challengeStore(), await issued.json(), { now });
        return bounceToApp(handoff);
    }

    /** Send the browser back into the app. */
    function bounceToApp(handoff, { error = null } = {}) {
        const scheme = env.APP_CALLBACK_URL || "ringdrill://auth/callback";
        const target = new URL(scheme);
        if (handoff) target.searchParams.set("handoff", handoff);
        if (error) target.searchParams.set("error", error);
        return new Response(null, {
            status: 302,
            headers: { location: target.toString(), "cache-control": "no-store" },
        });
    }

    async function callback(request) {
        const body = await request.json().catch(() => ({}));

        // A provider sign-in that finished in the browser: the app presents
        // the handoff code and collects the session it already earned.
        if (body.handoff) {
            const redeemed = await redeemHandoff(challengeStore(), body.handoff, { now });
            if (!redeemed.ok) return json({ error: redeemed.reason }, 401);
            return json(redeemed.payload);
        }

        const redeemed = await redeemChallenge(challengeStore(), {
            challengeId: body.challengeId, code: body.code, now,
        });
        if (!redeemed.ok) {
            const status = redeemed.reason === "bad_code" ? 401 : 400;
            return json({ error: redeemed.reason, attemptsLeft: redeemed.attemptsLeft }, status);
        }

        // A redeemed email challenge *is* proof of control of the address, so
        // this identity is verified — which is what lets it link to an existing
        // User rather than minting a duplicate (ADR-0024 step 2).
        const resolved = await resolveIdentity({
            provider: "email", subject: redeemed.email, email: redeemed.email,
            emailVerified: true, displayName: body.displayName,
        }, stores);
        if (!resolved.ok) return json({ error: resolved.reason }, 500);

        return issueTokens(resolved.user, {
            deviceLabel: body.deviceLabel ?? null,
            linked: resolved.linked,
            created: resolved.created,
        });
    }

    async function refresh(request) {
        const body = await request.json().catch(() => ({}));
        const rotated = await rotateSession(sessionStore(), {
            sessionId: body.sessionId, refreshToken: body.refreshToken, now,
            index: sessionIndexStore(),
        });
        if (!rotated.ok) {
            // A replay is a security signal, not a UX one (rollout plan's
            // telemetry list). Logged loudly; the client just sees 401.
            if (rotated.reason === "replayed") {
                console.error("[auth] refresh token replay — session ended", { userId: rotated.userId });
            }
            return json({ error: rotated.reason }, 401);
        }

        const user = await getUser(rotated.userId, stores);
        if (!user) return json({ error: "unknown_user" }, 401);

        const minted = await mintAccessToken({ user, env, now, stores });
        if (!minted.ok) return json({ error: minted.reason }, 500);

        return json({
            accessToken: minted.accessToken,
            expiresIn: minted.expiresIn,
            refreshToken: rotated.refreshToken,
            sessionId: rotated.sessionId,
            user: publicUser(user),
            accounts: minted.accounts,
            roles: minted.roles,
        });
    }

    /**
     * Sign out — end the caller's own session.
     *
     * **Ownership is proved, not assumed.** This used to end whatever
     * `sessionId` arrived in the body, unauthenticated: a 144-bit id is not
     * guessable, but an endpoint that destroys server state on an
     * attacker-supplied identifier should not be relying on that alone. An id
     * that leaked through a screenshot, a log line or a support ticket was a
     * forced-logout capability for anyone who saw it.
     *
     * The refresh token counts as proof alongside the access token, because by
     * the time somebody signs out their access token may well have expired —
     * and a stale client that could not revoke its own session would leave it
     * alive for the full 60-day refresh window.
     */
    async function logout(request) {
        const body = await request.json().catch(() => ({}));
        const principal = await authenticate(request, { env, now });
        await endSessionOwnedBy(sessionStore(), {
            sessionId: body.sessionId,
            userId: principal.ok && !principal.anonymous ? principal.userId : null,
            refreshToken: body.refreshToken ?? null,
            index: sessionIndexStore(),
        });
        // 204 whether or not anything was ended, and deliberately not a
        // boolean: telling a caller which session ids are real is free
        // reconnaissance, and the legitimate caller already knows.
        return new Response(null, { status: 204 });
    }

    /**
     * End *another* of the caller's sessions — the sessions list's
     * "log out this device" (DESIGN-015 §4.3).
     *
     * Separate from `logout` because the intent differs: this one always
     * requires a live authenticated principal, since revoking a device you are
     * not holding is an administrative act rather than a sign-out. A refresh
     * token is not accepted here — presenting one would mean holding the very
     * device you claim to be revoking.
     */
    async function revokeSession(request) {
        const principal = await authenticate(request, { env, now });
        if (!principal.ok) return json({ error: principal.reason }, principal.status);
        if (principal.anonymous) return json({ error: "authentication_required" }, 401);

        const body = await request.json().catch(() => ({}));
        await endSessionOwnedBy(sessionStore(), {
            sessionId: body.sessionId,
            userId: principal.userId,
            index: sessionIndexStore(),
        });
        return new Response(null, { status: 204 });
    }

    async function me(request) {
        const principal = await authenticate(request, { env, now });
        if (!principal.ok) return json({ error: principal.reason }, principal.status);
        if (principal.anonymous) return json({ error: "authentication_required" }, 401);

        const user = await getUser(principal.userId, stores);
        if (!user) return json({ error: "unknown_user" }, 401);

        const { accounts, roles } = await membershipsOf(user.id, stores);
        const detail = [];
        for (const id of accounts) {
            const account = await stores.accounts().get(id, { type: "json" });
            if (account) detail.push({ id, displayName: account.displayName, type: account.type, handle: account.handle ?? null, role: roles[id] });
        }

        return json({
            user: publicUser(user),
            accounts: detail,
            activeAccount: principal.accountId,
            devices: await sessionsOf(sessionStore(), user.id, { now, index: sessionIndexStore() }),
        });
    }

    /**
     * Set the signed-in user's own names (DESIGN-015 §3.7).
     *
     * Only ever the caller's own: the id comes from the verified token and is
     * never taken from the body, so there is no shape of this request that
     * renames somebody else.
     *
     * A personal account follows the display name — see `updateUserNames` for
     * why an organisation does not.
     */
    async function updateMe(request) {
        const principal = await authenticate(request, { env, now });
        if (!principal.ok) return json({ error: principal.reason }, principal.status);
        if (principal.anonymous) return json({ error: "authentication_required" }, 401);

        const body = await request.json().catch(() => ({}));
        const displayName = typeof body.displayName === "string" ? body.displayName.trim() : null;
        const nickname = typeof body.nickname === "string" ? body.nickname.trim() : null;

        // A display name is what every other screen shows this person as, so
        // clearing it would leave them nameless everywhere. Refused rather than
        // silently ignored, so a client that meant to set one is told.
        if (displayName !== null && displayName.length === 0) {
            return json({ error: "display_name_required" }, 400);
        }
        if (displayName === null && nickname === null) {
            return json({ error: "nothing_to_update" }, 400);
        }
        if ((displayName?.length ?? 0) > 80 || (nickname?.length ?? 0) > 40) {
            return json({ error: "name_too_long" }, 400);
        }

        const updated = await updateUserNames(principal.userId, { displayName, nickname }, stores);
        if (!updated.ok) return json({ error: updated.reason }, 404);
        return json({ user: publicUser(updated.user) });
    }

    async function issueTokens(user, extra = {}) {
        const minted = await mintAccessToken({ user, env, now, stores });
        if (!minted.ok) return json({ error: minted.reason }, 500);
        const session = await createSession(sessionStore(), {
            userId: user.id, deviceLabel: extra.deviceLabel, now,
            index: sessionIndexStore(),
        });
        return json({
            accessToken: minted.accessToken,
            expiresIn: minted.expiresIn,
            refreshToken: session.refreshToken,
            sessionId: session.sessionId,
            user: publicUser(user),
            accounts: minted.accounts,
            roles: minted.roles,
            // DESIGN-015 §3.4: a person who signs in with a different button
            // and lands in the same account must be told why. Silence here is
            // worse than the notice.
            providerLinked: !!extra.linked,
            accountCreated: !!extra.created,
        });
    }
}

// Module scope, so it runs once per cold start rather than per request — and
// only for the deployed handler, not for the ones tests construct with an
// explicit env.
logAuthMode();

export default createHandler();
