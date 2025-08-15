import { readBinary, getSlugRecord, keysFor, MIME_DRILL } from "./_shared.js";

export default async function (request) {
    try {
        const { pathname } = new URL(request.url);

        // Support both direct function path and a /d/* redirect
        // /.netlify/functions/deep-link/<slug[@ver]>
        // /d/<slug[@ver]>
        let tail = pathname.replace(/^.*\/\.netlify\/functions\/deep-link\//, "");
        if (tail === pathname) tail = pathname.replace(/^\/d\//, ""); // if you hit /d/* directly via redirect

        if (!tail) return new Response("Not found", { status: 404 });

        const [slug, verMaybe] = tail.split("@");
        const rec = await getSlugRecord(slug);
        if (!rec) return new Response("Unknown slug", { status: 404 });

        const { versioned, latest } = keysFor({
            ownerId: rec.ownerId, programId: rec.programId, version: verMaybe || "latest"
        });
        const key = verMaybe ? versioned : latest;

        const buf = await readBinary(key);
        if (!buf) return new Response("Not found", { status: 404 });

        const headers = new Headers({
            "Content-Type": MIME_DRILL,
            "Content-Length": String(buf.length),
            "Content-Disposition": `inline; filename="${verMaybe ? `${slug}@${verMaybe}.drill` : `${slug}.drill`}"`,
        });
        headers.set("Cache-Control", verMaybe ? "public, max-age=31536000, immutable" : "public, max-age=0, must-revalidate");

        return new Response(buf, { status: 200, headers });
    } catch (e) {
        return new Response(`Resolve error: ${e.message || e}`, { status: 500 });
    }
}
