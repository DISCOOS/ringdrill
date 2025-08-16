import { MIME_DRILL, getSlugRecord, keysFor, readJson } from "./_shared.js";

export default async function (request) {
    try {
        const { pathname } = new URL(request.url);
        // Support both direct function path and /api redirect
        const tail = pathname
            .replace(/^.*\/\.netlify\/functions\/drills-head\//, "")
            .replace(/^.*\/api\/drills\/head\//, "");

        if (!tail) return new Response("Missing slug", { status: 404 });
        const [slug, verMaybe] = tail.split("@");

        const rec = await getSlugRecord(slug);
        if (!rec) return new Response("Unknown slug", { status: 404 });

        const { meta } = keysFor({ ownerId: rec.ownerId, programId: rec.programId, version: "latest" });
        const m = await readJson(meta, null);
        if (!m) return new Response("Not found", { status: 404 });

        // Pick version info
        let vinfo = null;
        if (verMaybe) {
            vinfo = (m.versions || []).find(v => v.v === verMaybe) || null;
        } else {
            const sorted = (m.versions || []).slice().sort((a,b)=>a.v.localeCompare(b.v, undefined, {numeric:true}));
            vinfo = sorted.pop() || null;
        }
        if (!vinfo) return new Response("No version", { status: 404 });

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
            // For HEAD/GET, 304 must not include a body
            return new Response(null, { status: 304, headers: h304 });
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

        return new Response("", { status: 200, headers });
    } catch (e) {
        return new Response(`HEAD error: ${e.message || e}`, { status: 500 });
    }
}

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
