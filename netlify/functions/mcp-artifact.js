// Downloads an archive that `build_plan` just compiled (ADR-0070).
//
// The hosted MCP endpoint used to answer a build with ~100 KB of base64 inside the
// tool result's text block. A cold run from ChatGPT/Codex is what proved that unusable:
// every tool succeeded and the client still could not write a `.drill` file, because a
// long text block gets truncated and an agent cannot re-derive bytes it was shown. So
// the archive is held for a short window and handed over as a URL, and this serves it.
//
// ## Its own function, not a GET on /mcp
//
// Two reasons, both about what each function has to load. `mcp.js` carries the 737 KB
// cross-compiled compiler, and a byte read has no business paying for it. And `/mcp`
// answers 405 to GET on purpose — that is how a stateless Streamable HTTP server says
// it has nothing to push (ADR-0060) — which is a claim worth keeping true.
//
// ## What it will and will not serve
//
// Only what this deploy built, only under the compiler's own `contentHash`, only until
// the entry expires. There is no listing, no delete and no way to name a key: a client
// cannot ask for anything it was not already given a hash for, and a hash is only
// obtainable by having built that exact plan. The URL is a capability key, in the same
// family as an unguessable share link — which also means whoever holds it holds the
// archive until it expires. That is the mechanism, not a leak, and ADR-0070 says so.
import { getStore } from "@netlify/blobs";
import { MIME_DRILL, corsPreflight, withCors } from "./lib/shared.js";
import {
    ARTIFACT_CACHE_NS,
    ARTIFACT_TTL_MS,
    artifactKey,
    isFresh,
} from "./lib/mcp-artifact-store.js";

/// The hash in `/mcp/artifact/<hash>.drill`, or null if the path is not that shape.
///
/// Anchored to exactly 64 hex characters — the only thing a `contentHash` ever is — so
/// a traversal attempt or a probe for some other key never reaches the store.
///
/// Matched on the final segment rather than the full alias, because the function is
/// reachable two ways: through the `/mcp/artifact/*` rewrite, and directly at
/// `/.netlify/functions/mcp-artifact/<hash>.drill`, which Netlify serves natively and
/// `netlify functions:serve` is the only thing that offers locally. `deep-link.js`
/// handles the same pair for the same reason.
export function hashFromPath(pathname) {
    const match = /\/([0-9a-f]{64})\.drill$/.exec(pathname);
    return match ? match[1] : null;
}

export function createHandler({ store = () => getStore(ARTIFACT_CACHE_NS) } = {}) {
    return async function (request) {
        const preflight = corsPreflight(request);
        if (preflight) return preflight;

        if (request.method !== "GET" && request.method !== "HEAD") {
            return withCors(
                request,
                new Response("Method not allowed", {
                    status: 405,
                    headers: { allow: "GET, HEAD, OPTIONS" },
                }),
            );
        }

        const hash = hashFromPath(new URL(request.url).pathname);
        // Deliberately the same answer as an expired entry below. A malformed path
        // and a hash we do not hold are the same fact from the client's side, and
        // distinguishing them would confirm which hashes exist.
        if (!hash) return withCors(request, notFound());

        // One store per invocation, reused within it. Constructing it per *call* is
        // the rule (the access token Netlify refreshes per invocation is baked in,
        // which is why `shared.js` forbids memoizing one across a warm container);
        // constructing two inside one request would just be waste.
        const blobs = store();
        const key = artifactKey(hash);
        const entry = await blobs.get(key, { type: "json" });
        if (!isFresh(entry)) {
            // Delete on an expired read rather than only on a sweep: the promise is
            // that an entry does not outlive its window, and the read is the moment
            // we know it has. Same reasoning as the document cache.
            if (entry) await blobs.delete(key);
            return withCors(request, notFound());
        }

        const bytes = Buffer.from(entry.base64, "base64");
        const headers = new Headers({
            "Content-Type": MIME_DRILL,
            "Content-Length": String(bytes.length),
            "Content-Disposition":
                `attachment; filename="${entry.fileName ?? "plan.drill"}"`,
            // Content-addressed, so the bytes under a hash cannot change — but the
            // entry expires, and a cache that outlived it would serve an archive the
            // retention window promised was gone.
            "Cache-Control": "private, no-store",
        });

        if (request.method === "HEAD") {
            return withCors(request, new Response(null, { status: 200, headers }));
        }
        return withCors(request, new Response(bytes, { status: 200, headers }));
    };
}

function notFound() {
    return new Response(
        "No archive is held under that hash — it was never built here, or it has " +
            `expired (archives are held for ${Math.round(ARTIFACT_TTL_MS / 60000)} ` +
            "minutes). Build the plan again to get a fresh link.\n",
        { status: 404, headers: { "Content-Type": "text/plain; charset=utf-8" } },
    );
}

export default createHandler();
