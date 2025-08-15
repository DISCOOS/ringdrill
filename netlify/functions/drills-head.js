import { getSlugRecord, keysFor, readJson, MIME_DRILL } from "./_shared.js";

export async function handler(event) {
    try {
        if (event.httpMethod !== "HEAD" && event.httpMethod !== "GET") {
            return { statusCode: 405, body: "Method Not Allowed" };
        }

        const p = (event.path || "").replace(/^.*\/api\/drills\/head\//, "");
        if (!p) return { statusCode: 404, body: "Missing slug" };
        const [slug, verMaybe] = p.split("@");

        const rec = await getSlugRecord(slug);
        if (!rec) return { statusCode: 404, body: "Unknown slug" };

        const { meta } = keysFor({ ownerId: rec.ownerId, programId: rec.programId, version: "latest" });
        const m = await readJson(meta, null);
        if (!m) return { statusCode: 404, body: "Not found" };

        // pick version info
        let vinfo = null;
        if (verMaybe) {
            vinfo = (m.versions || []).find(v => v.v === verMaybe) || null;
        } else {
            const sorted = (m.versions || []).slice().sort((a,b)=>a.v.localeCompare(b.v, undefined, {numeric:true}));
            vinfo = sorted.pop() || null;
        }
        if (!vinfo) return { statusCode: 404, body: "No version" };

        const headers = {
            "Content-Type": MIME_DRILL,
            "Cache-Control": verMaybe
                ? "public, max-age=31536000, immutable"
                : "public, max-age=0, must-revalidate",
            "ETag": vinfo.etag,
            "Content-Length": String(vinfo.size || 0),
            "Last-Modified": vinfo.updatedAt ? new Date(vinfo.updatedAt).toUTCString() : undefined,
        };
        // remove undefined
        Object.keys(headers).forEach(k => headers[k] === undefined && delete headers[k]);

        return { statusCode: 200, headers, body: "" };
    } catch (e) {
        return { statusCode: 500, body: `HEAD error: ${e.message || e}` };
    }
}
