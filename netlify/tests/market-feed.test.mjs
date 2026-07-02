/**
 * Tests for market-feed.js — the public catalog feed (ADR-0040 widened shape).
 *
 * We import createHandler directly and inject a fake drills store, the same
 * way drills-preview.test.mjs fakes getSlugRecord/readJson. This avoids ever
 * touching @netlify/blobs, which is safe because _shared.js only calls
 * getStore() lazily.
 */
import { test } from "node:test";
import assert from "node:assert/strict";
import { createHandler } from "../functions/market-feed.js";

function makeStore(metaByKey) {
    return {
        list: async ({ prefix }) => ({
            blobs: Object.keys(metaByKey)
                .filter((k) => k.startsWith(prefix))
                .map((key) => ({ key })),
            cursor: undefined,
        }),
        get: async (key) => metaByKey[key] ?? null,
    };
}

function req(path) {
    return new Request(`http://api.ringdrill.app${path}`);
}

const MODERN_META = {
    "drills/acc-1/prog-1/meta.json": {
        programId: "prog-1",
        slug: "modern-plan",
        name: "Modern Plan",
        description: "A fresh plan",
        exerciseCount: 6,
        author: "acc-1",
        accessPolicy: "account",
        mapCenter: { lat: 61, lng: 11 },
        languageCode: "nb",
        tags: ["sar"],
        ownerId: "acc-1",
        published: true,
        versions: [{ v: "1", updatedAt: "2026-02-01T00:00:00.000Z" }],
    },
};

test("published items carry the widened shape", async () => {
    const handler = createHandler({ getDrillsStore: () => makeStore(MODERN_META) });
    const res = await handler(req("/api/market-feed"));
    assert.equal(res.status, 200);
    const { items } = await res.json();
    assert.equal(items.length, 1);
    assert.deepEqual(items[0], {
        programId: "prog-1",
        slug: "modern-plan",
        name: "Modern Plan",
        description: "A fresh plan",
        exerciseCount: 6,
        author: "acc-1",
        accessPolicy: "account",
        mapCenter: { lat: 61, lng: 11 },
        languageCode: "nb",
        tags: ["sar"],
        latestUrl: "http://api.ringdrill.app/d/modern-plan",
        updatedAt: "2026-02-01T00:00:00.000Z",
    });
});

test("unpublished items are omitted", async () => {
    const metaByKey = {
        "drills/anon/prog-2/meta.json": {
            programId: "prog-2",
            slug: "draft-plan",
            name: "Draft",
            ownerId: "anon",
            published: false,
            versions: [],
        },
    };
    const handler = createHandler({ getDrillsStore: () => makeStore(metaByKey) });
    const res = await handler(req("/api/market-feed"));
    const { items } = await res.json();
    assert.equal(items.length, 0);
});

test("a legacy blob (no exerciseCount/author/accessPolicy) projects with graceful defaults", async () => {
    const metaByKey = {
        "drills/anon/prog-3/meta.json": {
            programId: "prog-3",
            slug: "legacy-plan",
            name: "Legacy",
            ownerId: "anon",
            published: true,
            versions: [],
        },
    };
    const handler = createHandler({ getDrillsStore: () => makeStore(metaByKey) });
    const res = await handler(req("/api/market-feed"));
    const { items } = await res.json();
    assert.equal(items.length, 1);
    assert.equal(items[0].exerciseCount, null);
    assert.equal(items[0].author, "anon");
    assert.equal(items[0].accessPolicy, "public");
    assert.equal(items[0].description, "");
    assert.equal(items[0].updatedAt, null);
    assert.equal(items[0].mapCenter, null);
    assert.equal(items[0].languageCode, null);
});

test("items are sorted by updatedAt descending", async () => {
    const metaByKey = {
        "drills/anon/prog-a/meta.json": {
            programId: "prog-a", slug: "older", name: "Older", ownerId: "anon", published: true,
            versions: [{ v: "1", updatedAt: "2026-01-01T00:00:00.000Z" }],
        },
        "drills/anon/prog-b/meta.json": {
            programId: "prog-b", slug: "newer", name: "Newer", ownerId: "anon", published: true,
            versions: [{ v: "1", updatedAt: "2026-03-01T00:00:00.000Z" }],
        },
    };
    const handler = createHandler({ getDrillsStore: () => makeStore(metaByKey) });
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
    const handler = createHandler({ getDrillsStore: () => makeStore(MODERN_META) });
    const res = await handler(req("/api/market-feed"));
    assert.equal(res.headers.get("cache-control"), "public, max-age=30");
});
