import { getDrillsStore, getDrillsStoreStrong, getSlugIndexStoreStrong } from "./shared.js";
import { ANON_NAMESPACE, catalogKeysFor, newEntryId, slugIndexKey, storedNamespaceFor } from "./catalog.js";

/**
 * The one-off move to ADR-0074's key layout.
 *
 * Two phases, deliberately separate:
 *
 *   copy     read every blob under drills/<ownerId>/<planId>/, write it under
 *            catalog/<entryId>/, then repoint the slug index.
 *   cleanup  delete the old blobs and the flat index keys.
 *
 * **Copy first, repoint second, delete last.** Reversing any two opens a window
 * where a live /d/<slug> 404s. Splitting cleanup into its own run means nothing
 * is destroyed until the new layout has been verified serving real traffic —
 * at three plans there is no reason to make that atomic.
 *
 * **Resumable and idempotent.** An entry that already has an `entryId` is
 * skipped, so a half-finished run just needs running again. There is no
 * rename in Netlify Blobs, so a copy is a read plus a write; a re-run of a
 * partially copied entry simply overwrites identical bytes.
 *
 * The dual-read in catalog.js is what lets this run with the site live: until
 * an entry is repointed, `findEntry` falls back to the flat key and the old
 * blob layout.
 */

/** Every pre-migration index record: a flat key (no `/`) without an entryId. */
async function legacyRecords(idx) {
    const out = [];
    let cursor;
    do {
        const page = await idx.list({ cursor });
        cursor = page?.cursor;
        for (const blob of page?.blobs ?? []) {
            const key = String(blob.key);
            if (key.includes("/")) continue; // already namespaced
            const rec = await idx.get(key, { type: "json" });
            if (rec && !rec.entryId) out.push({ slug: key, rec });
        }
    } while (cursor);
    return out;
}

export async function migrateCatalogKeys({
    dryRun = true,
    idx = getSlugIndexStoreStrong(),
    // **Strong.** Every read here feeds a write somewhere else, which is
    // exactly the case lib/shared.js documents for readBinaryStrong: an
    // eventually consistent read of a recently uploaded version answers null,
    // and this would record "source_vanished" for a blob that is right there —
    // then the cleanup phase would delete the original it failed to copy.
    drills = getDrillsStoreStrong(),
    now = () => new Date().toISOString(),
    makeEntryId = newEntryId,
} = {}) {
    const report = { phase: "copy", dryRun, scanned: 0, migrated: [], skipped: [], errors: [] };

    for (const { slug, rec } of await legacyRecords(idx)) {
        report.scanned++;
        const ownerId = rec.ownerId ?? ANON_NAMESPACE;
        const planId = rec.programId ?? rec.planId;
        if (!planId) {
            report.errors.push({ slug, reason: "no_plan_id" });
            continue;
        }

        const namespace = storedNamespaceFor(ownerId === ANON_NAMESPACE ? null : ownerId);

        // Already done in an earlier run? Skip rather than mint a second entry.
        const existing = await idx.get(slugIndexKey(namespace, slug), { type: "json" });
        if (existing?.entryId) {
            report.skipped.push({ slug, namespace, entryId: existing.entryId, reason: "already_migrated" });
            continue;
        }

        const prefix = `drills/${ownerId}/${planId}/`;
        const names = [];
        let cursor;
        do {
            const page = await drills.list({ prefix, cursor });
            cursor = page?.cursor;
            for (const b of page?.blobs ?? []) names.push(String(b.key));
        } while (cursor);

        if (names.length === 0) {
            report.errors.push({ slug, reason: "no_blobs", prefix });
            continue;
        }

        const entryId = makeEntryId();
        const copied = [];

        if (!dryRun) {
            for (const from of names) {
                // Copy by read+write: Netlify Blobs has no move.
                const to = `catalog/${entryId}/${from.slice(prefix.length)}`;
                const isJson = from.endsWith(".json");
                const body = isJson
                    ? await drills.get(from, { type: "json" })
                    : await drills.get(from, { type: "arrayBuffer" });
                if (body == null) {
                    report.errors.push({ slug, reason: "source_vanished", from });
                    continue;
                }
                await drills.set(to, isJson ? JSON.stringify(body) : Buffer.from(body));
                copied.push(to);
            }

            // Repoint only after every blob is in place. Doing this first would
            // leave a window where the index points at bytes that are not there
            // yet, and /d/<slug> would 404 for a plan that exists.
            await idx.set(slugIndexKey(namespace, slug), JSON.stringify({
                ...rec, entryId, planId, programId: planId,
                ownerAccountId: ownerId === ANON_NAMESPACE ? null : ownerId,
                namespace, slug, migratedAt: now(),
            }));
        }

        report.migrated.push({ slug, namespace, entryId, from: prefix, blobs: dryRun ? names.length : copied.length });
    }

    return report;
}

/**
 * Delete what the copy phase superseded.
 *
 * Run only after the new layout has been verified. Refuses to touch anything
 * that has not been repointed, so a cleanup cannot run ahead of a copy.
 */
export async function cleanupCatalogKeys({
    dryRun = true,
    idx = getSlugIndexStoreStrong(),
    // Strong for the same reason: this decides deletions.
    drills = getDrillsStoreStrong(),
} = {}) {
    const report = { phase: "cleanup", dryRun, removedBlobs: [], removedKeys: [], skipped: [] };

    let cursor;
    do {
        const page = await idx.list({ cursor });
        cursor = page?.cursor;
        for (const blob of page?.blobs ?? []) {
            const key = String(blob.key);
            if (key.includes("/")) continue;
            const rec = await idx.get(key, { type: "json" });
            if (!rec) continue;

            const ownerId = rec.ownerId ?? ANON_NAMESPACE;
            const planId = rec.programId ?? rec.planId;
            const namespace = storedNamespaceFor(ownerId === ANON_NAMESPACE ? null : ownerId);
            const migrated = await idx.get(slugIndexKey(namespace, key), { type: "json" });

            if (!migrated?.entryId) {
                // Never delete ahead of the copy.
                report.skipped.push({ slug: key, reason: "not_migrated" });
                continue;
            }

            const prefix = `drills/${ownerId}/${planId}/`;
            let c2;
            do {
                const p = await drills.list({ prefix, cursor: c2 });
                c2 = p?.cursor;
                for (const b of p?.blobs ?? []) {
                    if (!dryRun) await drills.delete(String(b.key));
                    report.removedBlobs.push(String(b.key));
                }
            } while (c2);

            if (!dryRun) await idx.delete(key);
            report.removedKeys.push(key);
        }
    } while (cursor);

    return report;
}
