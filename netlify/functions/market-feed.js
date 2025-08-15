// Lists published drills from meta.json files
import { getDrillsStore, nowIso } from "./_shared.js";

export async function handler(event) {
    try {
        if (event.httpMethod !== "GET") return { statusCode: 405, body: "Method Not Allowed" };

        const qs = new URLSearchParams(event.rawQuery || event.queryStringParameters || {});
        const limit = clampInt(qs.get("limit"), 1, 100, 50);
        const origin = (event.headers?.["x-forwarded-proto"] || "https") + "://" + (event.headers?.["x-forwarded-host"] || event.headers?.["host"]);
        let cursor = qs.get("cursor") || undefined;

        const drills = getDrillsStore(); // ✅ created at invocation
        const items = [];
        let nextCursor;

        while (items.length < limit) {
            const page = await drills.list({ prefix: "drills/", cursor, limit: 100 });
            cursor = page.cursor;

            const metaKeys = (page.blobs || [])
                .map(b => b.key)
                .filter(k => k.endsWith("/meta.json"));

            const metas = await Promise.all(metaKeys.map(k => drills.get(k, { type: "json" })));

            for (const m of metas) {
                if (!m || !m.published) continue;
                const latest = latestVersionEntry(m.versions);
                items.push({
                    programId: m.programId,
                    slug: m.slug,
                    name: m.name,
                    tags: m.tags || [],
                    latestUrl: `${origin}/d/${m.slug}`,
                    updatedAt: latest?.updatedAt || null,
                });
                if (items.length >= limit) break;
            }
            if (!cursor || items.length >= limit) {
                nextCursor = cursor;
                break;
            }
        }

        items.sort((a, b) => String(b.updatedAt).localeCompare(String(a.updatedAt)));

        return {
            statusCode: 200,
            headers: {
                "content-type": "application/json",
                "cache-control": "public, max-age=30",
                "x-generated-at": nowIso(),
            },
            body: JSON.stringify(nextCursor ? { items, nextCursor } : { items }, null, 2),
        };
    } catch (e) {
        return { statusCode: 500, body: `feed error: ${e.message || e}` };
    }
}

function latestVersionEntry(versions) {
    if (!Array.isArray(versions) || versions.length === 0) return null;
    return versions.slice().sort((a, b) => a.v.localeCompare(b.v, undefined, { numeric: true })).pop();
}
function clampInt(v, min, max, dflt) {
    const n = Number.parseInt(v ?? "", 10);
    if (Number.isNaN(n)) return dflt;
    return Math.min(max, Math.max(min, n));
}
