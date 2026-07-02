/**
 * Tests for metaToFeedItem in _shared.js — the shared meta.json → catalog
 * item projection (ADR-0040), reused by market-feed.js and (later) the
 * ADR-0044 per-slug meta endpoint.
 */
import { test } from "node:test";
import assert from "node:assert/strict";
import { metaToFeedItem, latestVersionEntry } from "../functions/_shared.js";

const ORIGIN = "https://api.ringdrill.app";

test("metaToFeedItem: a full modern blob projects every field", () => {
    const meta = {
        programId: "prog-1",
        slug: "sprint-1",
        name: "Sprint",
        description: "A full plan",
        exerciseCount: 4,
        author: "Kari",
        accessPolicy: "shared",
        mapCenter: { lat: 61, lng: 11 },
        tags: ["a", "b"],
        ownerId: "acc-1",
        versions: [
            { v: "1", updatedAt: "2026-01-01T00:00:00.000Z" },
            { v: "2", updatedAt: "2026-02-01T00:00:00.000Z" },
        ],
    };
    assert.deepEqual(metaToFeedItem(meta, { origin: ORIGIN }), {
        programId: "prog-1",
        slug: "sprint-1",
        name: "Sprint",
        description: "A full plan",
        exerciseCount: 4,
        author: "Kari",
        accessPolicy: "shared",
        mapCenter: { lat: 61, lng: 11 },
        tags: ["a", "b"],
        latestUrl: "https://api.ringdrill.app/d/sprint-1",
        updatedAt: "2026-02-01T00:00:00.000Z",
    });
});

test("metaToFeedItem: legacy blob (no exerciseCount/author/accessPolicy) → graceful defaults, anon owner", () => {
    const meta = {
        programId: "prog-2",
        slug: "legacy-anon",
        name: "Legacy Anon",
        ownerId: "anon",
        tags: [],
        versions: [],
    };
    const item = metaToFeedItem(meta, { origin: ORIGIN });
    assert.equal(item.exerciseCount, null);
    assert.equal(item.author, "anon");
    assert.equal(item.accessPolicy, "public");
    assert.equal(item.description, "");
    assert.equal(item.mapCenter, null);
});

test("metaToFeedItem: legacy blob owned by an account → accessPolicy defaults to account", () => {
    const meta = {
        programId: "prog-3",
        slug: "legacy-owned",
        name: "Legacy Owned",
        ownerId: "acc-42",
        versions: [],
    };
    const item = metaToFeedItem(meta, { origin: ORIGIN });
    assert.equal(item.exerciseCount, null);
    assert.equal(item.author, "acc-42");
    assert.equal(item.accessPolicy, "account");
});

test("metaToFeedItem: no versions → updatedAt null", () => {
    const meta = {
        programId: "prog-4",
        slug: "no-versions",
        name: "No Versions",
        ownerId: "anon",
    };
    const item = metaToFeedItem(meta, { origin: ORIGIN });
    assert.equal(item.updatedAt, null);
});

test("metaToFeedItem: exerciseCount 0 is preserved, not coerced to null", () => {
    const meta = { programId: "prog-5", slug: "empty-plan", name: "Empty", ownerId: "anon", exerciseCount: 0, versions: [] };
    const item = metaToFeedItem(meta, { origin: ORIGIN });
    assert.equal(item.exerciseCount, 0);
});

test("metaToFeedItem: non-array tags default to []", () => {
    const meta = { programId: "prog-6", slug: "bad-tags", name: "Bad Tags", ownerId: "anon", tags: "not-an-array", versions: [] };
    const item = metaToFeedItem(meta, { origin: ORIGIN });
    assert.deepEqual(item.tags, []);
});

// ---------- metaToFeedItem: mapCenter (ADR-0040 addendum) ----------

test("metaToFeedItem: malformed mapCenter (non-finite fields) → null, never thrown", () => {
    const meta = { programId: "prog-7", slug: "bad-center", name: "Bad Center", ownerId: "anon", mapCenter: { lat: "not-a-number", lng: 11 }, versions: [] };
    const item = metaToFeedItem(meta, { origin: ORIGIN });
    assert.equal(item.mapCenter, null);
});

test("metaToFeedItem: missing mapCenter → null", () => {
    const meta = { programId: "prog-8", slug: "no-center", name: "No Center", ownerId: "anon", versions: [] };
    const item = metaToFeedItem(meta, { origin: ORIGIN });
    assert.equal(item.mapCenter, null);
});

// ---------- latestVersionEntry ----------

test("latestVersionEntry: picks the numerically highest version", () => {
    const versions = [
        { v: "2", updatedAt: "b" },
        { v: "10", updatedAt: "c" },
        { v: "1", updatedAt: "a" },
    ];
    assert.equal(latestVersionEntry(versions).v, "10");
});

test("latestVersionEntry: empty/missing versions → null", () => {
    assert.equal(latestVersionEntry([]), null);
    assert.equal(latestVersionEntry(undefined), null);
});
