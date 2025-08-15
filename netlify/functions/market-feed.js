// netlify/functions/market-feed.js
import { getStore } from "@netlify/blobs";
import { nowIso } from "./_shared.js"; // optional, only used for a header; remove if you prefer

// We keep all program metadata at keys like: drills/{ownerId}/{programId}/meta.json
const drills = getStore("drills");

/**
 * GET /api/market/feed?limit=50&cursor=...
 * Returns: { items: [...], nextCursor?: "..." }
 *
 * Item shape:
 * { programId, slug, name, tags, updatedAt }
 */
export async function handler(event) {
    try {
        if (event.httpMethod !== "GET") {
            return { statusCode: 405, body: "Method Not Allowed" };
        }

        const qs = new URLSearchParams(event.rawQuery || event.queryStringParameters || {});
        const limit = clampInt(qs.get("limit"), 1, 100, 50);
        const origin = (event.headers?.["x-forwarded-proto"] || "https") + "://" + (event.headers?.["x-forwarded-host"] || event.headers?.["host"]);
        let cursor = qs.get("cursor") || undefined;

        const items = [];
        let nextCursor;

        // We iterate pages of blob keys, but *only* fetch meta.json keys, and only
        // until we collect `limit` published items.
        while (items.length < limit) {
            const page = await drills.list({ prefix: "drills/", cursor, limit: 100 }); // page of keys
            cursor = page.cursor; // may be undefined at end

            const metaKeys = (page.blobs || [])
                .map(b => b.key)
                .filter(k => k.endsWith("/meta.json"));

            // Fetch meta docs in parallel, but stop once we have enough published items
            const metas = await Promise.all(
                metaKeys.map((k) => drills.get(k, { type: "json" }))
            );

            for (const m of metas) {
                if (!m || !m.published) continue;
                const latestUrl = `${origin}/d/${m.slug}`;


                const latest = latestVersionEntry(m.versions);
                items.push({
                    programId: m.programId,
                    slug: m.slug,
                    name: m.name,
                    tags: m.tags || [],
                    latestUrl: latestUrl,
                    updatedAt: latest?.updatedAt || null,
                });

                if (items.length >= limit) break;
            }

            if (!cursor || items.length >= limit) {
                nextCursor = cursor; // if cursor is set, client can request next page
                break;
            }
        }

        // Sort newest first (client can skip if they paginate by cursor)
        items.sort((a, b) => String(b.updatedAt).localeCompare(String(a.updatedAt)));

        const body = JSON.stringify(
            nextCursor ? { items, nextCursor } : { items },
            null,
            2
        );

        return {
            statusCode: 200,
            headers: {
                "content-type": "application/json",
                // Cache lightly; feed should feel fresh while still CDN-cacheable
                "cache-control": "public, max-age=30",
                "x-generated-at": nowIso(),
            },
            body,
        };
    } catch (e) {
        return { statusCode: 500, body: `feed error: ${e.message || e}` };
    }
}

function latestVersionEntry(versions) {
    if (!Array.isArray(versions) || versions.length === 0) return null;
    // versions: [{ v, etag, size, updatedAt }]
    return versions
        .slice()
        .sort((a, b) => a.v.localeCompare(b.v, undefined, { numeric: true }))
        .pop();
}

function clampInt(v, min, max, dflt) {
    const n = Number.parseInt(v ?? "", 10);
    if (Number.isNaN(n)) return dflt;
    return Math.min(max, Math.max(min, n));
}
