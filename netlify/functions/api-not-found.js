import { corsPreflight, withCors, nowIso } from "./_shared.js";

// Catch-all for unknown /api/* paths. Without this, unmatched /api/ requests
// fall through netlify.toml to the SPA rewrite (`/* -> /index.html`) and the
// caller gets the Flutter app shell with HTTP 200 instead of a clear error.
// The netlify.toml `/api/*` rewrite (status 200) routes here last, after every
// real /api/ endpoint, and this function returns a JSON 404.
export default async function (request) {
    const preflight = corsPreflight(request);
    if (preflight) return preflight;

    const url = new URL(request.url);

    const body = {
        error: "not_found",
        message: `No API endpoint matches ${request.method} ${url.pathname}`,
        endpoints: [
            "GET /api/market-feed",
            "GET /api/drills-head/{slug}",
            "GET /api/drills-admin (admin)",
            "POST /api/drills-upload (admin)",
        ],
        docs: "https://github.com/DISCOOS/ringdrill/blob/main/docs/api.md",
    };

    return withCors(request, new Response(JSON.stringify(body, null, 2), {
        status: 404,
        headers: {
            "content-type": "application/json",
            "cache-control": "no-store",
            "x-generated-at": nowIso(),
        },
    }));
}
