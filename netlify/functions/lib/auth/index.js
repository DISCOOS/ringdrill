import { createLiveAdapter } from "./live.js";
import { createOffAdapter } from "./off.js";
import { refuse } from "./principal.js";

export { ANONYMOUS, bearerToken, hasRole, isMemberOf, refuse } from "./principal.js";
export { signJwt, verifyJwt, generateKeypair } from "./jwt.js";
export { ISSUER, AUDIENCE } from "./live.js";

/**
 * `AUTH_MODE` selects the auth backend (ADR-0073). It is a deployment mode, not
 * a feature flag: dev and CI need to exercise the real authorisation matrix
 * with no mail provider and no signing key, and that need outlives the account
 * rollout entirely.
 *
 *   live  (default when unset)  signed Ed25519 JWT           production
 *   mock                        `test.<claims>` tokens       netlify dev, CI
 *   off                         everything anonymous         rollback, regression
 *
 * Unset means `live`, so a deploy that configures nothing gets production
 * semantics and a misconfiguration fails closed rather than open.
 */
export const AUTH_MODES = Object.freeze({ LIVE: "live", MOCK: "mock", OFF: "off" });

/**
 * An unrecognised value falls back to `live` and complains loudly rather than
 * throwing.
 *
 * Falling back is the safe direction — `live` is the mode that verifies — and
 * throwing would turn one typo'd env var into a site-wide outage. But it must
 * be loud: silently treating `AUTH_MODE=mokc` as `live` in a dev environment
 * produces a mystifying "why is nothing authenticating" hunt, which is exactly
 * the failure ADR-0073 called out when it chose a string over a boolean.
 */
export function resolveMode(env = process.env, { warn = console.error } = {}) {
    const raw = String(env.AUTH_MODE ?? "").trim().toLowerCase();
    if (!raw) return AUTH_MODES.LIVE;
    if (raw === AUTH_MODES.LIVE || raw === AUTH_MODES.MOCK || raw === AUTH_MODES.OFF) return raw;
    warn(
        `[auth] Unknown AUTH_MODE ${JSON.stringify(raw)} — expected ` +
        `"live", "mock" or "off". Falling back to "live", so nothing will ` +
        `authenticate unless a signing key is configured.`,
    );
    return AUTH_MODES.LIVE;
}

/**
 * Resolve the adapter for `mode`.
 *
 * `mock` is loaded with a dynamic import on purpose. Its module throws at load
 * when `CONTEXT=production` (ADR-0073's second guard), and a static import here
 * would fire that in production even on a `live` deploy — turning a safety
 * device into an outage. Imported only when actually selected, the guard fires
 * exactly when someone asks for mock in production, which is the case it exists
 * for.
 */
export async function createAdapter({ env = process.env, now = Date.now, warn } = {}) {
    const mode = resolveMode(env, warn ? { warn } : undefined);
    switch (mode) {
        case AUTH_MODES.OFF:
            return createOffAdapter();
        case AUTH_MODES.MOCK: {
            const { createMockAdapter } = await import("./mock.js");
            return createMockAdapter({ env, now });
        }
        default:
            return createLiveAdapter({ env, now });
    }
}

// One adapter per container. Adapters hold no per-request state — unlike the
// Netlify Blobs Store, whose access token expires (see the warning in
// lib/shared.js), there is nothing here that goes stale — so resolving once is
// safe and keeps the dynamic import off the hot path.
let _cached = null;

/**
 * Classify a request as anonymous, authenticated, or refused.
 *
 * Returns, never throws (see principal.js for the shapes). Pass `adapter` to
 * bypass the cache in tests.
 */
export async function authenticate(request, { adapter, env, now, warn } = {}) {
    try {
        const a = adapter ?? (_cached ??= await createAdapter({ env, now, warn }));
        return await a.authenticate(request);
    } catch (err) {
        // An adapter that fails to construct or throws mid-check must not be
        // read as "anonymous, carry on" — that would turn a broken auth
        // backend into an open door. Refuse instead.
        console.error("[auth] adapter failure", err);
        return refuse(401, "adapter_error");
    }
}

/** Test seam: drop the memoized adapter so the next call re-resolves. */
export function resetAdapterCache() {
    _cached = null;
}

/** Turn a refusal into an HTTP response. */
export function refusalResponse(result) {
    const status = result?.status === 403 ? 403 : 401;
    return new Response(JSON.stringify({ error: result?.reason || "unauthorized" }), {
        status,
        headers: { "content-type": "application/json" },
    });
}
