import { getBlob } from "@netlify/blobs";
import { getSlugRecord, keysFor } from "../functions/_shared.js";

/**
 * Handles:
 *   /d/:slug           -> latest
 *   /d/:slug@1.2.3     -> specific version
 *
 * Returns the raw .drill bytes with proper headers.
 */
export default async (request, context) => {
    try {
        const url = new URL(request.url);
        const tail = url.pathname.replace(/^\/d\//, "");
        if (!tail) return new Response("Not found", { status: 404 });

        const [slug, verMaybe] = tail.split("@");
        const record = await getSlugRecord(slug);
        if (!record) return new Response("Unknown slug", { status: 404 });

        const { ownerId, programId } = record;
        const { versioned, latest } = keysFor({
            ownerId,
            programId,
            version: verMaybe || "latest"
        });

        const key = verMaybe ? versioned : latest;
        const blob = await getBlob({ key });
        if (!blob?.body) return new Response("Not found", { status: 404 });

        // Pass through blob with cache/etag semantics (Edge runtime)
        const headers = new Headers();
        headers.set("Content-Type", blob.contentType || "application/octet-stream");
        // If SDK surfaces etag, include it; otherwise clients rely on versioned URLs.
        if (blob.etag) headers.set("ETag", blob.etag);
        headers.set("Cache-Control", verMaybe
            ? "public, max-age=31536000, immutable"
            : "public, max-age=0, must-revalidate");

        // Optional: filename hint
        const filename = verMaybe ? `${slug}@${verMaybe}.drill` : `${slug}.drill`;
        headers.set("Content-Disposition", `inline; filename="${filename}"`);

        return new Response(blob.body, { status: 200, headers });
    } catch (e) {
        return new Response(`Resolve error: ${e.message || e}`, { status: 500 });
    }
};

export const config = { path: "/d/*" };
