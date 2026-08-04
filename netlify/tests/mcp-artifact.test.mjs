// The download route for a built archive (ADR-0070).
//
// The half of the handle that the MCP endpoint tests cannot see: `build_plan` returns a
// URL and asserts what it stored, and this asserts that following that URL produces the
// file. A build whose link 404s is exactly the failure ADR-0070 set out to fix, just
// moved one step later.
import { test } from "node:test";
import assert from "node:assert/strict";

import { createHandler, hashFromPath } from "../functions/mcp-artifact.js";
import { MIME_DRILL } from "../functions/lib/shared.js";
import {
    ARTIFACT_TTL_MS,
    archiveFileName,
    artifactKey,
} from "../functions/lib/mcp-artifact-store.js";

const HASH = "a".repeat(64);
const ARCHIVE = Buffer.from("PK pretend this is a zip");

function memoryStore(entries = {}) {
    const map = new Map(Object.entries(entries));
    return {
        get: async (key) => map.get(key) ?? null,
        setJSON: async (key, value) => void map.set(key, value),
        delete: async (key) => void map.delete(key),
        has: (key) => map.has(key),
    };
}

function held({ storedAt = Date.now(), fileName = "plan.drill" } = {}) {
    return { base64: ARCHIVE.toString("base64"), storedAt, fileName };
}

function get(handler, path = `/mcp/artifact/${HASH}.drill`, method = "GET") {
    return handler(new Request(`https://api.ringdrill.app${path}`, { method }));
}

test("a held archive downloads as an attachment", async () => {
    const store = memoryStore({
        [artifactKey(HASH)]: held({ fileName: "lsor-2026.drill" }),
    });
    const response = await get(createHandler({ store: () => store }));

    assert.equal(response.status, 200);
    assert.equal(response.headers.get("content-type"), MIME_DRILL);
    assert.equal(
        response.headers.get("content-disposition"),
        'attachment; filename="lsor-2026.drill"',
    );
    // The point of the whole route: the author gets a file, not a rendered page and
    // not a truncated blob.
    assert.equal(response.headers.get("content-length"), String(ARCHIVE.length));
    const bytes = Buffer.from(await response.arrayBuffer());
    assert.deepEqual(bytes, ARCHIVE);
});

test("HEAD answers the headers without the body", async () => {
    const store = memoryStore({ [artifactKey(HASH)]: held() });
    const response = await get(
        createHandler({ store: () => store }),
        `/mcp/artifact/${HASH}.drill`,
        "HEAD",
    );
    assert.equal(response.status, 200);
    assert.equal(response.headers.get("content-length"), String(ARCHIVE.length));
    assert.equal((await response.text()).length, 0);
});

test("the direct function path works too, not just the alias", async () => {
    // Netlify serves `/.netlify/functions/<name>` natively, and it is the only form
    // `netlify functions:serve` offers locally. `deep-link.js` accepts both for the
    // same reason.
    const store = memoryStore({ [artifactKey(HASH)]: held() });
    const response = await get(
        createHandler({ store: () => store }),
        `/.netlify/functions/mcp-artifact/${HASH}.drill`,
    );
    assert.equal(response.status, 200);
});

test("an expired entry is a 404, and is deleted on the way out", async () => {
    // The retention promise is that an entry does not outlive its window; the read is
    // the moment we know it has. Same reasoning as the document cache.
    const store = memoryStore({
        [artifactKey(HASH)]: held({ storedAt: Date.now() - ARTIFACT_TTL_MS - 1000 }),
    });
    const response = await get(createHandler({ store: () => store }));

    assert.equal(response.status, 404);
    assert.match(await response.text(), /expired/);
    assert.equal(
        store.has(artifactKey(HASH)),
        false,
        "an expired entry must not survive the read that found it expired",
    );
});

test("an entry with no storedAt expires rather than living forever", async () => {
    const store = memoryStore({
        [artifactKey(HASH)]: { base64: ARCHIVE.toString("base64") },
    });
    const response = await get(createHandler({ store: () => store }));
    assert.equal(response.status, 404);
});

test("a hash we do not hold is a 404 that says what to do", async () => {
    const handler = createHandler({ store: () => memoryStore() });
    const response = await get(handler);
    assert.equal(response.status, 404);
    assert.match(await response.text(), /Build the plan again/);
});

test("only a 64-hex hash reaches the store", async () => {
    // Anchored so a traversal attempt or a probe for another key never becomes a
    // lookup. Asserted through the handler rather than only through hashFromPath,
    // because the guard is worth nothing if the handler stops consulting it.
    let looked = 0;
    const store = memoryStore();
    const counting = {
        ...store,
        get: async (key) => {
            looked += 1;
            return store.get(key);
        },
    };
    const handler = createHandler({ store: () => counting });

    for (const path of [
        "/mcp/artifact/../../etc/passwd",
        "/mcp/artifact/plan.drill",
        `/mcp/artifact/${"a".repeat(63)}.drill`,
        `/mcp/artifact/${"a".repeat(65)}.drill`,
        `/mcp/artifact/${"A".repeat(64)}.drill`,
        `/mcp/artifact/${HASH}`,
        `/mcp/artifact/${HASH}.zip`,
    ]) {
        const response = await get(handler, path);
        assert.equal(response.status, 404, path);
    }
    assert.equal(looked, 0, "a malformed path must not become a store lookup");
});

test("a malformed path and an unheld hash answer identically", async () => {
    // Distinguishing them would confirm which hashes exist, which is the one thing an
    // unguessable key must not leak.
    const handler = createHandler({ store: () => memoryStore() });
    const bad = await get(handler, "/mcp/artifact/nonsense");
    const missing = await get(handler);
    assert.equal(bad.status, missing.status);
    assert.equal(await bad.text(), await missing.text());
});

test("a write method is refused", async () => {
    const store = memoryStore({ [artifactKey(HASH)]: held() });
    const response = await get(
        createHandler({ store: () => store }),
        `/mcp/artifact/${HASH}.drill`,
        "DELETE",
    );
    assert.equal(response.status, 405);
    assert.match(response.headers.get("allow"), /GET/);
});

test("the response is not cacheable past its retention window", async () => {
    const store = memoryStore({ [artifactKey(HASH)]: held() });
    const response = await get(createHandler({ store: () => store }));
    assert.match(response.headers.get("cache-control"), /no-store/);
});

test("hashFromPath takes the hash and nothing else", async () => {
    assert.equal(hashFromPath(`/mcp/artifact/${HASH}.drill`), HASH);
    assert.equal(hashFromPath("/mcp/artifact/x.drill"), null);
});

test("the download filename comes from the plan name", async () => {
    assert.equal(archiveFileName("LSOR øvelseshefte 2026"), "lsor-velseshefte-2026.drill");
    // A name that slugs to nothing still has to produce a usable filename.
    assert.equal(archiveFileName("???"), "plan.drill");
    assert.equal(archiveFileName(undefined), "plan.drill");
});
