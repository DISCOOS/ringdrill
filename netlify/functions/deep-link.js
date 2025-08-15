import { readBinary, getSlugRecord, keysFor, MIME_DRILL } from "./_shared.js";

export async function handler(event) {
    try {
        const tail = (event.path || "").replace(/^.*\/d\//, "");
        if (!tail) return { statusCode: 404, body: "Not found" };

        const [slug, verMaybe] = tail.split("@");
        const rec = await getSlugRecord(slug);
        if (!rec) return { statusCode: 404, body: "Unknown slug" };

        const { versioned, latest } = keysFor({
            ownerId: rec.ownerId, programId: rec.programId, version: verMaybe || "latest"
        });
        const key = verMaybe ? versioned : latest;

        const buf = await readBinary(key);
        if (!buf) return { statusCode: 404, body: "Not found" };

        const headers = {
            "Content-Type": MIME_DRILL,
            "Cache-Control": verMaybe
                ? "public, max-age=31536000, immutable"
                : "public, max-age=0, must-revalidate",
            "Content-Disposition": `inline; filename="${verMaybe ? `${slug}@${verMaybe}.drill` : `${slug}.drill`}"`,
            "Content-Length": String(buf.length),
        };

        return { statusCode: 200, isBase64Encoded: true, headers, body: buf.toString("base64") };
    } catch (e) {
        return { statusCode: 500, body: `Resolve error: ${e.message || e}` };
    }
}
