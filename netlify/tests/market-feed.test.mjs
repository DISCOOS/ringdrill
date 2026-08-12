/**
 * Tests for market-feed.js — the public catalog feed (ADR-0040 widened shape).
 *
 * We import createHandler directly and inject a fake drills store, the same
 * way drills-preview.test.mjs fakes getSlugRecord/readJson. This avoids ever
 * touching @netlify/blobs, which is safe because lib/shared.js only calls
 * getStore() lazily.
 */
import { test } from "node:test";
import assert from "node:assert/strict";
import { createHandler } from "../functions/market-feed.js";

function makeStore(metaByKey) {
    return {
        list: async ({ prefix = "" } = {}) => ({
            blobs: Object.keys(metaByKey)
                .filter((k) => k.startsWith(prefix))
                .map((key) => ({ key })),
            cursor: undefined,
        }),
        get: async (key) => metaByKey[key] ?? null,
    };
}

/**
 * The feed enumerates the slug index rather than scanning blobs (ADR-0074 §4):
 * a blob scan cannot produce a feed, because meta.json carries no namespace and
 * latestUrl needs one.
 */
function indexFor(metaByKey) {
    const records = {};
    for (const key of Object.keys(metaByKey)) {
        if (!key.endsWith("/meta.json")) continue;
        const meta = metaByKey[key];
        const entryId = key.split("/")[1];
        const ns = meta.ownerId && meta.ownerId !== "anon" ? meta.ownerId : "anon";
        records[`${ns}/${meta.slug}`] = { entryId, planId: meta.programId, ownerId: meta.ownerId };
    }
    return makeStore(records);
}

const handlerFor = (metaByKey) => createHandler({
    getDrillsStore: () => makeStore(metaByKey),
    getSlugIndexStore: () => indexFor(metaByKey),
});

function req(path) {
    return new Request(`http://api.ringdrill.app${path}`);
}

const MODERN_META = {
    "catalog/e_1/meta.json": {
        programId: "prog-1",
        slug: "modern-plan",
        name: "Modern Plan",
        description: "A fresh plan",
        exerciseCount: 6,
        author: "acc-1",
        accessPolicy: "account",
        mapCenter: { lat: 61, lng: 11 },
        mapBounds: { north: 62, south: 60, east: 12, west: 10 },
        place: "Bergen, Norway",
        languageCode: "nb",
        tags: ["sar"],
        ownerId: "acc-1",
        published: true,
        versions: [{ v: "1", updatedAt: "2026-02-01T00:00:00.000Z" }],
    },
};

test("published items carry the widened shape", async () => {
    const handler = handlerFor(MODERN_META);
    const res = await handler(req("/api/market-feed"));
    assert.equal(res.status, 200);
    const { items } = await res.json();
    assert.equal(items.length, 1);
    assert.deepEqual(items[0], {
        planId: "prog-1",
        programId: "prog-1",
        slug: "modern-plan",
        name: "Modern Plan",
        description: "A fresh plan",
        exerciseCount: 6,
        author: "acc-1",
        accessPolicy: "account",
        mapCenter: { lat: 61, lng: 11 },
        mapBounds: { north: 62, south: 60, east: 12, west: 10 },
        place: "Bergen, Norway",
        languageCode: "nb",
        tags: ["sar"],
        // Owned by acc-1, so it is addressed in that namespace. An anon plan
        // keeps its bare /d/<slug> URL instead — covered separately below.
        namespace: "acc-1",
        latestUrl: "http://api.ringdrill.app/d/acc-1/modern-plan",
        updatedAt: "2026-02-01T00:00:00.000Z",
    });
});

test("unpublished items are omitted", async () => {
    const metaByKey = {
        "catalog/e_2/meta.json": {
            programId: "prog-2",
            slug: "draft-plan",
            name: "Draft",
            ownerId: "anon",
            published: false,
            versions: [],
        },
    };
    const handler = handlerFor(metaByKey);
    const res = await handler(req("/api/market-feed"));
    const { items } = await res.json();
    assert.equal(items.length, 0);
});

test("a legacy blob (no exerciseCount/author/accessPolicy) projects with graceful defaults", async () => {
    const metaByKey = {
        "catalog/e_3/meta.json": {
            programId: "prog-3",
            slug: "legacy-plan",
            name: "Legacy",
            ownerId: "anon",
            published: true,
            versions: [],
        },
    };
    const handler = handlerFor(metaByKey);
    const res = await handler(req("/api/market-feed"));
    const { items } = await res.json();
    assert.equal(items.length, 1);
    assert.equal(items[0].exerciseCount, null);
    assert.equal(items[0].author, "anon");
    assert.equal(items[0].accessPolicy, "public");
    assert.equal(items[0].description, "");
    assert.equal(items[0].updatedAt, null);
    assert.equal(items[0].mapCenter, null);
    assert.equal(items[0].mapBounds, null);
    assert.equal(items[0].place, null);
    assert.equal(items[0].languageCode, null);
});

test("items are sorted by updatedAt descending", async () => {
    const metaByKey = {
        "catalog/e_a/meta.json": {
            programId: "prog-a", slug: "older", name: "Older", ownerId: "anon", published: true,
            versions: [{ v: "1", updatedAt: "2026-01-01T00:00:00.000Z" }],
        },
        "catalog/e_b/meta.json": {
            programId: "prog-b", slug: "newer", name: "Newer", ownerId: "anon", published: true,
            versions: [{ v: "1", updatedAt: "2026-03-01T00:00:00.000Z" }],
        },
    };
    const handler = handlerFor(metaByKey);
    const res = await handler(req("/api/market-feed"));
    const { items } = await res.json();
    assert.deepEqual(items.map((i) => i.slug), ["newer", "older"]);
});

test("non-GET method → 405", async () => {
    const handler = createHandler({ getDrillsStore: () => makeStore({}) });
    const res = await handler(new Request("http://api.ringdrill.app/api/market-feed", { method: "POST" }));
    assert.equal(res.status, 405);
});

test("response has cache-control: public, max-age=30", async () => {
    const handler = handlerFor(MODERN_META);
    const res = await handler(req("/api/market-feed"));
    assert.equal(res.headers.get("cache-control"), "public, max-age=30");
});

// ---------- ADR-0074 §2: namespaces in the feed ----------

const MIGRATED_META = {
    "catalog/e_1/meta.json": {
        programId: "prog-a", slug: "lsor", name: "LSOR", ownerId: "anon",
        published: true, versions: [{ v: "1", updatedAt: "2026-03-01T00:00:00.000Z" }],
    },
    "catalog/e_2/meta.json": {
        programId: "prog-b", slug: "vinter", name: "Vinter", ownerId: "a_bergen",
        published: true, versions: [{ v: "1", updatedAt: "2026-03-02T00:00:00.000Z" }],
    },
};

test("a migrated anon entry keeps its bare URL; an account entry gains its namespace", async () => {
    const { items } = await (await handlerFor(MIGRATED_META)(req("/api/market-feed"))).json();
    const anon = items.find((i) => i.slug === "lsor");
    const owned = items.find((i) => i.slug === "vinter");

    assert.equal(anon.namespace, null);
    assert.equal(anon.latestUrl, "http://api.ringdrill.app/d/lsor");
    assert.equal(owned.namespace, "a_bergen");
    assert.equal(owned.latestUrl, "http://api.ringdrill.app/d/a_bergen/vinter");
});

