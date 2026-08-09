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

/**
 * Which entry an upload of `slug` is targeting, and where a new one would land.
 *
 * **Lookup falls back to `anon`; claiming does not.** That asymmetry resolves a
 * conflict between two ADRs, and it is worth stating because neither is wrong
 * on its own:
 *
 * * [ADR-0074](../../../docs/adrs/0074-catalog-entry-as-distinct-object.md) §4
 *   says the write path carries no namespace — an authenticated upload lands in
 *   the caller's account.
 * * [ADR-0025](../../../docs/adrs/0025-authorization-and-publish-policy.md)'s
 *   matrix says an authenticated user may write an existing `public` plan.
 *
 * Taken literally together, the second is unreachable: if the namespace is
 * always the caller's, a signed-in user can never address an `anon` plan by
 * slug, and everyone who signs in silently loses the wiki model on the plans
 * they have been co-editing. So an *existing* entry is looked for in the
 * caller's namespace first and then in `anon`, while a *new* slug is always
 * claimed in the caller's own. Authorisation is unchanged either way — finding
 * the `anon` entry does not grant anything, it just means the matrix gets asked
 * about the right plan.
 *
 * Known gap, deliberately not invented around: a signed-in user cannot create
 * `<their-account>/<slug>` while `anon/<slug>` exists — the fallback finds the
 * anon one. That is the fork-keeps-its-name case, and giving it an explicit
 * signal is a client-visible API decision rather than something to guess at
 * here.
 */
export function uploadNamespaceFor(principal) {
    const authenticated = !!principal && principal.ok !== false && !principal.anonymous;
    return authenticated && principal.accountId ? principal.accountId : ANON_NAMESPACE;
}

export async function findUploadTarget({ principal, slug }, opts = {}) {
    const namespace = uploadNamespaceFor(principal);

    const own = await findEntry({ namespace, slug }, opts);
    if (own) return { existing: own, namespace, foundIn: namespace };

    if (namespace !== ANON_NAMESPACE) {
        const shared = await findEntry({ namespace: ANON_NAMESPACE, slug }, opts);
        if (shared) return { existing: shared, namespace: ANON_NAMESPACE, foundIn: ANON_NAMESPACE };
    }

    return { existing: null, namespace, foundIn: null };
}

/**
 * Wind up an account's catalog entries when the account is deleted.
 *
 * **Not everything is kept.** The reason for keeping a plan at all is that
 * somebody else is relying on it, and that is true of exactly two kinds:
 *
 * * **Published** — it is in the public feed and people have installed it.
 *   DESIGN-015 §5.1 is explicit that deleting an account does not unpublish,
 *   and the confirm dialog says so before the user commits.
 * * **Shared with named accounts** — a granted account may be co-editing it
 *   right now, and deleting it would take their work with it.
 *
 * Anything else — an unpublished draft nobody was granted — has no such
 * reliance, and keeping it would be retaining somebody's data after they asked
 * for it to be gone. Those are deleted, unless the user chose [releaseDrafts],
 * in which case they are published to the public catalog instead: an explicit
 * "leave my work to the community" that must never be the default, because
 * publishing is an act with consequences the user is not around to reverse.
 *
 * For the entries that stay:
 *
 * **The index key is not rewritten.** It contains the account id, so moving an
 * entry into `anon/` would change `/d/<handle>/<slug>` and break every link
 * already shared. The handle is retired rather than released for the same
 * reason — see `deleteAccount`, and note that it is only retired when
 * something is actually left under it.
 *
 * Returns what happened, because the handle decision depends on it: a
 * namespace with nothing left in it has nothing to keep resolving for.
 */
export async function dropAccountOwnership(
    accountId,
    { indexStore, readJson, writeJson, drillsStore = null, releaseDrafts = false },
) {
    if (!accountId) return { retained: 0, deleted: 0, released: 0 };
    const prefix = `${accountId}/`;
    let cursor;
    let retained = 0;
    let deleted = 0;
    let released = 0;

    do {
        // Strong: this read decides a write, which is the case lib/shared.js
        // documents at length — an eventually consistent read of a
        // recently-written record answers null and the entry keeps its owner.
        const page = await indexStore.list({ prefix, cursor });
        cursor = page?.cursor;
        for (const blob of page?.blobs ?? []) {
            const key = String(blob.key);
            const rec = await indexStore.get(key, { type: "json" });
            if (!rec) continue;

            const keys = keysForEntry(rec);
            const meta = await readJson(keys.meta, null);

            const published = meta?.published === true;
            const hasGrantees = Array.isArray(meta?.sharedAccountIds)
                && meta.sharedAccountIds.length > 0;
            const reliedOn = published || hasGrantees;

            if (!reliedOn && !releaseDrafts) {
                await deleteEntry({ indexStore, drillsStore, key, keys });
                deleted += 1;
                continue;
            }

            await indexStore.set(key, JSON.stringify({
                ...rec, ownerAccountId: null, ownerDeletedAt: new Date().toISOString(),
            }));
            if (!meta) continue;

            await writeJson(keys.meta, {
                ...meta,
                ownerId: ANON_NAMESPACE,
                // No owner means nobody to keep it for. `shared` in particular
                // must not survive: its grantee list names accounts that were
                // granted access *by* an owner who no longer exists.
                accessPolicy: "public",
                sharedAccountIds: [],
                // A draft the user chose to leave behind becomes visible; one
                // that was already published stays as it was.
                published: published || releaseDrafts,
            });
            if (reliedOn) retained += 1; else released += 1;
        }
    } while (cursor);

    return { retained, deleted, released };
}

/** Remove an entry's index record and every blob under its prefix. */
async function deleteEntry({ indexStore, drillsStore, key, keys }) {
    if (drillsStore) {
        let cursor;
        do {
            const page = await drillsStore.list({ prefix: keys.prefix, cursor });
            cursor = page?.cursor;
            for (const blob of page?.blobs ?? []) {
                await drillsStore.delete(String(blob.key));
            }
        } while (cursor);
    }
    // The index key last: while it exists the blobs are reachable, and the
    // other order would leave a record pointing at bytes that are gone.
    await indexStore.delete(key);
}
