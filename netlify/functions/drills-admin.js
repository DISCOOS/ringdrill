import {
    getDrillsStore, getSlugRecord, deleteSlugRecord,
    keysFor, readJson, writeJsonConditional,
    readBinary, writeBinaryConditional, getBlobEtag,
    nowIso, getSlugIndexStore
} from "./_shared.js";

export default async function (request) {
    try {
        // Auth
        const token = (process.env.ADMIN_TOKEN || "").trim();
        const auth  = request.headers.get("authorization") || "";
        const ok = token && auth.toLowerCase().startsWith("bearer ") && auth.slice(7).trim() === token;
        if (!ok) return json({ error: "Unauthorized" }, 401);

        const url = new URL(request.url);
        const action  = (url.searchParams.get("action") || "").toLowerCase();
        const slug    = url.searchParams.get("slug");
        const version = url.searchParams.get("version"); // required for deleteVersion

        if (action!=="list-all" && !slug) return json({ error: "Missing slug" }, 400);

        const rec = await getSlugRecord(slug);
        if (!rec) return json({ error: "Unknown slug" }, 404);

        const { ownerId, programId } = rec;
        const { latest, meta } = keysFor({ ownerId, programId, version: "latest" });
        const metaDoc = await readJson(meta, null);

        switch (action) {
            /* ---------------- list all slugs (admin) ---------------- */
            case "list-all": {
                const limit  = clampInt(url.searchParams.get("limit"), 1, 100, 50);
                const prefix = (url.searchParams.get("prefix") || "").trim();
                let cursor   = url.searchParams.get("cursor") || undefined;

                const slugIndex = getSlugIndexStore();
                const drills    = getDrillsStore();

                const items = [];
                let nextCursor;

                // Iterate over slug-index in pages until we fill 'limit'
                while (items.length < limit) {
                    const page = await slugIndex.list({ cursor, prefix: prefix || undefined });
                    // page.blobs: [{ key, size, uploadedAt, ... }]
                    for (const b of page.blobs) {
                        // key is typically the slug name in the index store
                        const slug = b.key;

                        // Resolve ownerId/programId from the slug-index record
                        const rec = await readJson(keysFor({ slug }).slugIndex); // fallback if getSlugRecord not desired here
                        // If your existing getSlugRecord(slug) returns the same shape, you can use:
                        // const rec = await getSlugRecord(slug);
                        if (!rec) continue;

                        const { ownerId, programId } = rec;
                        const { meta } = keysFor({ ownerId, programId });
                        const metaJson = await readJson(meta);
                        const versions = Array.isArray(metaJson?.versions) ? metaJson.versions : [];
                        const latest   = versions.length
                            ? versions.slice().sort((a, b) => a.v.localeCompare(b.v, undefined, { numeric: true })).pop()
                            : null;

                        items.push({
                            slug,
                            ownerId,
                            programId,
                            published: !!metaJson?.published,
                            versions: versions.map(v => ({ v: v.v, etag: v.etag, size: v.size, updatedAt: v.updatedAt })),
                            latest: latest ? { v: latest.v, etag: latest.etag } : null,
                            updatedAt: metaJson?.updatedAt || null,
                        });

                        if (items.length >= limit) break;
                    }

                    if (items.length >= limit || !page.cursor) {
                        nextCursor = page.cursor || undefined;
                        break;
                    }
                    cursor = page.cursor;
                }

                return json(
                    nextCursor ? { items, nextCursor, generatedAt: nowIso() } : { items, generatedAt: nowIso() },
                    200
                );
            }

            /* ---------------- publish and unpublish existing (admin) ---------------- */
            case "publish":
            case "unpublish": {
                if (!metaDoc) return json({ error: "No meta for slug" }, 404);
                const metaEtag = await getBlobEtag(meta);
                metaDoc.published = action === "publish";
                if (action === "publish") metaDoc.publishedAt = nowIso();
                else metaDoc.unpublishedAt = nowIso();

                const { modified } = await writeJsonConditional(meta, metaDoc, { onlyIfMatch: metaEtag });
                if (!modified) return json({ error: "Precondition failed (meta changed)" }, 412);

                return json({ ok: true, slug, published: metaDoc.published });
            }

            case "deleteversion": {
                if (!version) return json({ error: "Missing version" }, 400);
                if (!metaDoc?.versions?.length) return json({ error: "No versions to delete" }, 404);

                // Remove versioned blob
                const { versioned } = keysFor({ ownerId, programId, version });
                await getDrillsStore().delete(versioned);

                // Update meta (guarded)
                const metaEtag1 = await getBlobEtag(meta);
                const remaining = metaDoc.versions.filter(v => v.v !== version);
                metaDoc.versions = remaining;

                if (remaining.length === 0) {
                    // Delete latest + meta + slug record
                    const latestEtag = await getBlobEtag(latest);
                    try { if (latestEtag) await getDrillsStore().delete(latest); } catch {}
                    try { if (metaEtag1)   await getDrillsStore().delete(meta); } catch {}
                    try { await deleteSlugRecord(slug); } catch {}
                    return json({ ok: true, slug, deletedVersion: version, remainingVersions: [], cleaned: true });
                }

                // New latest is the highest version string
                const newLatest = remaining.slice().sort((a,b)=>a.v.localeCompare(b.v, undefined, {numeric:true})).pop();

                // Repoint latest guarded by its current ETag (or create if missing)
                const latestEtag = await getBlobEtag(latest);
                const { versioned: newLatestKey } = keysFor({ ownerId, programId, version: newLatest.v });
                const newBytes = await readBinary(newLatestKey);
                if (!newBytes) return json({ error: "New latest bytes not found" }, 500);

                const lRes = await writeBinaryConditional(
                    latest,
                    newBytes,
                    latestEtag ? { onlyIfMatch: latestEtag } : { onlyIfNew: true }
                );
                if (!lRes.modified && latestEtag) {
                    // Someone else changed latest during the operation
                    return json({ error: "Precondition failed (latest changed)" }, 412);
                }

                // Persist updated meta guarded by latest-known ETag
                const metaEtag2 = await getBlobEtag(meta);
                const mRes = await writeJsonConditional(meta, metaDoc, { onlyIfMatch: metaEtag2 });
                if (!mRes.modified) return json({ error: "Precondition failed (meta changed)" }, 412);

                return json({
                    ok: true,
                    slug,
                    deletedVersion: version,
                    newLatest: newLatest.v,
                    remainingVersions: remaining.map(v => v.v),
                });
            }

            case "deleteall": {
                const prefix = `drills/${ownerId}/${programId}/`;
                const s = getDrillsStore();
                let cursor, deleted = 0;
                do {
                    const page = await s.list({ prefix, limit: 1000, cursor });
                    cursor = page.cursor;
                    const keys = (page.blobs || []).map(b => b.key);
                    await Promise.all(keys.map(k => s.delete(k)));
                    deleted += keys.length;
                } while (cursor);
                try { await deleteSlugRecord(slug); } catch {}
                return json({ ok: true, slug, deletedKeys: deleted });
            }

            default:
                return json({ error: "Invalid action. Use: unpublish | deleteVersion | deleteAll | publish" }, 400);
        }
    } catch (e) {
        return json({ error: String(e?.message || e) }, 500);
    }
}

function json(obj, status = 200) {
    return new Response(JSON.stringify(obj, null, 2), {
        status,
        headers: { "content-type": "application/json" },
    });
}
