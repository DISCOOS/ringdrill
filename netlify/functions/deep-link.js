import {
    readBinary, readJson, getSlugRecord, keysFor, MIME_DRILL,
    sha256Hex, toStrongEtag
} from "./_shared.js";

export default async function (request) {
    try {
        const { pathname } = new URL(request.url);

        // Support both direct function path and a /d/* redirect
        // /.netlify/functions/deep-link/<slug[@ver]>
        // /d/<slug[@ver]>
        let tail = pathname.replace(/^.*\/\.netlify\/functions\/deep-link\//, "");
        if (tail === pathname) tail = pathname.replace(/^\/d\//, "");
        if (!tail) return new Response("Not found", { status: 404 });

        const [slug, verMaybe] = tail.split("@");

        // Lookup owner/program via slug-index
        const rec = await getSlugRecord(slug);
        if (!rec) return new Response("Unknown slug", { status: 404 });

        // Read meta to obtain version info (for ETag/size/Last-Modified)
        const { meta, versioned, latest } = keysFor({
            ownerId: rec.ownerId, programId: rec.programId, version: verMaybe || "latest",
        });

        const metaDoc = await readJson(meta, null);
        let vinfo = null;
        if (metaDoc && Array.isArray(metaDoc.versions)) {
            if (verMaybe) {
                vinfo = metaDoc.versions.find(v => v.v === verMaybe) || null;
            } else {
                vinfo = metaDoc.versions
                    .slice()
                    .sort((a, b) => a.v.localeCompare(b.v, undefined, { numeric: true }))
                    .pop() || null;
            }
        }

        // If we have an ETag from meta, honor conditional requests before reading the blob
        const cacheHeader = verMaybe
            ? "public, max-age=31536000, immutable"
            : "public, max-age=0, must-revalidate";

        const inm = request.headers.get("if-none-match");
        if (vinfo?.etag && inm && etagMatches(inm, vinfo.etag)) {
            const h304 = new Headers({
                "ETag": vinfo.etag,
                "Cache-Control": cacheHeader,
            });
            if (vinfo.updatedAt) h304.set("Last-Modified", new Date(vinfo.updatedAt).toUTCString());
            return new Response(null, { status: 304, headers: h304 });
        }

        // Fetch the blob
        const key = verMaybe ? versioned : latest;
        const buf = await readBinary(key);
        if (!buf) return new Response("Not found", { status: 404 });

        // Fallback: if meta missing, compute ETag from bytes
        const etag = vinfo?.etag ?? toStrongEtag(sha256Hex(buf));
        const lastMod = vinfo?.updatedAt ? new Date(vinfo.updatedAt).toUTCString() : undefined;

        const headers = new Headers({
            "Content-Type": MIME_DRILL,
            "Content-Length": String(buf.length),
            "Content-Disposition": `inline; filename="${verMaybe ? `${slug}@${verMaybe}.drill` : `${slug}.drill`}"`,
            "ETag": etag,
            "Cache-Control": cacheHeader,
        });
        if (lastMod) headers.set("Last-Modified", lastMod);

        // Support HEAD (no body) and GET (send file)
        if (request.method === "HEAD") {
            return new Response(null, { status: 200, headers });
        }
        return new Response(buf, { status: 200, headers });
    } catch (e) {
        return new Response(`Resolve error: ${e.message || e}`, { status: 500 });
    }
}

// Accepts one or many ETags per RFC 7232 (comma-separated list).
// Matches strong or weak validators.
function etagMatches(ifNoneMatchHeader, currentEtag) {
    const raw = (ifNoneMatchHeader || "").trim();
    if (!raw) return false;
    if (raw === "*") return true;
    const tokens = raw.split(",").map(t => t.trim());
    return tokens.some(t => t === currentEtag || t === `W/${currentEtag}`);
}
