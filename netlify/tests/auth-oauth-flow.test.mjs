/**
 * The server-side authorization-code flow (ADR-0024, DESIGN-015 §3.2).
 *
 * The app never holds a client id, a client secret, or a provider SDK: it asks
 * what exists, opens the authorize URL in a system browser, and later collects
 * a session. These tests cover the parts that are ours — everything from the
 * provider's redirect onwards — and the properties that make it safe:
 *
 * * `state` is single-use and names the provider, so a redeemed one cannot be
 *   replayed or pointed at a different provider's configuration.
 * * the `nonce` binds the `id_token` to the authorize request we started.
 * * the session crosses the browser→app boundary as a one-minute single-use
 *   code, never as tokens in a URL.
 */
import { test } from "node:test";
import assert from "node:assert/strict";
import crypto from "node:crypto";

import { createHandler } from "../functions/auth.js";
import { createMockAdapter } from "../functions/lib/mail/index.js";
import { generateKeypair } from "../functions/lib/auth/index.js";
import { resetJwksCache } from "../functions/lib/auth/providers.js";

const KEYS = generateKeypair();
const rsa = crypto.generateKeyPairSync("rsa", { modulusLength: 2048 });

function fakeStore() {
    const data = new Map();
    return {
        data,
        async get(key, opts) {
            const raw = data.get(key);
            return raw === undefined ? null : (opts?.type === "json" ? JSON.parse(raw) : raw);
        },
        async set(key, value, opts = {}) {
            if (opts.onlyIfNew && data.has(key)) return { modified: false };
            data.set(key, value); return { modified: true };
        },
        async delete(key) { data.delete(key); },
        async list({ prefix = "", cursor } = {}) {
            if (cursor) return { blobs: [], cursor: undefined };
            return { blobs: [...data.keys()].filter((k) => k.startsWith(prefix)).map((key) => ({ key })), cursor: undefined };
        },
    };
}

const ENV = {
    AUTH_MODE: "live",
    AUTH_SIGNING_KEY_PRIVATE: KEYS.privateKey,
    AUTH_SIGNING_KEY_PUBLIC: KEYS.publicKey,
    PUBLIC_APP_ORIGIN: "https://ringdrill.app",
    PUBLIC_API_ORIGIN: "https://api.ringdrill.app",
    OAUTH_GOOGLE_CLIENT_ID: "web-client.apps.googleusercontent.com",
    OAUTH_GOOGLE_CLIENT_SECRET: "s3cret",
    // The baseline is a *compliant* deployment: guideline 4.8 requires Sign in
    // with Apple alongside third-party login, and `offerableProviders` refuses
    // to advertise Google without it. Tests that want the violation opt in.
    OAUTH_APPLE_CLIENT_ID: "app.ringdrill.web",
};

const b64 = (o) => Buffer.from(JSON.stringify(o)).toString("base64url");

/** An id_token as Google would mint it. */
function idToken(over = {}) {
    const claims = {
        iss: "https://accounts.google.com",
        aud: ENV.OAUTH_GOOGLE_CLIENT_ID,
        sub: "google-sub-1",
        email: "kari@example.com",
        email_verified: true,
        exp: Math.floor(Date.now() / 1000) + 600,
        ...over,
    };
    const input = `${b64({ alg: "RS256", typ: "JWT", kid: "k1" })}.${b64(claims)}`;
    const sig = crypto.sign("sha256", Buffer.from(input), rsa.privateKey);
    return `${input}.${sig.toString("base64url")}`;
}

/**
 * Stands in for Google: serves the JWKS, and answers the token endpoint with
 * whatever `tokenResponse` currently is.
 */
function upstream({ token = null, tokenOk = true } = {}) {
    // `nonce` is filled in by `walkTo` from the authorize URL, because a real
    // provider echoes back the nonce we sent. A token minted without it is a
    // *different* test — see the bad-nonce case below.
    const state = { exchanges: [], nonce: null };
    const mint = token ?? (() => ({ id_token: idToken({ nonce: state.nonce }) }));
    state.fetch = async (url, init) => {
        // Dispatch on the *token* endpoint rather than on a provider-specific
        // JWKS path: matching only Google's `/oauth2/v3/certs` recorded
        // Apple's key fetch as an exchange, and the assertion then read an
        // empty body.
        if (!String(url).endsWith("/token")) {
            return {
                ok: true,
                json: async () => ({
                    keys: [{ ...rsa.publicKey.export({ format: "jwk" }), kid: "k1", use: "sig" }],
                }),
            };
        }
        state.exchanges.push(Object.fromEntries(new URLSearchParams(init.body)));
        return { ok: tokenOk, json: async () => mint() };
    };
    return state;
}

function harness(over = {}) {
    const raw = {
        accounts: fakeStore(), users: fakeStore(), identities: fakeStore(), members: fakeStore(), memberIndex: fakeStore(),
        emailIndex: fakeStore(), handles: fakeStore(), sessions: fakeStore(), sessionIndex: fakeStore(), challenges: fakeStore(),
    };
    const stores = {
        accounts: () => raw.accounts, users: () => raw.users, identities: () => raw.identities,
        members: () => raw.members, memberIndex: () => raw.memberIndex,
        emailIndex: () => raw.emailIndex, handles: () => raw.handles,
        sessions: () => raw.sessions, sessionIndex: () => raw.sessionIndex,
    };
    return {
        raw,
        stores,
        handler: createHandler({
            env: { ...ENV, ...over },
            stores,
            challengeStore: () => raw.challenges,
            sessionStore: () => raw.sessions,
            sessionIndexStore: () => raw.sessionIndex,
            mailer: createMockAdapter(),
        }),
    };
}

const get = (h, path) => h.handler(new Request(`https://api.ringdrill.app/api/auth/${path}`));

async function discover(h) {
    const body = await (await get(h, "providers")).json();
    return body.providers;
}

test.beforeEach(resetJwksCache);

// ---------- discovery ----------

test("providers are discovered at runtime, not baked into a build", async () => {
    const h = harness();
    const providers = await discover(h);

    assert.deepEqual(providers.map((p) => p.id), ["google", "apple"]);
    assert.equal(providers[0].label, "Google");
});

test("an unconfigured provider is simply absent", async () => {
    // Not disabled, not broken — absent. A build must never believe in a
    // provider nobody configured.
    const h = harness({ OAUTH_GOOGLE_CLIENT_ID: "", OAUTH_APPLE_CLIENT_ID: "" });
    assert.deepEqual(await discover(h), []);
});

test("the authorize URL points at the provider's own domain", async () => {
    // The user signs in on Google's page, not on ours. "Server-side" describes
    // where the *code* is exchanged, nothing the human sees.
    const h = harness();
    const url = new URL((await discover(h))[0].authorizeUrl);

    assert.equal(url.origin, "https://accounts.google.com");
    assert.equal(url.searchParams.get("client_id"), ENV.OAUTH_GOOGLE_CLIENT_ID);
    assert.equal(url.searchParams.get("response_type"), "code");
    assert.equal(
        url.searchParams.get("redirect_uri"),
        "https://api.ringdrill.app/api/auth/callback/google",
        "the provider redirects to us, never to the app",
    );
});

test("the authorize URL carries PKCE and a nonce", async () => {
    const h = harness();
    const url = new URL((await discover(h))[0].authorizeUrl);

    assert.equal(url.searchParams.get("code_challenge_method"), "S256");
    assert.ok(url.searchParams.get("code_challenge"));
    assert.ok(url.searchParams.get("nonce"));
    // The verifier is the secret and stays here.
    assert.equal(url.searchParams.has("code_verifier"), false);
});

test("no client secret appears anywhere in the response", async () => {
    // The whole point of the architecture.
    const h = harness();
    const body = await (await get(h, "providers")).text();

    assert.equal(body.includes("s3cret"), false);
});

test("discovery is never cached", async () => {
    // Each call parks a fresh single-use state; a cached response would hand
    // two people the same one.
    const h = harness();
    assert.equal((await get(h, "providers")).headers.get("cache-control"), "no-store");
});

// ---------- the callback ----------

/** Walk discovery → provider redirect, returning the bounce Response. */
async function walkTo(h, up, { tamper = (p) => p } = {}) {
    const authorizeUrl = new URL((await discover(h))[0].authorizeUrl);
    up.nonce = authorizeUrl.searchParams.get("nonce");
    const params = tamper(new URLSearchParams({
        code: "auth-code-1",
        state: authorizeUrl.searchParams.get("state"),
    }));
    globalThis.fetch = up.fetch;
    try {
        return await h.handler(new Request(
            `https://api.ringdrill.app/api/auth/callback/google?${params}`,
        ));
    } finally {
        delete globalThis.fetch;
    }
}

test("a completed sign-in bounces into the app with a handoff code", async () => {
    const h = harness();
    const res = await walkTo(h, upstream());

    assert.equal(res.status, 302);
    const location = new URL(res.headers.get("location"));
    assert.equal(location.protocol, "ringdrill:");
    assert.ok(location.searchParams.get("handoff"));
});

test("tokens never appear in the redirect URL", async () => {
    // A URL lands in browser history, in Referer headers, and in whatever the
    // OS logs for a custom-scheme launch. A one-minute single-use code does
    // not.
    const h = harness();
    const res = await walkTo(h, upstream());
    const location = res.headers.get("location");

    assert.equal(location.includes("accessToken"), false);
    assert.equal(location.includes("refreshToken"), false);
});

test("the handoff code is exchanged for the session, once", async () => {
    const h = harness();
    const bounce = await walkTo(h, upstream());
    const handoff = new URL(bounce.headers.get("location")).searchParams.get("handoff");

    const collect = () => h.handler(new Request("https://api.ringdrill.app/api/auth/callback", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ handoff }),
    }));

    const first = await collect();
    assert.equal(first.status, 200);
    const session = await first.json();
    assert.equal(session.user.email, "kari@example.com");
    assert.ok(session.accessToken && session.refreshToken);

    // Single-use: a replayed code finds nothing.
    assert.equal((await collect()).status, 401);
});

test("the code exchange sends the secret and the verifier, and nothing else does", async () => {
    const h = harness();
    const up = upstream();
    await walkTo(h, up);

    const exchange = up.exchanges.at(-1);
    assert.equal(exchange.client_secret, "s3cret");
    assert.equal(exchange.grant_type, "authorization_code");
    assert.ok(exchange.code_verifier, "PKCE completes the pair the challenge started");
    assert.equal(exchange.redirect_uri, "https://api.ringdrill.app/api/auth/callback/google");
});

test("signing in creates the user and their personal account", async () => {
    const h = harness();
    const bounce = await walkTo(h, upstream());
    const handoff = new URL(bounce.headers.get("location")).searchParams.get("handoff");
    const session = await (await h.handler(new Request("https://api.ringdrill.app/api/auth/callback", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ handoff }),
    }))).json();

    assert.equal(session.accountCreated, true);
    assert.equal(h.raw.users.data.size, 1);
    assert.equal(h.raw.accounts.data.size, 1);
});

// ---------- refusals ----------

test("a replayed state is refused", async () => {
    // Single-use, because a state that survives its redemption is a CSRF token
    // that can be reused.
    const h = harness();
    const up = upstream();
    const authorizeUrl = new URL((await discover(h))[0].authorizeUrl);
    const state = authorizeUrl.searchParams.get("state");
    up.nonce = authorizeUrl.searchParams.get("nonce");

    const call = async () => {
        globalThis.fetch = up.fetch;
        try {
            return await h.handler(new Request(
                `https://api.ringdrill.app/api/auth/callback/google?code=c&state=${state}`,
            ));
        } finally { delete globalThis.fetch; }
    };

    assert.equal(new URL((await call()).headers.get("location")).searchParams.get("error"), null);
    assert.equal(
        new URL((await call()).headers.get("location")).searchParams.get("error"),
        "unknown_state",
    );
});

test("an unknown state is refused", async () => {
    const h = harness();
    const res = await h.handler(new Request(
        "https://api.ringdrill.app/api/auth/callback/google?code=c&state=made-up",
    ));
    assert.equal(new URL(res.headers.get("location")).searchParams.get("error"), "unknown_state");
});

test("a state redeemed against a different provider's path is refused", async () => {
    // The path segment does not get to name the provider — the parked
    // authorization does, or a valid state could be pointed at another
    // provider's client configuration.
    const h = harness();
    const authorizeUrl = new URL((await discover(h))[0].authorizeUrl);
    const state = authorizeUrl.searchParams.get("state");

    const res = await h.handler(new Request(
        `https://api.ringdrill.app/api/auth/callback/apple?code=c&state=${state}`,
    ));
    assert.equal(
        new URL(res.headers.get("location")).searchParams.get("error"),
        "unknown_provider",
    );
});

test("a token whose nonce does not match is refused", async () => {
    // This is what stops an id_token obtained elsewhere being replayed here.
    const h = harness();
    const up = upstream({ token: () => ({ id_token: idToken({ nonce: "not-ours" }) }) });

    const res = await walkTo(h, up);
    assert.equal(new URL(res.headers.get("location")).searchParams.get("error"), "bad_nonce");
});

test("a failed code exchange bounces with a reason, not a blank page", async () => {
    // A human is looking at this inside a sign-in sheet. Leaving them on an
    // error page gives them nothing to do.
    const h = harness();
    const res = await walkTo(h, upstream({ tokenOk: false }));

    assert.equal(res.status, 302);
    assert.equal(
        new URL(res.headers.get("location")).searchParams.get("error"),
        "code_exchange_failed",
    );
});

test("a cancelled sign-in bounces without touching anything", async () => {
    const h = harness();
    const res = await h.handler(new Request(
        "https://api.ringdrill.app/api/auth/callback/google?error=access_denied&state=x",
    ));

    assert.equal(new URL(res.headers.get("location")).searchParams.get("error"), "access_denied");
    assert.equal(h.raw.users.data.size, 0);
});

test("an unknown handoff code is 401", async () => {
    const h = harness();
    const res = await h.handler(new Request("https://api.ringdrill.app/api/auth/callback", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ handoff: "made-up" }),
    }));
    assert.equal(res.status, 401);
});

// ---------- Apple's signed client assertion ----------

test("Apple is sent a signed assertion, not a static secret", async () => {
    // Apple issues no static secret: the token endpoint expects a short-lived
    // JWT signed with the .p8 key. A downloadable key that must be *signed
    // with* cannot be lifted from a build and replayed, because what it
    // produces expires.
    const ec = crypto.generateKeyPairSync("ec", { namedCurve: "P-256" });
    const h = harness({
        OAUTH_GOOGLE_CLIENT_ID: "",
        OAUTH_APPLE_TEAM_ID: "TEAM123",
        OAUTH_APPLE_KEY_ID: "KEY123",
        OAUTH_APPLE_PRIVATE_KEY: ec.privateKey.export({ type: "pkcs8", format: "pem" }),
    });

    const authorizeUrl = new URL((await discover(h))[0].authorizeUrl);
    const up = upstream();
    up.nonce = authorizeUrl.searchParams.get("nonce");
    globalThis.fetch = up.fetch;
    try {
        await h.handler(new Request(
            "https://api.ringdrill.app/api/auth/callback/apple?code=c&state="
            + authorizeUrl.searchParams.get("state"),
        ));
    } finally { delete globalThis.fetch; }

    const secret = up.exchanges.at(-1).client_secret;
    const [header, claims] = secret.split(".").slice(0, 2)
        .map((p) => JSON.parse(Buffer.from(p, "base64url").toString()));

    assert.equal(header.alg, "ES256");
    assert.equal(header.kid, "KEY123", "names the key Apple should verify with");
    assert.equal(claims.iss, "TEAM123");
    assert.equal(claims.sub, "app.ringdrill.web", "the Services ID, not the bundle id");
    assert.equal(claims.aud, "https://appleid.apple.com");
    assert.ok(claims.exp - claims.iat <= 300, "short-lived");

    // And it actually verifies against the key, rather than merely looking
    // like a JWT.
    const ok = crypto.verify(
        "sha256",
        Buffer.from(secret.split(".").slice(0, 2).join(".")),
        { key: ec.publicKey, dsaEncoding: "ieee-p1363" },
        Buffer.from(secret.split(".")[2], "base64url"),
    );
    assert.equal(ok, true);
});

test("Apple asks for a form post, or it returns no email at all", async () => {
    const h = harness({ OAUTH_GOOGLE_CLIENT_ID: "" });
    const url = new URL((await discover(h))[0].authorizeUrl);

    assert.equal(url.searchParams.get("response_mode"), "form_post");
    assert.equal(url.origin, "https://appleid.apple.com");
});

// ---------- App Store guideline 4.8 ----------

test("Google without Apple is not offered at all", async () => {
    // Runtime configuration turned a 4.8 violation into a deployment mistake:
    // set Google, forget Apple, and the app ships third-party login without
    // the privacy-preserving alternative the guideline requires. Nothing would
    // have surfaced it — the buttons render and review rejects later.
    const h = harness({ OAUTH_APPLE_CLIENT_ID: "" });

    assert.deepEqual(await discover(h), [], "no buttons rather than the wrong ones");
});

test("Google with Apple is offered", async () => {
    const h = harness();

    assert.deepEqual(
        (await discover(h)).map((p) => p.id).sort(),
        ["apple", "google"],
    );
});

test("Apple alone is fine — it is the alternative, not the thing needing one", async () => {
    const h = harness({
        OAUTH_GOOGLE_CLIENT_ID: "",
        OAUTH_APPLE_CLIENT_ID: "app.ringdrill.web",
    });

    assert.deepEqual((await discover(h)).map((p) => p.id), ["apple"]);
});

test("no providers at all is fine — 4.8 does not apply", async () => {
    // An app offering no third-party login has nothing to pair with Apple.
    const h = harness({ OAUTH_GOOGLE_CLIENT_ID: "", OAUTH_APPLE_CLIENT_ID: "" });

    assert.deepEqual(await discover(h), []);
});

test("the rule does not apply outside a live deployment", async () => {
    // A developer configuring Google alone to exercise the flow is not
    // shipping anything, and a guard that blocks them is one people route
    // around.
    const h = harness({ AUTH_MODE: "mock", OAUTH_APPLE_CLIENT_ID: "" });

    assert.deepEqual((await discover(h)).map((p) => p.id), ["google"]);
});
