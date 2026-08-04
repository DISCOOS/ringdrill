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

/// An in-memory stand-in for a Netlify Blobs store, with the two calls the limiter
/// actually makes.
///
/// `getWithMetadata` and the conditional-write options are deliberately absent. The
/// limiter no longer uses either, and a fake that offered them is how two ETag bugs
/// stayed invisible here while breaking production.
function fakeStore({ failRead = false, failWrite = false } = {}) {
    const entries = new Map();
    return {
        entries,
        // Mutable so a test can break a healthy store mid-flight, which is how the
        // "stops reading" case below distinguishes cause from coincidence.
        failRead,
        failWrite,
        async get(key) {
            if (this.failRead) throw new Error("blobs unavailable");
            const hit = entries.get(key);
            return hit ? JSON.parse(hit) : null;
        },
        async set(key, value) {
            if (this.failWrite) throw new Error("read-only");
            entries.set(key, value);
            return { modified: true };
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
    });
    return {
        limiter,
        store,
        count: () => JSON.parse(store.entries.get("caller") ?? "null")?.count,
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
    const h = harness({ limit: 3 });
    await h.limiter.consume("caller", 3);
    assert.equal(h.count(), 3);

    await h.limiter.consume("caller", 1);
    await h.limiter.consume("caller", 1);

    assert.equal(h.count(), 3, "refusals must not increment the counter");
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

test("a looping client is bounded, which is the case that matters", async () => {
    // Sequential calls are what a runaway script and a stuck agent both produce, and
    // this is the bound the limiter genuinely provides.
    const { limiter } = harness({ limit: 20 });

    let allowed = 0;
    for (let i = 0; i < 200; i += 1) {
        if ((await limiter.consume("caller", 1)).allowed) allowed += 1;
    }

    assert.equal(allowed, 20, `budget was 20 but ${allowed} of 200 calls were allowed`);
});

test("concurrent calls undercount, and that is the known trade", async () => {
    // Documented rather than asserted away. A read-modify-write lets simultaneous
    // callers read the same value and the last write win, so a burst can spend more
    // than it is charged for. Two attempts at an exact counter via ETag
    // compare-and-swap each took the endpoint down (see the note in
    // lib/mcp-rate-limit.js); an approximate bound that cannot 429 a healthy caller is
    // the deliberate replacement.
    //
    // The test exists so the weakness is visible in the suite instead of only in
    // production, and so anyone tempted to reintroduce a CAS reads why first.
    const { limiter } = harness({ limit: 5 });

    const verdicts = await Promise.all(
        Array.from({ length: 20 }, () => limiter.consume("caller", 1)),
    );
    const allowed = verdicts.filter((v) => v.allowed).length;

    assert.ok(
        allowed > 5,
        "if this now equals the budget, the counter became atomic and the comment above is stale",
    );
    // The next sequential call still sees a counter and still gets refused, so the
    // leak is bounded to one burst rather than being unbounded over time.
    const after = await limiter.consume("caller", 5);
    assert.equal(after.allowed, false);
});

test("an unreadable store fails open", async () => {
    // A limiter that can take the endpoint down with it is worse than the abuse it
    // prevents. This one guards CPU, not private data.
    const { limiter } = harness({ store: fakeStore({ failRead: true }) });
    const verdict = await limiter.consume("caller", 1);
    assert.equal(verdict.allowed, true);
    assert.equal(verdict.degraded, true);
});

test("an unwritable store fails open", async () => {
    const { limiter } = harness({ store: fakeStore({ failWrite: true }) });
    const verdict = await limiter.consume("caller", 1);
    assert.equal(verdict.allowed, true);
    assert.equal(verdict.degraded, true);
});

test("a store that cannot be constructed fails open", async () => {
    // getStore throws where the Blobs environment is absent, which is every context
    // that is not a deployed function. The packaging suite drives the real default
    // export, so a throw here would 500 rather than degrade.
    const limiter = createRateLimiter({
        blobs: () => {
            throw new Error("MissingBlobsEnvironmentError");
        },
    });
    const verdict = await limiter.consume("caller", 1);
    assert.equal(verdict.allowed, true);
    assert.equal(verdict.degraded, true);
});

test("a store that stops reading releases the limit rather than holding it", async () => {
    // The regression test for both outages, in the form that distinguishes cause from
    // coincidence: refusal must require a value actually read.
    //
    // Spend the whole budget against a healthy store, so a refusal is otherwise
    // guaranteed, then break reads. The answer has to flip back to allowed — the
    // limiter cannot know the caller is over budget, so it must not claim they are.
    // Both outages were the opposite: a store that stopped cooperating produced 429s.
    const store = fakeStore();
    const { limiter } = harness({ limit: 2, store });

    await limiter.consume("caller", 2);
    assert.equal((await limiter.consume("caller", 1)).allowed, false);

    store.failRead = true;
    const verdict = await limiter.consume("caller", 1);
    assert.equal(verdict.allowed, true, "an unreadable counter must not refuse");
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
