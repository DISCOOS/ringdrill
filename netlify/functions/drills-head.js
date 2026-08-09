import {
    MIME_DRILL,
    readJson as _readJson,
    latestVersionEntry,
    corsPreflight,
    withCors,
} from "./lib/shared.js";
import {
    findEntry as _findEntry, keysForEntry, parseCatalogPath, resolveNamespace as _resolveNamespace,
} from "./lib/catalog.js";

export function createHandler({ findEntry = _findEntry, resolveNamespace = _resolveNamespace, readJson = _readJson } = {}) {
    return async function (request) {
        const preflight = corsPreflight(request);
        if (preflight) return preflight;

        try {
            const { pathname } = new URL(request.url);
            // Support the direct function path and both netlify.toml aliases:
            // the hyphenated form (/api/drills-head/*, mirroring this file's own
            // name — what DrillClient.head() actually calls) and the slashed
            // form (/api/drills/head/*). Missing the hyphenated strip here used
            // to leave the whole "/api/drills-head/<slug>" prefix stuck to the
            // front of `tail`, so every lookup used a bogus slug and reported
            // "Unknown slug" regardless of whether the real slug existed.
            const tail = pathname
                .replace(/^.*\/\.netlify\/functions\/drills-head\//, "")
                .replace(/^.*\/api\/drills-head\//, "")
                .replace(/^.*\/api\/drills\/head\//, "");

            if (!tail) return withCors(request, new Response("Missing slug", { status: 404 }));

            // Optional namespace segment (ADR-0074 §2), then dual-read: a
            // pre-migration entry still resolves from the flat key and the old
            // blob layout, which is what lets the migration run with the site
            // live. keysForEntry hides which layout a record is in.
            const parsed = parseCatalogPath(tail);
            if (!parsed) return withCors(request, new Response("Not found", { status: 404 }));
            const { slug, version: verMaybe } = parsed;

            const ns = await resolveNamespace(parsed.explicitNamespace ? parsed.namespace : null, {});
            const rec = await findEntry({ namespace: ns.namespace, slug });
            if (!rec) return withCors(request, new Response("Unknown slug", { status: 404 }));

            const { meta } = keysForEntry(rec, "latest");
            const m = await readJson(meta, null);
            if (!m) return withCors(request, new Response("Not found", { status: 404 }));

            // Pick version info
            let vinfo = null;
            if (verMaybe) {
                vinfo = (m.versions || []).find(v => v.v === verMaybe) || null;
            } else {
                vinfo = latestVersionEntry(m.versions);
            }
            if (!vinfo) return withCors(request, new Response("No version", { status: 404 }));

            // --- NEW: If-None-Match support -> 304 Not Modified
            const inm = request.headers.get("if-none-match");
            if (inm && etagMatches(inm, vinfo.etag)) {
                const h304 = new Headers({
                    "ETag": vinfo.etag,
                    "Cache-Control": verMaybe
                        ? "public, max-age=31536000, immutable"
                        : "public, max-age=0, must-revalidate",
                });
                if (vinfo.updatedAt) h304.set("Last-Modified", new Date(vinfo.updatedAt).toUTCString());
                if (vinfo.v != null) h304.set("x-version", String(vinfo.v));
                // For HEAD/GET, 304 must not include a body
                return withCors(request, new Response(null, { status: 304, headers: h304 }));
            }

            // Normal 200 response for HEAD (empty body)
            const headers = new Headers({
                "Content-Type": MIME_DRILL,
                "ETag": vinfo.etag,
                "Content-Length": String(vinfo.size || 0),
            });
            headers.set(
                "Cache-Control",
                verMaybe ? "public, max-age=31536000, immutable" : "public, max-age=0, must-revalidate"
            );
            if (vinfo.updatedAt) headers.set("Last-Modified", new Date(vinfo.updatedAt).toUTCString());
            if (vinfo.v != null) headers.set("x-version", String(vinfo.v));

            return withCors(request, new Response("", { status: 200, headers }));
        } catch (e) {
            return withCors(request, new Response(`HEAD error: ${e.message || e}`, { status: 500 }));
        }
    };
}

export default createHandler();

// Accepts one or many ETags per RFC 7232 (comma-separated list)
// We generate strong ETags like:  "abcdef1234..."
function etagMatches(ifNoneMatchHeader, currentEtag) {
    if (!ifNoneMatchHeader) return false;
    const raw = ifNoneMatchHeader.trim();
    if (raw === "*") return true;
    // split by commas, trim tokens
    const tokens = raw.split(",").map(t => t.trim());
    // match strong or weak form just in case ("W/etag")
    return tokens.some(t => t === currentEtag || t === `W/${currentEtag}`);
}
