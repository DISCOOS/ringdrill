import {
    keysFor, readJson, sanitizeSlug,
    getSlugRecord, claimSlug, sha256Hex,
    toStrongEtag, nowIso, originFromRequest, readDrillBytes,
    writeBinaryConditional, writeJsonConditional, getBlobEtag,
    corsPreflight, withCors
} from "./_shared.js";

export default async function (request) {
    const preflight = corsPreflight(request);
    if (preflight) return preflight;

    try {
        if (request.method !== "POST") return withCors(request, new Response("Method Not Allowed", { status: 405 }));

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

        const explicitVersion = qs.get("version");
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
                    return withCors(request, new Response(`Slug '${slug}' already in use`, { status: 409 }));
                }
            }
        } else {
            // Slug exists — enforce same mapping unless caller explicitly changed it
            if (existing.ownerId !== ownerId || existing.programId !== programId) {
                return withCors(request, new Response(`Slug '${slug}' already in use`, { status: 409 }));
            }
        }

        // The keys for `latest` and `meta` do not depend on version. We read
        // them upfront so we can:
        //   - validate the client's If-Match against the current `latest` etag
        //     before we make any storage writes (full client-driven OCC), and
        //   - know which version to assign when the client did not specify one
        //     (auto-bump = max(meta.versions) + 1).
        const { latest, meta } = keysFor({ ownerId, programId, version: "_" });

        let currentMeta = await readJson(meta, {
            programId, slug, name, ownerId, description: "", published: false, tags: [], versions: []
        });
        let metaEtag = await getBlobEtag(meta);

        // OCC against the client's view. The client supplies an `If-Match`
        // header that came from a previous HEAD/download/upload response —
        // those carry the *content* etag (sha256 of the version bytes), not
        // the storage etag. So we compare the client's etag with the most
        // recent version's content etag from meta.
        const clientIfMatch = request.headers.get("if-match");
        if (clientIfMatch) {
            const sorted = (currentMeta.versions || [])
                .slice()
                .sort((a, b) => a.v.localeCompare(b.v, undefined, { numeric: true }));
            const currentContentEtag = sorted.length
                ? sorted[sorted.length - 1].etag
                : null;
            if (clientIfMatch !== currentContentEtag) {
                return withCors(request, new Response(
                    "Precondition failed (latest changed since you last saw it)",
                    { status: 412 }
                ));
            }
        }

        // 1) Write versioned blob.
        // For explicit version: try once, 409 on collision (legacy behaviour).
        // For auto-bump: retry on collision against a re-read meta, bounded.
        // The retry is necessary because two concurrent uploads can both read
        // the same `max(meta.versions)` and try to claim the same next version.
        const maxVersionRetries = 5;
        let version;
        let versioned;
        let vRes;
        for (let attempt = 0; ; attempt++) {
            if (explicitVersion) {
                version = explicitVersion;
            } else {
                const maxV = (currentMeta.versions || []).reduce((acc, v) => {
                    const n = parseInt(v.v, 10);
                    return Number.isFinite(n) ? Math.max(acc, n) : acc;
                }, 0);
                version = String(maxV + 1);
            }
            versioned = keysFor({ ownerId, programId, version }).versioned;
            vRes = await writeBinaryConditional(versioned, bytes, { onlyIfNew: true });
            if (vRes.modified) break;
            if (explicitVersion || attempt >= maxVersionRetries) {
                return withCors(request, new Response(
                    `Version '${version}' already exists`, { status: 409 }
                ));
            }
            // Race: another writer took our auto-assigned version. Re-read meta
            // and try the next slot.
            currentMeta = await readJson(meta, currentMeta);
            metaEtag = await getBlobEtag(meta);
        }

        // 2) Update latest under storage-level OCC. The client's If-Match was
        // already validated above against the content etag; here we guard
        // against a server-internal race between our getBlobEtag read and the
        // write by passing the storage etag we just observed.
        const currentLatestStorageEtag = await getBlobEtag(latest);
        const latestRes = currentLatestStorageEtag
            ? await writeBinaryConditional(latest, bytes, { onlyIfMatch: currentLatestStorageEtag })
            : await writeBinaryConditional(latest, bytes, { onlyIfNew: true });
        if (!latestRes.modified) {
            return withCors(request, new Response(
                "Precondition failed (latest changed)", { status: 412 }
            ));
        }

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
            return withCors(request, new Response("Precondition failed (meta changed)", { status: 412 }));
        }

        const origin = originFromRequest(request);
        return withCors(request, new Response(JSON.stringify({
            slug, programId, version, etag,
            latest:    `${origin}/d/${slug}`,
            versioned: `${origin}/d/${slug}@${version}`,
        }), { status: 200, headers: { "content-type": "application/json" } }));

    } catch (e) {
        return withCors(request, new Response(`Upload error: ${e.message || e}`, { status: 500 }));
    }
}
