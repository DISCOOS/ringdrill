// netlify/functions/deep-link.js
import {
    readBinary,
    getSlugRecord,
    keysFor,
    MIME_DRILL, // "application/vnd.ringdrill+zip"
} from "./_shared.js";

export async function handler(event) {
    try {
        const url = new URL(event.rawUrl ?? buildUrlFromEvent(event));
        const originalPath = url.pathname;

        // Normalize tail: accept both /.netlify/functions/deep-link/... and /d/...
        let tail = originalPath
            .replace(/^.*\/\.netlify\/functions\/deep-link\//, "")
            .replace(/^\/d\//, "")
            .replace(/^\/+/, "");
        if (!tail) return { statusCode: 404, body: "Not found" };

        try { tail = decodeURIComponent(tail); } catch {}

        // Extract version from query if provided
        const queryVersion = (url.searchParams.get("version") || "").trim();

        // Detect if request already has ".drill" (any placement)
        const hasDrillExt = /\.drill(?:$|[/?#])/i.test(tail);

        // Normalize tail by removing .drill wherever it appears (end or after @ver)
        // e.g., "slug.drill@1.2.3" -> "slug@1.2.3", "slug@1.2.3.drill" -> "slug@1.2.3"
        tail = tail
            .replace(/\.drill(@[^/]+)?$/i, (_m, ver) => ver ?? "")   // ... .drill[@ver] at end
            .replace(/(@[^/]+)\.drill$/i, "$1");                     // ... @ver.drill at end

        // Parse "<slug>" or "<slug>@<version>"
        const m = tail.match(/^([^@/]+)(?:@([^/]+))?$/);
        if (!m) return { statusCode: 404, body: "Not found" };

        const slug = m[1];
        const version = (m[2] || queryVersion || "").trim() || null;

        // If the original path did NOT include ".drill", redirect to the canonical .drill URL
        if (!hasDrillExt) {
            const canonical = `/d/${slug}${version ? `@${version}` : ""}.drill`;
            url.pathname = canonical;
            url.search = ""; // strip query once canonicalized
            return {
                statusCode: 301,
                headers: { Location: url.toString() },
                body: "",
            };
        }

        // Already a .drill URL -> serve the file (attachment)
        const rec = await getSlugRecord(slug);
        if (!rec) return { statusCode: 404, body: "Unknown slug" };

        const { versioned, latest } = keysFor({
            ownerId: rec.ownerId,
            programId: rec.programId,
            version: version || "latest",
        });
        const key = version ? versioned : latest;

        const buf = await readBinary(key);
        if (!buf) return { statusCode: 404, body: "Not found" };

        const filename = `${slug}${version ? `@${version}` : ""}.drill`;
        const headers = {
            "Content-Type": MIME_DRILL, // application/vnd.ringdrill+zip
            "Content-Disposition": `attachment; filename="${filename}"`,
            "Content-Length": String(buf.length),
            "Cache-Control": version
                ? "public, max-age=31536000, immutable"
                : "public, max-age=0, must-revalidate",
        };

        return {
            statusCode: 200,
            isBase64Encoded: true,
            headers,
            body: buf.toString("base64"),
        };
    } catch (e) {
        return { statusCode: 500, body: `Resolve error: ${e.message || e}` };
    }
}

/* ------------ helpers ------------ */
function buildUrlFromEvent(event) {
    const h = event.headers || {};
    const proto = h["x-forwarded-proto"] || "https";
    const host  = h["x-forwarded-host"]  || h["host"];
    const qs    = event.rawQuery ? `?${event.rawQuery}` : "";
    return `${proto}://${host}${event.path}${qs}`;
}
