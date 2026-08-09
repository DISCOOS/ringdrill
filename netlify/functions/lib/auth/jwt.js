import crypto from "node:crypto";

/**
 * Compact JWS (RFC 7515) restricted to EdDSA/Ed25519, per ADR-0025.
 *
 * Hand-rolled rather than pulled from npm because Node 22 signs and verifies
 * Ed25519 natively (`crypto.sign(null, ...)`), and the whole surface we need is
 * one algorithm, one key type, three claims checks. A JWT library would bring a
 * multi-algorithm parser, and multi-algorithm parsers are where JWT's sharp
 * edges live — `alg: none`, HS/RS confusion, and the rest of RFC 8725's list.
 *
 * The only algorithm this module can produce or accept is `EdDSA`. A token
 * arriving with any other `alg` is rejected before its signature is examined,
 * so the confusion attacks have nothing to confuse.
 */

const ALG = "EdDSA";
const HEADER_B64 = b64u(JSON.stringify({ alg: ALG, typ: "JWT" }));

function b64u(input) {
    return Buffer.from(input).toString("base64url");
}

function fromB64u(input) {
    return Buffer.from(input, "base64url");
}

/**
 * Sign `claims` into a compact JWS. `privateKey` is a PEM Ed25519 private key
 * (what `AUTH_SIGNING_KEY_PRIVATE` holds).
 */
export function signJwt(claims, privateKey) {
    const key = crypto.createPrivateKey(privateKey);
    if (key.asymmetricKeyType !== "ed25519") {
        throw new Error(`signing key must be ed25519, got ${key.asymmetricKeyType}`);
    }
    const payload = b64u(JSON.stringify(claims));
    const signingInput = `${HEADER_B64}.${payload}`;
    // `null` algorithm is how node names "the one the key implies", which for
    // Ed25519 is PureEdDSA. Passing "sha256" here throws.
    const sig = crypto.sign(null, Buffer.from(signingInput), key);
    return `${signingInput}.${sig.toString("base64url")}`;
}

/**
 * Verify a compact JWS and return its claims.
 *
 * `publicKeys` is an array so a key rotation can accept the current and the
 * previous key at once (ADR-0025). Verification stops at the first key that
 * accepts, and a token that no key accepts is indistinguishable from a forged
 * one — which is the point.
 *
 * Returns `{ ok: true, claims }` or `{ ok: false, reason }`. Never throws for
 * malformed input: a caller handling untrusted bytes should not have to
 * distinguish "bad token" from "bug" through a try/catch.
 */
export function verifyJwt(token, publicKeys, { now = Date.now, issuer, audience } = {}) {
    if (typeof token !== "string") return fail("not_a_string");

    const parts = token.split(".");
    if (parts.length !== 3) return fail("malformed");
    const [headerB64, payloadB64, sigB64] = parts;

    let header;
    try {
        header = JSON.parse(fromB64u(headerB64).toString("utf8"));
    } catch {
        return fail("bad_header");
    }
    // Checked before the signature, so `alg: none` and algorithm-confusion
    // tokens are refused on shape rather than on a verification result.
    if (!header || header.alg !== ALG) return fail("bad_alg");

    const signingInput = Buffer.from(`${headerB64}.${payloadB64}`);
    let sig;
    try {
        sig = fromB64u(sigB64);
    } catch {
        return fail("bad_signature_encoding");
    }

    const keys = Array.isArray(publicKeys) ? publicKeys : [publicKeys];
    const accepted = keys.some((pem) => {
        if (!pem) return false;
        try {
            return crypto.verify(null, signingInput, crypto.createPublicKey(pem), sig);
        } catch {
            // A malformed key in the list must not mask a good one after it.
            return false;
        }
    });
    if (!accepted) return fail("bad_signature");

    let claims;
    try {
        claims = JSON.parse(fromB64u(payloadB64).toString("utf8"));
    } catch {
        return fail("bad_payload");
    }
    if (!claims || typeof claims !== "object") return fail("bad_payload");

    if (issuer && claims.iss !== issuer) return fail("bad_iss");
    if (audience && claims.aud !== audience) return fail("bad_aud");

    // exp is required. A token without one never expires, which for an access
    // token is a bug rather than a feature.
    if (!Number.isFinite(claims.exp)) return fail("missing_exp");
    if (claims.exp * 1000 <= now()) return fail("expired");

    return { ok: true, claims };
}

function fail(reason) {
    return { ok: false, reason };
}

/** Generate an Ed25519 keypair as PEM, for tests and for `make` key setup. */
export function generateKeypair() {
    const { publicKey, privateKey } = crypto.generateKeyPairSync("ed25519");
    return {
        publicKey: publicKey.export({ type: "spki", format: "pem" }),
        privateKey: privateKey.export({ type: "pkcs8", format: "pem" }),
    };
}
