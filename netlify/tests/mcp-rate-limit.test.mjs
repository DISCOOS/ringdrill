// The in-function rate limiter (lib/mcp-rate-limit.js).
//
// This exists because the two declarative attempts did not, and could not be proven
// wrong except by bursting production. The whole reason for enforcing in the function
// is that the behaviour becomes testable here — including the compare-and-swap
// contention path, which is the part a production burst is least likely to exercise
// on purpose and most likely to hit by accident.
import { test } from "node:test";
import assert from "node:assert/strict";

import {
    clientKey,
    createRateLimiter,
    meteredCalls,
    WINDOW_LIMIT,
    WINDOW_MS,
} from "../functions/lib/mcp-rate-limit.js";

/// An in-memory stand-in for a Netlify Blobs store, with the ETag semantics the
/// limiter depends on: `set` honours `onlyIfMatch`/`onlyIfNew` and reports
/// `modified: false` when the condition fails, rather than throwing.
function fakeStore({ etagNeverMatches = false } = {}) {
    const entries = new Map();
    let sequence = 0;
    return {
        entries,
        calls: { get: 0, set: 0 },
        // Split reads, mirroring what the limiter actually calls. `getWithMetadata`
        // is deliberately absent: using it is the bug this fake now makes impossible
        // to reintroduce silently.
        async getMetadata(key) {
            const hit = entries.get(key);
            if (!hit) return null;
            // When `etagNeverMatches`, hand back an ETag that will not satisfy
            // `onlyIfMatch` — reproducing production, where getWithMetadata's ETag
            // was not the one `set` compares.
            return { etag: etagNeverMatches ? `${hit.etag}-wrong` : hit.etag };
        },
        async get(key, _opts) {
            this.calls.get += 1;
            const hit = entries.get(key);
            return hit ? JSON.parse(hit.value) : null;
        },
        async set(key, value, condition = {}) {
            this.calls.set += 1;
            const hit = entries.get(key);
            if (condition.onlyIfNew === true && hit) {
                return { modified: false, etag: hit.etag };
            }
            // An unconditional write ({}) always lands, which is what the limiter's
            // final attempt relies on.
            if (condition.onlyIfMatch != null && hit?.etag !== condition.onlyIfMatch) {
                return { modified: false, etag: hit?.etag };
            }
            sequence += 1;
            const etag = `etag-${sequence}`;
            entries.set(key, { value, etag });
            return { modified: true, etag };
        },
    };
}

/// A limiter over a fake store with a clock the test drives.
function harness({ limit = WINDOW_LIMIT, store = fakeStore() } = {}) {
    let clock = 1_000_000;
    const limiter = createRateLimiter({
        blobs: () => store,
        now: () => clock,
        limit,
        // No real waiting in tests.
        pause: async () => {},
    });
    return {
        limiter,
        store,
        advance: (ms) => {
            clock += ms;
        },
    };
}

test("protocol traffic and search_catalog cost nothing", () => {
    // Introspection has to stay free: it is how a client connects, and telling a
    // reconnecting client to wait would break discovery rather than curb abuse.
    assert.equal(meteredCalls([{ method: "initialize", id: 1 }]), 0);
    assert.equal(meteredCalls([{ method: "tools/list", id: 2 }]), 0);
    assert.equal(meteredCalls([{ method: "resources/read", id: 3 }]), 0);
    assert.equal(
        meteredCalls([{ method: "tools/call", id: 4, params: { name: "search_catalog" } }]),
        0,
    );
});

test("every other tool call costs one, including ones added later", () => {
    for (const name of ["schema", "get_plan", "create_plan", "analyze_plan", "build_plan", "render_plan"]) {
        assert.equal(
            meteredCalls([{ method: "tools/call", id: 1, params: { name } }]),
            1,
            `${name} should be metered`,
        );
    }
    // The exempt list is an allowlist, so an unknown tool is metered by default.
    // That is the safe direction: every tool but one reaches the compiler.
    assert.equal(
        meteredCalls([{ method: "tools/call", id: 1, params: { name: "some_future_tool" } }]),
        1,
    );
});

test("a batch costs what it asks for, not one", () => {
    const batch = [
        { method: "initialize", id: 1 },
        { method: "tools/call", id: 2, params: { name: "build_plan" } },
        { method: "tools/call", id: 3, params: { name: "build_plan" } },
        { method: "tools/call", id: 4, params: { name: "search_catalog" } },
        { method: "tools/call", params: { name: "render_plan" } }, // notification
    ];
    // Two builds plus one render. The notification counts: the work is the same
    // whether or not the client wants an answer.
    assert.equal(meteredCalls(batch), 3);
});

test("spends up to the limit, then refuses with a retry hint", async () => {
    const { limiter } = harness({ limit: 5 });

    for (let i = 1; i <= 5; i += 1) {
        const verdict = await limiter.consume("caller", 1);
        assert.equal(verdict.allowed, true, `call ${i} should be allowed`);
        assert.equal(verdict.remaining, 5 - i);
    }

    const refused = await limiter.consume("caller", 1);
    assert.equal(refused.allowed, false);
    assert.equal(refused.remaining, 0);
    assert.ok(
        refused.retryAfterSeconds >= 1 && refused.retryAfterSeconds <= 60,
        `retryAfterSeconds should be a usable wait, got ${refused.retryAfterSeconds}`,
    );
});

test("a refused request spends nothing", async () => {
    // Otherwise a client retrying in a loop pushes its own window out and can never
    // recover inside it.
    const { limiter, store } = harness({ limit: 3 });
    await limiter.consume("caller", 3);

    const before = JSON.parse(store.entries.get("caller").value).count;
    await limiter.consume("caller", 1);
    await limiter.consume("caller", 1);
    const after = JSON.parse(store.entries.get("caller").value).count;

    assert.equal(before, 3);
    assert.equal(after, 3, "refusals must not increment the counter");
});

test("a batch larger than the whole budget is refused outright", async () => {
    const { limiter } = harness({ limit: 5 });
    const verdict = await limiter.consume("caller", 6);
    assert.equal(verdict.allowed, false);
    assert.equal(verdict.remaining, 5);
});

test("the window resets, and an idle caller is not charged for history", async () => {
    const { limiter, advance } = harness({ limit: 2 });
    await limiter.consume("caller", 2);
    assert.equal((await limiter.consume("caller", 1)).allowed, false);

    advance(WINDOW_MS);
    const afterWindow = await limiter.consume("caller", 1);
    assert.equal(afterWindow.allowed, true, "a new window starts fresh");
    assert.equal(afterWindow.remaining, 1);
});

test("callers have separate budgets", async () => {
    const { limiter } = harness({ limit: 1 });
    assert.equal((await limiter.consume("alice", 1)).allowed, true);
    assert.equal((await limiter.consume("bob", 1)).allowed, true);
    assert.equal((await limiter.consume("alice", 1)).allowed, false);
});

test("concurrent calls cannot overshoot the limit", async () => {
    // The reason the counter is a compare-and-swap rather than a read-modify-write.
    // Twenty simultaneous calls against a budget of five must yield five, not twenty:
    // a plain increment would have them all read 0 and all write 1.
    const { limiter } = harness({ limit: 5 });

    const verdicts = await Promise.all(
        Array.from({ length: 20 }, () => limiter.consume("caller", 1)),
    );
    const allowed = verdicts.filter((v) => v.allowed && !v.degraded).length;

    assert.equal(allowed, 5, `expected exactly 5 allowed, got ${allowed}`);
});

test("no burst gets through, however concurrent", async () => {
    // The production case, scaled up: 100 concurrent calls against a budget of 60 were
    // all served. Nothing may exceed the budget no matter how many arrive at once.
    const { limiter } = harness({ limit: 10 });

    const verdicts = await Promise.all(
        Array.from({ length: 200 }, () => limiter.consume("caller", 1)),
    );
    const allowed = verdicts.filter((v) => v.allowed).length;

    // The invariant is the ceiling, not the exact figure. Under contention this deep
    // some budget goes unspent, because a caller that exhausts its retries is refused
    // while room technically remained. Erring downward is the right direction: the
    // guarantee worth having is that a burst can never exceed the budget.
    assert.ok(allowed > 0, "the limiter must not refuse everything");
    assert.ok(
        allowed <= 10,
        `budget was 10 but ${allowed} of 200 concurrent calls were allowed`,
    );
});

test("the limit still holds when the ETag never matches", async () => {
    // The regression test for the bug that shipped: the ETag came from
    // `getWithMetadata`, `set` compared something else, so every write after the first
    // failed and the counter stayed at 1 while production served everything. The
    // symptom was invisible — no error, no throw, all tests green.
    //
    // The unconditional final attempt is what makes this survivable. The count must
    // still advance and the limit must still bite, even with the CAS permanently
    // broken.
    const { limiter } = harness({
        limit: 3,
        store: fakeStore({ etagNeverMatches: true }),
    });

    assert.equal((await limiter.consume("caller", 1)).allowed, true);
    assert.equal((await limiter.consume("caller", 1)).allowed, true);
    assert.equal((await limiter.consume("caller", 1)).allowed, true);

    const refused = await limiter.consume("caller", 1);
    assert.equal(
        refused.allowed,
        false,
        "the counter must advance even when the compare-and-swap cannot",
    );
});

test("a broken ETag degrades to approximate rather than to nothing", async () => {
    // And it says so, so the distinction is observable rather than inferred from
    // behaviour in production.
    const { limiter } = harness({
        limit: 10,
        store: fakeStore({ etagNeverMatches: true }),
    });
    // The first call creates the entry via `onlyIfNew` and is exact; only from the
    // second on does the broken `onlyIfMatch` come into play.
    const first = await limiter.consume("caller", 1);
    assert.equal(first.allowed, true);
    assert.equal(first.approximate, undefined);

    const verdict = await limiter.consume("caller", 1);
    assert.equal(verdict.allowed, true);
    assert.equal(verdict.approximate, true);

    // Where the CAS works, it stays exact and says nothing.
    const healthy = harness({ limit: 10 });
    const exact = await healthy.limiter.consume("caller", 1);
    assert.equal(exact.allowed, true);
    assert.equal(exact.approximate, undefined);
});

test("an unreadable store fails open", async () => {
    // A limiter that can take the endpoint down with it is worse than the abuse it
    // prevents. This one guards CPU, not private data.
    const limiter = createRateLimiter({
        pause: async () => {},
        blobs: () => ({
            async getMetadata() {
                throw new Error("blobs unavailable");
            },
            async get() {
                throw new Error("blobs unavailable");
            },
            async set() {
                throw new Error("blobs unavailable");
            },
        }),
    });

    const verdict = await limiter.consume("caller", 1);
    assert.equal(verdict.allowed, true);
    assert.equal(verdict.degraded, true);
});

test("an unwritable store fails open", async () => {
    const limiter = createRateLimiter({
        pause: async () => {},
        blobs: () => ({
            async getMetadata() {
                return null;
            },
            async get() {
                return null;
            },
            async set() {
                throw new Error("read-only");
            },
        }),
    });

    const verdict = await limiter.consume("caller", 1);
    assert.equal(verdict.allowed, true);
    assert.equal(verdict.degraded, true);
});

test("the caller key comes from the connection IP and is not the IP", async () => {
    const headers = new Headers({
        "x-nf-client-connection-ip": "203.0.113.7",
        "x-forwarded-for": "198.51.100.1, 203.0.113.7",
    });
    const key = clientKey(headers);

    assert.doesNotMatch(key, /203\.0\.113\.7/, "the address must not be stored");
    assert.match(key, /^[0-9a-f]{32}$/);

    // Netlify's own header wins over the client-supplied one, which is forgeable —
    // otherwise a caller could reset their own budget per request.
    const spoofed = clientKey(
        new Headers({
            "x-nf-client-connection-ip": "203.0.113.7",
            "x-forwarded-for": "10.0.0.99",
        }),
    );
    assert.equal(spoofed, key);

    // Different callers must not collide.
    assert.notEqual(
        key,
        clientKey(new Headers({ "x-nf-client-connection-ip": "203.0.113.8" })),
    );
});
