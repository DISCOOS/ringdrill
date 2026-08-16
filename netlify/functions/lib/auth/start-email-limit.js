import { createHash } from "node:crypto";
import { getStore } from "@netlify/blobs";

import { createRateLimiter } from "../mcp-rate-limit.js";

/**
 * The abuse bound on `POST /api/auth/start-email` (ADR-0079).
 *
 * That endpoint takes any address and sends mail to it with no token, and it
 * cannot do otherwise: the email *is* how authentication starts, so at the
 * moment it is called there is no credential in existence to check. What is
 * left is bounding the damage.
 *
 * **Two counters, doing different jobs.** The per-recipient one is the point:
 * it caps how much mail one address can be sent *regardless of who asked*, so
 * no amount of IP rotation, proxying or distribution lets anyone flood a chosen
 * person's inbox. The per-source one caps how many different addresses one
 * origin can walk through, which protects the Resend quota and the function
 * meter. Source limiting alone is defeated by the cheapest thing an abuser can
 * do, which is why it is the second counter here rather than the only one.
 *
 * **A refusal is silent.** The caller gets the same response either way — same
 * shape, same status — and only the send is suppressed. Returning 429 would
 * answer the question the endpoint is deliberately built not to answer: whether
 * a given address is worth mailing. `start-email` creates a challenge for any
 * syntactically valid address and resolves identity only at `callback`, and a
 * visible rate limit would hand back the enumeration oracle that design avoids.
 * This is the one place where the usual advice to make throttling observable is
 * the wrong advice.
 *
 * Refusals are logged instead, because they still need to be visible to *us*.
 *
 * The counter itself is `createRateLimiter` from the MCP limiter, unchanged.
 * Everything hard about it — strong reads, and the fail-open property that two
 * outages bought — is documented there and applies here for the same reasons.
 */

/** Emails to one address per hour, counted whoever asks. */
export const RECIPIENT_LIMIT = Number(process.env.START_EMAIL_RECIPIENT_LIMIT ?? 3);

/** Distinct sign-in attempts from one source per hour. */
export const SOURCE_LIMIT = Number(process.env.START_EMAIL_SOURCE_LIMIT ?? 20);

export const WINDOW_MS = 60 * 60 * 1000;

const NS = "start-email-limit";

/**
 * Counter keys are hashes, never the address or the IP.
 *
 * A counter needs to tell callers apart, not identify them. An email address is
 * the most personal thing this endpoint handles — it belongs to somebody who
 * may have no account and never asked for anything — and there is no reason for
 * it to sit in plaintext in a store whose only job is counting to three. The
 * prefixes keep the two keyspaces from ever colliding.
 */
export function recipientKey(email) {
    const normalised = String(email ?? "").trim().toLowerCase();
    return `to:${createHash("sha256").update(`ringdrill-start-email:${normalised}`).digest("hex").slice(0, 32)}`;
}

export function sourceKey(headers) {
    // `x-nf-client-connection-ip` is the connecting peer and the one header a
    // client cannot forge. `x-forwarded-for` is caller-supplied and is a local
    // development fallback only — forging it there is the point.
    const direct = headers?.get?.("x-nf-client-connection-ip");
    const forwarded = headers?.get?.("x-forwarded-for");
    const ip = (direct || forwarded?.split(",")[0] || "unknown").trim();
    return `from:${createHash("sha256").update(`ringdrill-start-email:${ip}`).digest("hex").slice(0, 32)}`;
}

function store() {
    // Never memoized, and strongly consistent. Both for the reasons written up
    // at length in lib/mcp-rate-limit.js — the second one is load-bearing and
    // its absence is the bug that took that endpoint down twice.
    return getStore(NS, { consistency: "strong" });
}

/**
 * Whether this request may actually send.
 *
 * **Source is checked first, and the recipient counter is only spent if it
 * passes.** Charging the recipient for a request that was never going to send
 * would let a flood from one exhausted origin eat a real person's budget, and
 * the recipient counter is the one that must stay meaningful.
 *
 * Fails open at every step, inherited from `createRateLimiter`: a store problem
 * allows the send. A limiter that can stop people signing in is a worse fault
 * than the abuse it prevents.
 */
export function createStartEmailLimiter({
    blobs = store,
    now = () => Date.now(),
    recipientLimit = RECIPIENT_LIMIT,
    sourceLimit = SOURCE_LIMIT,
    windowMs = WINDOW_MS,
} = {}) {
    const bySource = createRateLimiter({ blobs, now, limit: sourceLimit, windowMs });
    const byRecipient = createRateLimiter({ blobs, now, limit: recipientLimit, windowMs });

    return {
        async allowSend({ email, headers }) {
            const source = await bySource.consume(sourceKey(headers), 1);
            if (!source.allowed) return { allowed: false, reason: "source" };

            const recipient = await byRecipient.consume(recipientKey(email), 1);
            if (!recipient.allowed) return { allowed: false, reason: "recipient" };

            return { allowed: true };
        },
    };
}
