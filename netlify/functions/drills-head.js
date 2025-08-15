import { getBlob } from "@netlify/blobs";
import { getSlugRecord, keysFor } from "./_shared.js";

/**
 * HEAD /api/drills/head/:slug[@version]
 * Returns headers only (ETag, Content-Length, Last-Modified if available).
 */
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

        const { versioned, latest } = keysFor({
            ownerId: rec.ownerId,
            programId: rec.programId,
            version: verMaybe || "latest"
        });
        const key = verMaybe ? versioned : latest;

        const blob = await getBlob({ key });
        if (!blob) return { statusCode: 404, body: "Not found" };

        const headers = {
            "Content-Type": blob.contentType || "application/octet-stream",
            "Cache-Control": verMaybe
                ? "public, max-age=31536000, immutable"
                : "public, max-age=0, must-revalidate"
        };
        if (blob.etag) headers["ETag"] = blob.etag;
        if (blob.size) headers["Content-Length"] = String(blob.size);
        if (blob.lastModified) headers["Last-Modified"] = new Date(blob.lastModified).toUTCString();

        // HEAD: no body. (On GET, we still return no body to keep it simple.)
        return { statusCode: 200, headers, body: "" };
    } catch (e) {
        return { statusCode: 500, body: `HEAD error: ${e.message || e}` };
    }
}
