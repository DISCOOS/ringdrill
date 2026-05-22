import {
    keysFor, readJson, sanitizeSlug,
    getSlugRecord, claimSlug, sha256Hex,
    toStrongEtag, nowIso, originFromRequest, readDrillBytes,
    writeBinaryConditional, writeJsonConditional,
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
        const slugTakenResponse = () => withCors(request, new Response(
            `Slug '${slug}' already in use`,
            { status: 409, headers: { "x-conflict-kind": "slug" } }
        ));
        if (!existing) {
            // Atomic create (onlyIfNew)
            const claimed = await claimSlug(slug, { ownerId, programId, createdAt: nowIso() });
            if (!claimed) {
                // someone else created between our read and write → verify ownership
                const now = await getSlugRecord(slug);
                if (!now || now.ownerId !== ownerId || now.programId !== programId) {
                    return slugTakenResponse();
                }
            }
        } else {
            // Slug exists — enforce same mapping unless caller explicitly changed it
            if (existing.ownerId !== ownerId || existing.programId !== programId) {
                return slugTakenResponse();
            }
        }

        const { latest, meta } = keysFor({ ownerId, programId, version: "_" });
        const currentMeta = await readJson(meta, {
            programId, slug, name, ownerId, description: "", published: false, tags: [], versions: []
        });

        // Sort meta.versions once — used by the OCC check and the "is this a
        // no-op?" check.
        const sortedVersions = (currentMeta.versions || [])
            .slice()
            .sort((a, b) => a.v.localeCompare(b.v, undefined, { numeric: true }));
        const currentLatest = sortedVersions.length
            ? sortedVersions[sortedVersions.length - 1]
            : null;
        const currentContentEtag = currentLatest?.etag ?? null;

        // ---- Optimistic concurrency check ----
        // The single OCC gate: the client's If-Match (a content etag = sha256
        // of the bytes they last saw as "latest") must match the most recent
        // version's content etag in meta. If yes, their view is fresh and we
        // proceed. If no, state has moved on and we return 412 — the client
        // should refresh + show a diff against the new remote state before
        // retrying. Subsequent writes (latest, meta) are unconditional
        // overwrites; we trust the gate above.
        const clientIfMatch = request.headers.get("if-match");
        if (clientIfMatch && clientIfMatch !== currentContentEtag) {
            return withCors(request, new Response(
                "Precondition failed (latest changed since you last saw it)",
                { status: 412 }
            ));
        }

        // ---- No-op check ----
        // If the bytes the client is uploading are byte-identical to the
        // current latest version, there's nothing to publish. Return 304 with
        // the existing etag/version — no new versioned blob, no meta change.
        // (Without this, repeated publishes of the same content accumulate
        // duplicate versioned blobs with the same content etag.)
        const incomingEtag = toStrongEtag(sha256Hex(bytes));
        if (currentLatest && currentLatest.etag === incomingEtag) {
            const origin = originFromRequest(request);
            return withCors(request, new Response(null, {
                status: 304,
                headers: {
                    "etag": incomingEtag,
                    "x-version": String(currentLatest.v),
                    "x-latest": `${origin}/d/${slug}`,
                    "x-versioned": `${origin}/d/${slug}@${currentLatest.v}`,
                    "x-program-id": String(programId),
                },
            }));
        }

        // ---- Write versioned blob ----
        // Auto-bump version: start at max(meta.versions) + 1, walk forward on
        // collision (orphan versioned blobs from previous failed uploads can
        // leave gaps where storage has the slot but meta does not). Bounded
        // retry. Explicit-version callers get the legacy "409 if taken"
        // behaviour without walking.
        const maxVersionRetries = 16;
        let version;
        let versioned;
        let vRes;
        let attemptVersion = explicitVersion
            ? null
            : (currentMeta.versions || []).reduce((acc, v) => {
                  const n = parseInt(v.v, 10);
                  return Number.isFinite(n) ? Math.max(acc, n) : acc;
              }, 0) + 1;
        for (let attempt = 0; ; attempt++) {
            version = explicitVersion ?? String(attemptVersion);
            versioned = keysFor({ ownerId, programId, version }).versioned;
            vRes = await writeBinaryConditional(versioned, bytes, { onlyIfNew: true });
            if (vRes.modified) break;
            if (explicitVersion || attempt >= maxVersionRetries) {
                return withCors(request, new Response(
                    `Version '${version}' already exists`,
                    { status: 409, headers: { "x-conflict-kind": "version" } }
                ));
            }
            attemptVersion += 1;
        }

        // ---- Update latest (unconditional overwrite) ----
        // The OCC gate above has already established that the client's view
        // is fresh. We don't second-guess with another storage-level lock.
        await writeBinaryConditional(latest, bytes, {});

        // ---- Update meta (unconditional overwrite) ----
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
        await writeJsonConditional(meta, currentMeta, {});

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
