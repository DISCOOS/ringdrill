/**
 * Catalog entry identity, keys and URL parsing (ADR-0074 §2 and §4).
 *
 * The properties worth the most: the blob key contains neither the account nor
 * its handle, and segment count alone disambiguates a namespaced URL.
 *
 * This file also used to pin the dual-read fallback that let the re-key
 * migration run with the site live. That ran on 2026-08-12, so what is pinned
 * now is the opposite property — a record with no `entryId` throws instead of
 * naming a key in a layout that no longer exists.
 */
import { test } from "node:test";
import assert from "node:assert/strict";

import {
    ANON_NAMESPACE,
    catalogKeysFor,
    catalogPathFor,
    claimEntry,
    findEntry,
    keysForEntry,
    parseCatalogPath,
    findUploadTarget,
    resolveNamespace,
    slugIndexKey,
    storedNamespaceFor,
} from "../functions/lib/catalog.js";

function fakeStore(seed = {}) {
    const data = new Map(Object.entries(seed).map(([k, v]) => [k, JSON.stringify(v)]));
    return {
        data,
        async get(key, opts) {
            const raw = data.get(key);
            return raw === undefined ? null : (opts?.type === "json" ? JSON.parse(raw) : raw);
        },
        async set(key, value, opts = {}) {
            if (opts.onlyIfNew && data.has(key)) return { modified: false };
            data.set(key, value); return { modified: true };
        },
        async delete(key) { data.delete(key); },
        async list({ prefix = "" } = {}) {
            return { blobs: [...data.keys()].filter((k) => k.startsWith(prefix)).map((key) => ({ key })), cursor: undefined };
        },
    };
}

function handleStores(handles = {}) {
    const store = fakeStore(handles);
    return { handles: () => store };
}

// ---------- keys ----------

test("a catalog blob key contains neither the account nor its handle", () => {
    const keys = catalogKeysFor("e_abc123", "5");
    for (const key of [keys.latest, keys.versioned, keys.meta]) {
        assert.match(key, /^catalog\/e_abc123\//);
        // With the account in the path, "delete the account" must remember not
        // to sweep it — an exception that reads like correct code. With the
        // handle in it, every rename moves every blob.
        assert.doesNotMatch(key, /a_|redcross|anon/, key);
    }
    assert.equal(keys.versioned, "catalog/e_abc123/5.drill");
    assert.equal(keys.latest, "catalog/e_abc123/latest.drill");
});

test("storedNamespaceFor uses the account id, so a rename rewrites nothing", () => {
    assert.equal(storedNamespaceFor("a_bergen"), "a_bergen");
    assert.equal(storedNamespaceFor(null), ANON_NAMESPACE);
    assert.equal(storedNamespaceFor("anon"), ANON_NAMESPACE);
});

// ---------- URL parsing ----------

test("segment count disambiguates: one is anon, two is namespaced", () => {
    assert.deepEqual(parseCatalogPath("lsor-eidene-2026"), {
        namespace: ANON_NAMESPACE, slug: "lsor-eidene-2026", version: null, explicitNamespace: false,
    });
    assert.deepEqual(parseCatalogPath("redcross-bergen/lsor-eidene-2026"), {
        namespace: "redcross-bergen", slug: "lsor-eidene-2026", version: null, explicitNamespace: true,
    });
});

test("namespace and @version compose, which the dropped @ sigil would have broken", () => {
    assert.deepEqual(parseCatalogPath("lsor-eidene-2026@5"), {
        namespace: ANON_NAMESPACE, slug: "lsor-eidene-2026", version: "5", explicitNamespace: false,
    });
    assert.deepEqual(parseCatalogPath("redcross-bergen/lsor-eidene-2026@5"), {
        namespace: "redcross-bergen", slug: "lsor-eidene-2026", version: "5", explicitNamespace: true,
    });
});

test("the .drill suffix and stray slashes are tolerated", () => {
    assert.equal(parseCatalogPath("/lsor-eidene-2026.drill/").slug, "lsor-eidene-2026");
    assert.equal(parseCatalogPath("redcross-bergen/plan@3.drill").version, "3");
});

test("three segments is not a thing, and is refused rather than guessed at", () => {
    assert.equal(parseCatalogPath("a/b/c"), null);
    assert.equal(parseCatalogPath(""), null);
    assert.equal(parseCatalogPath(null), null);
});

test("catalogPathFor omits anon, so every existing link keeps its shape", () => {
    assert.equal(catalogPathFor({ namespace: ANON_NAMESPACE, slug: "lsor" }), "/d/lsor");
    assert.equal(catalogPathFor({ namespace: ANON_NAMESPACE, slug: "lsor", version: "5" }), "/d/lsor@5");
    assert.equal(catalogPathFor({ namespace: "redcross-bergen", slug: "lsor" }), "/d/redcross-bergen/lsor");
});

// ---------- namespace resolution ----------

test("a URL namespace may be a handle or an account id, and both resolve", async () => {
    const stores = handleStores({ "redcross-bergen": { accountId: "a_bergen" } });
    assert.equal((await resolveNamespace("redcross-bergen", { stores })).namespace, "a_bergen");
    // An account that has not claimed a handle still needs a working URL.
    assert.equal((await resolveNamespace("a_bergen", { stores })).namespace, "a_bergen");
});

test("a tombstoned handle still resolves, and reports the current one", async () => {
    // This is what makes a rename non-breaking for links already shared.
    const stores = handleStores({
        "old-name": { accountId: "a_bergen", tombstone: true, redirectsTo: "new-name" },
        "new-name": { accountId: "a_bergen" },
    });
    const res = await resolveNamespace("old-name", { stores });
    assert.equal(res.namespace, "a_bergen");
    assert.equal(res.canonical, "new-name");
    assert.equal(res.movedFrom, "old-name");
});

test("anon resolves to itself", async () => {
    assert.equal((await resolveNamespace("anon", { stores: handleStores() })).namespace, ANON_NAMESPACE);
    assert.equal((await resolveNamespace(null, { stores: handleStores() })).namespace, ANON_NAMESPACE);
});

// ---------- resolution ----------

test("a record resolves by namespaced key and reads from catalog/", async () => {
    const store = fakeStore({
        [slugIndexKey("a_bergen", "lsor")]: { entryId: "e_1", planId: "p_1", ownerAccountId: "a_bergen" },
    });
    const rec = await findEntry({ namespace: "a_bergen", slug: "lsor" }, { store });
    assert.equal(rec.entryId, "e_1");
    assert.equal(keysForEntry(rec).meta, "catalog/e_1/meta.json");
    assert.equal(keysForEntry(rec, "5").versioned, "catalog/e_1/5.drill");
});

test("a record with no entryId throws rather than naming a plausible key", async () => {
    // Before the ADR-0074 migration this meant "pre-migration" and the old
    // owner-scoped layout was returned. It cannot mean that any more, so it
    // means a corrupt index record — and the useful response is to fail where
    // it is read, not to hand back a key that 404s like an ordinary missing
    // plan and hides the corruption.
    assert.throws(() => keysForEntry({ slug: "lsor", ownerId: "anon", programId: "p_9" }), /no entryId/);
    assert.throws(() => keysForEntry(null), /no entryId/);
});

test("a bare slug is no longer resolvable — the flat keys are gone", async () => {
    const store = fakeStore({ "lsor": { ownerId: "anon", programId: "p_9" } });
    assert.equal(await findEntry({ namespace: ANON_NAMESPACE, slug: "lsor" }, { store }), null);
});

test("an unknown slug is null", async () => {
    assert.equal(await findEntry({ namespace: ANON_NAMESPACE, slug: "nope" }, { store: fakeStore() }), null);
});

// ---------- claiming ----------

test("claiming is atomic within a namespace", async () => {
    const store = fakeStore();
    const first = await claimEntry({ namespace: "a_bergen", slug: "lsor", planId: "p_1", ownerAccountId: "a_bergen" }, { store });
    assert.equal(first.ok, true);
    assert.match(first.record.entryId, /^e_/);

    const clash = await claimEntry({ namespace: "a_bergen", slug: "lsor", planId: "p_2", ownerAccountId: "a_bergen" }, { store });
    assert.equal(clash.reason, "taken");
});

test("THE POINT OF §2: the same slug in two namespaces is two entries", async () => {
    // A fork keeps its name beside the original, which retires the cost
    // ADR-0025 accepted with visible reluctance.
    const store = fakeStore();
    const anon = await claimEntry({ namespace: ANON_NAMESPACE, slug: "lsor-eidene-2026", planId: "p_1" }, { store });
    const mine = await claimEntry({ namespace: "a_bergen", slug: "lsor-eidene-2026", planId: "p_2", ownerAccountId: "a_bergen" }, { store });

    assert.equal(anon.ok, true);
    assert.equal(mine.ok, true, "no -2 suffix, no (kopi)");
    assert.notEqual(anon.record.entryId, mine.record.entryId);
});

// ---------- upload targeting: the ADR-0074 §4 / ADR-0025 conflict ----------

const anonPrincipal = { ok: true, anonymous: true };
const bergen = { ok: true, anonymous: false, userId: "u_1", accountId: "a_bergen", accounts: ["a_bergen"], roles: { a_bergen: "member" } };

test("an anonymous upload targets anon", async () => {
    const store = fakeStore();
    const t = await findUploadTarget({ principal: anonPrincipal, slug: "new-plan" }, { store });
    assert.equal(t.namespace, ANON_NAMESPACE);
    assert.equal(t.existing, null);
});

test("a new slug is claimed in the caller's own namespace", async () => {
    const store = fakeStore();
    const t = await findUploadTarget({ principal: bergen, slug: "new-plan" }, { store });
    assert.equal(t.namespace, "a_bergen");
    assert.equal(t.existing, null);
});

test("the caller's own namespace wins when the slug exists in both", async () => {
    const store = fakeStore({
        [slugIndexKey("a_bergen", "lsor")]: { entryId: "e_mine" },
        [slugIndexKey(ANON_NAMESPACE, "lsor")]: { entryId: "e_theirs" },
    });
    const t = await findUploadTarget({ principal: bergen, slug: "lsor" }, { store });
    assert.equal(t.existing.entryId, "e_mine");
    assert.equal(t.foundIn, "a_bergen");
});

test("LOOKUP falls back to anon, so a signed-in user keeps the wiki model", async () => {
    // Without this, ADR-0025's "policy public → authenticated user may write"
    // row is unreachable: everyone who signs in silently loses write access to
    // the public plans they have been co-editing.
    const store = fakeStore({ [slugIndexKey(ANON_NAMESPACE, "lsor")]: { entryId: "e_theirs" } });
    const t = await findUploadTarget({ principal: bergen, slug: "lsor" }, { store });
    assert.equal(t.existing.entryId, "e_theirs");
    assert.equal(t.foundIn, ANON_NAMESPACE, "authorisation is then asked about the right plan");
});

test("CLAIMING does not fall back — a brand new slug never lands in anon for a signed-in user", async () => {
    const store = fakeStore();
    const t = await findUploadTarget({ principal: bergen, slug: "brand-new" }, { store });
    assert.equal(t.namespace, "a_bergen");
    assert.equal(t.foundIn, null);
});

test("an existing anon entry is found through the anon fallback", async () => {
    // Lookup falls back to `anon`; claiming does not. A slug already published
    // anonymously is still that entry, whoever is uploading now.
    const store = fakeStore({
        [slugIndexKey(ANON_NAMESPACE, "lsor")]: { entryId: "e_1", planId: "p_1" },
    });
    const t = await findUploadTarget({ principal: bergen, slug: "lsor" }, { store });
    assert.equal(t.existing.entryId, "e_1");
    assert.equal(t.foundIn, ANON_NAMESPACE);
});
