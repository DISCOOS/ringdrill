import crypto from "node:crypto";

import { hash, newToken } from "./session.js";
import { verifyIdToken } from "./providers.js";

/**
 * The authorization-code flow, run entirely on the server.
 *
 * The app never holds a client id, a client secret, or a provider SDK. It asks
 * which providers exist, opens the authorize URL we built in a *system
 * browser*, and later collects a session. Everything in between — the code
 * exchange, the `id_token` verification — happens here.
 *
 * The user still sees the provider's own login page, on the provider's own
 * domain. "Server-side" describes where the code is exchanged, not where the
 * human authenticates: steps 3 and 4 below are invisible to them and happen
 * after they have already signed in.
 *
 * 1. `GET /api/auth/providers` — we mint `state`, `nonce` and a PKCE verifier,
 *    park them, and hand back an authorize URL.
 * 2. The browser goes to the provider. The person signs in there.
 * 3. The provider redirects to `GET /api/auth/callback/:provider` with a code.
 * 4. We exchange the code (confidential client — a native app could only ever
 *    be a public one) and verify the `id_token`.
 * 5. We park the session under a single-use handoff code and bounce the
 *    browser to `ringdrill://auth/callback?handoff=…`.
 * 6. The app posts that handoff code and gets its tokens.
 *
 * **Why step 5 and 6 rather than putting tokens in the redirect.** A URL ends
 * up in browser history, in `Referer` headers, and in any logging the OS does
 * for a custom-scheme launch. A single-use code that expires in a minute and
 * is exchanged over TLS does not.
 */

/** How long an authorization may sit half-finished. */
export const PENDING_TTL_MS = 10 * 60 * 1000;

/** How long the app has to collect its session after the browser bounces back. */
export const HANDOFF_TTL_MS = 60 * 1000;

const PENDING_PREFIX = "oauth:";
const HANDOFF_PREFIX = "handoff:";

function base64url(buf) {
    return Buffer.from(buf).toString("base64url");
}

/** RFC 7636 S256: the challenge is the hash, the verifier is the secret. */
function pkce() {
    const verifier = newToken(32);
    const challenge = base64url(crypto.createHash("sha256").update(verifier).digest());
    return { verifier, challenge };
}

/**
 * Begin an authorization and return the URL the browser should open.
 *
 * `state` is the anti-CSRF token *and* the lookup key for everything we need
 * at callback time. It is stored rather than signed so redeeming it can be
 * single-use — a signed state would be replayable until it expired.
 */
export async function startAuthorization(store, provider, {
    redirectUri,
    now = Date.now,
    makeToken = newToken,
}) {
    const state = makeToken(18);
    const nonce = makeToken(18);
    const { verifier, challenge } = pkce();

    await store.set(`${PENDING_PREFIX}${state}`, JSON.stringify({
        provider: provider.id,
        // **Not hashed**, unlike the credentials elsewhere in this codebase.
        // PKCE requires the verifier in plaintext at exchange time — the
        // *challenge* is the hash, and that is what went to the provider. It
        // is also useless on its own: without the matching authorization code,
        // which only arrives at our own redirect URI, it completes nothing.
        verifier,
        nonce,
        redirectUri,
        expiresAt: now() + PENDING_TTL_MS,
    }));

    const url = new URL(provider.authorizeUrl);
    url.searchParams.set("client_id", provider.clientId);
    url.searchParams.set("redirect_uri", redirectUri);
    url.searchParams.set("response_type", "code");
    url.searchParams.set("scope", provider.scope);
    url.searchParams.set("state", state);
    url.searchParams.set("nonce", nonce);
    url.searchParams.set("code_challenge", challenge);
    url.searchParams.set("code_challenge_method", "S256");
    // Apple will not return name/email at all unless the response is form-posted.
    if (provider.responseMode) url.searchParams.set("response_mode", provider.responseMode);

    return { state, nonce, authorizeUrl: url.toString() };
}

/**
 * Consume a pending authorization. Single-use: the record is deleted whether or
 * not the rest of the callback succeeds, so a replayed `state` finds nothing.
 */
export async function redeemAuthorization(store, state, { now = Date.now } = {}) {
    if (!state) return { ok: false, reason: "missing_state" };
    const key = `${PENDING_PREFIX}${state}`;
    const rec = await store.get(key, { type: "json" });
    if (!rec) return { ok: false, reason: "unknown_state" };
    await store.delete(key);
    if (rec.expiresAt <= now()) return { ok: false, reason: "expired" };
    return { ok: true, pending: rec };
}

/**
 * Apple's client secret: a short-lived JWT signed with the `.p8` key.
 *
 * Apple is the only one of the three that issues no static secret, and the
 * reason is a good one — a downloadable key that must be signed with cannot be
 * copied out of a build and replayed, because the assertion it produces expires.
 * Minted per exchange rather than cached: it costs a signature, and a cached
 * one is a credential sitting in memory for no gain.
 *
 * `aud` is Apple, `sub` is our Services ID, `iss` is the team. Five minutes is
 * far inside Apple's six-month ceiling and long enough for any exchange.
 */
function appleClientSecret(provider, { now = Date.now } = {}) {
    const { teamId, keyId, privateKey } = provider.appleKey;
    const iat = Math.floor(now() / 1000);
    const header = base64url(JSON.stringify({ alg: "ES256", kid: keyId }));
    const claims = base64url(JSON.stringify({
        iss: teamId,
        iat,
        exp: iat + 300,
        aud: "https://appleid.apple.com",
        sub: provider.clientId,
    }));
    const input = `${header}.${claims}`;
    const sig = crypto.sign("sha256", Buffer.from(input), {
        key: crypto.createPrivateKey(privateKey),
        // JWS wants the raw r||s pair, not the DER wrapping node defaults to.
        dsaEncoding: "ieee-p1363",
    });
    return `${input}.${base64url(sig)}`;
}

/**
 * Exchange an authorization code for tokens, then verify the `id_token`.
 *
 * The client secret is sent here and nowhere else. `client_secret` is omitted
 * when a provider is configured without one — Apple uses a signed assertion
 * rather than a static secret, and a public client uses PKCE alone.
 */
export async function exchangeCode(provider, {
    code,
    redirectUri,
    verifier,
    nonce,
    now = Date.now,
    fetchImpl = fetch,
}) {
    const body = new URLSearchParams({
        grant_type: "authorization_code",
        code,
        redirect_uri: redirectUri,
        client_id: provider.clientId,
        code_verifier: verifier,
    });
    const secret = provider.appleKey
        ? appleClientSecret(provider, { now })
        : provider.clientSecret;
    if (secret) body.set("client_secret", secret);

    const res = await fetchImpl(provider.tokenUrl, {
        method: "POST",
        headers: {
            "content-type": "application/x-www-form-urlencoded",
            accept: "application/json",
        },
        body: body.toString(),
    });
    if (!res.ok) return { ok: false, reason: "code_exchange_failed" };

    const payload = await res.json().catch(() => null);
    const idToken = payload?.id_token;
    if (!idToken) return { ok: false, reason: "no_id_token" };

    // The nonce is checked here, against the one we minted at step 1. This is
    // what binds the token to *our* authorize request.
    const verified = await verifyIdToken(idToken, provider, { now, nonce, fetchImpl });
    if (!verified.ok) return { ok: false, reason: verified.reason };
    return { ok: true, identity: verified.identity };
}

/**
 * Park a completed sign-in for the app to collect, and return the code.
 *
 * The payload is whatever `POST /api/auth/callback` would have returned. It
 * lives for a minute, is single-use, and is the only thing that crosses the
 * browser→app boundary — the tokens themselves never appear in a URL.
 */
export async function putHandoff(store, payload, { now = Date.now, makeToken = newToken } = {}) {
    const code = makeToken(24);
    await store.set(`${HANDOFF_PREFIX}${hash(code)}`, JSON.stringify({
        payload,
        expiresAt: now() + HANDOFF_TTL_MS,
    }));
    return code;
}

/** Collect a parked sign-in. Single-use, like every other code here. */
export async function redeemHandoff(store, code, { now = Date.now } = {}) {
    if (!code) return { ok: false, reason: "missing_code" };
    const key = `${HANDOFF_PREFIX}${hash(code)}`;
    const rec = await store.get(key, { type: "json" });
    if (!rec) return { ok: false, reason: "unknown_or_used" };
    await store.delete(key);
    if (rec.expiresAt <= now()) return { ok: false, reason: "expired" };
    return { ok: true, payload: rec.payload };
}
