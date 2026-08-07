/**
 * ADR-0025's authorisation matrix for catalog writes, as a pure decision.
 *
 * Kept out of the handler on purpose: the matrix is the part with security
 * consequences and the part worth exhaustive tests, while the handler around it
 * is plumbing. A pure function also means the same decision can be exercised
 * under `AUTH_MODE=mock` in CI (ADR-0073) without standing up blob storage.
 *
 * Returns the decision *and* what to write, so the caller does not re-derive
 * ownership and policy and get a different answer than the one authorised.
 */

export const ACCESS_POLICIES = Object.freeze({
    ACCOUNT: "account", SHARED: "shared", PUBLIC: "public",
});

export const ANON_OWNER = "anon";

/**
 * Read a plan's policy from its stored meta, tolerating everything older.
 *
 * Absent reads as `public`, matching the wiki-model reality of every plan
 * published before accounts existed. The serialized name `wiki` is accepted as
 * an alias for one release (ADR-0025), because the rename happened after those
 * blobs were written and they are not going to rewrite themselves.
 */
export function readAccessPolicy(meta) {
    const raw = meta?.accessPolicy;
    if (raw === "wiki") return ACCESS_POLICIES.PUBLIC;
    if (raw === ACCESS_POLICIES.ACCOUNT || raw === ACCESS_POLICIES.SHARED || raw === ACCESS_POLICIES.PUBLIC) {
        return raw;
    }
    return meta?.ownerId && meta.ownerId !== ANON_OWNER ? ACCESS_POLICIES.ACCOUNT : ACCESS_POLICIES.PUBLIC;
}

function sharedAccountIds(meta) {
    const ids = meta?.sharedAccountIds;
    return Array.isArray(ids) ? ids.filter((s) => typeof s === "string") : [];
}

function isMember(principal, accountId) {
    if (!principal || principal.anonymous || !accountId) return false;
    return Array.isArray(principal.accounts) && principal.accounts.includes(accountId);
}

function deny(status, reason) {
    return { ok: false, status, reason };
}

/**
 * Decide whether this principal may write this slug, and under what ownership.
 *
 * `existing` is the slug-index record (null for a new slug) and `meta` is the
 * plan's stored meta.json (null for a new slug).
 */
export function authorizeCatalogWrite({ principal, existing, meta }) {
    const authenticated = !!principal && principal.ok !== false && !principal.anonymous;

    // ---- New slug ----
    if (!existing) {
        if (!authenticated) {
            // **Anonymous publishing survives enforcement** (ADR-0025, amended
            // 2026-08-05). Without this, turning enforcement on would break
            // every app that has not been updated yet — and during an App Store
            // review window, that is every phone in the field. Signing in buys
            // protection; it is not the price of publishing.
            return { ok: true, ownerId: ANON_OWNER, accessPolicy: ACCESS_POLICIES.PUBLIC, claimed: true };
        }
        if (!principal.accountId) return deny(403, "no_active_account");
        return { ok: true, ownerId: principal.accountId, accessPolicy: ACCESS_POLICIES.ACCOUNT, claimed: true };
    }

    // ---- Existing slug ----
    const owner = existing.ownerId ?? meta?.ownerId ?? ANON_OWNER;
    const policy = readAccessPolicy(meta ?? { ownerId: owner });

    if (policy === ACCESS_POLICIES.PUBLIC) {
        // The wiki model, kept as a first-class option rather than a
        // compatibility crutch: anyone holding the file may publish.
        return { ok: true, ownerId: owner, accessPolicy: policy, claimed: false };
    }

    if (!authenticated) return deny(401, "authentication_required");

    if (policy === ACCESS_POLICIES.ACCOUNT) {
        // Any member, at any role. A guest publishes exactly like an owner —
        // what guest withholds is the staff roster, not the ability to work
        // (ADR-0024, amended 2026-08-05).
        if (!isMember(principal, owner)) return deny(403, "not_a_member");
        return { ok: true, ownerId: owner, accessPolicy: policy, claimed: false };
    }

    if (policy === ACCESS_POLICIES.SHARED) {
        const grantees = sharedAccountIds(meta);
        const allowed = isMember(principal, owner) || grantees.some((id) => isMember(principal, id));
        if (!allowed) return deny(403, "not_a_member");
        return { ok: true, ownerId: owner, accessPolicy: policy, claimed: false };
    }

    return deny(403, "unknown_policy");
}

/**
 * Who may change a plan's access policy: an `owner` of the owning account, and
 * nobody else.
 *
 * This is the one catalog operation where role rank matters. Publishing follows
 * from membership; deciding *who else* may publish is administration, which is
 * what `owner` means (ADR-0024, amended 2026-08-05).
 */
export function authorizePolicyChange({ principal, existing, meta }) {
    if (!existing) return deny(404, "unknown_slug");
    const authenticated = !!principal && principal.ok !== false && !principal.anonymous;
    if (!authenticated) return deny(401, "authentication_required");

    const owner = existing.ownerId ?? meta?.ownerId ?? ANON_OWNER;
    if (owner === ANON_OWNER) {
        // An anon plan has no owner to be, and none can be claimed: ADR-0025
        // chose fork-to-leave over in-place adoption, so there is deliberately
        // no path from anon to owned.
        return deny(403, "anon_plan_has_no_owner");
    }
    if (!isMember(principal, owner)) return deny(403, "not_a_member");
    if (principal.roles?.[owner] !== "owner") return deny(403, "owner_role_required");
    return { ok: true, ownerId: owner };
}
