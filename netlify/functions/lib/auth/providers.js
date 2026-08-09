import crypto from "node:crypto";

/**
 * Third-party identity providers: who they are, and how to believe them.
 *
 * **Separate from `jwt.js` on purpose.** That module is EdDSA-only and says so
 * loudly — one algorithm, so the confusion attacks have nothing to confuse.
 * Provider tokens are RS256 or ES256, and teaching `jwt.js` to accept those
 * would hand our own token verifier a multi-algorithm parser it does not need.
 * The two stay apart: our tokens are Ed25519 and nothing else, theirs are
 * RSA/EC and nothing else.
 *
 * **No client secret is ever readable from a client.** Everything here runs
 * server-side; the app receives an authorize URL and, later, a session. The
 * ids and secrets live in env vars and never enter a build.
 */

/** The only signature algorithms an external id_token may use. */
const ALLOWED_ALGS = new Set(["RS256", "ES256"]);

/** How long a fetched JWKS is reused before it is refetched. */
const JWKS_TTL_MS = 60 * 60 * 1000;

/** Tolerance for clock skew between us and a provider. */
const SKEW_S = 120;

/**
 * A provider's fixed facts. Client ids and secrets are *not* here — those come
 * from the environment, which is what makes a provider addable without a
 * deploy of anything but config.
 */
const PROVIDERS = Object.freeze({
    google: {
        id: "google",
        label: "Google",
        authorizeUrl: "https://accounts.google.com/o/oauth2/v2/auth",
        tokenUrl: "https://oauth2.googleapis.com/token",
        jwksUrl: "https://www.googleapis.com/oauth2/v3/certs",
        scope: "openid email profile",
        // Google has emitted both spellings historically and both are valid.
        issuers: ["https://accounts.google.com", "accounts.google.com"],
    },
    apple: {
        id: "apple",
        label: "Apple",
        authorizeUrl: "https://appleid.apple.com/auth/authorize",
        tokenUrl: "https://appleid.apple.com/auth/token",
        jwksUrl: "https://appleid.apple.com/auth/keys",
        scope: "name email",
        issuers: ["https://appleid.apple.com"],
        // Apple only returns name/email in the *form post* of the first
        // authorization, and only when these scopes are requested.
        responseMode: "form_post",
    },
    microsoft: {
        id: "microsoft",
        label: "Microsoft",
        authorizeUrl: "https://login.microsoftonline.com/common/oauth2/v2.0/authorize",
        tokenUrl: "https://login.microsoftonline.com/common/oauth2/v2.0/token",
        jwksUrl: "https://login.microsoftonline.com/common/discovery/v2.0/keys",
        scope: "openid email profile",
        // **Multi-tenant issuers are per-tenant.** `common` is a routing
        // endpoint, not an issuer: a real token says
        // `https://login.microsoftonline.com/<tid>/v2.0`, where `<tid>` is the
        // tenant. So neither an exact match nor skipping the check is right —
        // the issuer is verified against the token's own `tid`, which is
        // itself covered by the signature. See `issuerMatches`.
        tenantIssuer: true,
    },
});

export const PROVIDER_IDS = Object.freeze(Object.keys(PROVIDERS));

/**
 * Which providers are usable, from the environment.
 *
 * A provider with no client id is simply absent — not disabled, not broken,
 * absent. That is what lets the app ask at runtime instead of shipping a build
 * that believes in a provider nobody configured.
 */
export function configuredProviders(env = process.env) {
    const out = [];
    for (const id of PROVIDER_IDS) {
        const clientId = env[`OAUTH_${id.toUpperCase()}_CLIENT_ID`];
        if (!clientId) continue;
        out.push({
            ...PROVIDERS[id],
            clientId,
            clientSecret: env[`OAUTH_${id.toUpperCase()}_CLIENT_SECRET`] ?? null,
            // Apple issues no static secret: the token endpoint expects a
            // short-lived JWT signed with a key you download once. Carried
            // here so `oauth.js` can mint one per exchange.
            appleKey: id === "apple" && env.OAUTH_APPLE_PRIVATE_KEY
                ? {
                    teamId: env.OAUTH_APPLE_TEAM_ID,
                    keyId: env.OAUTH_APPLE_KEY_ID,
                    privateKey: env.OAUTH_APPLE_PRIVATE_KEY,
                }
                : null,
            // Extra audiences a token may legitimately carry — a native Apple
            // sign-in presents the bundle id, not the web Service ID.
            extraAudiences: (env[`OAUTH_${id.toUpperCase()}_AUDIENCES`] ?? "")
                .split(",").map((s) => s.trim()).filter(Boolean),
        });
    }
    return out;
}

export function providerConfig(id, env = process.env) {
    return configuredProviders(env).find((p) => p.id === id) ?? null;
}

/* ---------- JWKS ---------- */

/**
 * Cached keys per JWKS URL.
 *
 * Module-level and therefore per-instance: a warm Netlify function reuses it, a
 * cold one refetches. That is the right trade — the alternative is a blob round
 * trip on a path that already has one to the provider.
 */
const jwksCache = new Map();

/**
 * Public keys for [url], by `kid`.
 *
 * `force` bypasses the cache, for the one case that matters: a token arrives
 * signed with a key we have never seen because the provider rotated. Refetching
 * then is correct; refetching on *every* unknown kid would let anyone drive our
 * outbound request rate by sending garbage, so the caller refetches at most
 * once per verification and only after the cache has been consulted.
 */
export async function fetchJwks(url, { force = false, now = Date.now, fetchImpl = fetch } = {}) {
    const hit = jwksCache.get(url);
    if (!force && hit && hit.expiresAt > now()) return hit.keys;

    const res = await fetchImpl(url, { headers: { accept: "application/json" } });
    if (!res.ok) throw new Error(`jwks_fetch_failed:${res.status}`);
    const body = await res.json();

    const keys = new Map();
    for (const jwk of body?.keys ?? []) {
        if (!jwk.kid) continue;
        // Only the algorithms we accept, decided here rather than trusting the
        // token's own header to pick.
        if (jwk.alg && !ALLOWED_ALGS.has(jwk.alg)) continue;
        try {
            keys.set(jwk.kid, crypto.createPublicKey({ key: jwk, format: "jwk" }));
        } catch {
            // A key we cannot import is a key we cannot verify with. Skipping
            // it is better than failing the whole set, which would take the
            // working keys down with it.
        }
    }
    jwksCache.set(url, { keys, expiresAt: now() + JWKS_TTL_MS });
    return keys;
}

/** Drop cached keys. Tests use it; nothing in production should need it. */
export function resetJwksCache() {
    jwksCache.clear();
}

/* ---------- verification ---------- */

function decodeSegment(segment) {
    return JSON.parse(Buffer.from(segment, "base64url").toString("utf8"));
}

const fail = (reason) => ({ ok: false, reason });

/**
 * Is `iss` acceptable for this provider?
 *
 * For most providers this is set membership. For a multi-tenant Microsoft app
 * the issuer names the tenant, so it is checked against the token's own `tid` —
 * which sounds circular and is not: `tid` is inside the signed payload, so an
 * attacker cannot choose it without a valid signature, and the check is really
 * "this token's issuer is the one its own tenant claim implies". Accepting any
 * `login.microsoftonline.com/*` issuer without that binding would accept a
 * token minted for a different tenant.
 */
function issuerMatches(provider, claims) {
    if (provider.tenantIssuer) {
        const tid = claims.tid;
        if (typeof tid !== "string" || !tid) return false;
        return claims.iss === `https://login.microsoftonline.com/${tid}/v2.0`;
    }
    return (provider.issuers ?? []).includes(claims.iss);
}

/**
 * Verify a provider `id_token` and return the identity it asserts.
 *
 * Returns `{ ok: true, identity }` or `{ ok: false, reason }`, and never throws
 * for malformed input — a caller handling untrusted bytes should not have to
 * tell "bad token" from "bug" through a try/catch.
 *
 * The checks, in the order they matter:
 *
 * 1. **Algorithm allowlist before anything else.** `none` and the HS/RS
 *    confusion family are refused before a signature is examined.
 * 2. **Signature**, against the provider's published key for this `kid`.
 * 3. **Issuer**, exactly — see [issuerMatches].
 * 4. **Audience** must be one of *our* client ids. Without this, a token minted
 *    for any other Google application would sign somebody in here.
 * 5. **Expiry**, with a small skew allowance.
 * 6. **Nonce**, when one was requested. This is what binds the token to the
 *    authorize request we started, and is why a replayed token from elsewhere
 *    does not work.
 */
export async function verifyIdToken(token, provider, {
    now = Date.now,
    nonce = null,
    fetchImpl = fetch,
} = {}) {
    if (typeof token !== "string") return fail("not_a_string");
    const parts = token.split(".");
    if (parts.length !== 3) return fail("malformed");

    let header;
    let claims;
    try {
        header = decodeSegment(parts[0]);
        claims = decodeSegment(parts[1]);
    } catch {
        return fail("malformed");
    }

    if (!ALLOWED_ALGS.has(header?.alg)) return fail("bad_alg");
    if (!header?.kid) return fail("no_kid");

    let keys = await fetchJwks(provider.jwksUrl, { now, fetchImpl });
    let key = keys.get(header.kid);
    if (!key) {
        // Unknown kid: the provider may have rotated. One refetch, then give up.
        keys = await fetchJwks(provider.jwksUrl, { force: true, now, fetchImpl });
        key = keys.get(header.kid);
    }
    if (!key) return fail("unknown_key");

    const signingInput = Buffer.from(`${parts[0]}.${parts[1]}`);
    const signature = Buffer.from(parts[2], "base64url");
    const algo = header.alg === "ES256"
        ? { dsaEncoding: "ieee-p1363", key }
        : key;
    let signatureOk = false;
    try {
        signatureOk = crypto.verify("sha256", signingInput, algo, signature);
    } catch {
        signatureOk = false;
    }
    if (!signatureOk) return fail("bad_signature");

    if (!issuerMatches(provider, claims)) return fail("bad_issuer");

    const audiences = new Set([provider.clientId, ...(provider.extraAudiences ?? [])]);
    const aud = Array.isArray(claims.aud) ? claims.aud : [claims.aud];
    if (!aud.some((a) => audiences.has(a))) return fail("bad_audience");

    const nowS = Math.floor(now() / 1000);
    if (typeof claims.exp !== "number" || claims.exp + SKEW_S < nowS) return fail("expired");
    if (typeof claims.iat === "number" && claims.iat - SKEW_S > nowS) return fail("issued_in_future");

    if (nonce != null && claims.nonce !== nonce) return fail("bad_nonce");

    if (!claims.sub) return fail("no_subject");

    return {
        ok: true,
        identity: {
            provider: provider.id,
            subject: String(claims.sub),
            email: typeof claims.email === "string" ? claims.email : null,
            // **Only a verified address may link accounts.** An unverified one
            // would let somebody claim an address they do not control and be
            // merged into the existing user who does (ADR-0024 step 2).
            // Google sends a boolean, Apple sends the string "true".
            emailVerified: claims.email_verified === true
                || claims.email_verified === "true",
            displayName: typeof claims.name === "string" ? claims.name : null,
        },
    };
}
