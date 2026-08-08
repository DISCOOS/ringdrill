/**
 * The one-off move to ADR-0074's key layout.
 *
 * The ordering is the risk, so it is what the tests are about: copy first,
 * repoint second, delete last. A dry run must touch nothing, a half-run must be
 * resumable, and cleanup must refuse to run ahead of a copy.
 */
import { test } from "node:test";
import assert from "node:assert/strict";

import { cleanupCatalogKeys, migrateCatalogKeys } from "../functions/lib/migrate-catalog.js";
import { findEntry, keysForEntry, slugIndexKey } from "../functions/lib/catalog.js";

function fakeStore(seed = {}) {
    const data = new Map(Object.entries(seed));
    return {
        data,
        async get(key, opts) {
            const raw = data.get(key);
            if (raw === undefined) return null;
            if (opts?.type === "json") return typeof raw === "string" ? JSON.parse(raw) : raw;
            if (opts?.type === "arrayBuffer") return Buffer.isBuffer(raw) ? raw : Buffer.from(String(raw));
            return raw;
        },
        async set(key, value) { data.set(key, value); return { modified: true }; },
        async delete(key) { data.delete(key); },
        async list({ prefix = "", cursor } = {}) {
            if (cursor) return { blobs: [], cursor: undefined };
            return { blobs: [...data.keys()].filter((k) => k.startsWith(prefix)).map((key) => ({ key })), cursor: undefined };
        },
    };
}

function world() {
    const idx = fakeStore({
        "lsor-eidene-2026": JSON.stringify({ ownerId: "anon", programId: "p_1", createdAt: "2026-01-01" }),
        "vintersamling": JSON.stringify({ ownerId: "a_bergen", programId: "p_2", createdAt: "2026-02-01" }),
    });
    const drills = fakeStore({
        "drills/anon/p_1/latest.drill": Buffer.from("PK-latest-1"),
        "drills/anon/p_1/5.drill": Buffer.from("PK-v5"),
        "drills/anon/p_1/meta.json": JSON.stringify({ slug: "lsor-eidene-2026", ownerId: "anon", versions: [{ v: "5" }] }),
        "drills/a_bergen/p_2/latest.drill": Buffer.from("PK-latest-2"),
        "drills/a_bergen/p_2/meta.json": JSON.stringify({ slug: "vintersamling", ownerId: "a_bergen", versions: [] }),
    });
    let n = 0;
    return { idx, drills, makeEntryId: () => `e_${++n}` };
}

const run = (w, over = {}) => migrateCatalogKeys({ idx: w.idx, drills: w.drills, makeEntryId: w.makeEntryId, ...over });
const clean = (w, over = {}) => cleanupCatalogKeys({ idx: w.idx, drills: w.drills, ...over });

// ---------- dry run ----------

test("a dry run reports what it would move and touches nothing", async () => {
    const w = world();
    const before = new Map(w.drills.data);
    const report = await run(w);

    assert.equal(report.dryRun, true);
    assert.equal(report.scanned, 2);
    assert.deepEqual(report.migrated.map((m) => m.slug).sort(), ["lsor-eidene-2026", "vintersamling"]);
    assert.deepEqual(report.migrated.find((m) => m.slug === "lsor-eidene-2026").blobs, 3);

    assert.deepEqual([...w.drills.data.keys()].sort(), [...before.keys()].sort());
    assert.equal(w.idx.data.size, 2, "no index records written");
});

// ---------- copy ----------

test("copy writes catalog/<entryId>/ and repoints the index, leaving the old blobs alone", async () => {
    const w = world();
    await run(w, { dryRun: false });

    // Copied, byte for byte.
    assert.equal(w.drills.data.get("catalog/e_1/latest.drill").toString(), "PK-latest-1");
    assert.equal(w.drills.data.get("catalog/e_1/5.drill").toString(), "PK-v5");
    assert.ok(w.drills.data.has("catalog/e_1/meta.json"));

    // Old blobs survive the copy phase — cleanup is a separate, later decision.
    assert.ok(w.drills.data.has("drills/anon/p_1/latest.drill"));

    const rec = await w.idx.get(slugIndexKey("anon", "lsor-eidene-2026"), { type: "json" });
    assert.equal(rec.entryId, "e_1");
    assert.equal(rec.ownerAccountId, null, "an anon plan has no owning account");
});

test("an account-owned plan lands in its account's namespace", async () => {
    const w = world();
    await run(w, { dryRun: false });
    const rec = await w.idx.get(slugIndexKey("a_bergen", "vintersamling"), { type: "json" });
    assert.equal(rec.entryId, "e_2");
    assert.equal(rec.namespace, "a_bergen");
    assert.equal(rec.ownerAccountId, "a_bergen");
});

test("the flat key is left in place by copy, so a rollback is just not deploying the new reader", async () => {
    const w = world();
    await run(w, { dryRun: false });
    assert.ok(w.idx.data.has("lsor-eidene-2026"));
});

// ---------- the property that makes it safe ----------

test("resolution works throughout: before, midway and after", async () => {
    const w = world();

    // Before: the flat fallback finds it in the old layout.
    let rec = await findEntry({ namespace: "anon", slug: "lsor-eidene-2026" }, { store: w.idx });
    assert.equal(rec.legacy, true);
    assert.equal(keysForEntry(rec).latest, "drills/anon/p_1/latest.drill");

    await run(w, { dryRun: false });

    // After: the namespaced key wins and points at the new layout.
    rec = await findEntry({ namespace: "anon", slug: "lsor-eidene-2026" }, { store: w.idx });
    assert.equal(rec.legacy, false);
    assert.equal(keysForEntry(rec).latest, "catalog/e_1/latest.drill");
    assert.equal(keysForEntry(rec, "5").versioned, "catalog/e_1/5.drill");
});

// ---------- resumable ----------

test("re-running skips what is done rather than minting a second entry", async () => {
    const w = world();
    await run(w, { dryRun: false });
    const second = await run(w, { dryRun: false });

    assert.equal(second.migrated.length, 0);
    assert.equal(second.skipped.length, 2);
    assert.deepEqual(second.skipped.map((s) => s.reason), ["already_migrated", "already_migrated"]);
    // A second entry id would orphan the first copy's blobs.
    assert.ok(!w.drills.data.has("catalog/e_3/latest.drill"));
});

test("a record with no blobs is reported rather than repointed at nothing", async () => {
    const w = world();
    w.idx.data.set("ghost", JSON.stringify({ ownerId: "anon", programId: "p_missing" }));
    const report = await run(w, { dryRun: false });
    assert.ok(report.errors.some((e) => e.slug === "ghost" && e.reason === "no_blobs"));
    assert.equal(await w.idx.get(slugIndexKey("anon", "ghost"), { type: "json" }), null);
});

test("a record with no plan id is reported, not guessed at", async () => {
    const w = world();
    w.idx.data.set("broken", JSON.stringify({ ownerId: "anon" }));
    const report = await run(w, { dryRun: false });
    assert.ok(report.errors.some((e) => e.slug === "broken" && e.reason === "no_plan_id"));
});

// ---------- cleanup ----------

test("cleanup REFUSES to delete anything that has not been repointed", async () => {
    // The ordering guarantee: a cleanup can never run ahead of a copy.
    const w = world();
    const report = await clean(w, { dryRun: false });

    assert.equal(report.removedKeys.length, 0);
    assert.equal(report.skipped.length, 2);
    assert.deepEqual(report.skipped.map((s) => s.reason), ["not_migrated", "not_migrated"]);
    assert.ok(w.drills.data.has("drills/anon/p_1/latest.drill"), "nothing destroyed");
});

test("cleanup dry run reports what it would delete and deletes nothing", async () => {
    const w = world();
    await run(w, { dryRun: false });
    const report = await clean(w);

    assert.equal(report.removedBlobs.length, 5);
    assert.ok(w.drills.data.has("drills/anon/p_1/latest.drill"));
    assert.ok(w.idx.data.has("lsor-eidene-2026"));
});

test("cleanup removes the old blobs and the flat keys, and resolution still works", async () => {
    const w = world();
    await run(w, { dryRun: false });
    await clean(w, { dryRun: false });

    assert.ok(!w.drills.data.has("drills/anon/p_1/latest.drill"));
    assert.ok(!w.idx.data.has("lsor-eidene-2026"));
    assert.ok(w.drills.data.has("catalog/e_1/latest.drill"));

    const rec = await findEntry({ namespace: "anon", slug: "lsor-eidene-2026" }, { store: w.idx });
    assert.equal(rec.entryId, "e_1", "the namespaced record is what serves it now");
});

test("cleanup is idempotent", async () => {
    const w = world();
    await run(w, { dryRun: false });
    await clean(w, { dryRun: false });
    const again = await clean(w, { dryRun: false });
    assert.equal(again.removedKeys.length, 0);
});
