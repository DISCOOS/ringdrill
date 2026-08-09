/**
 * POST /api/drills/policy — changing a plan's access policy (ADR-0025).
 *
 * The endpoint is thin; authorizePolicyChange is tested exhaustively in
 * authorize.test.mjs. What is tested here is the wiring nobody else covers:
 * that owner-only really is enforced end to end, that `shared` cannot be set
 * without grantees, and that the conditional write is guarded.
 */
import { test } from "node:test";
import assert from "node:assert/strict";
import { createHandler } from "../functions/drills-policy.js";
import { mintTestToken } from "../functions/lib/auth/mock.js";
import { AUDIENCE, ISSUER } from "../functions/lib/auth/index.js";

const ENV = { AUTH_MODE: "mock" };

const token = (userId, roles) => mintTestToken({
    iss: ISSUER, aud: AUDIENCE, sub: userId,
    act: Object.keys(roles)[0] ?? null, acts: Object.keys(roles), roles,
    exp: Math.floor(Date.now() / 1000) + 3600,
});

function call(handler, { slug = "lsor", as, body }) {
    return handler(new Request(`https://api.ringdrill.app/api/drills/policy?slug=${slug}`, {
        method: "POST",
        headers: { "content-type": "application/json", ...(as ? { authorization: `Bearer ${as}` } : {}) },
        body: JSON.stringify(body ?? {}),
    }));
}

function harness({ entry, meta }) {
    const state = { meta: meta ? { ...meta } : null, etag: '"e1"', reportedEtag: '"e1"', written: null };
    return {
        state,
        handler: createHandler({
            env: ENV,
            findEntry: async () => entry,
            resolveNamespace: async (ns) => ({ namespace: ns ?? "anon", canonical: ns ?? "anon" }),
            readJsonStrong: async () => state.meta,
            getBlobEtag: async () => state.reportedEtag,
            writeJsonConditional: async (_key, obj, opts) => {
                // Stands in for a conditional write: a mismatched etag means
                // somebody else wrote in between.
                if (opts?.onlyIfMatch && opts.onlyIfMatch !== state.etag) return { modified: false };
                state.written = obj;
                return { modified: true };
            },
        }),
    };
}

const OWNED = { entryId: "e_1", ownerId: "a_bergen", planId: "p_1", slug: "lsor", namespace: "a_bergen" };
const OWNED_META = { slug: "lsor", ownerId: "a_bergen", accessPolicy: "account" };

test("an owner may change the policy", async () => {
    const h = harness({ entry: OWNED, meta: OWNED_META });

    const res = await call(h.handler, { as: token("u_1", { a_bergen: "owner" }), body: { accessPolicy: "public" } });
    assert.equal(res.status, 200);
    assert.equal((await res.json()).accessPolicy, "public");
    assert.equal(h.state.written.accessPolicy, "public");
});

test("a member and a guest may not — this is the one place rank matters", async () => {
    const h = harness({ entry: OWNED, meta: OWNED_META });

    for (const role of ["member", "guest"]) {
        const res = await call(h.handler, { as: token("u_2", { a_bergen: role }), body: { accessPolicy: "public" } });
        assert.equal(res.status, 403, role);
        assert.equal((await res.json()).error, "owner_role_required", role);
    }
});

test("an anonymous caller is 401", async () => {
    const h = harness({ entry: OWNED, meta: OWNED_META });
    assert.equal((await call(h.handler, { body: { accessPolicy: "public" } })).status, 401);
});

test("`shared` without grantees is refused, not stored empty", async () => {
    // Storing it would read as "shared" in the UI while behaving as "account".
    const h = harness({ entry: OWNED, meta: OWNED_META });

    const res = await call(h.handler, {
        as: token("u_1", { a_bergen: "owner" }), body: { accessPolicy: "shared" },
    });
    assert.equal(res.status, 400);
    assert.equal((await res.json()).error, "shared_requires_accounts");
    assert.equal(h.state.written, null);
});

test("`shared` with grantees stores them, and moving away clears them", async () => {
    const h = harness({ entry: OWNED, meta: OWNED_META });
    const as = token("u_1", { a_bergen: "owner" });

    await call(h.handler, { as, body: { accessPolicy: "shared", sharedAccountIds: ["a_fjell"] } });
    assert.deepEqual(h.state.written.sharedAccountIds, ["a_fjell"]);

    // A stale grantee list on an account-policy plan would grant access the UI
    // no longer shows.
    await call(h.handler, { as, body: { accessPolicy: "account" } });
    assert.deepEqual(h.state.written.sharedAccountIds, []);
});

test("an unrecognised policy is refused", async () => {
    const h = harness({ entry: OWNED, meta: OWNED_META });
    const res = await call(h.handler, { as: token("u_1", { a_bergen: "owner" }), body: { accessPolicy: "everyone" } });
    assert.equal(res.status, 400);
});

test("an anon plan cannot have its policy changed — no path from anon to owned", async () => {
    const h = harness({
        entry: { ownerId: "anon", programId: "p_9", slug: "lsor", namespace: "anon" },
        meta: { slug: "lsor", ownerId: "anon", accessPolicy: "public" },
    });

    const res = await call(h.handler, { as: token("u_1", { a_bergen: "owner" }), body: { accessPolicy: "account" } });
    assert.equal(res.status, 403);
    assert.equal((await res.json()).error, "anon_plan_has_no_owner");
});

test("an unknown slug is 404", async () => {
    const h = harness({ entry: null, meta: null });
    assert.equal((await call(h.handler, { as: token("u_1", { a_bergen: "owner" }), body: { accessPolicy: "public" } })).status, 404);
});

test("a concurrent change is a 412 rather than a silent overwrite", async () => {
    const h = harness({ entry: OWNED, meta: OWNED_META });
    // The etag the handler reads no longer matches the one the store will
    // accept — somebody else wrote in between.
    h.state.reportedEtag = '"stale"';

    const res = await call(h.handler, { as: token("u_1", { a_bergen: "owner" }), body: { accessPolicy: "public" } });
    assert.equal(res.status, 412, "a concurrent change must not be silently overwritten");
});

test("GET is not allowed — this endpoint only mutates", async () => {
    const h = harness({ entry: OWNED, meta: OWNED_META });
    const res = await h.handler(new Request("https://api.ringdrill.app/api/drills/policy?slug=lsor"));
    assert.equal(res.status, 405);
});
