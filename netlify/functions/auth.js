import { corsPreflight, withCors } from "./lib/shared.js";
import { authenticate, AUDIENCE, ISSUER, signJwt, resolveMode, AUTH_MODES } from "./lib/auth/index.js";
import {
    ACCESS_TTL_S, createSession, endSession, redeemChallenge, rotateSession, sessionsOf, startChallenge,
} from "./lib/auth/session.js";
import { defaultStores, getUser, membershipsOf, normalizeEmail, resolveIdentity } from "./lib/identity.js";
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

const json = (body, status = 200) =>
    new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });

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

        try {
            switch (`${request.method} ${route}`) {
                case "POST start-email": return withCors(request, await startEmail(request));
                case "POST callback": return withCors(request, await callback(request));
                case "POST refresh": return withCors(request, await refresh(request));
                case "POST logout": return withCors(request, await logout(request));
                case "GET me": return withCors(request, await me(request));
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

    async function callback(request) {
        const body = await request.json().catch(() => ({}));
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

    async function logout(request) {
        const body = await request.json().catch(() => ({}));
        await endSession(sessionStore(), body.sessionId);
        // 204 whether or not the session existed: telling a caller which
        // session ids are real is free reconnaissance, and there is nothing
        // useful they could do with the distinction.
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
