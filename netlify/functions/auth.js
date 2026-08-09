import { corsPreflight, withCors } from "./lib/shared.js";
import { authenticate, AUDIENCE, ISSUER, signJwt, resolveMode, AUTH_MODES } from "./lib/auth/index.js";
import {
    ACCESS_TTL_S, createSession, endSessionOwnedBy, redeemChallenge, rotateSession, sessionsOf, startChallenge,
} from "./lib/auth/session.js";
import { defaultStores, getUser, membershipsOf, normalizeEmail, resolveIdentity, sweepExpired } from "./lib/identity.js";
import { offerableProviders, providerConfig } from "./lib/auth/providers.js";
import {
    exchangeCode, putHandoff, redeemAuthorization, redeemHandoff, startAuthorization,
} from "./lib/auth/oauth.js";
import { createMailer, sendTemplate } from "./lib/mail/index.js";
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
    return { id: user.id, displayName: user.displayName, email: user.primaryEmail };
}

export function createHandler({
    env = process.env,
    now = Date.now,
    stores = defaultStores,
    challengeStore = () => getStore(CHALLENGES_NS, strong),
    sessionStore = () => getStore("sessions", strong),
    mailer = null,
} = {}) {
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

        const send = mailer ?? createMailer({ env });
        const url = `${env.PUBLIC_APP_ORIGIN || "https://ringdrill.app"}/auth/callback?c=${encodeURIComponent(challengeId)}&k=${encodeURIComponent(code)}`;
        const sent = await sendTemplate(send, {
            to: email, template: "signIn", locale,
            params: { code, url, minutes: Math.round(expiresInMs / 60000) },
            idempotencyKey: challengeId,
        });

        // Under AUTH_MODE=mock the whole mail channel is short-circuited
        // (ADR-0073), so the code comes back in the body and the flow runs end
        // to end with no provider. Never in live: the response would be the
        // credential.
        const mocked = resolveMode(env) === AUTH_MODES.MOCK;
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
            devices: await sessionsOf(sessionStore(), user.id),
        });
    }

    async function issueTokens(user, extra = {}) {
        const minted = await mintAccessToken({ user, env, now, stores });
        if (!minted.ok) return json({ error: minted.reason }, 500);
        const session = await createSession(sessionStore(), {
            userId: user.id, deviceLabel: extra.deviceLabel, now,
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

export default createHandler();
