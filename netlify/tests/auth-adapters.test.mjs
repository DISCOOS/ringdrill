/**
 * Tests for the auth adapter seam (ADR-0073).
 *
 * Three groups, and the middle one matters most:
 *
 *  1. Mode selection — unset means live, unknown falls back loudly.
 *  2. **The two guards.** A mock adapter mints principals from unsigned input,
 *     so it is a total authorisation bypass by construction. Guard 1: the live
 *     adapter refuses `test.` tokens on format, before verification, always.
 *     Guard 2: the mock module refuses to load under CONTEXT=production.
 *  3. A contract run — the same matrix questions asked of `live` and `mock`,
 *     asserting they answer identically. That is the claim the whole ADR rests
 *     on: dev exercises the production path.
 */
import { test } from "node:test";
import assert from "node:assert/strict";

import {
    AUTH_MODES,
    authenticate,
    createAdapter,
    generateKeypair,
    hasRole,
    isMemberOf,
    logAuthMode,
    resolveMode,
    signJwt,
    verifyJwt,
    ISSUER,
    AUDIENCE,
} from "../functions/lib/auth/index.js";
import { createLiveAdapter } from "../functions/lib/auth/live.js";
import { createOffAdapter } from "../functions/lib/auth/off.js";

const KEYS = generateKeypair();
const OTHER = generateKeypair();

const req = (headers = {}) => new Request("https://api.ringdrill.app/x", { headers });
const bearer = (token) => req({ authorization: `Bearer ${token}` });

const CLAIMS = {
    iss: ISSUER,
    aud: AUDIENCE,
    sub: "u_kari",
    act: "a_bergen",
    acts: ["a_bergen", "a_kari"],
    roles: { a_bergen: "owner", a_kari: "owner" },
    exp: Math.floor(Date.now() / 1000) + 3600,
    iat: Math.floor(Date.now() / 1000),
};

const liveToken = (over = {}) => signJwt({ ...CLAIMS, ...over }, KEYS.privateKey);

// ---------- mode selection ----------

test("resolveMode: unset means live, so an unconfigured deploy gets production semantics", () => {
    assert.equal(resolveMode({}), AUTH_MODES.LIVE);
    assert.equal(resolveMode({ AUTH_MODE: "" }), AUTH_MODES.LIVE);
});

test("resolveMode: the three known values, case- and space-insensitive", () => {
    assert.equal(resolveMode({ AUTH_MODE: "live" }), AUTH_MODES.LIVE);
    assert.equal(resolveMode({ AUTH_MODE: " MOCK " }), AUTH_MODES.MOCK);
    assert.equal(resolveMode({ AUTH_MODE: "Off" }), AUTH_MODES.OFF);
});

test("resolveMode: an unknown value falls back to live and says so loudly", () => {
    const warnings = [];
    const mode = resolveMode({ AUTH_MODE: "mokc" }, { warn: (m) => warnings.push(m) });
    assert.equal(mode, AUTH_MODES.LIVE, "falls back to the verifying mode, not the permissive one");
    assert.equal(warnings.length, 1, "silence here produces a mystifying debugging session");
    assert.match(warnings[0], /mokc/);
});

// ---------- guard 1: live refuses test tokens ----------

test("GUARD 1: the live adapter refuses a `test.` token, before signature verification", async () => {
    const adapter = createLiveAdapter({ env: { AUTH_SIGNING_KEY_PUBLIC: KEYS.publicKey } });
    const forged = "test." + Buffer.from(JSON.stringify(CLAIMS)).toString("base64url");
    const res = await adapter.authenticate(bearer(forged));
    assert.equal(res.ok, false);
    assert.equal(res.status, 401);
    assert.equal(res.reason, "test_token_refused");
});

test("GUARD 1 holds even with no verification key configured", async () => {
    // The refusal is on format, so it cannot depend on key configuration —
    // otherwise a half-configured deploy would be the hole.
    const adapter = createLiveAdapter({ env: {} });
    const forged = "test." + Buffer.from(JSON.stringify(CLAIMS)).toString("base64url");
    const res = await adapter.authenticate(bearer(forged));
    assert.equal(res.reason, "test_token_refused");
});

test("live refuses everything when no verification key is configured, rather than falling back to anonymous", async () => {
    const adapter = createLiveAdapter({ env: {} });
    const res = await adapter.authenticate(bearer(liveToken()));
    assert.equal(res.ok, false, "treating this as anonymous would silently downgrade every authenticated call");
    assert.equal(res.reason, "no_verification_key");
});

// ---------- guard 2: mock refuses to load in production ----------

test("GUARD 2: the mock module refuses to load when CONTEXT=production", async () => {
    const saved = process.env.CONTEXT;
    process.env.CONTEXT = "production";
    try {
        // A cache-busting query forces a fresh module evaluation, so the
        // load-time guard actually runs rather than hitting the module cache.
        await assert.rejects(
            () => import("../functions/lib/auth/mock.js?production-guard"),
            /must never load in a production deploy/,
        );
    } finally {
        if (saved === undefined) delete process.env.CONTEXT;
        else process.env.CONTEXT = saved;
    }
});

test("GUARD 2: createAdapter does not load mock on a live deploy, so the guard is not an outage", async () => {
    // A static import of mock.js would throw here even though this deploy never
    // asked for mock. The dynamic import is what keeps the safety device from
    // becoming the failure.
    const adapter = await createAdapter({
        env: { CONTEXT: "production", AUTH_SIGNING_KEY_PUBLIC: KEYS.publicKey },
    });
    assert.equal(adapter.mode, "live");
});

test("GUARD 2: asking for mock in production fails, and authenticate() refuses rather than passing through", async () => {
    const res = await authenticate(bearer("test.x"), {
        env: { CONTEXT: "production", AUTH_MODE: "mock" },
    });
    assert.equal(res.ok, false, "a broken auth backend must not read as anonymous");
    assert.equal(res.status, 401);
});

// ---------- jwt ----------

test("verifyJwt: rejects alg confusion before looking at the signature", () => {
    const header = Buffer.from(JSON.stringify({ alg: "none", typ: "JWT" })).toString("base64url");
    const payload = Buffer.from(JSON.stringify(CLAIMS)).toString("base64url");
    const res = verifyJwt(`${header}.${payload}.`, [KEYS.publicKey], { issuer: ISSUER, audience: AUDIENCE });
    assert.equal(res.ok, false);
    assert.equal(res.reason, "bad_alg");
});

test("verifyJwt: rejects a token signed with a different key", () => {
    const token = signJwt(CLAIMS, OTHER.privateKey);
    const res = verifyJwt(token, [KEYS.publicKey], { issuer: ISSUER, audience: AUDIENCE });
    assert.equal(res.reason, "bad_signature");
});

test("verifyJwt: accepts the previous key during a rotation window", () => {
    const token = signJwt(CLAIMS, OTHER.privateKey);
    const res = verifyJwt(token, [KEYS.publicKey, OTHER.publicKey], { issuer: ISSUER, audience: AUDIENCE });
    assert.equal(res.ok, true);
});

test("verifyJwt: a malformed key in the list does not mask a good one after it", () => {
    const token = signJwt(CLAIMS, KEYS.privateKey);
    const res = verifyJwt(token, ["not-a-pem", KEYS.publicKey], { issuer: ISSUER, audience: AUDIENCE });
    assert.equal(res.ok, true);
});

test("verifyJwt: checks iss, aud and exp", () => {
    const opts = { issuer: ISSUER, audience: AUDIENCE };
    assert.equal(verifyJwt(signJwt({ ...CLAIMS, iss: "evil" }, KEYS.privateKey), [KEYS.publicKey], opts).reason, "bad_iss");
    assert.equal(verifyJwt(signJwt({ ...CLAIMS, aud: "other" }, KEYS.privateKey), [KEYS.publicKey], opts).reason, "bad_aud");
    assert.equal(verifyJwt(signJwt({ ...CLAIMS, exp: 1 }, KEYS.privateKey), [KEYS.publicKey], opts).reason, "expired");
});

test("verifyJwt: a token with no exp is refused — an access token that never expires is a bug", () => {
    const { exp, ...noExp } = CLAIMS;
    const res = verifyJwt(signJwt(noExp, KEYS.privateKey), [KEYS.publicKey], { issuer: ISSUER, audience: AUDIENCE });
    assert.equal(res.reason, "missing_exp");
});

test("verifyJwt: never throws on garbage", () => {
    for (const junk of ["", "a", "a.b", "a.b.c", "....", null, undefined, 42]) {
        const res = verifyJwt(junk, [KEYS.publicKey]);
        assert.equal(res.ok, false, `expected refusal for ${JSON.stringify(junk)}`);
    }
});

// ---------- off ----------

test("off: everything is anonymous, and a present token is ignored rather than rejected", async () => {
    const adapter = createOffAdapter();
    assert.deepEqual(await adapter.authenticate(req()), { ok: true, anonymous: true });
    // 401-ing a correctly-behaving client would make the rollback switch an outage.
    assert.deepEqual(await adapter.authenticate(bearer(liveToken())), { ok: true, anonymous: true });
});

// ---------- contract: live and mock answer identically ----------

async function adapters() {
    const live = createLiveAdapter({ env: { AUTH_SIGNING_KEY_PUBLIC: KEYS.publicKey } });
    const { createMockAdapter, mintTestToken } = await import("../functions/lib/auth/mock.js");
    const mock = createMockAdapter({ env: {} });
    return [
        { name: "live", adapter: live, token: (c) => signJwt({ ...CLAIMS, ...c }, KEYS.privateKey) },
        { name: "mock", adapter: mock, token: (c) => mintTestToken({ ...CLAIMS, ...c }) },
    ];
}

test("contract: no credential is anonymous in both modes", async () => {
    for (const { name, adapter } of await adapters()) {
        assert.deepEqual(await adapter.authenticate(req()), { ok: true, anonymous: true }, name);
    }
});

test("contract: a valid token yields the same principal in both modes", async () => {
    for (const { name, adapter, token } of await adapters()) {
        const res = await adapter.authenticate(bearer(token()));
        assert.equal(res.ok, true, name);
        assert.equal(res.anonymous, false, name);
        assert.equal(res.userId, "u_kari", name);
        assert.equal(res.accountId, "a_bergen", name);
        assert.equal(res.role, "owner", name);
        assert.deepEqual(res.accounts, ["a_bergen", "a_kari"], name);
    }
});

test("contract: X-Active-Account switches account without re-minting", async () => {
    for (const { name, adapter, token } of await adapters()) {
        const res = await adapter.authenticate(
            new Request("https://api.ringdrill.app/x", {
                headers: { authorization: `Bearer ${token()}`, "x-active-account": "a_kari" },
            }),
        );
        assert.equal(res.accountId, "a_kari", name);
    }
});

test("contract: X-Active-Account naming an account outside the token is 403, not a silent fallback", async () => {
    for (const { name, adapter, token } of await adapters()) {
        const res = await adapter.authenticate(
            new Request("https://api.ringdrill.app/x", {
                headers: { authorization: `Bearer ${token()}`, "x-active-account": "a_someone_else" },
            }),
        );
        assert.equal(res.ok, false, name);
        assert.equal(res.status, 403, name);
        assert.equal(res.reason, "account_not_in_token", name);
    }
});

test("contract: an expired token is refused in both modes", async () => {
    for (const { name, adapter, token } of await adapters()) {
        const res = await adapter.authenticate(bearer(token({ exp: 1 })));
        assert.equal(res.ok, false, name);
        assert.equal(res.reason, "expired", name);
    }
});

test("contract: each mode refuses the other's token format", async () => {
    const [live, mock] = await adapters();
    assert.equal((await live.adapter.authenticate(bearer(mock.token()))).reason, "test_token_refused");
    assert.equal((await mock.adapter.authenticate(bearer(live.token()))).reason, "expected_test_token");
});

// ---------- role helpers ----------

test("isMemberOf / hasRole: every member publishes; rank orders administration only", async () => {
    const { createMockAdapter, mintTestToken } = await import("../functions/lib/auth/mock.js");
    const adapter = createMockAdapter({ env: {} });
    const res = await adapter.authenticate(bearer(mintTestToken({
        ...CLAIMS, act: "a_bergen", acts: ["a_bergen"], roles: { a_bergen: "guest" },
    })));

    // A guest is in the account, so a guest publishes (ADR-0024, amended
    // 2026-08-05). The distinction guest carries is the staff roster, not this.
    assert.equal(isMemberOf(res, "a_bergen"), true);
    assert.equal(isMemberOf(res, "a_other"), false);

    assert.equal(hasRole(res, "a_bergen", "guest"), true);
    assert.equal(hasRole(res, "a_bergen", "member"), false);
    assert.equal(hasRole(res, "a_bergen", "owner"), false);
});

// ---------- the cold-start announcement ----------

/**
 * Every way of getting `AUTH_MODE` wrong looks identical from outside: sign-in
 * fails and nothing says why. These pin the line that tells you, and the one
 * detail in it that is worth more than the mode name — that `live` without a
 * signing key authenticates nothing.
 */
test("logAuthMode announces the resolved mode on stdout", () => {
    const lines = [];
    const log = (m) => lines.push(m);

    assert.equal(logAuthMode({ AUTH_MODE: "mock" }, { log }), AUTH_MODES.MOCK);
    assert.match(lines.at(-1), /mode=mock/);
    assert.match(lines.at(-1), /codes returned in the response body/);
});

test("logAuthMode names the missing signing key, not just the mode", () => {
    // The most common local failure: AUTH_MODE unset defaults to live, which
    // then needs a key nobody set. "mode=live" alone would not explain why
    // nothing authenticates.
    const lines = [];
    const log = (m) => lines.push(m);

    logAuthMode({}, { log });
    assert.match(lines.at(-1), /mode=live/);
    assert.match(lines.at(-1), /AUTH_SIGNING_KEY_PRIVATE is unset/);

    logAuthMode({ AUTH_SIGNING_KEY_PRIVATE: "k" }, { log });
    assert.doesNotMatch(lines.at(-1), /unset/);
});

test("logAuthMode reports off as the rollback mode it is", () => {
    const lines = [];
    logAuthMode({ AUTH_MODE: "off" }, { log: (m) => lines.push(m) });
    assert.match(lines.at(-1), /mode=off/);
    assert.match(lines.at(-1), /every request anonymous/);
});
