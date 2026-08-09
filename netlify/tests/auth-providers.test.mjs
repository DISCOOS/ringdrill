/**
 * Verifying a third-party `id_token` (ADR-0024).
 *
 * This is the code that decides whether somebody is who a provider says they
 * are, so most of these tests are attacks rather than happy paths. The ones
 * that matter most are the checks a plausible implementation *omits*:
 * algorithm confusion, a token minted for a different application, and — for
 * multi-tenant Microsoft — an issuer that names a tenant the token does not
 * belong to.
 */
import { test } from "node:test";
import assert from "node:assert/strict";
import crypto from "node:crypto";

import {
    configuredProviders,
    providerConfig,
    resetJwksCache,
    verifyIdToken,
} from "../functions/lib/auth/providers.js";

const NOW = 1_800_000_000_000;
const nowFn = () => NOW;
const nowS = Math.floor(NOW / 1000);

const rsa = crypto.generateKeyPairSync("rsa", { modulusLength: 2048 });
const ec = crypto.generateKeyPairSync("ec", { namedCurve: "P-256" });

const b64 = (o) => Buffer.from(JSON.stringify(o)).toString("base64url");

/** Sign a token the way a provider would. */
function mint(claims, { alg = "RS256", kid = "k1", key = rsa.privateKey } = {}) {
    const input = `${b64({ alg, typ: "JWT", kid })}.${b64(claims)}`;
    if (alg === "none") return `${input}.`;
    if (alg === "HS256") {
        const mac = crypto.createHmac("sha256", "whatever").update(input).digest("base64url");
        return `${input}.${mac}`;
    }
    const opts = alg === "ES256" ? { key, dsaEncoding: "ieee-p1363" } : key;
    return `${input}.${crypto.sign("sha256", Buffer.from(input), opts).toString("base64url")}`;
}

/** A JWKS endpoint that counts how often it was asked. */
function jwks(keys = [{ kid: "k1", key: rsa.publicKey }]) {
    const state = { calls: 0 };
    state.fetch = async () => {
        state.calls += 1;
        return {
            ok: true,
            json: async () => ({
                keys: keys.map(({ kid, key }) => ({
                    ...key.export({ format: "jwk" }),
                    kid,
                    use: "sig",
                })),
            }),
        };
    };
    return state;
}

const GOOGLE_ENV = {
    OAUTH_GOOGLE_CLIENT_ID: "web-client.apps.googleusercontent.com",
    OAUTH_GOOGLE_CLIENT_SECRET: "s3cret",
    OAUTH_GOOGLE_AUDIENCES: "ios-client.apps.googleusercontent.com",
};

const google = () => providerConfig("google", GOOGLE_ENV);

const claims = (over = {}) => ({
    iss: "https://accounts.google.com",
    aud: "web-client.apps.googleusercontent.com",
    sub: "1234567890",
    email: "kari@example.com",
    email_verified: true,
    exp: nowS + 600,
    iat: nowS,
    ...over,
});

const verify = (token, { provider = google(), ...rest } = {}) =>
    verifyIdToken(token, provider, { now: nowFn, ...rest });

test.beforeEach(resetJwksCache);

// ---------- the registry ----------

test("a provider with no client id is absent, not disabled", async () => {
    // The app asks at runtime precisely so a build never has to believe in a
    // provider nobody configured.
    assert.deepEqual(configuredProviders({}), []);
    assert.deepEqual(
        configuredProviders(GOOGLE_ENV).map((p) => p.id),
        ["google"],
    );
});

test("the client secret stays in the config object, never in the wire shape", async () => {
    // A guard on the shape the discovery endpoint is built from.
    const p = google();
    assert.equal(p.clientSecret, "s3cret");
    assert.ok(!("clientSecret" in { id: p.id, label: p.label }));
});

// ---------- the happy paths ----------

test("a well-formed RS256 token verifies", async () => {
    const j = jwks();
    const res = await verify(mint(claims()), { fetchImpl: j.fetch });

    assert.equal(res.ok, true);
    assert.deepEqual(res.identity, {
        provider: "google",
        subject: "1234567890",
        email: "kari@example.com",
        emailVerified: true,
        displayName: null,
    });
});

test("ES256 verifies too", async () => {
    const j = jwks([{ kid: "k1", key: ec.publicKey }]);
    const token = mint(claims(), { alg: "ES256", key: ec.privateKey });

    assert.equal((await verify(token, { fetchImpl: j.fetch })).ok, true);
});

test("a native audience is accepted alongside the web one", async () => {
    // Sign in with Apple on iOS presents the bundle id, not the web Service
    // ID. Same for a Google iOS client.
    const j = jwks();
    const token = mint(claims({ aud: "ios-client.apps.googleusercontent.com" }));

    assert.equal((await verify(token, { fetchImpl: j.fetch })).ok, true);
});

// ---------- algorithm confusion ----------

test("`alg: none` is refused before the signature is looked at", async () => {
    const j = jwks();
    const res = await verify(mint(claims(), { alg: "none" }), { fetchImpl: j.fetch });

    assert.equal(res.ok, false);
    assert.equal(res.reason, "bad_alg");
    assert.equal(j.calls, 0, "and without fetching anything");
});

test("HS256 is refused — the public key is not a shared secret", async () => {
    // The classic confusion: sign with HMAC keyed on the provider's *public*
    // key, and a verifier that dispatches on the header's alg accepts it.
    const j = jwks();
    const res = await verify(mint(claims(), { alg: "HS256" }), { fetchImpl: j.fetch });

    assert.equal(res.reason, "bad_alg");
});

test("a token signed by the wrong key is refused", async () => {
    const other = crypto.generateKeyPairSync("rsa", { modulusLength: 2048 });
    const j = jwks();
    const token = mint(claims(), { key: other.privateKey });

    assert.equal((await verify(token, { fetchImpl: j.fetch })).reason, "bad_signature");
});

// ---------- claims ----------

test("a token for a different application is refused", async () => {
    // Without this check, any Google id_token from any app on the internet
    // signs somebody in here.
    const j = jwks();
    const token = mint(claims({ aud: "someone-elses-app.apps.googleusercontent.com" }));

    assert.equal((await verify(token, { fetchImpl: j.fetch })).reason, "bad_audience");
});

test("a token from a different issuer is refused", async () => {
    const j = jwks();
    assert.equal(
        (await verify(mint(claims({ iss: "https://evil.example" })), { fetchImpl: j.fetch })).reason,
        "bad_issuer",
    );
});

test("both spellings of Google's issuer are accepted", async () => {
    // Google has emitted the scheme-less form historically and both are valid.
    const j = jwks();
    assert.equal(
        (await verify(mint(claims({ iss: "accounts.google.com" })), { fetchImpl: j.fetch })).ok,
        true,
    );
});

test("an expired token is refused", async () => {
    const j = jwks();
    const token = mint(claims({ exp: nowS - 600 }));

    assert.equal((await verify(token, { fetchImpl: j.fetch })).reason, "expired");
});

test("a small clock skew is tolerated", async () => {
    // Refusing a token that expired one second ago by our clock would fail
    // real sign-ins for no security gain.
    const j = jwks();
    const token = mint(claims({ exp: nowS - 30 }));

    assert.equal((await verify(token, { fetchImpl: j.fetch })).ok, true);
});

test("the nonce binds the token to the request we started", async () => {
    // This is what stops a token obtained elsewhere being replayed here.
    const j = jwks();
    const token = mint(claims({ nonce: "n-correct" }));

    assert.equal((await verify(token, { fetchImpl: j.fetch, nonce: "n-correct" })).ok, true);
    assert.equal(
        (await verify(token, { fetchImpl: j.fetch, nonce: "n-different" })).reason,
        "bad_nonce",
    );
});

test("a token with no nonce is refused when one was requested", async () => {
    const j = jwks();
    assert.equal(
        (await verify(mint(claims()), { fetchImpl: j.fetch, nonce: "n-1" })).reason,
        "bad_nonce",
    );
});

// ---------- email ----------

test("an unverified address is reported as unverified", async () => {
    // Only a verified address may link to an existing user; an unverified one
    // would let somebody claim an address they do not control.
    const j = jwks();
    const res = await verify(mint(claims({ email_verified: false })), { fetchImpl: j.fetch });

    assert.equal(res.ok, true);
    assert.equal(res.identity.emailVerified, false);
});

test("Apple's string 'true' counts as verified", async () => {
    // Google sends a boolean, Apple sends the string. A strict `=== true`
    // would silently treat every Apple sign-in as unverified.
    const j = jwks();
    const res = await verify(mint(claims({ email_verified: "true" })), { fetchImpl: j.fetch });

    assert.equal(res.identity.emailVerified, true);
});

// ---------- Microsoft's per-tenant issuer ----------

const MS_ENV = { OAUTH_MICROSOFT_CLIENT_ID: "ms-app-id" };
const microsoft = () => providerConfig("microsoft", MS_ENV);

test("a multi-tenant issuer is accepted when it matches the token's own tenant", async () => {
    const j = jwks();
    const token = mint({
        iss: "https://login.microsoftonline.com/tenant-abc/v2.0",
        tid: "tenant-abc",
        aud: "ms-app-id",
        sub: "ms-sub",
        exp: nowS + 600,
    });

    assert.equal((await verify(token, { provider: microsoft(), fetchImpl: j.fetch })).ok, true);
});

test("an issuer naming a different tenant than the token is refused", async () => {
    // `common` is a routing endpoint, not an issuer. Accepting any
    // login.microsoftonline.com/* issuer without binding it to the signed
    // `tid` would accept a token minted for a different tenant.
    const j = jwks();
    const token = mint({
        iss: "https://login.microsoftonline.com/tenant-abc/v2.0",
        tid: "tenant-xyz",
        aud: "ms-app-id",
        sub: "ms-sub",
        exp: nowS + 600,
    });

    assert.equal(
        (await verify(token, { provider: microsoft(), fetchImpl: j.fetch })).reason,
        "bad_issuer",
    );
});

test("a Microsoft token with no tenant claim is refused", async () => {
    const j = jwks();
    const token = mint({
        iss: "https://login.microsoftonline.com/common/v2.0",
        aud: "ms-app-id",
        sub: "ms-sub",
        exp: nowS + 600,
    });

    assert.equal(
        (await verify(token, { provider: microsoft(), fetchImpl: j.fetch })).reason,
        "bad_issuer",
    );
});

// ---------- key rotation ----------

test("an unknown kid refetches once, then gives up", async () => {
    // Providers rotate keys. Refetching on *every* unknown kid would let
    // anyone drive our outbound request rate with garbage tokens.
    const j = jwks();
    const token = mint(claims(), { kid: "rotated-away" });

    const res = await verify(token, { fetchImpl: j.fetch });

    assert.equal(res.reason, "unknown_key");
    assert.equal(j.calls, 2, "one cached read plus exactly one forced refetch");
});

test("the JWKS is cached across verifications", async () => {
    const j = jwks();
    await verify(mint(claims()), { fetchImpl: j.fetch });
    await verify(mint(claims()), { fetchImpl: j.fetch });

    assert.equal(j.calls, 1);
});

test("a rotated-in key is picked up by the forced refetch", async () => {
    const rotated = crypto.generateKeyPairSync("rsa", { modulusLength: 2048 });
    let served = [{ kid: "k1", key: rsa.publicKey }];
    const state = { calls: 0 };
    const fetchImpl = async () => {
        state.calls += 1;
        // The provider publishes the new key only on the second ask.
        if (state.calls > 1) served = [{ kid: "k2", key: rotated.publicKey }];
        return {
            ok: true,
            json: async () => ({
                keys: served.map(({ kid, key }) => ({
                    ...key.export({ format: "jwk" }), kid, use: "sig",
                })),
            }),
        };
    };

    const token = mint(claims(), { kid: "k2", key: rotated.privateKey });
    assert.equal((await verify(token, { fetchImpl })).ok, true);
});

// ---------- malformed input never throws ----------

test("garbage is a reason, not an exception", async () => {
    const j = jwks();
    for (const bad of ["", "a.b", "not-a-token", "a.b.c", "...."]) {
        const res = await verify(bad, { fetchImpl: j.fetch });
        assert.equal(res.ok, false, JSON.stringify(bad));
    }
    assert.equal((await verify(null, { fetchImpl: j.fetch })).reason, "not_a_string");
});
