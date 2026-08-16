// Which Blobs reads are strongly consistent, and why it matters.
//
// Netlify Blobs reads are eventually consistent by default: a write lands and a read
// moments later can still return the previous value, or nothing. Fine for serving the
// catalog, fatal for reading a value in order to decide what to write.
//
// It cost two outages in the MCP rate limiter before anything named the default —
// a counter that would not accumulate, and two ETag compare-and-swaps that "failed"
// when the ETags were simply stale. See lib/mcp-rate-limit.js and ADR-0060.
//
// The tests here are deliberately narrow, because most of this class of bug is not
// assertable offline. A fake store that answers reads immediately cannot reproduce a
// stale read, which is exactly how it hid: every existing suite passed throughout. What
// *is* assertable is which consistency each store accessor asks for, and that is the
// thing a refactor would silently drop — so it is what this pins down. The first block
// documents the failure mode against a fake that does model lag, so the reasoning lives
// somewhere executable rather than only in comments.
import { test } from "node:test";
import assert from "node:assert/strict";

import {
    appOrigin,
    getDrillsStore,
    getDrillsStoreStrong,
    getSlugIndexStore,
    getSlugIndexStoreStrong,
    NS,
} from "../functions/lib/shared.js";

/// Records what each accessor asks `getStore` for.
function spy() {
    const calls = [];
    const fake = (name, options) => {
        calls.push({ name, options });
        return {};
    };
    return { calls, fake };
}

test("the read-then-write accessors ask for strong consistency", () => {
    const { calls, fake } = spy();

    getDrillsStoreStrong(fake);
    getSlugIndexStoreStrong(fake);

    assert.deepEqual(calls, [
        { name: NS.DRILLS, options: { consistency: "strong" } },
        { name: NS.SLUG_INDEX, options: { consistency: "strong" } },
    ]);
});

test("the cached read accessors do not, so the public paths stay fast", () => {
    // The other half of the guard. Making everything strong would be safe and would
    // give up the edge cache on the read-heavy paths — the market feed, /d/<slug>,
    // drills-head and the MCP catalog tools — which only display what they read.
    const { calls, fake } = spy();

    getDrillsStore(fake);
    getSlugIndexStore(fake);

    for (const call of calls) {
        assert.equal(
            call.options,
            undefined,
            `${call.name} must not request strong consistency on the cached read path`,
        );
    }
});

test("an eventually consistent read breaks read-then-write, in both directions", async () => {
    // Not a test of our code. A demonstration, against a store that models lag, of why
    // the accessors above have to differ — kept executable because three separate
    // diagnoses of this bug in production all blamed ETag semantics instead.
    //
    // `lag: 1` means a read answers with the value as of one write ago.
    function laggingStore({ lag = 0 } = {}) {
        const history = [{ value: null, etag: null }];
        let sequence = 0;
        // Writes are always applied to the true head; only reads lag behind it.
        const head = () => history[history.length - 1];
        const visible = () => history[Math.max(0, history.length - 1 - lag)];
        return {
            latest: () => head().value,
            async get() {
                return visible().value;
            },
            async getMetadata() {
                const seen = visible();
                return seen.etag ? { etag: seen.etag } : null;
            },
            async set(_key, value, condition = {}) {
                const current = head();
                if (condition.onlyIfMatch != null && condition.onlyIfMatch !== current.etag) {
                    return { modified: false, etag: current.etag };
                }
                if (condition.onlyIfNew === true && current.value !== null) {
                    return { modified: false, etag: current.etag };
                }
                sequence += 1;
                history.push({ value: JSON.parse(value), etag: `etag-${sequence}` });
                return { modified: true, etag: `etag-${sequence}` };
            },
        };
    }

    /// Append one entry to a list held under a key, guarded by an ETag.
    async function append(store, item) {
        const etag = (await store.getMetadata())?.etag ?? null;
        const current = (await store.get()) ?? { items: [] };
        const next = { items: [...current.items, item] };
        const { modified } = await store.set(
            "k",
            JSON.stringify(next),
            etag ? { onlyIfMatch: etag } : { onlyIfNew: true },
        );
        return modified;
    }

    // Strongly consistent: each append sees the last, and all three survive.
    const strong = laggingStore({ lag: 0 });
    for (const item of ["a", "b", "c"]) {
        assert.equal(await append(strong, item), true, `${item} should have been written`);
    }
    assert.deepEqual((await strong.get()).items, ["a", "b", "c"]);

    // One write behind, and the guard misfires. The second append reads a state that
    // predates the first write, concludes the key is absent, guards with `onlyIfNew`,
    // and is rejected — with nobody else having touched the key. This is the spurious
    // precondition failure: an admin sees "meta changed" when nothing changed.
    const stale = laggingStore({ lag: 1 });
    assert.equal(await append(stale, "a"), true);
    assert.equal(
        await append(stale, "b"),
        false,
        "a stale read makes the guard misfire on a write that had no conflict",
    );

    // Unguarded, the same stale read is worse than a refusal. Both writes land, the
    // second one on a base that never saw the first, and "a" is gone from the stored
    // value. Nothing errors and nothing reports it. This is the lost update that
    // drills-upload's version list was exposed to.
    const unguarded = laggingStore({ lag: 1 });
    const blindAppend = async (item) => {
        const current = (await unguarded.get()) ?? { items: [] };
        await unguarded.set("k", JSON.stringify({ items: [...current.items, item] }), {});
    };
    await blindAppend("a");
    await blindAppend("b");
    assert.deepEqual(
        unguarded.latest().items,
        ["b"],
        "the stale base erased the earlier entry instead of appending to it",
    );
});

// ---------- outgoing link origin ----------

test("appOrigin refuses to guess when PUBLIC_APP_ORIGIN is unset", () => {
    // Both links RingDrill emails are absolute URLs built from this. The
    // hardcoded fallback that used to stand in here is exactly what would
    // defeat the variable the day the apex moves: the setting changes, two
    // files keep mailing the old host, and nothing fails. Taking out *sending*
    // is loud; taking out the destination is silent.
    assert.throws(() => appOrigin({}), /PUBLIC_APP_ORIGIN is unset/);
    assert.throws(() => appOrigin({ PUBLIC_APP_ORIGIN: "   " }), /PUBLIC_APP_ORIGIN is unset/);
});

test("appOrigin trims a trailing slash, so the path does not double it", () => {
    assert.equal(appOrigin({ PUBLIC_APP_ORIGIN: "https://ringdrill.app" }), "https://ringdrill.app");
    assert.equal(appOrigin({ PUBLIC_APP_ORIGIN: "https://ringdrill.app/" }), "https://ringdrill.app");
    assert.equal(appOrigin({ PUBLIC_APP_ORIGIN: "  https://ringdrill.app//  " }), "https://ringdrill.app");
});
