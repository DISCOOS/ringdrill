import {getDrillsStore as _getDrillsStore, getSlugIndexStore as _getSlugIndexStore, nowIso, corsPreflight, withCors, metaToFeedItem} from "./lib/shared.js";
import {keysForEntry} from "./lib/catalog.js";

export function createHandler({ getDrillsStore = _getDrillsStore, getSlugIndexStore = _getSlugIndexStore } = {}) {
    return async function (request) {
        const preflight = corsPreflight(request);
        if (preflight) return preflight;

        try {
            if (request.method !== "GET") return withCors(request, new Response("Method Not Allowed", {status: 405}));

            const url = new URL(request.url);
            const limit = clampInt(url.searchParams.get("limit"), 1, 100, 50);
            const origin = url.origin;

            // Enumerate the **index**, not the blob store (ADR-0074 §4).
            //
            // Post-migration a blob scan cannot produce a feed: meta.json lives
            // at catalog/<entryId>/ and carries no namespace, so latestUrl
            // would have nowhere to get one. The index is authoritative and
            // holds `(namespace, slug) -> entry`, which is exactly the pair a
            // feed item needs.
            const drills = getDrillsStore();
            const idx = getSlugIndexStore();
            const items = [];
            let cursor = url.searchParams.get("cursor") || undefined;
            let nextCursor;

            // Every index key is `<namespace>/<slug>`, so it is the entry's
            // identity and there is nothing to dedupe. Until 2026-08-12 a slug
            // could also appear flat, and this sorted namespaced records first
            // and dropped the flat twin so the copy phase could not show one
            // plan as two. Cleanup deleted the last flat key.
            while (items.length < limit) {
                const page = await idx.list({ cursor, limit: 100 });
                cursor = page.cursor;

                const records = await Promise.all(
                    (page.blobs || []).map(async (b) => {
                        const key = String(b.key);
                        const rec = await idx.get(key, { type: "json" });
                        if (!rec) return null;
                        const [namespace, slug] = key.split("/");
                        return { rec, namespace, slug };
                    }),
                );

                for (const entry of records) {
                    if (!entry) continue;

                    const m = await drills.get(keysForEntry(entry.rec).meta, { type: "json" });
                    if (!m || !m.published) continue;

                    items.push(metaToFeedItem(m, { origin, namespace: entry.namespace }));
                    if (items.length >= limit) break;
                }

                if (!cursor || items.length >= limit) {
                    nextCursor = cursor;
                    break;
                }
            }

            items.sort((a, b) => String(b.updatedAt).localeCompare(String(a.updatedAt)));

            return withCors(request, new Response(JSON.stringify(nextCursor ? {items, nextCursor} : {items}, null, 2), {
                status: 200,
                headers: {
                    "content-type": "application/json",
                    "cache-control": "public, max-age=30",
                    "x-generated-at": nowIso(),
                },
            }));
        } catch (e) {
            return withCors(request, new Response(`feed error: ${e.message || e}`, {status: 500}));
        }
    };
}

function clampInt(v, min, max, dflt) {
    const n = Number.parseInt(v ?? "", 10);
    if (Number.isNaN(n)) return dflt;
    return Math.min(max, Math.max(min, n));
}

export default createHandler();
