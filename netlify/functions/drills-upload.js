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

        const nameOrSlug = qs.get("slug") || qs.get("name");
        const slug = sanitizeSlug(nameOrSlug || "program");

        // Look up existing mapping (if any) BEFORE deciding ownerId/programId
        const existing = await getSlugRecord(slug);

        // Use provided IDs if present; otherwise reuse existing; otherwise defaults
        const ownerIdParam   = qs.get("ownerId");
        const programIdParam = qs.get("programId");

        const ownerId = ownerIdParam ?? existing?.ownerId ?? "anon";
        const programId = programIdParam ?? existing?.programId
            ?? (globalThis.crypto?.randomUUID?.() || Math.random().toString(36).slice(2) + Date.now().toString(36));

        const version   = qs.get("version") || "1.0.0";
        const name      = qs.get("name") || slug;
        const published = (qs.get("published") || "false").toLowerCase() === "true";
        const tags      = (qs.get("tags") || "").split(",").map(s => s.trim()).filter(Boolean);

        const bytes = await readDrillBytes(request);

        // ---- Slug claim / ownership check ----
        if (!existing) {
            // Atomic create (onlyIfNew)
            const claimed = await claimSlug(slug, { ownerId, programId, createdAt: nowIso() });
            if (!claimed) {
                // someone else created between our read and write → verify ownership
                const now = await getSlugRecord(slug);
                if (!now || now.ownerId !== ownerId || now.programId !== programId) {
                    return new Response(`Slug '${slug}' already in use`, { status: 409 });
                }
            }
        } else {
            // Slug exists — enforce same mapping unless caller explicitly changed it
            if (existing.ownerId !== ownerId || existing.programId !== programId) {
                return new Response(`Slug '${slug}' already in use`, { status: 409 });
            }
        }

        const { versioned, latest, meta } = keysFor({ ownerId, programId, version });

        // 1) Write versioned blob only if new
        const vRes = await writeBinaryConditional(versioned, bytes, { onlyIfNew: true });
        if (!vRes.modified) {
            return new Response(`Version '${version}' already exists`, { status: 409 });
        }

        // 2) Update latest guarded (or create if missing)
        const latestEtag = await getBlobEtag(latest);
        await writeBinaryConditional(
            latest,
            bytes,
            latestEtag ? { onlyIfMatch: latestEtag } : { onlyIfNew: true }
        );

        // 3) Update meta.json guarded
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
            return new Response("Precondition failed (meta changed)", { status: 412 });
        }

        const origin = originFromRequest(request);
        return new Response(JSON.stringify({
            slug, programId, version, etag,
            latest:    `${origin}/d/${slug}`,
            versioned: `${origin}/d/${slug}@${version}`,
        }), { status: 200, headers: { "content-type": "application/json" } });

    } catch (e) {
        return new Response(`Upload error: ${e.message || e}`, { status: 500 });
    }
}
