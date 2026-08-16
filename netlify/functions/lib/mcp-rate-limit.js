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
// ## The counter, and the one default that broke it three times
//
// Read, decide, write, against a **strongly consistent** store. That flag is the whole
// story, and it is worth the space because three different-looking failures were all
// the same bug wearing different clothes.
//
// Netlify Blobs reads are eventually consistent by default. A write lands and a read
// moments later can still return the previous value, or nothing. Every attempt at this
// counter was built on reads that were quietly stale:
//
//   1. Plain read-modify-write. Never accumulated: each request read a value from
//      before its predecessor's write, so the count hovered near zero and the endpoint
//      served everything while reporting a limit.
//   2. Compare-and-swap on the ETag from `getWithMetadata`. Diagnosed as "the wrong
//      ETag source". It was not — the ETag came back stale, so `onlyIfMatch` could not
//      match, every write after the first failed, and the counter sat at 1.
//   3. Compare-and-swap on the ETag from `getMetadata`, with logic to tell genuine
//      contention from a rejected condition. The stale ETag kept changing between
//      reads, so that logic concluded contention every time, exhausted its retries,
//      and refused the second metered call of every session. That one took the
//      endpoint down.
//
// Two outages and three diagnoses, none of which named the default. With strong reads
// the simplest version is also the correct one, so there is no compare-and-swap here:
// Blobs has no atomic increment, so concurrent callers can still read the same value
// and the last write wins. Under concurrency this undercounts. It bounds a client
// looping, which is what a runaway script and a stuck agent both are, and between them
// the realistic way this endpoint gets hammered.
//
// ## Fail open, and now only ever open
//
// Every store failure allows the request. There is exactly one refusal path and it
// fires only on a value successfully read. A rate limiter that can take the endpoint
// down with it is a worse bug than the abuse it prevents — this guards CPU on a free
// tier, not private data — and having proven that twice, the property is now
// structural rather than intended.
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
    //
    // `consistency: "strong"` is load-bearing, and its absence is the single fault
    // behind every failure this file records. Netlify Blobs reads are **eventually
    // consistent by default**: a write lands, and a read moments later can still
    // return the previous value or nothing at all. A counter cannot be built on that.
    //
    // It explains all three symptoms at once, which is why they resisted three
    // separate fixes. The plain read-modify-write never accumulated, because each
    // request read a value from before its predecessor's write. Both ETag
    // compare-and-swaps failed for the same reason one layer down — the ETag read back
    // was the stale one, so `onlyIfMatch` could not match, and the code that tried to
    // tell contention from a broken condition saw a changing ETag and concluded
    // contention. None of it was about ETag semantics. It was a stale read.
    //
    // Strong reads cost a little latency per metered call, in front of a compile that
    // costs far more.
    return getStore(RATE_LIMIT_NS, { consistency: "strong" });
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

/// Builds the limiter. Dependencies are injectable so every path here — including
/// both fail-open branches — is exercised offline, without Netlify Blobs.
export function createRateLimiter({
    blobs = store,
    now = () => Date.now(),
    limit = WINDOW_LIMIT,
    windowMs = WINDOW_MS,
} = {}) {
    return {
        /// Spends `cost` against `key`'s budget.
        ///
        /// Returns `{ allowed, remaining, retryAfterSeconds }`. When it refuses,
        /// nothing is spent: a request that is turned away should not also push the
        /// caller further past the limit and extend their own wait.
        ///
        /// Read, decide, write. No compare-and-swap, and that is a deliberate retreat
        /// rather than an oversight — see the note at the top of this file for the two
        /// outages that bought the lesson.
        ///
        /// The consequence, stated plainly: concurrent calls can undercount. Several
        /// arriving together all read the same value and the last write wins, so a
        /// caller with N requests genuinely in flight can slip through with fewer
        /// counted than they spent. What this does still catch is a client looping —
        /// which is what a runaway script and an agent stuck in a retry both are, and
        /// between them they are the realistic way this endpoint gets hammered.
        ///
        /// The refusal path is the important property now. There is exactly one, and
        /// it fires only on a value successfully read from the store. Every failure —
        /// unreachable store, unreadable entry, rejected write — allows the request.
        /// It is not possible for a store problem to turn into a 429, which is the
        /// mode that took the endpoint down twice.
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

            const current = now();
            let entry;
            try {
                entry = await s.get(key, { type: "json" });
            } catch {
                return { allowed: true, remaining: limit, degraded: true };
            }

            // A window that has run out starts over, treated the same as a missing
            // entry, so an idle caller is never charged for history.
            const fresh =
                !entry ||
                typeof entry.windowStart !== "number" ||
                current - entry.windowStart >= windowMs;
            const windowStart = fresh ? current : entry.windowStart;
            const used = fresh ? 0 : entry.count ?? 0;

            if (used + cost > limit) {
                const retryAfterSeconds = Math.max(
                    1,
                    Math.ceil((windowMs - (current - windowStart)) / 1000),
                );
                return {
                    allowed: false,
                    remaining: Math.max(0, limit - used),
                    retryAfterSeconds,
                };
            }

            try {
                await s.set(key, JSON.stringify({ windowStart, count: used + cost }));
            } catch {
                // The call is allowed; it simply went uncounted.
                return { allowed: true, remaining: limit - used - cost, degraded: true };
            }

            return { allowed: true, remaining: limit - used - cost };
        },

        /// Gives `cost` back to `key`, for work that was allowed and then did not
        /// happen.
        ///
        /// `consume` has to spend before the work, because the decision is what
        /// gates it. When the work then fails for a reason that has nothing to do
        /// with the caller — a provider outage, say — the spend was a charge for
        /// nothing, and the caller is left unable to retry the thing that never
        /// occurred. That is not a theoretical case: three sign-in attempts that
        /// 500'd inside the mailer emptied a real person's budget without a single
        /// mail being sent.
        ///
        /// Only ever refunds within the current window, and never below zero. A
        /// refund arriving after the window rolled over must not resurrect it: that
        /// would hand back budget the caller already got for free, and — worse — let
        /// a caller who can reliably make the work fail spend an unbounded number of
        /// times inside one window.
        ///
        /// Silent on every failure, like the rest of this file. A refund that cannot
        /// be written costs the caller some budget; a refund that throws costs them
        /// the request.
        async refund(key, cost) {
            if (cost <= 0) return;

            let s;
            try {
                s = blobs();
            } catch {
                return;
            }

            try {
                const entry = await s.get(key, { type: "json" });
                if (!entry || typeof entry.windowStart !== "number") return;
                if (now() - entry.windowStart >= windowMs) return;

                const count = Math.max(0, (entry.count ?? 0) - cost);
                await s.set(key, JSON.stringify({ windowStart: entry.windowStart, count }));
            } catch {
                // Uncounted, like a failed write in `consume`.
            }
        },
    };
}
