// Functions v2 (ESM)
import {
    MIME_DRILL,
    getSlugRecord, setSlugRecord, deleteSlugRecord,
    keysFor, readJson, writeJson, readBinary, deleteBlob, copyBlob,
    nowIso, originFromRequest
} from "./_shared.js";
import { getDrillsStore } from "./_shared.js";

export default async function (request) {
    try {
        // --- Auth (Bearer ADMIN_TOKEN) ---
        const token = (process.env.ADMIN_TOKEN || "").trim();
        const auth  = request.headers.get("authorization") || "";
        const ok = token && auth.toLowerCase().startsWith("bearer ") && auth.slice(7).trim() === token;
        if (!ok) {
            return json({ error: "Unauthorized" }, 401);
        }

        const url = new URL(request.url);
        const action = (url.searchParams.get("action") || "").toLowerCase();
        const slug   = url.searchParams.get("slug");
        const version = url.searchParams.get("version"); // required for deleteVersion

        if (!slug) return json({ error: "Missing slug" }, 400);

        const rec = await getSlugRecord(slug);
        if (!rec) return json({ error: "Unknown slug" }, 404);

        const { ownerId, programId } = rec;
        const { latest, meta } = keysFor({ ownerId, programId, version: "latest" });

        // Load meta (may not exist if nothing uploaded yet)
        const metaDoc = await readJson(meta, null);

        switch (action) {
            case "unpublish": {
                if (!metaDoc) return json({ error: "No meta for slug" }, 404);
                if (metaDoc.published === false) return json({ ok: true, slug, published: false, note: "already unpublished" });
                metaDoc.published = false;
                metaDoc.unpublishedAt = nowIso();
                await writeJson(meta, metaDoc);
                return json({ ok: true, slug, published: false });
            }

            case "publish": { // optional, handy during testing
                if (!metaDoc) return json({ error: "No meta for slug" }, 404);
                metaDoc.published = true;
                metaDoc.publishedAt = nowIso();
                await writeJson(meta, metaDoc);
                return json({ ok: true, slug, published: true });
            }

            case "deleteversion": {
                if (!version) return json({ error: "Missing version" }, 400);
                if (!metaDoc || !Array.isArray(metaDoc.versions) || metaDoc.versions.length === 0) {
                    return json({ error: "No versions to delete" }, 404);
                }

                // Remove the versioned blob
                const { versioned } = keysFor({ ownerId, programId, version });
                await deleteBlob(versioned);

                // Update meta
                const remaining = metaDoc.versions.filter(v => v.v !== version);
                metaDoc.versions = remaining;

                if (remaining.length === 0) {
                    // Clean up everything: latest + meta + slugIndex
                    await safeDelete(latest);
                    await deleteBlob(meta);  // meta.json key is under /drills/.../meta.json
                    await deleteSlugRecord(slug);
                    return json({ ok: true, slug, deletedVersion: version, remainingVersions: [], cleaned: true });
                }

                // Compute new latest (highest semver-like string)
                const newLatest = remaining
                    .slice()
                    .sort((a, b) => a.v.localeCompare(b.v, undefined, { numeric: true }))
                    .pop();

                // Copy the new latest content into latest key
                const { versioned: newLatestKey } = keysFor({ ownerId, programId, version: newLatest.v });
                const copied = await copyBlob(newLatestKey, latest, MIME_DRILL);

                // Persist updated meta
                await writeJson(meta, metaDoc);

                return json({
                    ok: true,
                    slug,
                    deletedVersion: version,
                    newLatest: copied ? newLatest.v : null,
                    remainingVersions: remaining.map(v => v.v),
                });
            }

            case "deleteall": {
                // Delete all under drills/{ownerId}/{programId}/
                const prefix = `drills/${ownerId}/${programId}/`;
                const drills = getDrillsStore();
                let cursor;
                let deleted = 0;
                do {
                    const page = await drills.list({ prefix, limit: 1000, cursor });
                    cursor = page.cursor;
                    const keys = (page.blobs || []).map(b => b.key);
                    await Promise.all(keys.map(k => drills.delete(k)));
                    deleted += keys.length;
                } while (cursor);

                await deleteSlugRecord(slug);

                return json({ ok: true, slug, deletedKeys: deleted });
            }

            default:
                return json({ error: "Invalid action. Use: unpublish | deleteVersion | deleteAll | publish" }, 400);
        }
    } catch (e) {
        return json({ error: String(e?.message || e) }, 500);
    }
}

async function safeDelete(key) {
    try { await deleteBlob(key); } catch { /* ignore */ }
}

function json(obj, status = 200) {
    return new Response(JSON.stringify(obj, null, 2), {
        status,
        headers: { "content-type": "application/json" },
    });
}
