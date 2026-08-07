import { verifyJwt } from "./jwt.js";
import { ANONYMOUS, bearerToken, principalFromClaims, refuse } from "./principal.js";

/**
 * The production auth adapter: a signed Ed25519 JWT, verified against the
 * public key(s) in the environment (ADR-0025, ADR-0073).
 */

export const ISSUER = "ringdrill.app";
export const AUDIENCE = "ringdrill-api";

/**
 * Guard 1 of the two in ADR-0073.
 *
 * A `test.` token is what the `mock` adapter mints, and this path refuses the
 * *format* before it ever reaches signature verification — unconditionally, on
 * every deploy, regardless of `AUTH_MODE`. So a misconfiguration cannot make a
 * forged principal work: even if somebody manages to get mock tokens in front
 * of the live adapter, the live adapter does not know how to say yes to them.
 *
 * Guard 2 lives in mock.js, which refuses to load in production at all. Two
 * independent guards because one is not enough for a credential-shaped thing:
 * this one fails safe if the deploy context is wrong, that one fails safe if
 * the mode is wrong.
 */
export const TEST_TOKEN_PREFIX = "test.";

export function createLiveAdapter({ env = process.env, now = Date.now } = {}) {
    const publicKeys = [
        env.AUTH_SIGNING_KEY_PUBLIC,
        // Accepted during a rotation window so tokens minted with the outgoing
        // key keep working until they expire (ADR-0025). Clients never see it.
        env.AUTH_SIGNING_KEY_PUBLIC_PREVIOUS,
    ].filter(Boolean);

    return {
        mode: "live",

        async authenticate(request) {
            const token = bearerToken(request);
            if (!token) return ANONYMOUS;

            if (token.startsWith(TEST_TOKEN_PREFIX)) return refuse(401, "test_token_refused");

            if (publicKeys.length === 0) {
                // Refusing is the only safe answer: with no key we cannot tell a
                // real token from a forged one, and treating the request as
                // anonymous would silently downgrade every authenticated call.
                return refuse(401, "no_verification_key");
            }

            const verified = verifyJwt(token, publicKeys, { now, issuer: ISSUER, audience: AUDIENCE });
            if (!verified.ok) return refuse(401, verified.reason);

            return principalFromClaims(verified.claims, request);
        },
    };
}
