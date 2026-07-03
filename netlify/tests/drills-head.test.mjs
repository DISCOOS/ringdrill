/**
 * Tests for drills-head.js — slug/path parsing across every alias
 * netlify.toml routes to this function, and the If-None-Match 304 path.
 *
 * Regression coverage for the bug where a request via the hyphenated
 * "/api/drills-head/<slug>" alias (what DrillClient.head() actually calls,
 * and the FIRST of the two aliases netlify.toml defines for this function)
 * was never stripped from the pathname, so `tail` — and therefore the slug
 * passed to getSlugRecord — was the whole "/api/drills-head/<realSlug>"
 * string. Every HEAD request reported "Unknown slug" (404) regardless of
 * whether the plan actually existed, which is what refreshCatalogItem's
 * client-side check (`!head.exists`) surfaced as "no longer available in
 * the catalog" for plans that were very much still there.
 */
import { test } from "node:test";
import assert from "node:assert/strict";
import { createHandler } from "../functions/drills-head.js";

const SLUG_RECORDS = {
    "lsor-eidene-2026": { ownerId: "anon", programId: "prog-abc" },
};

const META_STORE = {
    "drills/anon/prog-abc/meta.json": {
        versions: [
            { v: "1", etag: "\"etag-v1\"", size: 100, updatedAt: "2026-01-01T00:00:00.000Z" },
            { v: "2", etag: "\"etag-v2\"", size: 120, updatedAt: "2026-02-01T00:00:00.000Z" },
        ],
    },
};

function makeHandler(slugRecords = SLUG_RECORDS, metaStore = META_STORE) {
    return createHandler({
        getSlugRecord: async (slug) => slugRecords[slug] ?? null,
        readJson: async (key, fallback = null) => metaStore[key] ?? fallback,
    });
}

function req(path, { method = "HEAD", headers = {} } = {}) {
    return new Request(`http://api.ringdrill.app${path}`, { method, headers });
}

// ---------- Alias parsing: the actual bug ----------

test("hyphenated alias /api/drills-head/<slug> resolves the real slug (regression)", async () => {
    const handler = makeHandler();
    const res = await handler(req("/api/drills-head/lsor-eidene-2026"));
    assert.equal(res.status, 200, "an existing slug must not 404 via this alias");
    assert.equal(res.headers.get("etag"), "\"etag-v2\"", "picks the latest version");
});

test("slashed alias /api/drills/head/<slug> resolves the real slug", async () => {
    const handler = makeHandler();
    const res = await handler(req("/api/drills/head/lsor-eidene-2026"));
    assert.equal(res.status, 200);
    assert.equal(res.headers.get("etag"), "\"etag-v2\"");
});

test("direct function path /.netlify/functions/drills-head/<slug> resolves the real slug", async () => {
    const handler = makeHandler();
    const res = await handler(req("/.netlify/functions/drills-head/lsor-eidene-2026"));
    assert.equal(res.status, 200);
    assert.equal(res.headers.get("etag"), "\"etag-v2\"");
});

test("a genuinely unknown slug still 404s via the hyphenated alias", async () => {
    const handler = makeHandler();
    const res = await handler(req("/api/drills-head/does-not-exist"));
    assert.equal(res.status, 404);
});

test("missing slug (empty tail) 404s", async () => {
    const handler = makeHandler();
    const res = await handler(req("/api/drills-head/"));
    assert.equal(res.status, 404);
});

// ---------- Version suffix ----------

test("hyphenated alias with @version resolves that specific version, not latest", async () => {
    const handler = makeHandler();
    const res = await handler(req("/api/drills-head/lsor-eidene-2026@1"));
    assert.equal(res.status, 200);
    assert.equal(res.headers.get("etag"), "\"etag-v1\"");
    assert.ok(res.headers.get("cache-control")?.includes("immutable"), "pinned version is cacheable forever");
});

test("a 200 response for the unpinned latest exposes x-version", async () => {
    const handler = makeHandler();
    const res = await handler(req("/api/drills-head/lsor-eidene-2026"));
    assert.equal(res.status, 200);
    assert.equal(res.headers.get("x-version"), "2");
});

test("a 200 response for a pinned @version exposes that version, not latest", async () => {
    const handler = makeHandler();
    const res = await handler(req("/api/drills-head/lsor-eidene-2026@1"));
    assert.equal(res.status, 200);
    assert.equal(res.headers.get("x-version"), "1");
});

// ---------- If-None-Match / 304 ----------

test("If-None-Match matching the latest etag returns 304 with no body", async () => {
    const handler = makeHandler();
    const res = await handler(req("/api/drills-head/lsor-eidene-2026", {
        headers: { "if-none-match": "\"etag-v2\"" },
    }));
    assert.equal(res.status, 304);
    assert.equal(res.headers.get("etag"), "\"etag-v2\"");
});

test("a 304 response also exposes x-version, matching drills-upload's precedent", async () => {
    const handler = makeHandler();
    const res = await handler(req("/api/drills-head/lsor-eidene-2026", {
        headers: { "if-none-match": "\"etag-v2\"" },
    }));
    assert.equal(res.status, 304);
    assert.equal(res.headers.get("x-version"), "2");
});

test("If-None-Match with a stale etag returns 200, not 304", async () => {
    const handler = makeHandler();
    const res = await handler(req("/api/drills-head/lsor-eidene-2026", {
        headers: { "if-none-match": "\"etag-v1\"" },
    }));
    assert.equal(res.status, 200);
});

// ---------- CORS preflight ----------

test("OPTIONS from allowed origin → 204", async () => {
    const handler = makeHandler();
    const res = await handler(req("/api/drills-head/lsor-eidene-2026", {
        method: "OPTIONS",
        headers: { origin: "http://localhost:3000" },
    }));
    assert.equal(res.status, 204);
});
