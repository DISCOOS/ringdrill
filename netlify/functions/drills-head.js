import {getSlugRecord, keysFor, readJson, MIME_DRILL} from "./_shared.js";

export default async function (request) {
    try {
        const {pathname} = new URL(request.url);
        // Support both direct function path and your /api redirect
        // /.netlify/functions/drills-head/<slug[@ver]>
        // /api/drills/head/<slug[@ver]>
        const tail = pathname
            .replace(/^.*\/\.netlify\/functions\/drills-head\//, "")
            .replace(/^.*\/api\/drills\/head\//, "");

        if (!tail) return new Response("Missing slug", {status: 404});
        const [slug, verMaybe] = tail.split("@");

        const rec = await getSlugRecord(slug);
        if (!rec) return new Response("Unknown slug", {status: 404});

        const {meta} = keysFor({ownerId: rec.ownerId, programId: rec.programId, version: "latest"});
        const m = await readJson(meta, null);
        if (!m) return new Response("Not found", {status: 404});

        let vinfo = null;
        if (verMaybe) {
            vinfo = (m.versions || []).find(v => v.v === verMaybe) || null;
        } else {
            const sorted = (m.versions || []).slice().sort((a, b) => a.v.localeCompare(b.v, undefined, {numeric: true}));
            vinfo = sorted.pop() || null;
        }
        if (!vinfo) return new Response("No version", {status: 404});

        const headers = new Headers({
            "Content-Type": MIME_DRILL,
            "ETag": vinfo.etag,
            "Content-Length": String(vinfo.size || 0),
        });
        headers.set("Cache-Control", verMaybe ? "public, max-age=31536000, immutable" : "public, max-age=0, must-revalidate");
        if (vinfo.updatedAt) headers.set("Last-Modified", new Date(vinfo.updatedAt).toUTCString());

        // HEAD: empty body; GET: return metadata as JSON if you want (we'll keep empty)
        return new Response("", {status: 200, headers});
    } catch (e) {
        return new Response(`HEAD error: ${e.message || e}`, {status: 500});
    }
}
