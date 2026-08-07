import { ANONYMOUS, bearerToken, principalFromClaims, refuse } from "./principal.js";

/**
 * The dev and test auth adapter (ADR-0073).
 *
 * It replaces exactly one thing: signature verification. A `test.` token
 * carries its claims in the clear instead of being verified against a public
 * key, so a test can mint a `guest` on one account and an `owner` on another in
 * one line, with no sign-up and no seeded identity graph.
 *
 * **Everything else is the live path.** The same endpoints, the same principal
 * shape, the same ADR-0025 authorisation matrix downstream. A `guest` is
 * refused on an `account`-policy slug here for exactly the reason it is refused
 * in production, through the same code — which is the entire argument for an
 * adapter rather than an `if (isDev)` branch.
 */

export const TEST_TOKEN_PREFIX = "test.";

/**
 * Guard 2 of the two in ADR-0073, and the reason this is a module-level
 * side effect rather than a check inside `authenticate`.
 *
 * An adapter that mints principals from unsigned input is a total authorisation
 * bypass. It must be impossible to reach from production **even by someone
 * actively configuring it that way**, so the refusal is at load: the function
 * fails to start rather than starting and serving forged principals. A
 * per-request check would leave a window between deploy and first request in
 * which everything looks healthy.
 *
 * `CONTEXT` is set by Netlify on every deploy (`production`, `deploy-preview`,
 * `branch-deploy`). Guard 1 lives in live.js.
 */
export function assertNotProduction(env = process.env) {
    if (env.CONTEXT === "production") {
        throw new Error(
            "AUTH_MODE=mock refused: the mock auth adapter mints principals from " +
            "unsigned tokens and must never load in a production deploy. " +
            "Unset AUTH_MODE (defaults to live) or set AUTH_MODE=live.",
        );
    }
}

assertNotProduction();

/** Mint a token for tests. Claims match the live JWT's, minus the signature. */
export function mintTestToken(claims) {
    return TEST_TOKEN_PREFIX + Buffer.from(JSON.stringify(claims)).toString("base64url");
}

export function createMockAdapter({ env = process.env, now = Date.now } = {}) {
    assertNotProduction(env);

    return {
        mode: "mock",

        async authenticate(request) {
            const token = bearerToken(request);
            if (!token) return ANONYMOUS;

            // Only the test format is understood. A real signed JWT presented to
            // the mock adapter is refused rather than half-parsed, so a
            // misconfigured client fails loudly instead of behaving subtly
            // differently in dev than it will in production.
            if (!token.startsWith(TEST_TOKEN_PREFIX)) return refuse(401, "expected_test_token");

            let claims;
            try {
                claims = JSON.parse(
                    Buffer.from(token.slice(TEST_TOKEN_PREFIX.length), "base64url").toString("utf8"),
                );
            } catch {
                return refuse(401, "malformed_test_token");
            }
            if (!claims || typeof claims !== "object") return refuse(401, "malformed_test_token");

            // Expiry is honoured when present so a test can exercise the expired
            // path, but is not required — most tests should not have to think
            // about clocks to get a principal.
            if (Number.isFinite(claims.exp) && claims.exp * 1000 <= now()) {
                return refuse(401, "expired");
            }

            return principalFromClaims(claims, request);
        },
    };
}
