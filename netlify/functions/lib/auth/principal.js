/**
 * The shape every auth adapter returns, and the claims → principal step the
 * `live` and `mock` adapters share (ADR-0073: same contract in every mode).
 *
 * A result is one of three things, and callers branch on `ok` then `anonymous`:
 *
 *   { ok: true,  anonymous: true  }                        no credential offered
 *   { ok: true,  anonymous: false, userId, accountId, … }  a principal
 *   { ok: false, status: 401 | 403, reason }               refused
 *
 * Refusals are returned rather than thrown. A handler processing untrusted
 * input should not need a try/catch to tell "bad token" from "bug", and an
 * exception thrown across the adapter seam would be indistinguishable from an
 * adapter crash — which is the one case that must never be treated as
 * "anonymous, carry on".
 */

export const ANONYMOUS = Object.freeze({ ok: true, anonymous: true });

export function refuse(status, reason) {
    return { ok: false, status, reason };
}

/** The `Authorization: Bearer <token>` value, or null when absent. */
export function bearerToken(request) {
    const raw = request?.headers?.get?.("authorization") || "";
    const m = raw.match(/^Bearer\s+(.+)$/i);
    return m ? m[1].trim() : null;
}

/**
 * Turn verified claims into a principal, resolving which account is active.
 *
 * `X-Active-Account` lets a client switch account without re-minting a token
 * (ADR-0025), so the header wins over the `act` claim — but only for an account
 * the token already vouches for. A header naming an account outside `acts` is a
 * 403 and not a silent fallback to `act`: quietly serving a different account
 * than the one asked for is how a client ends up publishing to the wrong place
 * and being told it succeeded.
 */
export function principalFromClaims(claims, request) {
    const userId = claims?.sub;
    if (!userId || typeof userId !== "string") return refuse(401, "missing_sub");

    const accounts = Array.isArray(claims.acts) ? claims.acts.filter((a) => typeof a === "string") : [];
    const roles = (claims.roles && typeof claims.roles === "object") ? claims.roles : {};

    const requested = request?.headers?.get?.("x-active-account")?.trim() || null;
    const accountId = requested || claims.act || null;

    if (accountId) {
        if (!accounts.includes(accountId)) return refuse(403, "account_not_in_token");
    }

    return {
        ok: true,
        anonymous: false,
        userId,
        accountId,
        role: accountId ? (roles[accountId] ?? null) : null,
        accounts,
        roles,
    };
}

/**
 * Whether `principal` holds `role` (or better) on `accountId`.
 *
 * The ordering is owner > member > guest for *administration* only. It says
 * nothing about publishing, which every member may do (ADR-0024, amended
 * 2026-08-05), so callers asking "may this person publish" should ask
 * `isMemberOf` instead of reaching for a rank.
 */
const RANK = Object.freeze({ owner: 3, member: 2, guest: 1 });

export function isMemberOf(principal, accountId) {
    if (!principal?.ok || principal.anonymous || !accountId) return false;
    return principal.accounts.includes(accountId);
}

export function hasRole(principal, accountId, minimum) {
    if (!isMemberOf(principal, accountId)) return false;
    const held = RANK[principal.roles[accountId]] ?? 0;
    const needed = RANK[minimum] ?? Number.POSITIVE_INFINITY;
    return held >= needed;
}
