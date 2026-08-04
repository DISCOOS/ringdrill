// Rate limiting for the hosted MCP endpoint, done in the function because Netlify
// will not do it for us.
//
// ADR-0060 named a rate limit as one of three abuse controls standing in for
// authentication. Two attempts to declare it failed: `rateLimit` in the function's
// `config` export, and `[redirects.rate_limit]` in netlify.toml. Both are read during
// a deploy's post-processing stage, and this site deploys with `netlify deploy --prod
// --dir=. --functions=...`, which never runs it. Netlify's own config resolver parses
// both forms happily; the deploy then registers neither. Proven against production
// both times: 100 requests in under 4 seconds, 100 answers, no 429.
//
// So it is enforced here instead. That has one advantage over either declarative
// form, beyond actually working: it covers `/.netlify/functions/mcp`, which Netlify
// serves whether or not a redirect names it and which no redirect-level rule can
// reach.
//
// ## What is metered
//
// Tool calls, not protocol traffic. `initialize`, `tools/list` and `resources/read`
// are free: they are how a client discovers the server, they touch no compiler, and
// a client reconnecting should never be told to wait. `search_catalog` is free too —
// it lists blobs and never enters the compiler.
//
// Everything else is metered, and the exempt list is the allowlist rather than the
// other way round, so a tool added later is metered until someone decides otherwise.
// That is the safe direction to be wrong in: every remaining tool reaches the
// cross-compiled Dart, which is synchronous CPU the function cannot yield during.
//
// ## Exact, not approximate
//
// The counter is a compare-and-swap loop on an ETag, the pattern `shared.js` already
// uses for the slug index. Netlify Blobs has no atomic increment, and a plain
// read-modify-write would let two concurrent requests both read 59 and both write 60,
// so a burst could overshoot by however many callers arrive at once — which is
// exactly the case a rate limit exists for. `onlyIfMatch` makes the loser of that
// race retry against the winner's value instead of clobbering it.
//
// ## Fail open
//
// If the store errors, the request proceeds. A rate limiter that can take the
// endpoint down with it is a worse bug than the abuse it prevents, and this one is
// guarding CPU on a free tier, not protecting private data.
import { createHash } from "node:crypto";
import { getStore } from "@netlify/blobs";

/// Requests allowed per window, per caller. Matches the number the declarative
/// attempts used, and the number `/docs/mcp` states.
export const WINDOW_LIMIT = 60;

/// Window length. A fixed window rather than a sliding one: a sliding window needs
/// the timestamps of every request in it, which is a much larger value to read and
/// write per call, for a bound that is no tighter at this scale.
export const WINDOW_MS = 60_000;

/// Namespace for the counters, separate from every other store so a counter can
/// never collide with a document, an artefact or a published plan.
const RATE_LIMIT_NS = "mcp-rate-limit";

/// Compare-and-swap attempts before a contended call is waved through.
///
/// Only genuine contention consumes these — a store that ignores the condition
/// outright is detected on the first rejection and does not loop. Eight is well past
/// what a parallel client produces on one key, and bounded because this sits in front
/// of a compile: a caller must never wait long to be told a number.
const MAX_CAS_ATTEMPTS = 8;

/// Tool calls that do not count against the limit.
///
/// `search_catalog` lists blobs; everything else in the table reaches the compiler.
export const UNMETERED_TOOLS = new Set(["search_catalog"]);

/// JSON-RPC methods that do not count against the limit, whatever they carry.
const UNMETERED_METHODS = new Set([
    "initialize",
    "tools/list",
    "resources/list",
    "resources/read",
    "prompts/list",
    "prompts/get",
    "ping",
]);

function store() {
    // Constructed per call, never memoized — the client bakes in an access token
    // Netlify refreshes per invocation. See the writeup in shared.js.
    return getStore(RATE_LIMIT_NS);
}

/// Counts how many metered tool calls a request body represents.
///
/// Takes the already-parsed messages so a batch costs what it actually asks for: a
/// client that batches five builds should spend five, not one. Notifications (no
/// `id`) still count if they are tool calls, because the work is the same.
export function meteredCalls(messages) {
    let count = 0;
    for (const message of messages) {
        if (!message || typeof message !== "object") continue;
        if (message.method !== "tools/call") continue;
        const name = message.params?.name;
        if (typeof name === "string" && UNMETERED_TOOLS.has(name)) continue;
        count += 1;
    }
    return count;
}

/// True when nothing in this request is metered, so the caller can skip the store
/// entirely. Kept separate from `meteredCalls` for readability at the call site.
export function isUnmeteredMethod(method) {
    return UNMETERED_METHODS.has(method);
}

/// Identifies the caller, as a hash rather than an address.
///
/// Netlify sets `x-nf-client-connection-ip` to the connecting peer, which is the one
/// header a client cannot forge — `x-forwarded-for` is caller-supplied and is only a
/// fallback for local development, where forging it is the point. Hashed because a
/// counter needs to distinguish callers, not identify them, and this endpoint's whole
/// promise is that it does not retain what it is sent. An IP is personal data; its
/// hash under a fixed salt is still linkable, so this is not anonymity — it is not
/// keeping the address in plaintext in a store we do not need it in.
export function clientKey(headers) {
    const direct = headers.get("x-nf-client-connection-ip");
    const forwarded = headers.get("x-forwarded-for");
    const ip = (direct || forwarded?.split(",")[0] || "unknown").trim();
    return createHash("sha256").update(`ringdrill-mcp:${ip}`).digest("hex").slice(0, 32);
}

/// Builds the limiter. Dependencies are injectable so the tests can drive the
/// compare-and-swap loop, including its contention path, without Netlify Blobs.
export function createRateLimiter({
    blobs = store,
    now = () => Date.now(),
    limit = WINDOW_LIMIT,
    windowMs = WINDOW_MS,
    maxAttempts = MAX_CAS_ATTEMPTS,
    // Backoff between lost races, injectable so tests neither sleep nor depend on
    // timing. Tiny: the collision it waits out is one store round-trip.
    pause = (attempt) =>
        new Promise((resolve) => setTimeout(resolve, Math.min(20 * (attempt + 1), 80))),
} = {}) {
    return {
        /// Spends `cost` against `key`'s budget.
        ///
        /// Returns `{ allowed, remaining, retryAfterSeconds }`. When it refuses,
        /// nothing is spent: a request that is turned away should not also push the
        /// caller further past the limit and extend their wait.
        async consume(key, cost) {
            if (cost <= 0) return { allowed: true, remaining: limit };

            // Inside the guard, not above it: `getStore` throws outright when the
            // Blobs environment is absent, which is every context that is not a
            // deployed function — the packaging test drives the real default export,
            // and a throw here would 500 the request rather than degrade it. Failing
            // open starts at construction.
            let s;
            try {
                s = blobs();
            } catch {
                return { allowed: true, remaining: limit, degraded: true };
            }

            for (let attempt = 0; attempt < maxAttempts; attempt += 1) {
                const current = now();
                let entry = null;
                let etag;

                try {
                    // ETag from `getMetadata`, value from `get`, in that order.
                    //
                    // Not `getWithMetadata`, which returns both in one call and is
                    // the obvious thing to reach for — its ETag is not what `set`
                    // compares against, so `onlyIfMatch` never matched and every
                    // write after the very first one failed. The counter sat at 1
                    // while the endpoint served everything. `drills-admin.js` has
                    // been doing it this way (`getBlobEtag` -> `getMetadata`) all
                    // along; this now matches the pattern that works.
                    //
                    // Two reads race, and the order picks which way. ETag first
                    // means a write landing between them leaves the value newer than
                    // the ETag, so the CAS fails and we retry — safe. The reverse
                    // would let a stale value pass a fresh ETag and silently
                    // undercount.
                    etag = (await s.getMetadata(key))?.etag ?? undefined;
                    entry = etag === undefined
                        ? null
                        : await s.get(key, { type: "json" });
                } catch {
                    // Fail open: an unreadable counter must not refuse the request.
                    return { allowed: true, remaining: limit, degraded: true };
                }

                // A window that has run out starts over. Treated the same as a
                // missing entry, so an idle caller is never charged for history.
                const fresh =
                    !entry ||
                    typeof entry.windowStart !== "number" ||
                    current - entry.windowStart >= windowMs;
                const windowStart = fresh ? current : entry.windowStart;
                const used = fresh ? 0 : entry.count ?? 0;

                if (used + cost > limit) {
                    const elapsed = current - windowStart;
                    const retryAfterSeconds = Math.max(
                        1,
                        Math.ceil((windowMs - elapsed) / 1000),
                    );
                    return {
                        allowed: false,
                        remaining: Math.max(0, limit - used),
                        retryAfterSeconds,
                    };
                }

                const next = { windowStart, count: used + cost };
                // A fresh window may be replacing an expired entry that still exists,
                // so `onlyIfNew` is only right when there was nothing to read.
                // Otherwise match the ETag the count was based on.
                const condition =
                    etag === undefined ? { onlyIfNew: true } : { onlyIfMatch: etag };

                let modified;
                try {
                    ({ modified } = await s.set(key, JSON.stringify(next), condition));
                } catch {
                    return { allowed: true, remaining: limit, degraded: true };
                }

                if (modified) {
                    return { allowed: true, remaining: limit - next.count };
                }

                // The write was rejected, and *why* decides what to do. These are two
                // very different situations that the first two versions of this file
                // conflated, once in each direction — allowing everything, then
                // refusing everything.
                //
                // Re-read the ETag. If it moved, another request wrote in between:
                // genuine contention, so retry and recount against what landed. The
                // limit stays exact, which is the whole reason for the CAS.
                //
                // If it did not move, our condition was rejected while the value we
                // matched is still current — the condition is not being honoured at
                // all. That is a broken store contract, not a race, and retrying
                // cannot fix it: this is what silently pinned the counter at 1 in
                // production. Write unconditionally so the count still advances, and
                // say the answer is approximate.
                let settled;
                try {
                    settled = (await s.getMetadata(key))?.etag;
                } catch {
                    return { allowed: true, remaining: limit, degraded: true };
                }

                if (etag !== undefined && settled === etag) {
                    try {
                        await s.set(key, JSON.stringify(next), {});
                    } catch {
                        return { allowed: true, remaining: limit, degraded: true };
                    }
                    return {
                        allowed: true,
                        remaining: limit - next.count,
                        approximate: true,
                    };
                }

                // Real contention. Pause so the retry reads settled state instead of
                // re-entering the same collision.
                await pause(attempt);
            }

            // Eight lost races, every one of them against a counter that moved. This
            // is refused, and getting here now means something specific: a single
            // caller has at least eight metered calls in flight at once.
            //
            // An earlier version refused here too and took the endpoint down, because
            // back then this branch also caught a permanently broken condition — the
            // second metered call of every session landed here. That cause is now
            // detected above and handled with an unconditional write, so what remains
            // is genuine concurrency from one caller, which no authoring session
            // produces and which is the shape of the burst this exists to stop.
            //
            // Allowing instead would leak in exactly the case that matters: with
            // enough callers arriving together, every one of them exhausts its retries
            // and every one gets served. Refusing with a one-second Retry-After costs
            // a busy client a moment and costs an abuser their burst.
            return { allowed: false, remaining: 0, retryAfterSeconds: 1, contended: true };
        },
    };
}
