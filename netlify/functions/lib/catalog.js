import { DRILL_EXT, getSlugIndexStore, getSlugIndexStoreStrong } from "./shared.js";
import { newId, normalizeHandle, resolveHandle } from "./identity.js";

/**
 * Catalog entry identity and storage keys (ADR-0074).
 *
 * A catalog entry is a distinct object from the plan an account holds: its own
 * key, its own lifecycle, its own identity `(namespace, slug)`. This module owns
 * all three, and the dual-read fallback that lets the migration run with the
 * site live.
 */

export const ANON_NAMESPACE = "anon";

/* ---------- keys ---------- */

/**
 * Blob keys for a catalog entry.
 *
 * **The key contains neither the owning account nor its handle**, and that is
 * the point (ADR-0074 §4). With the account in the path, "delete the account"
 * must remember *not* to sweep `drills/<accountId>/*` — an exception that reads
 * like correct code in review. With the handle in the path, every rename would
 * move every blob. An opaque entry id makes both impossible rather than
 * forbidden.
 */
export function catalogKeysFor(entryId, version = "_") {
    return {
        versioned: `catalog/${entryId}/${version}${DRILL_EXT}`,
        latest: `catalog/${entryId}/latest${DRILL_EXT}`,
        meta: `catalog/${entryId}/meta.json`,
        prefix: `catalog/${entryId}/`,
    };
}

export function newEntryId() {
    return newId("e");
}

export function slugIndexKey(namespace, slug) {
    return `${namespace}/${slug}`;
}

/**
 * The namespace a slug is *stored* under.
 *
 * The stored namespace is the **account id**, not the handle — a deliberate
 * refinement of ADR-0074's wording, which says "an account handle, or the
 * reserved anon". Storing the id keeps the index stable across a handle rename,
 * so a rename rewrites nothing at all rather than re-keying every slug the
 * account has published. The handle is what a *URL* shows; `resolveNamespace`
 * maps one to the other on read.
 */
export function storedNamespaceFor(accountId) {
    return accountId && accountId !== ANON_NAMESPACE ? accountId : ANON_NAMESPACE;
}

/* ---------- URL parsing ---------- */

/**
 * Parse the tail of `/d/…` or `/i/…` into `{ namespace, slug, version }`.
 *
 * One segment means `anon`; two means namespaced. Nothing else is possible,
 * because `sanitizeSlug` strips everything outside `[a-z0-9-]` so a slug can
 * never contain a `/` — segment count disambiguates on its own, which is why
 * there is no sigil (an earlier draft of ADR-0074 had `@`, and `@` was already
 * the version separator in this very route).
 *
 *   lsor-eidene-2026                    → anon, latest
 *   lsor-eidene-2026@5                  → anon, version 5
 *   redcross-bergen/lsor-eidene-2026    → namespaced, latest
 *   redcross-bergen/lsor-eidene-2026@5  → namespaced, version 5
 */
export function parseCatalogPath(tail) {
    const clean = String(tail ?? "").replace(/^\/+|\/+$/g, "").replace(/\.drill$/i, "");
    if (!clean) return null;

    const parts = clean.split("/");
    if (parts.length > 2) return null;

    const [rawNamespace, rawSlug] = parts.length === 2 ? parts : [null, parts[0]];
    const m = String(rawSlug).match(/^([^@/]+)(?:@([^/]+))?$/);
    if (!m) return null;

    return {
        namespace: rawNamespace ? normalizeHandle(rawNamespace) : ANON_NAMESPACE,
        slug: m[1],
        version: m[2] ?? null,
        explicitNamespace: parts.length === 2,
    };
}

/** The public path for an entry, omitting `anon` so existing links keep their shape. */
export function catalogPathFor({ namespace, slug, version = null }) {
    const ns = namespace && namespace !== ANON_NAMESPACE ? `${namespace}/` : "";
    return `/d/${ns}${slug}${version ? `@${version}` : ""}`;
}

/* ---------- resolution ---------- */

/**
 * Turn a URL namespace into the stored one.
 *
 * A URL may carry either a handle (`redcross-bergen`) or an account id
 * (`a_x7k2…`), and both resolve to the same entry. A tombstoned handle still
 * resolves — that is what makes a rename non-breaking for links already shared
 * (ADR-0074 §2) — and reports the current handle so a caller can redirect.
 */
export async function resolveNamespace(urlNamespace, { stores } = {}) {
    const ns = normalizeHandle(urlNamespace);
    if (!ns || ns === ANON_NAMESPACE) return { namespace: ANON_NAMESPACE, canonical: ANON_NAMESPACE };

    const handle = await resolveHandle(ns, stores).catch(() => null);
    if (handle?.accountId) {
        return {
            namespace: handle.accountId,
            canonical: handle.tombstone ? handle.redirectsTo : ns,
            movedFrom: handle.tombstone ? ns : null,
        };
    }
    // Not a known handle — treat it as an account id. An account that has not
    // claimed a handle still needs a working URL.
    return { namespace: ns, canonical: ns };
}

/**
 * Find a catalog entry by `(namespace, slug)`.
 *
 * **Dual-read**, and this is what lets the migration run with the site live:
 * the new key is tried first, then the pre-migration flat `slug-index/<slug>`.
 * A record without an `entryId` is a pre-migration one, and the caller reads
 * its blobs from the old `drills/<ownerId>/<planId>/` layout via `legacy`.
 *
 * Delete this fallback once the migration has run and been verified — the
 * cleanup phase is what makes it safe to.
 */
export async function findEntry({ namespace, slug }, { strong = false, store } = {}) {
    const idx = store ?? (strong ? getSlugIndexStoreStrong() : getSlugIndexStore());

    const namespaced = await idx.get(slugIndexKey(namespace, slug), { type: "json" });
    if (namespaced) return { ...namespaced, namespace, slug, legacy: !namespaced.entryId };

    // Pre-migration records live at the bare slug and are all `anon`, since
    // nothing could be account-owned before namespaces existed.
    if (namespace === ANON_NAMESPACE) {
        const flat = await idx.get(slug, { type: "json" });
        if (flat) return { ...flat, namespace: ANON_NAMESPACE, slug, legacy: !flat.entryId };
    }
    return null;
}

/**
 * Blob keys for a record from `findEntry`, in whichever layout it is in.
 *
 * Callers should never branch on the layout themselves — that is how one read
 * path gets migrated and another does not.
 */
export function keysForEntry(record, version = "_") {
    if (record?.entryId) return catalogKeysFor(record.entryId, version);
    // Pre-migration: the old owner-scoped layout.
    const owner = record?.ownerId ?? ANON_NAMESPACE;
    const plan = record?.programId ?? record?.planId;
    return {
        versioned: `drills/${owner}/${plan}/${version}${DRILL_EXT}`,
        latest: `drills/${owner}/${plan}/latest${DRILL_EXT}`,
        meta: `drills/${owner}/${plan}/meta.json`,
        prefix: `drills/${owner}/${plan}/`,
    };
}

/**
 * Claim `(namespace, slug)` for a new entry, atomically.
 *
 * `onlyIfNew` rather than read-then-write: two people publishing the same name
 * in the same namespace in the same second must not both win, and a strong read
 * followed by a write still leaves the window open.
 */
export async function claimEntry({ namespace, slug, planId, ownerAccountId }, { store, now = () => new Date().toISOString() } = {}) {
    const idx = store ?? getSlugIndexStore();
    const entryId = newEntryId();
    const record = { entryId, planId, programId: planId, ownerId: ownerAccountId, ownerAccountId, namespace, slug, createdAt: now() };
    const { modified } = await idx.set(slugIndexKey(namespace, slug), JSON.stringify(record), { onlyIfNew: true });
    return modified ? { ok: true, record } : { ok: false, reason: "taken" };
}
