import {
    keysFor, readJson, sanitizeSlug,
    getSlugRecord, claimSlug, sha256Hex,
    toStrongEtag, nowIso, originFromRequest, readDrillBytes,
    writeBinaryConditional, writeJsonConditional, getBlobEtag
} from "./_shared.js";

export default async function (request) {
    try {
        if (request.method !== "POST") return new Response("Method Not Allowed", { status: 405 });

        const url = new URL(request.url);
        const qs = url.searchParams;

        const ownerId   = qs.get("ownerId")   || "anon";
        const programId = qs.get("programId") || (globalThis.crypto?.randomUUID?.() || Math.random().toString(36).slice(2) + Date.now().toString(36));
        const version   = qs.get("version")   || "1.0.0";
        const name      = qs.get("name")      || programId;
        const slug      = sanitizeSlug(qs.get("slug") || name);
        const published = (qs.get("published") || "false").toLowerCase() === "true";
        const tags      = (qs.get("tags") || "").split(",").map(s => s.trim()).filter(Boolean);

        const bytes = await readDrillBytes(request);

        // ---- Slug claim (atomic) ----
        const existing = await getSlugRecord(slug);
        if (!existing) {
            const claimed = await claimSlug(slug, { ownerId, programId, createdAt: nowIso() });
            if (!claimed) {
                // Someone else claimed concurrently — re-read and verify ownership
                const now = await getSlugRecord(slug);
                if (!now || now.ownerId !== ownerId || now.programId !== programId) {
                    return new Response(`Slug '${slug}' already in use`, { status: 409 });
                }
            }
        } else if (existing.ownerId !== ownerId || existing.programId !== programId) {
            return new Response(`Slug '${slug}' already in use`, { status: 409 });
        }

        const { versioned, latest, meta } = keysFor({ ownerId, programId, version });

        // ---- 1) Write versioned blob only if key is new ----
        const vRes = await writeBinaryConditional(versioned, bytes, { onlyIfNew: true });
        if (!vRes.modified) {
            return new Response(`Version '${version}' already exists`, { status: 409 });
        }

        // ---- 2) Update latest pointer guarded by current ETag (or create if missing) ----
        const latestEtag = await getBlobEtag(latest);
        const lRes = await writeBinaryConditional(
            latest,
            bytes,
            latestEtag ? { onlyIfMatch: latestEtag } : { onlyIfNew: true }
        );
        // If not modified here, it just means someone else advanced "latest" in the meantime. That's fine.

        // ---- 3) Update meta.json with optimistic concurrency ----
        const currentMeta = await readJson(meta, {
            programId, slug, name, ownerId, description: "", published: false, tags: [], versions: []
        });
        const metaEtag = await getBlobEtag(meta);

        const etag = toStrongEtag(sha256Hex(bytes));
        currentMeta.slug = slug;
        currentMeta.name = name;
        currentMeta.published = !!published;
        currentMeta.tags = Array.from(new Set([...(currentMeta.tags || []), ...tags]));

        const without = (currentMeta.versions || []).filter(v => v.v !== version);
        currentMeta.versions = [
            ...without,
            { v: version, etag, size: bytes.length, updatedAt: nowIso() }
        ].sort((a, b) => a.v.localeCompare(b.v, undefined, { numeric: true }));

        const mRes = await writeJsonConditional(
            meta,
            currentMeta,
            metaEtag ? { onlyIfMatch: metaEtag } : { onlyIfNew: true }
        );
        if (!mRes.modified && metaEtag) {
            // Someone else updated meta between our read and write → conflict
            return new Response("Precondition failed (meta changed)", { status: 412 });
        }

        const origin = originFromRequest(request);
        return new Response(JSON.stringify({
            slug, programId, version, etag,
            latest:    `${origin}/d/${slug}`,
            versioned: `${origin}/d/${slug}@${version}`,
            note: !lRes.modified && latestEtag ? "latest not advanced (concurrent update)" : undefined
        }), { status: 200, headers: { "content-type": "application/json" } });
    } catch (e) {
        return new Response(`Upload error: ${e.message || e}`, { status: 500 });
    }
}
