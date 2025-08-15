import {getDrillsStore, nowIso} from "./_shared.js";

export default async function (request) {
    try {
        if (request.method !== "GET") return new Response("Method Not Allowed", {status: 405});

        const url = new URL(request.url);
        const limit = clampInt(url.searchParams.get("limit"), 1, 100, 50);
        const origin = url.origin;

        const drills = getDrillsStore();
        const items = [];
        let cursor = url.searchParams.get("cursor") || undefined;
        let nextCursor;

        while (items.length < limit) {
            const page = await drills.list({prefix: "drills/", cursor, limit: 100});
            cursor = page.cursor;

            const metaKeys = (page.blobs || []).map(b => b.key).filter(k => k.endsWith("/meta.json"));
            const metas = await Promise.all(metaKeys.map(k => drills.get(k, {type: "json"})));

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

        return new Response(JSON.stringify(nextCursor ? {items, nextCursor} : {items}, null, 2), {
            status: 200,
            headers: {
                "content-type": "application/json",
                "cache-control": "public, max-age=30",
                "x-generated-at": nowIso(),
            },
        });
    } catch (e) {
        return new Response(`feed error: ${e.message || e}`, {status: 500});
    }
}

function latestVersionEntry(versions) {
    if (!Array.isArray(versions) || versions.length === 0) return null;
    return versions.slice().sort((a, b) => a.v.localeCompare(b.v, undefined, {numeric: true})).pop();
}

function clampInt(v, min, max, dflt) {
    const n = Number.parseInt(v ?? "", 10);
    if (Number.isNaN(n)) return dflt;
    return Math.min(max, Math.max(min, n));
}
