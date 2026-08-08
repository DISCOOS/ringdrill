// netlify/functions/drills-admin.js
import {
    getSlugIndexStore as _getSlugIndexStore,
    getDrillsStore as _getDrillsStore,
    readJson as _readJson, readJsonStrong as _readJsonStrong,
    readBinary as _readBinary, readBinaryStrong as _readBinaryStrong,
    writeJsonConditional as _writeJsonConditional,
    writeBinaryConditional as _writeBinaryConditional,
    getBlobEtag as _getBlobEtag,
    nowIso,
    corsPreflight, withCors
} from "./lib/shared.js";
import {
    findEntry as _findEntry, keysForEntry, parseCatalogPath,
    resolveNamespace as _resolveNamespace, slugIndexKey,
} from "./lib/catalog.js";

/**
 * `createHandler({ deps })`, matching every other function in this directory.
 *
 * It was the one without a seam, and that is exactly why `deleteall` — the most
 * destructive action in the codebase — had no handler test until the catalog
 * re-key made it obviously dangerous.
 */
export function createHandler({
    env = process.env,
    getSlugIndexStore = _getSlugIndexStore,
    getDrillsStore = _getDrillsStore,
    findEntry = _findEntry,
    resolveNamespace = _resolveNamespace,
    readJson = _readJson,
    readJsonStrong = _readJsonStrong,
    readBinary = _readBinary,
    readBinaryStrong = _readBinaryStrong,
    writeJsonConditional = _writeJsonConditional,
    writeBinaryConditional = _writeBinaryConditional,
    getBlobEtag = _getBlobEtag,
} = {}) {
    return async function (request) {
    const preflight = corsPreflight(request);
    if (preflight) return preflight;

    // Bind request-scoped json() helper so admin responses get CORS headers
    // when the call comes from an allowlisted browser origin.
    const json = (obj, status = 200) => withCors(request, new Response(
        JSON.stringify(obj, null, 2),
        { status, headers: { "content-type": "application/json" } },
    ));

    try {
        // ---- Auth (Bearer ADMIN_TOKEN) ----
        const token = (env.ADMIN_TOKEN || "").trim();
        const auth  = request.headers.get("authorization") || "";
        const ok = token && auth.toLowerCase().startsWith("bearer ") && auth.slice(7).trim() === token;
        if (!ok) return json({ error: "Unauthorized" }, 401);

        const url = new URL(request.url);

        // normalize: lowercase + trim only
        let action = (url.searchParams.get("action") ?? "").toLowerCase().trim();
        let slug = (url.searchParams.get("slug") ?? "").trim();
        let version = (url.searchParams.get("version") ?? "").trim();

        // Removes the index key the record actually came from. A migrated
        // entry lives at <namespace>/<slug>; a pre-migration one at the bare
        // slug. Deleting only the bare key would leave a migrated entry
        // resolvable after "delete all".
        const deleteEntryRecord = async (found) => {
            if (!found) return;
            const idx = getSlugIndexStore();
            await idx.delete(found.rec.entryId ? slugIndexKey(found.namespace, found.slug) : found.slug);
        };

        // Every action resolves through this, so none of them can drift onto
        // one layout while the others move (ADR-0074 §4). It returns the
        // record and its keys together, because using one without the other is
        // how a delete ends up scanning the wrong prefix.
        const resolve = async (name, { strong = false } = {}) => {
            const parsed = parseCatalogPath(name);
            if (!parsed) return null;
            const ns = await resolveNamespace(parsed.explicitNamespace ? parsed.namespace : null, {});
            const rec = await findEntry({ namespace: ns.namespace, slug: parsed.slug }, { strong });
            return rec ? { rec, slug: parsed.slug, namespace: ns.namespace } : null;
        };

        switch (action) {
            // ---------- ONE-OFF MIGRATION (ADR-0074) ----------
            //
            // Run here rather than from a local script: inside the Netlify
            // runtime blob access just works, where a script would need a site
            // id and an API token plumbed into getStore({ siteID, token }) —
            // credential handling for no gain. It also reuses this endpoint's
            // existing ADMIN_TOKEN gate.
            //
            // Both default to a dry run. Pass dryRun=false to act.
            case "migrate-catalog-keys": {
                const { migrateCatalogKeys } = await import("./lib/migrate-catalog.js");
                const dryRun = (url.searchParams.get("dryRun") ?? "true").toLowerCase() !== "false";
                const report = await migrateCatalogKeys({ dryRun });
                return json(report);
            }
            case "migrate-catalog-keys-cleanup": {
                const { cleanupCatalogKeys } = await import("./lib/migrate-catalog.js");
                const dryRun = (url.searchParams.get("dryRun") ?? "true").toLowerCase() !== "false";
                const report = await cleanupCatalogKeys({ dryRun });
                return json(report);
            }

            // ---------- READ-ONLY ADMIN ----------
            case "listall": {
                const limit  = clampInt(url.searchParams.get("limit"), 1, 200, 50);
                let cursor = url.searchParams.get("cursor") || undefined;

                const idx = getSlugIndexStore();
                const items = [];
                let nextCursor;

                while (items.length < limit) {
                    const page = await idx.list({ cursor, limit: Math.min(200, limit) });
                    cursor = page.cursor; // may be undefined at end

                    for (const b of (page.blobs || [])) {
                        const s = b.key; // slug key
                        const rec = await idx.get(s, { type: "json" });
                        if (!rec) continue;

                        const { meta } = keysForEntry(rec, "latest");
                        const m = await readJson(meta, null);

                        let latest = null, versionCount = 0, published = false, name, tags;
                        if (m) {
                            name = m.name;
                            tags = m.tags || [];
                            published = !!m.published;
                            const versions = Array.isArray(m.versions)
                                ? m.versions.slice().sort((a,b)=>a.v.localeCompare(b.v, undefined, {numeric:true}))
                                : [];
                            versionCount = versions.length;
                            latest = versions[versions.length - 1] || null;
                        }

                        items.push({
                            slug: s,
                            ownerId: rec.ownerId,
                            programId: rec.programId,
                            planId: rec.programId,
                            name, tags,
                            published,
                            versionCount,
                            latest: latest ? { v: latest.v, etag: latest.etag, size: latest.size, updatedAt: latest.updatedAt } : null,
                            createdAt: rec.createdAt || null
                        });

                        if (items.length >= limit) break;
                    }

                    if (!cursor || items.length >= limit) { nextCursor = cursor; break; }
                }

                return json(nextCursor ? { items, nextCursor } : { items });
            }
            case "versions": {
                if (!slug) return json({ error: "Missing slug for action: versions" }, 400);

                const found = await resolve(slug);
                const rec = found?.rec ?? null;
                if (!rec) return json({ error: "Unknown slug: " + slug }, 404);

                const { ownerId, programId } = rec;
                const { meta } = keysForEntry(rec, "latest");
                const m = await readJson(meta, null);
                if (!m) return json({ slug, ownerId, programId, planId: programId, versions: [], published: false });

                const versions = Array.isArray(m.versions)
                    ? m.versions.slice().sort((a,b)=>a.v.localeCompare(b.v, undefined, {numeric:true}))
                    : [];
                const latest = versions[versions.length - 1] || null;

                return json({
                    slug, ownerId, programId, planId: programId,
                    name: m.name, tags: m.tags || [],
                    published: !!m.published,
                    versionCount: versions.length,
                    latest: latest ? { v: latest.v, etag: latest.etag, size: latest.size, updatedAt: latest.updatedAt } : null,
                    versions
                });
            }

            // ---------- MUTATING ADMIN (guarded with ETags) ----------
            case "unpublish":
            case "publish": {
                if (!slug) return json({ error: `Missing slug for action: ${action}` }, 400);

                // Strong: this mapping decides which blobs the mutation below
                // touches. An eventually consistent read can miss a just-claimed slug
                // (a spurious 404) or hand back a stale owner/program pair.
                const found = await resolve(slug, { strong: true });
                const rec = found?.rec ?? null;
                if (!rec) return json({ error: "Unknown slug: " + slug }, 404);

                const { ownerId, programId } = rec;
                const { meta } = keysForEntry(rec, "latest");
                // ETag first, then the value it guards, and both strong: this reads
                // `meta` in order to write it back, so an eventually consistent read
                // either fails the conditional write for no reason (a 412 the admin
                // cannot act on) or bases the write on a stale object and erases
                // whatever landed in between. See the note in lib/shared.js.
                const metaEtag = await getBlobEtag(meta);
                const m = await readJsonStrong(meta, null);
                if (!m) return json({ error: "No meta for slug" }, 404);
                m.published = action === "publish";
                if (action === "publish") m.publishedAt = nowIso();
                else m.unpublishedAt = nowIso();

                const { modified } = await writeJsonConditional(meta, m, { onlyIfMatch: metaEtag });
                if (!modified) return json({ error: "Precondition failed (meta changed)" }, 412);
                return json({ ok: true, slug, published: m.published });
            }

            case "deleteversion": {
                if (!slug) return json({ error: "Missing slug for action: deleteversion" }, 400);
                if (!version) return json({ error: "Missing version" }, 400);

                // Strong: this mapping decides which blobs the mutation below
                // touches. An eventually consistent read can miss a just-claimed slug
                // (a spurious 404) or hand back a stale owner/program pair.
                const found = await resolve(slug, { strong: true });
                const rec = found?.rec ?? null;
                if (!rec) return json({ error: "Unknown slug: " + slug }, 404);

                const { ownerId, programId } = rec;
                const { latest, meta } = keysForEntry(rec, "latest");
                // Strong: the version list read here is filtered and written back.
                const m = await readJsonStrong(meta, null);
                if (!m?.versions?.length) return json({ error: "No versions to delete" }, 404);

                // Order: references first, bytes last.
                //
                // The versioned blob used to be deleted here, before either guarded
                // write. A precondition failure below then left the bytes gone and meta
                // still listing the version — a catalog entry pointing at nothing, which
                // no later request repairs. Deleting last inverts the failure: an
                // interruption leaves bytes nobody references. An orphan costs storage
                // and is greppable; a dangling reference is a broken download.
                const remaining = m.versions.filter(v => v.v !== version);
                const { versioned } = keysForEntry(rec, version);
                const dropBytes = async () => {
                    // Reported rather than thrown. By this point every reference is
                    // gone, so the catalog is already correct and the caller's request
                    // has succeeded; a failure here is an orphan to clean up, not a
                    // reason to fail an operation that did what was asked.
                    try {
                        await getDrillsStore().delete(versioned);
                        return true;
                    } catch {
                        return false;
                    }
                };

                if (remaining.length === 0) {
                    // Last version: drop the whole plan. Same order — the slug record
                    // and meta are what make the plan findable, so they go before the
                    // bytes they point at.
                    const latestEtag = await getBlobEtag(latest);
                    try { if (latestEtag) await getDrillsStore().delete(latest); } catch {}
                    try { await getDrillsStore().delete(meta); } catch {}
                    // Delete the index key the record actually came from: a
                // migrated entry is at <namespace>/<slug>, a pre-migration one
                // at the bare slug.
                try { await deleteEntryRecord(found); } catch {}
                    const bytesDeleted = await dropBytes();
                    return json({
                        ok: true, slug, deletedVersion: version,
                        remainingVersions: [], cleaned: true, bytesDeleted,
                    });
                }

                // Recompute latest
                const newLatest = remaining.slice().sort((a,b)=>a.v.localeCompare(b.v, undefined, {numeric:true})).pop();
                const { versioned: newLatestKey } = keysForEntry(rec, newLatest.v);
                // Strong: these bytes are read in order to be written to `latest`, and
                // an eventually consistent miss reports them as absent.
                const buf = await readBinaryStrong(newLatestKey);
                if (!buf) return json({ error: "New latest bytes not found" }, 500);

                // Guard latest pointer
                const latestEtag = await getBlobEtag(latest);
                const lRes = await writeBinaryConditional(
                    latest,
                    buf,
                    latestEtag ? { onlyIfMatch: latestEtag } : { onlyIfNew: true }
                );
                // `&& latestEtag` used to be here, and it meant a rejected write was
                // ignored whenever the guard had been `onlyIfNew` — the etag being null
                // is exactly the branch that picks `onlyIfNew`, so the one case the
                // check skipped was the one it was needed for. A rejection there means
                // `latest` exists after all, so these bytes were never written, and the
                // meta update below would then name a latest version whose pointer
                // still holds the previous archive. Any rejection is a precondition
                // failure.
                if (!lRes.modified) return json({ error: "Precondition failed (latest changed)" }, 412);

                // Guard meta write
                const metaEtag2 = await getBlobEtag(meta);
                m.versions = remaining;
                const mRes = await writeJsonConditional(meta, m, { onlyIfMatch: metaEtag2 });
                if (!mRes.modified) return json({ error: "Precondition failed (meta changed)" }, 412);

                // Nothing references the version now. Safe to drop the bytes.
                const bytesDeleted = await dropBytes();

                return json({
                    ok: true, slug,
                    deletedVersion: version,
                    newLatest: newLatest.v,
                    remainingVersions: remaining.map(v => v.v),
                    // false means the version is gone from the catalog but its archive
                    // is still in the store. Surfaced so an orphan is something an
                    // operator can see rather than something they have to go looking
                    // for.
                    bytesDeleted,
                });
            }

            case "deleteall": {
                if (!slug) return json({ error: "Missing slug for action: deleteall" }, 400);

                // Strong: this mapping decides which blobs the mutation below
                // touches. An eventually consistent read can miss a just-claimed slug
                // (a spurious 404) or hand back a stale owner/program pair.
                const found = await resolve(slug, { strong: true });
                const rec = found?.rec ?? null;
                if (!rec) return json({ error: "Unknown slug: " + slug }, 404);
                const { ownerId, programId } = rec;

                // **The prefix comes from the record, not from ownerId.** A
                // migrated entry lives at catalog/<entryId>/, so deriving the
                // old owner-scoped prefix here would delete nothing and report
                // success — the plan would look gone and still be served.
                const { prefix } = keysForEntry(rec);
                const s = getDrillsStore();
                let cursor, deleted = 0;
                do {
                    const page = await s.list({ prefix, limit: 1000, cursor });
                    cursor = page.cursor;
                    const keys = (page.blobs || []).map(b => b.key);
                    await Promise.all(keys.map(k => s.delete(k)));
                    deleted += keys.length;
                } while (cursor);

                // Delete the index key the record actually came from: a
                // migrated entry is at <namespace>/<slug>, a pre-migration one
                // at the bare slug.
                try { await deleteEntryRecord(found); } catch {}
                return json({ ok: true, slug, deletedKeys: deleted });
            }

            default:
                return json({
                    error: "Invalid action: " + action + ". " +
                            "Use: listall | versions | unpublish | publish | deleteversion | deleteall"
                    }, 400
                );
        }
    } catch (e) {
        return json({ error: String(e?.message || e) }, 500);
    }
    };
}

function clampInt(v, min, max, dflt) {
    const n = Number.parseInt(v ?? "", 10);
    if (Number.isNaN(n)) return dflt;
    return Math.min(max, Math.max(min, n));
}

export default createHandler();
