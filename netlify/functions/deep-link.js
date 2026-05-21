// netlify/functions/deep-link.js
import {
    MIME_DRILL,
    readBinary, readJson,
    getSlugRecord, keysFor,
    sha256Hex, toStrongEtag,
    corsPreflight, withCors
} from "./_shared.js";

export default async function (request) {
    const preflight = corsPreflight(request);
    if (preflight) return preflight;

    try {
        const url = new URL(request.url);
        const originalPath = url.pathname;

        // Recognize /o/ (App Link) or /d/
        const isOpenMode = /^\/o\//i.test(originalPath);
        // Detect when the function was reached directly via its function
        // path (typically only in local `netlify functions:serve`, since
        // production routes everything through the /d/ and /o/ aliases).
        // When this is the case we skip the `.drill` canonicalisation
        // redirect, since the redirect target (`/d/<slug>.drill`) does not
        // exist locally.
        const isViaFunctionPath =
            /^.*\/\.netlify\/functions\/deep-link\//.test(originalPath);

        // Normalize tail
        let tail = originalPath
            .replace(/^.*\/\.netlify\/functions\/deep-link\//, "")
            .replace(/^\/d\//i, "")
            .replace(/^\/o\//i, "")
            .replace(/^\/+/, "");

        if (!tail) return withCors(request, new Response("Not found", { status: 404 }));
        try { tail = decodeURIComponent(tail); } catch {}

        const hasDrillExt = /\.drill(?:$|[/?#@])/i.test(tail);

        // Normalize .drill position:
        //  - "slug.drill@1.2.3"  -> "slug@1.2.3"
        //  - "slug@1.2.3.drill"  -> "slug@1.2.3"
        //  - "slug.drill"        -> "slug"
        tail = tail
            .replace(/\.drill(@[^/]+)?$/i, (_m, ver) => ver ?? "")
            .replace(/(@[^/]+)\.drill$/i, "$1")
            .replace(/\.drill@/i, "@");

        // Parse "<slug>" or "<slug>@<version>"
        const m = tail.match(/^([^@/]+)(?:@([^/]+))?$/);
        if (!m) return withCors(request, new Response("Not found", { status: 404 }));
        const slug = m[1];
        const version = (m[2] || "").trim() || null;

        // ---------- /o/ behavior ----------
        if (isOpenMode) {
            const canonical = `/d/${slug}${version ? `@${version}` : ""}.drill`;
            const u = new URL(request.url);
            u.pathname = canonical;
            u.search = "";
            return withCors(request, new Response(null, { status: 302, headers: { Location: u.toString() } }));
        }

        // ---------- /d/ behavior ----------
        // When the request was sent directly to the function path (local
        // dev), serve the file directly. Otherwise produce a 301 to the
        // canonical `/d/<slug>.drill` form, which is the public-facing URL.
        if (!hasDrillExt && !isViaFunctionPath) {
            const canonical = `/d/${slug}${version ? `@${version}` : ""}.drill`;
            const u = new URL(request.url);
            u.pathname = canonical;
            u.search = ""; // ensure no query params
            return withCors(request, new Response(null, { status: 301, headers: { Location: u.toString() } }));
        }

        const rec = await getSlugRecord(slug);
        if (!rec) return withCors(request, new Response("Unknown slug", { status: 404 }));

        const { meta, versioned, latest } = keysFor({
            ownerId: rec.ownerId,
            programId: rec.programId,
            version: version || "latest",
        });

        const metaDoc = await readJson(meta, null);
        let vinfo = null;
        if (metaDoc && Array.isArray(metaDoc.versions)) {
            if (version) {
                vinfo = metaDoc.versions.find(v => v.v === version) || null;
            } else {
                vinfo = metaDoc.versions
                    .slice()
                    .sort((a, b) => a.v.localeCompare(b.v, undefined, { numeric: true }))
                    .pop() || null;
            }
        }

        const cacheHeader = version
            ? "public, max-age=31536000, immutable"
            : "public, max-age=0, must-revalidate";

        // Conditional GET
        const inm = request.headers.get("if-none-match");
        if (vinfo?.etag && inm && etagMatches(inm, vinfo.etag)) {
            const h304 = new Headers({
                "ETag": vinfo.etag,
                "Cache-Control": cacheHeader,
            });
            if (vinfo?.updatedAt) h304.set("Last-Modified", new Date(vinfo.updatedAt).toUTCString());
            return withCors(request, new Response(null, { status: 304, headers: h304 }));
        }

        const key = version ? versioned : latest;
        const buf = await readBinary(key);
        if (!buf) return withCors(request, new Response("Not found", { status: 404 }));

        const etag = vinfo?.etag ?? toStrongEtag(sha256Hex(buf));
        const lastMod = vinfo?.updatedAt ? new Date(vinfo.updatedAt).toUTCString() : undefined;

        const headers = new Headers({
            "Content-Type": MIME_DRILL,
            "Content-Length": String(buf.length),
            "Content-Disposition": `attachment; filename="${slug}${version ? `@${version}` : ""}.drill"`,
            "ETag": etag,
            "Cache-Control": cacheHeader,
        });
        if (lastMod) headers.set("Last-Modified", lastMod);

        if (request.method === "HEAD") {
            return withCors(request, new Response(null, { status: 200, headers }));
        }
        return withCors(request, new Response(buf, { status: 200, headers }));
    } catch (e) {
        return withCors(request, new Response(`Resolve error: ${e.message || e}`, { status: 500 }));
    }
}

/* ------------ helpers ------------ */
function etagMatches(ifNoneMatchHeader, currentEtag) {
    const raw = (ifNoneMatchHeader || "").trim();
    if (!raw) return false;
    if (raw === "*") return true;
    const tokens = raw.split(",").map(t => t.trim());
    return tokens.some(t => t === currentEtag || t === `W/${currentEtag}`);
}
