/**
 * `drills-admin` against both storage layouts, with `deleteall` as the point.
 *
 * `deleteall` used to derive its prefix from `ownerId`/`programId`. For a
 * migrated entry that names a location holding nothing, so it would have
 * deleted nothing, answered 200, and left the plan still being served by
 * `/d/<slug>` — a destructive action reporting success while doing the
 * opposite of what it says. Nothing would have caught that: this was the one
 * function with no injectable seam and so no handler test at all.
 *
 * Every case therefore runs against a pre-migration record and a migrated one.
 */
import { test } from "node:test";
import assert from "node:assert/strict";

import { createHandler } from "../functions/drills-admin.js";

const TOKEN = "test-admin-token";
const ENV = { ADMIN_TOKEN: TOKEN };

const META = {
    programId: "prog-1", slug: "lsor", name: "LSOR", published: true,
    versions: [{ v: "1", etag: '"e1"', size: 9, updatedAt: "2026-06-01T00:00:00.000Z" }],
};

/** A blob store that records deletions, so a no-op delete is visible. */
function store(seed = {}) {
    const data = new Map(Object.entries(seed));
    const deleted = [];
    return {
        data, deleted,
        async get(key) { return data.get(key) ?? null; },
        async set(key, value) { data.set(key, value); return { modified: true }; },
        async delete(key) { deleted.push(key); data.delete(key); },
        async list({ prefix = "", cursor } = {}) {
            if (cursor) return { blobs: [], cursor: undefined };
            const blobs = [...data.keys()].filter((k) => k.startsWith(prefix)).map((key) => ({ key }));
            return { blobs, cursor: undefined };
        },
    };
}

/**
 * Two worlds that differ only in storage shape.
 *
 * `legacy` is a pre-migration record — a flat index key and
 * `drills/<owner>/<plan>/` blobs. `migrated` is the same plan after the copy —
 * a namespaced index key and `catalog/<entryId>/` blobs. Every admin action
 * must behave identically against both.
 */
function world(kind) {
    const migrated = kind === "migrated";

    const indexKey = migrated ? "anon/lsor" : "lsor";
    const rec = migrated
        ? { entryId: "e_1", planId: "prog-1", programId: "prog-1", ownerAccountId: null }
        : { ownerId: "anon", programId: "prog-1" };

    const base = migrated ? "catalog/e_1/" : "drills/anon/prog-1/";
    const drills = store({
        [`${base}meta.json`]: META,
        [`${base}latest.drill`]: Buffer.from("PK"),
        [`${base}1.drill`]: Buffer.from("PK"),
    });
    const idx = store({ [indexKey]: rec });

    return {
        kind, migrated, indexKey, base, idx, drills,
        handler: createHandler({
            env: ENV,
            getDrillsStore: () => drills,
            getSlugIndexStore: () => idx,
            findEntry: async ({ slug }) => (slug === "lsor" ? rec : null),
            resolveNamespace: async (ns) => ({ namespace: ns ?? "anon", canonical: ns ?? "anon" }),
            readJson: async (key, dflt = null) => drills.data.get(key) ?? dflt,
            readJsonStrong: async (key, dflt = null) => drills.data.get(key) ?? dflt,
            readBinary: async (key) => drills.data.get(key) ?? null,
            readBinaryStrong: async (key) => drills.data.get(key) ?? null,
            writeJsonConditional: async (key, obj) => { drills.data.set(key, obj); return { modified: true }; },
            getBlobEtag: async (key) => (drills.data.has(key) ? '"e1"' : null),
        }),
    };
}

const admin = (action, { method = "POST", extra = "", auth = true } = {}) => new Request(
    `https://api.ringdrill.app/api/drills-admin?action=${action}&slug=lsor${extra}`,
    { method, headers: auth ? { authorization: `Bearer ${TOKEN}` } : {} },
);

for (const kind of ["legacy", "migrated"]) {
    test(`deleteall actually removes the plan's blobs — ${kind}`, async () => {
        const w = world(kind);

        const res = await w.handler(admin("deleteall"));
        assert.equal(res.status, 200, kind);

        // The assertion that matters. A prefix derived from the wrong layout
        // names an empty location: nothing is deleted and the call still
        // answers 200.
        assert.ok(
            w.drills.deleted.length >= 3,
            `${kind}: expected the blobs under ${w.base} to be deleted, got ${JSON.stringify(w.drills.deleted)}`,
        );
        assert.equal(w.drills.data.size, 0, `${kind}: blobs left behind: ${[...w.drills.data.keys()]}`);
    });

    test(`deleteall removes the index key the record came from — ${kind}`, async () => {
        const w = world(kind);

        await w.handler(admin("deleteall"));

        // Deleting only the bare slug would leave a migrated entry resolvable
        // after "delete all" — the plan reported gone, and still serving.
        assert.deepEqual(w.idx.deleted, [w.indexKey], kind);
        assert.equal(w.idx.data.size, 0, `${kind}: index key left: ${[...w.idx.data.keys()]}`);
    });

    test(`versions reads the layout the record points at — ${kind}`, async () => {
        const w = world(kind);

        const res = await w.handler(admin("versions", { method: "GET" }));
        assert.equal(res.status, 200, kind);
        assert.equal((await res.json()).versions.length, 1, kind);
    });

    test(`publish and unpublish write back to the right meta blob — ${kind}`, async () => {
        const w = world(kind);

        assert.equal((await w.handler(admin("unpublish"))).status, 200, kind);
        assert.equal(w.drills.data.get(`${w.base}meta.json`).published, false, kind);

        assert.equal((await w.handler(admin("publish"))).status, 200, kind);
        assert.equal(w.drills.data.get(`${w.base}meta.json`).published, true, kind);
    });

    test(`an unknown slug is 404 rather than a silent success — ${kind}`, async () => {
        const w = world(kind);
        const res = await w.handler(new Request(
            "https://api.ringdrill.app/api/drills-admin?action=deleteall&slug=no-such-plan",
            { method: "POST", headers: { authorization: `Bearer ${TOKEN}` } },
        ));
        assert.equal(res.status, 404, kind);
        assert.equal(w.drills.deleted.length, 0, `${kind}: a 404 must not delete anything`);
    });
}

test("an unauthenticated deleteall is refused before anything is touched", async () => {
    const w = world("migrated");

    const res = await w.handler(admin("deleteall", { auth: false }));
    assert.equal(res.status, 401);
    assert.equal(w.drills.deleted.length, 0, "nothing may be deleted on an unauthorised call");
    assert.equal(w.idx.deleted.length, 0);
});

test("a wrong bearer token is refused", async () => {
    const w = world("migrated");

    const res = await w.handler(new Request(
        "https://api.ringdrill.app/api/drills-admin?action=deleteall&slug=lsor",
        { method: "POST", headers: { authorization: "Bearer not-the-token" } },
    ));
    assert.equal(res.status, 401);
    assert.equal(w.drills.deleted.length, 0);
});
