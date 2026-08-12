/**
 * The MCP catalog tools against the ADR-0074 storage layout.
 *
 * This test exists because the migration runbook named `mcp-backend.js` as the
 * one catalog reader with no test that would notice it breaking: it is a
 * library under `lib/` rather than a function, and the hosted endpoint is only
 * exercised by `npm run smoke:mcp`, which is not part of `npm test`. That is
 * still true, which is why the file stays after the migration it was written
 * for.
 *
 * Every case used to run twice, against a pre-migration record and a migrated
 * one, so an MCP client could not tell which side of the migration it was on.
 * The migration ran on 2026-08-12 and the old layout is gone, so only the one
 * world remains.
 */
import { test } from "node:test";
import assert from "node:assert/strict";

import { createCompilerBackend } from "../functions/lib/mcp-backend.js";

const META = (slug, ownerId) => ({
    programId: "prog-1",
    slug,
    name: "Test Plan",
    description: "A plan",
    ownerId,
    published: true,
    exerciseCount: 2,
    versions: [
        { v: "1", etag: '"e1"', size: 10, updatedAt: "2026-06-01T00:00:00.000Z" },
        { v: "2", etag: '"e2"', size: 12, updatedAt: "2026-07-01T00:00:00.000Z" },
    ],
});

/** The catalog as it is stored: a namespaced index key and `catalog/<entryId>/` blobs. */
function world() {
    const meta = META("test-plan", "anon");

    const indexKey = "anon/test-plan";
    const record = { entryId: "e_1", planId: "prog-1", programId: "prog-1", ownerAccountId: null };

    const blobs = {
        "catalog/e_1/meta.json": meta,
        "catalog/e_1/2.drill": Buffer.from("PK-v2"),
        "catalog/e_1/latest.drill": Buffer.from("PK-v2"),
    };

    return {
        record,
        readBinaryCalls: [],
        deps(extra = {}) {
            const self = this;
            return {
                getDrillsStore: () => ({
                    list: async ({ prefix = "" } = {}) => ({
                        blobs: Object.keys(blobs).filter((k) => k.startsWith(prefix)).map((key) => ({ key })),
                        cursor: undefined,
                    }),
                    get: async (key, opts) => {
                        const v = blobs[key];
                        if (v === undefined) return null;
                        return opts?.type === "arrayBuffer" ? v : v;
                    },
                }),
                getSlugIndexStore: () => ({
                    list: async () => ({ blobs: [{ key: indexKey }], cursor: undefined }),
                    get: async (k) => (k === indexKey ? record : null),
                }),
                findEntry: async ({ slug }) => (slug === "test-plan" ? { ...record, slug } : null),
                resolveNamespace: async (ns) => ({ namespace: ns ?? "anon", canonical: ns ?? "anon" }),
                readJson: async (key) => blobs[key] ?? null,
                readBinary: async (key) => {
                    self.readBinaryCalls.push(key);
                    return blobs[key] ?? null;
                },
                artifactCache: () => ({ get: async () => null, set: async () => ({ modified: true }) }),
                ...extra,
            };
        },
    };
}

// ---------- search_catalog ----------

test("search_catalog lists a published plan", async () => {
    {
        const w = world();
        const backend = createCompilerBackend(w.deps());
        const { items } = await backend.searchCatalog({});

        assert.equal(items.length, 1);
        assert.equal(items[0].slug, "test-plan");
        assert.equal(items[0].name, "Test Plan");
        // An anon plan reports no namespace and keeps its bare URL either side
        // of the migration.
        assert.equal(items[0].namespace, null);
        assert.match(items[0].latestUrl, /\/d\/test-plan$/);
    }
});

test("search_catalog omits an unpublished plan", async () => {
    {
        const w = world();
        const deps = w.deps();
        const origGet = deps.getDrillsStore;
        deps.getDrillsStore = () => {
            const store = origGet();
            return { ...store, get: async (k, o) => {
                const v = await store.get(k, o);
                return v && v.published ? { ...v, published: false } : v;
            } };
        };
        const { items } = await createCompilerBackend(deps).searchCatalog({});
        assert.equal(items.length, 0);
    }
});

test("search_catalog surfaces an account namespace in the URL once migrated", async () => {
    const meta = META("vinter", "a_bergen");
    const backend = createCompilerBackend({
        getDrillsStore: () => ({
            list: async () => ({ blobs: [], cursor: undefined }),
            get: async () => meta,
        }),
        getSlugIndexStore: () => ({
            list: async () => ({ blobs: [{ key: "a_bergen/vinter" }], cursor: undefined }),
            get: async () => ({ entryId: "e_2", planId: "prog-1", ownerAccountId: "a_bergen" }),
        }),
        readJson: async () => meta,
        readBinary: async () => null,
        artifactCache: () => ({ get: async () => null, set: async () => ({ modified: true }) }),
    });

    const { items } = await backend.searchCatalog({});
    assert.equal(items[0].namespace, "a_bergen");
    assert.match(items[0].latestUrl, /\/d\/a_bergen\/vinter$/);
});

// ---------- get_plan ----------

test("get_plan resolves `latest` to a concrete version", async () => {
    {
        const w = world();
        // The compiler is not what this test is about, so stub the invoke step
        // and assert on which blob key was read.
        const backend = createCompilerBackend({
            ...w.deps(),
            invoke: async () => ({ ok: true, source: "# plan" }),
        });

        await backend.getPlan({ slug: "test-plan" }).catch(() => {});

        const expected = "catalog/e_1/2.drill";
        assert.ok(
            w.readBinaryCalls.includes(expected),
            `expected a read of ${expected}, got ${JSON.stringify(w.readBinaryCalls)}`,
        );
    }
});

test("get_plan reports an unknown slug rather than throwing something opaque", async () => {
    {
        const backend = createCompilerBackend(world().deps());
        await assert.rejects(
            () => backend.getPlan({ slug: "no-such-plan" }),
            /no published plan with slug/,
        );
    }
});

test("get_plan accepts a namespaced slug", async () => {
    // An MCP client that read `a_bergen/vinter` out of search_catalog has to be
    // able to hand it straight back.
    const meta = META("vinter", "a_bergen");
    const reads = [];
    const backend = createCompilerBackend({
        getDrillsStore: () => ({ list: async () => ({ blobs: [] }), get: async () => meta }),
        getSlugIndexStore: () => ({ list: async () => ({ blobs: [] }), get: async () => null }),
        findEntry: async ({ namespace, slug }) =>
            namespace === "a_bergen" && slug === "vinter"
                ? { entryId: "e_2", planId: "prog-1", programId: "prog-1", slug, legacy: false }
                : null,
        resolveNamespace: async (ns) => ({ namespace: ns ?? "anon", canonical: ns ?? "anon" }),
        readJson: async () => meta,
        readBinary: async (key) => { reads.push(key); return null; },
        artifactCache: () => ({ get: async () => null, set: async () => ({ modified: true }) }),
        invoke: async () => ({ ok: true, source: "# plan" }),
    });

    await backend.getPlan({ slug: "a_bergen/vinter" }).catch(() => {});
    assert.ok(reads.some((k) => k.startsWith("catalog/e_2/")), JSON.stringify(reads));
});
