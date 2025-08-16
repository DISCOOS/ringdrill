// netlify/functions/drills-admin.js
import {
    getSlugRecord, deleteSlugRecord, getSlugIndexStore,
    keysFor, readJson, readBinary,
    writeJsonConditional, writeBinaryConditional, getBlobEtag,
    nowIso
} from "./_shared.js";
import { getDrillsStore } from "./_shared.js";

export default async function (request) {
    try {
        // ---- Auth (Bearer ADMIN_TOKEN) ----
        const token = (process.env.ADMIN_TOKEN || "").trim();
        const auth  = request.headers.get("authorization") || "";
        const ok = token && auth.toLowerCase().startsWith("bearer ") && auth.slice(7).trim() === token;
        if (!ok) return json({ error: "Unauthorized" }, 401);

        const url = new URL(request.url);
        const action = url.searchParams.get("action");
        const slug = (url.searchParams.get("slug") || "").trim();
        const version = url.searchParams.get("version");

        switch (action) {
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

                        const { meta } = keysFor({ ownerId: rec.ownerId, programId: rec.programId, version: "latest" });
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

            case "list": {
                if (!slug) return json({ error: "Missing slug for action: list" }, 400);

                const rec = await getSlugRecord(slug);
                if (!rec) return json({ error: "Unknown slug" }, 404);

                const { ownerId, programId } = rec;
                const { meta } = keysFor({ ownerId, programId, version: "latest" });
                const m = await readJson(meta, null);
                if (!m) return json({ slug, ownerId, programId, versions: [], published: false });

                const versions = Array.isArray(m.versions)
                    ? m.versions.slice().sort((a,b)=>a.v.localeCompare(b.v, undefined, {numeric:true}))
                    : [];
                const latest = versions[versions.length - 1] || null;

                return json({
                    slug, ownerId, programId,
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

                const rec = await getSlugRecord(slug);
                if (!rec) return json({ error: "Unknown slug" }, 404);

                const { ownerId, programId } = rec;
                const { meta } = keysFor({ ownerId, programId, version: "latest" });
                const m = await readJson(meta, null);
                if (!m) return json({ error: "No meta for slug" }, 404);

                const metaEtag = await getBlobEtag(meta);
                m.published = action === "publish";
                if (action === "publish") m.publishedAt = nowIso();
                else m.unpublishedAt = nowIso();

                const { modified } = await writeJsonConditional(meta, m, { onlyIfMatch: metaEtag });
                if (!modified) return json({ error: "Precondition failed (meta changed)" }, 412);
                return json({ ok: true, slug, published: m.published });
            }

            case "deleteversion": {
                if (!slug) return json({ error: "Missing slug for action: deleteVersion" }, 400);
                if (!version) return json({ error: "Missing version" }, 400);

                const rec = await getSlugRecord(slug);
                if (!rec) return json({ error: "Unknown slug" }, 404);

                const { ownerId, programId } = rec;
                const { latest, meta } = keysFor({ ownerId, programId, version: "latest" });
                const m = await readJson(meta, null);
                if (!m?.versions?.length) return json({ error: "No versions to delete" }, 404);

                // Delete the versioned blob
                const { versioned } = keysFor({ ownerId, programId, version });
                await getDrillsStore().delete(versioned);

                // Update meta
                const remaining = m.versions.filter(v => v.v !== version);
                if (remaining.length === 0) {
                    // Clean everything
                    const latestEtag = await getBlobEtag(latest);
                    try { if (latestEtag) await getDrillsStore().delete(latest); } catch {}
                    try { await getDrillsStore().delete(meta); } catch {}
                    try { await deleteSlugRecord(slug); } catch {}
                    return json({ ok: true, slug, deletedVersion: version, remainingVersions: [], cleaned: true });
                }

                // Recompute latest
                const newLatest = remaining.slice().sort((a,b)=>a.v.localeCompare(b.v, undefined, {numeric:true})).pop();
                const { versioned: newLatestKey } = keysFor({ ownerId, programId, version: newLatest.v });
                const buf = await readBinary(newLatestKey);
                if (!buf) return json({ error: "New latest bytes not found" }, 500);

                // Guard latest pointer
                const latestEtag = await getBlobEtag(latest);
                const lRes = await writeBinaryConditional(
                    latest,
                    buf,
                    latestEtag ? { onlyIfMatch: latestEtag } : { onlyIfNew: true }
                );
                if (!lRes.modified && latestEtag) return json({ error: "Precondition failed (latest changed)" }, 412);

                // Guard meta write
                const metaEtag2 = await getBlobEtag(meta);
                m.versions = remaining;
                const mRes = await writeJsonConditional(meta, m, { onlyIfMatch: metaEtag2 });
                if (!mRes.modified) return json({ error: "Precondition failed (meta changed)" }, 412);

                return json({
                    ok: true, slug,
                    deletedVersion: version,
                    newLatest: newLatest.v,
                    remainingVersions: remaining.map(v => v.v)
                });
            }

            case "deleteall": {
                if (!slug) return json({ error: "Missing slug for action: deleteAll" }, 400);

                const rec = await getSlugRecord(slug);
                if (!rec) return json({ error: "Unknown slug" }, 404);
                const { ownerId, programId } = rec;

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
                return json({ error: "Invalid action. Use: list | listAll | unpublish | publish | deleteVersion | deleteAll" }, 400);
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

function clampInt(v, min, max, dflt) {
    const n = Number.parseInt(v ?? "", 10);
    if (Number.isNaN(n)) return dflt;
    return Math.min(max, Math.max(min, n));
}
