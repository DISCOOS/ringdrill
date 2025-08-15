import { MIME_DRILL, keysFor, writeBlob, writeJson, readJson,
    getSlugRecord, setSlugRecord, sanitizeSlug,
    sha256Hex, toStrongEtag, nowIso } from "./_shared.js";

/**
 * Upload endpoint
 * POST /api/drills/upload?name=&slug=&programId=&version=&ownerId=&published=true|false&tags=tag1,tag2
 * Body: raw .drill bytes (Content-Type: application/vnd.ringdrill+json)
 */
export async function handler(event) {
    try {
        if (event.httpMethod !== "POST") {
            return { statusCode: 405, body: "Method Not Allowed" };
        }

        // decode raw body (binary). Netlify sets isBase64Encoded for binary bodies.
        if (!event.isBase64Encoded) {
            return { statusCode: 400, body: "Expected binary body (base64Encoded)" };
        }
        const bytes = Buffer.from(event.body, "base64");

        const headers = event.headers || {};
        const ct = (headers["content-type"] || headers["Content-Type"] || "").toLowerCase();
        if (!ct.includes("application/") && !ct.includes("json") && !ct.includes("drill")) {
            // Accept anyway but annotate as drill MIME
        }

        const qs = new URLSearchParams(event.rawQuery || event.queryStringParameters || {});
        const ownerId   = qs.get("ownerId")   || "anon";
        const programId = qs.get("programId") || cryptoRandom();
        const version   = qs.get("version")   || "1.0.0";
        const name      = qs.get("name")      || programId;
        const slugReq   = qs.get("slug")      || name;
        const slug      = sanitizeSlug(slugReq);
        const published = (qs.get("published") || "false").toLowerCase() === "true";
        const tags      = (qs.get("tags") || "").split(",").map(s => s.trim()).filter(Boolean);

        // Maintain slug index (slug -> ownerId/programId)
        const existing = await getSlugRecord(slug);
        if (existing && (existing.ownerId !== ownerId || existing.programId !== programId)) {
            // You can choose to reject or allow multiple owners per slug; we reject for simplicity.
            return { statusCode: 409, body: `Slug '${slug}' already in use` };
        }
        if (!existing) {
            await setSlugRecord(slug, { ownerId, programId, createdAt: nowIso() });
        }

        const { versioned, latest, meta } = keysFor({ ownerId, programId, version });

        // Write versioned file and "latest" alias
        await writeBlob(versioned, bytes, MIME_DRILL);
        await writeBlob(latest, bytes, MIME_DRILL);

        // Build / update meta
        let metaDoc = await readJson(meta, {
            programId, slug, name, ownerId,
            description: "",
            published: false,
            tags: [],
            versions: []
        });

        // Compute ETag for this upload
        const etag = toStrongEtag(sha256Hex(bytes));

        // Update meta
        metaDoc.slug = slug;
        metaDoc.name = name;
        metaDoc.published = !!published;
        metaDoc.tags = Array.from(new Set([...(metaDoc.tags || []), ...tags]));

        const withoutThisVersion = (metaDoc.versions || []).filter(v => v.v !== version);
        metaDoc.versions = [
            ...withoutThisVersion,
            { v: version, etag, size: bytes.length, updatedAt: nowIso() }
        ].sort((a, b) => a.v.localeCompare(b.v, undefined, { numeric: true }));

        await writeJson(meta, metaDoc);

        const origin = absoluteOrigin(event);
        return {
            statusCode: 200,
            headers: { "content-type": "application/json" },
            body: JSON.stringify({
                slug,
                programId,
                version,
                etag,
                latest: `${origin}/d/${slug}`,
                versioned: `${origin}/d/${slug}@${version}`
            })
        };
    } catch (e) {
        return { statusCode: 500, body: `Upload error: ${e.message || e}` };
    }
}

function cryptoRandom() {
    return (globalThis.crypto?.randomUUID?.() || Math.random().toString(36).slice(2) + Date.now().toString(36));
}

function absoluteOrigin(event) {
    const h = event.headers || {};
    const proto = h["x-forwarded-proto"] || "https";
    const host = h["x-forwarded-host"] || h["host"];
    return `${proto}://${host}`;
}
