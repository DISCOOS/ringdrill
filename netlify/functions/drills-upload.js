import {
    MIME_DRILL, keysFor, writeBinary, writeJson, readJson,
    getSlugRecord, setSlugRecord, sanitizeSlug,
    sha256Hex, toStrongEtag, nowIso, absoluteOrigin, decodeBody
} from "./_shared.js";

export async function handler(event) {
    try {
        if (event.httpMethod !== "POST") return { statusCode: 405, body: "Method Not Allowed" };

        const bytes = decodeBody(event);

        const qs = new URLSearchParams(event.rawQuery || event.queryStringParameters || {});
        const ownerId   = qs.get("ownerId")   || "anon";
        const programId = qs.get("programId") || cryptoRandom();
        const version   = qs.get("version")   || "1.0.0";
        const name      = qs.get("name")      || programId;
        const slugReq   = qs.get("slug")      || name;
        const slug      = sanitizeSlug(slugReq);
        const published = (qs.get("published") || "false").toLowerCase() === "true";
        const tags      = (qs.get("tags") || "").split(",").map(s => s.trim()).filter(Boolean);

        const existing = await getSlugRecord(slug);
        if (existing && (existing.ownerId !== ownerId || existing.programId !== programId)) {
            return { statusCode: 409, body: `Slug '${slug}' already in use` };
        }
        if (!existing) await setSlugRecord(slug, { ownerId, programId, createdAt: nowIso() });

        const { versioned, latest, meta } = keysFor({ ownerId, programId, version });

        await writeBinary(versioned, bytes, MIME_DRILL);
        await writeBinary(latest,    bytes, MIME_DRILL);

        let metaDoc = await readJson(meta, {
            programId, slug, name, ownerId, description: "", published: false, tags: [], versions: []
        });

        const etag = toStrongEtag(sha256Hex(bytes));
        metaDoc.slug = slug;
        metaDoc.name = name;
        metaDoc.published = !!published;
        metaDoc.tags = Array.from(new Set([...(metaDoc.tags || []), ...tags]));

        const without = (metaDoc.versions || []).filter(v => v.v !== version);
        metaDoc.versions = [
            ...without,
            { v: version, etag, size: bytes.length, updatedAt: nowIso() }
        ].sort((a, b) => a.v.localeCompare(b.v, undefined, { numeric: true }));

        await writeJson(meta, metaDoc);

        const origin = absoluteOrigin(event);
        return {
            statusCode: 200,
            headers: { "content-type": "application/json" },
            body: JSON.stringify({
                slug, programId, version, etag,
                latest:    `${origin}/d/${slug}`,
                versioned: `${origin}/d/${slug}@${version}`,
            })
        };
    } catch (e) {
        return { statusCode: 500, body: `Upload error: ${e.message || e}` };
    }
}

function cryptoRandom() {
    return (globalThis.crypto?.randomUUID?.() || Math.random().toString(36).slice(2) + Date.now().toString(36));
}
