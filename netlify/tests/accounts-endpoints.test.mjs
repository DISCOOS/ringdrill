/**
 * Organisations and members (DESIGN-015 §6), under AUTH_MODE=mock.
 *
 * The invariants get the most attention: only an owner administers, an
 * organisation never loses its last accepted owner, and invited is a state
 * rather than a role.
 */
import { test } from "node:test";
import assert from "node:assert/strict";

import { createHandler } from "../functions/accounts.js";
import { createMockAdapter } from "../functions/lib/mail/index.js";
import { mintTestToken } from "../functions/lib/auth/mock.js";
import { AUDIENCE, ISSUER } from "../functions/lib/auth/index.js";
import { membersOf, putMember } from "../functions/lib/identity.js";

function fakeStore() {
    const data = new Map();
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
        async list({ prefix = "", cursor } = {}) {
            if (cursor) return { blobs: [], cursor: undefined };
            return { blobs: [...data.keys()].filter((k) => k.startsWith(prefix)).map((key) => ({ key })), cursor: undefined };
        },
    };
}

/**
 * A catalog store, holding decoded objects.
 *
 * Writers in this codebase are split: some hand the blob store a JSON string,
 * some hand it an object. A fake that stored whichever it was given would let
 * a test read back a string and quietly compare `undefined` against the value
 * it expected — which is exactly how the deletion tests first "passed" the
 * write and failed the assertion. Normalising on write keeps reads honest.
 */
function jsonStore(seed = {}) {
    const data = new Map(Object.entries(seed));
    const decode = (v) => (typeof v === "string" ? JSON.parse(v) : v);
    return {
        data,
        async get(key) { return data.get(key) ?? null; },
        async set(key, value) { data.set(key, decode(value)); return { modified: true }; },
        async delete(key) { data.delete(key); },
        async list({ prefix = "", cursor } = {}) {
            if (cursor) return { blobs: [], cursor: undefined };
            return { blobs: [...data.keys()].filter((k) => k.startsWith(prefix)).map((key) => ({ key })), cursor: undefined };
        },
    };
}

function harness({ index = {}, drills = {} } = {}) {
    const raw = {
        accounts: fakeStore(), users: fakeStore(), identities: fakeStore(), members: fakeStore(),
        emailIndex: fakeStore(), handles: fakeStore(), sessions: fakeStore(), invites: fakeStore(),
        index: jsonStore(index), drills: jsonStore(drills),
    };
    const stores = {
        accounts: () => raw.accounts, users: () => raw.users, identities: () => raw.identities,
        members: () => raw.members, emailIndex: () => raw.emailIndex, handles: () => raw.handles,
        sessions: () => raw.sessions,
    };
    const mailer = createMockAdapter();
    const handler = createHandler({
        env: { AUTH_MODE: "mock", PUBLIC_APP_ORIGIN: "https://ringdrill.app" },
        stores, inviteStore: () => raw.invites, mailer,
        getSlugIndexStore: () => raw.index,
        getDrillsStore: () => raw.drills,
        // The fake drills store holds objects rather than JSON text, so the
        // json helpers are matched to it instead of stringifying on the way in
        // and leaving the assertions reading a string.
        readJson: async (key, dflt = null) => raw.drills.data.get(key) ?? dflt,
        writeJson: async (key, obj) => { raw.drills.data.set(key, obj); return { modified: true }; },
    });
    return { handler, stores, raw, mailer };
}

const token = (userId, roles) => mintTestToken({
    iss: ISSUER, aud: AUDIENCE, sub: userId,
    act: Object.keys(roles)[0] ?? null, acts: Object.keys(roles), roles,
    exp: Math.floor(Date.now() / 1000) + 3600,
});

const call = (h, method, path, { as, body } = {}) => h.handler(new Request(
    `https://api.ringdrill.app/api/accounts${path}`,
    {
        method,
        headers: { "content-type": "application/json", ...(as ? { authorization: `Bearer ${as}` } : {}) },
        ...(body ? { body: JSON.stringify(body) } : {}),
    },
));

async function orgWith(h, roles) {
    await h.stores.accounts().set("a_bergen", JSON.stringify({ id: "a_bergen", displayName: "Red Cross Bergen", type: "organization" }));
    for (const [userId, role] of Object.entries(roles)) {
        await h.stores.users().set(userId, JSON.stringify({ id: userId, displayName: userId, primaryEmail: `${userId}@example.com` }));
        await putMember("a_bergen", userId, role, { acceptedAt: "2026-08-01" }, h.stores);
    }
}

// ---------- auth ----------

test("every route requires authentication", async () => {
    const h = harness();
    assert.equal((await call(h, "GET", "/a_bergen/members")).status, 401);
});

// ---------- create ----------

test("creating an organisation makes the creator its owner", async () => {
    const h = harness();
    const res = await call(h, "POST", "", { as: token("u_1", {}), body: { displayName: "Red Cross Bergen", handle: "redcross-bergen" } });
    assert.equal(res.status, 201);
    const { account } = await res.json();
    assert.equal(account.type, "organization");
    assert.equal(account.handle, "redcross-bergen");

    const member = await h.stores.members().get(`${account.id}/u_1`, { type: "json" });
    assert.equal(member.role, "owner");
});

test("a reserved or taken handle is refused rather than silently dropped", async () => {
    const h = harness();
    assert.equal((await call(h, "POST", "", { as: token("u_1", {}), body: { displayName: "X", handle: "anon" } })).status, 400);

    await call(h, "POST", "", { as: token("u_1", {}), body: { displayName: "A", handle: "taken-name" } });
    const clash = await call(h, "POST", "", { as: token("u_2", {}), body: { displayName: "B", handle: "taken-name" } });
    assert.equal(clash.status, 409);
});

test("upgrading a personal account requires owning it", async () => {
    const h = harness();
    await h.stores.accounts().set("a_kari", JSON.stringify({ id: "a_kari", displayName: "Kari", type: "personal" }));

    const notOwner = await call(h, "POST", "", { as: token("u_2", { a_kari: "member" }), body: { displayName: "Org", upgradeAccountId: "a_kari" } });
    assert.equal(notOwner.status, 403);

    const owner = await call(h, "POST", "", { as: token("u_1", { a_kari: "owner" }), body: { displayName: "Org", upgradeAccountId: "a_kari" } });
    const body = await owner.json();
    assert.equal(body.upgraded, true);
    assert.equal(body.account.type, "organization");
});

// ---------- list ----------

test("members list shows accepted and invited rows, and flags a single owner", async () => {
    const h = harness();
    await orgWith(h, { u_1: "owner", u_2: "member" });
    const res = await call(h, "GET", "/a_bergen/members", { as: token("u_2", { a_bergen: "member" }) });
    const body = await res.json();

    assert.equal(res.status, 200);
    assert.equal(body.singleOwner, true, "DESIGN-015 §4.4's advisory needs this");
    assert.deepEqual(body.members.map((m) => m.state).sort(), ["accepted", "accepted"]);
});

test("a non-member cannot read the members list", async () => {
    const h = harness();
    await orgWith(h, { u_1: "owner" });
    assert.equal((await call(h, "GET", "/a_bergen/members", { as: token("u_9", { a_other: "owner" }) })).status, 403);
});

// ---------- invite ----------

test("only an owner may invite, and the invitation is addressed to the email", async () => {
    const h = harness();
    await orgWith(h, { u_1: "owner", u_2: "member" });

    // Publishing follows from membership; deciding who else is here is
    // administration, which is what owner means.
    assert.equal((await call(h, "POST", "/a_bergen/members", {
        as: token("u_2", { a_bergen: "member" }), body: { email: "ola@example.com", role: "member" },
    })).status, 403);

    const res = await call(h, "POST", "/a_bergen/members", {
        as: token("u_1", { a_bergen: "owner" }), body: { email: "Ola@Example.com", role: "guest", locale: "nb" },
    });
    assert.equal(res.status, 201);

    assert.equal(h.mailer.outbox.length, 1);
    assert.equal(h.mailer.outbox[0].to, "ola@example.com");
    assert.match(h.mailer.outbox[0].subject, /invitert/, "the inviter's locale, the only signal for someone with no account");
    assert.match(h.mailer.outbox[0].text, /logge inn/, "accepting requires signing in — a forwarded invite is not a handover");
});

test("an invited row is a state, not a grant", async () => {
    const h = harness();
    await orgWith(h, { u_1: "owner" });
    await call(h, "POST", "/a_bergen/members", { as: token("u_1", { a_bergen: "owner" }), body: { email: "ola@example.com", role: "member" } });

    const body = await (await call(h, "GET", "/a_bergen/members", { as: token("u_1", { a_bergen: "owner" }) })).json();
    const pending = body.members.find((m) => m.email === "ola@example.com");
    assert.equal(pending.state, "invited");
    assert.equal(pending.role, "member", "the role is chosen at invite time and does not change on acceptance");
    assert.equal(pending.acceptedAt, null);
});

test("an invalid role or address is refused", async () => {
    const h = harness();
    await orgWith(h, { u_1: "owner" });
    const as = token("u_1", { a_bergen: "owner" });
    assert.equal((await call(h, "POST", "/a_bergen/members", { as, body: { email: "a@b.com", role: "editor" } })).status, 400);
    assert.equal((await call(h, "POST", "/a_bergen/members", { as, body: { email: "nope", role: "member" } })).status, 400);
});

// ---------- the last-owner invariant ----------

test("the last accepted owner cannot be demoted", async () => {
    const h = harness();
    await orgWith(h, { u_1: "owner", u_2: "member" });
    const res = await call(h, "PATCH", "/a_bergen/members/u_1", {
        as: token("u_1", { a_bergen: "owner" }), body: { role: "member" },
    });
    assert.equal(res.status, 409);
    assert.equal((await res.json()).error, "last_owner");
});

test("the last accepted owner cannot leave, which is what strands an organisation", async () => {
    const h = harness();
    await orgWith(h, { u_1: "owner", u_2: "member" });
    const res = await call(h, "DELETE", "/a_bergen/members/u_1", { as: token("u_1", { a_bergen: "owner" }) });
    assert.equal(res.status, 409);
});

test("with two owners either may step down", async () => {
    const h = harness();
    await orgWith(h, { u_1: "owner", u_2: "owner" });
    const res = await call(h, "PATCH", "/a_bergen/members/u_1", {
        as: token("u_1", { a_bergen: "owner" }), body: { role: "member" },
    });
    assert.equal(res.status, 200);
});

test("an INVITED owner does not count — they cannot keep the account reachable", async () => {
    const h = harness();
    await orgWith(h, { u_1: "owner" });
    await putMember("a_bergen", "u_invited", "owner", { invitedAt: "2026-08-02", acceptedAt: null }, h.stores);

    const res = await call(h, "DELETE", "/a_bergen/members/u_1", { as: token("u_1", { a_bergen: "owner" }) });
    assert.equal(res.status, 409, "an unaccepted owner is not an owner yet");
});

// ---------- remove and leave ----------

test("a member may remove themselves; only an owner may remove anyone else", async () => {
    const h = harness();
    await orgWith(h, { u_1: "owner", u_2: "member", u_3: "guest" });

    assert.equal((await call(h, "DELETE", "/a_bergen/members/u_3", { as: token("u_2", { a_bergen: "member" }) })).status, 403);
    assert.equal((await call(h, "DELETE", "/a_bergen/members/u_2", { as: token("u_2", { a_bergen: "member" }) })).status, 204, "leaving");
    assert.equal((await call(h, "DELETE", "/a_bergen/members/u_3", { as: token("u_1", { a_bergen: "owner" }) })).status, 204);
});

test("removing somebody who is not a member is 404", async () => {
    const h = harness();
    await orgWith(h, { u_1: "owner" });
    assert.equal((await call(h, "DELETE", "/a_bergen/members/u_nope", { as: token("u_1", { a_bergen: "owner" }) })).status, 404);
});

// ---------- plans (the Library's fourth tab, DESIGN-015 §5.7) ----------

const planMeta = (o) => ({
    programId: o.id, slug: o.slug, name: o.name, description: "",
    published: o.published ?? true, exerciseCount: 1,
    versions: [{ v: "1", etag: '"e1"', size: 9, updatedAt: o.updatedAt ?? "2026-06-01T00:00:00.000Z" }],
});

/** One account with two plans, plus an anon plan and another account's plan. */
function catalog() {
    return {
        index: {
            "a_bergen/vinter": { entryId: "e_1", planId: "p_1", ownerAccountId: "a_bergen" },
            "a_bergen/host": { entryId: "e_2", planId: "p_2", ownerAccountId: "a_bergen" },
            // Neither of these may appear in a_bergen's list.
            "anon/lsor": { entryId: "e_3", planId: "p_3", ownerAccountId: null },
            "a_bergen2/annet": { entryId: "e_4", planId: "p_4", ownerAccountId: "a_bergen2" },
        },
        drills: {
            "catalog/e_1/meta.json": planMeta({ id: "p_1", slug: "vinter", name: "Vinter", updatedAt: "2026-07-01T00:00:00.000Z" }),
            "catalog/e_2/meta.json": planMeta({ id: "p_2", slug: "host", name: "Høst", published: false, updatedAt: "2026-06-01T00:00:00.000Z" }),
            "catalog/e_3/meta.json": planMeta({ id: "p_3", slug: "lsor", name: "LSOR" }),
            "catalog/e_4/meta.json": planMeta({ id: "p_4", slug: "annet", name: "Annet" }),
        },
    };
}

test("an account's plans list only that account's plans", async () => {
    const h = harness(catalog());
    await orgWith(h, { u_1: "owner" });

    const res = await call(h, "GET", "/a_bergen/plans", { as: token("u_1", { a_bergen: "owner" }) });
    assert.equal(res.status, 200);
    const { items } = await res.json();

    // The trailing slash in the prefix is what keeps `a_bergen2` out; the anon
    // namespace is a different account entirely.
    assert.deepEqual(items.map((i) => i.slug).sort(), ["host", "vinter"]);
});

test("unpublished plans are listed, and say so", async () => {
    // An account library that showed only published plans would omit exactly
    // the drafts the tab exists for.
    const h = harness(catalog());
    await orgWith(h, { u_1: "owner" });

    const { items } = await (await call(h, "GET", "/a_bergen/plans", { as: token("u_1", { a_bergen: "owner" }) })).json();
    const host = items.find((i) => i.slug === "host");
    assert.equal(host.published, false);
    assert.equal(items.find((i) => i.slug === "vinter").published, true);
});

test("each item carries the account namespace in its URL", async () => {
    const h = harness(catalog());
    await orgWith(h, { u_1: "owner" });

    const { items } = await (await call(h, "GET", "/a_bergen/plans", { as: token("u_1", { a_bergen: "owner" }) })).json();
    assert.equal(items.find((i) => i.slug === "vinter").namespace, "a_bergen");
    assert.match(items.find((i) => i.slug === "vinter").latestUrl, /\/d\/a_bergen\/vinter$/);
});

test("a guest sees the account's plans — guest is a PII tier, not a smaller catalog", async () => {
    // Hiding the plans from a guest would hide the thing they were invited to
    // work on. What a guest does not get is the roster inside a plan, and that
    // is enforced on the download path (ADR-0072), not here.
    const h = harness(catalog());
    await orgWith(h, { u_1: "owner", u_3: "guest" });

    const res = await call(h, "GET", "/a_bergen/plans", { as: token("u_3", { a_bergen: "guest" }) });
    assert.equal(res.status, 200);
    assert.equal((await res.json()).items.length, 2);
});

test("a non-member cannot list an account's plans", async () => {
    const h = harness(catalog());
    await orgWith(h, { u_1: "owner" });

    const res = await call(h, "GET", "/a_bergen/plans", { as: token("u_9", { a_other: "owner" }) });
    assert.equal(res.status, 403);
    assert.equal((await res.json()).error, "not_a_member");
});

test("listing an account's plans requires authentication", async () => {
    const h = harness(catalog());
    assert.equal((await call(h, "GET", "/a_bergen/plans")).status, 401);
});

test("an index entry whose meta is missing is skipped, not returned half-built", async () => {
    const c = catalog();
    delete c.drills["catalog/e_2/meta.json"];
    const h = harness(c);
    await orgWith(h, { u_1: "owner" });

    const { items } = await (await call(h, "GET", "/a_bergen/plans", { as: token("u_1", { a_bergen: "owner" }) })).json();
    assert.deepEqual(items.map((i) => i.slug), ["vinter"]);
});

test("an account with no plans gets an empty list, not a 404", async () => {
    const h = harness(catalog());
    await orgWith(h, { u_1: "owner" });
    await h.stores.accounts().set("a_empty", JSON.stringify({ id: "a_empty", displayName: "Empty", type: "organization" }));
    await putMember("a_empty", "u_1", "owner", { acceptedAt: "2026-08-01" }, h.stores);

    const res = await call(h, "GET", "/a_empty/plans", { as: token("u_1", { a_empty: "owner" }) });
    assert.equal(res.status, 200);
    assert.deepEqual((await res.json()).items, []);
});

test("POST to the plans route is not a route", async () => {
    const h = harness(catalog());
    await orgWith(h, { u_1: "owner" });
    assert.equal((await call(h, "POST", "/a_bergen/plans", { as: token("u_1", { a_bergen: "owner" }), body: {} })).status, 404);
});

// ---------- deletion (DESIGN-015 §5.1) ----------

/// An organisation with a handle and one published plan in its namespace.
async function orgWithPlan(h) {
    await orgWith(h, { u_1: 'owner' });
    await h.stores.accounts().set("a_bergen", JSON.stringify({
        id: "a_bergen", displayName: "Red Cross Bergen", type: "organization", handle: "redcross-bergen",
    }));
    await h.stores.handles().set("redcross-bergen", JSON.stringify({ accountId: "a_bergen" }));
    await h.raw.index.set("a_bergen/vinter", { entryId: "e_1", planId: "p_1", ownerAccountId: "a_bergen" });
    await h.raw.drills.set("catalog/e_1/meta.json", {
        programId: "p_1", slug: "vinter", name: "Vinter", published: true,
        ownerId: "a_bergen", accessPolicy: "shared", sharedAccountIds: ["a_fjell"],
        versions: [{ v: "1", etag: '"e1"', size: 9 }],
    });
}

test("only an owner may delete an account", async () => {
    const h = harness();
    await orgWithPlan(h);
    const res = await call(h, "DELETE", "/a_bergen", { as: token("u_2", { a_bergen: "member" }) });
    assert.equal(res.status, 403);
    assert.ok(await h.stores.accounts().get("a_bergen", { type: "json" }));
});

test("deleting an organisation removes it and its member rows", async () => {
    const h = harness();
    await orgWithPlan(h);
    await putMember("a_bergen", "u_2", "member", { acceptedAt: "2026-08-01" }, h.stores);

    const res = await call(h, "DELETE", "/a_bergen", { as: token("u_1", { a_bergen: "owner" }) });
    assert.equal(res.status, 200);

    assert.equal(await h.stores.accounts().get("a_bergen", { type: "json" }), null);
    assert.deepEqual(await membersOf("a_bergen", h.stores), []);
});

test("published plans survive, losing only their owner", async () => {
    // "Delete my account" reasonably sounds like it should unpublish, and it
    // must not: other people have installed these plans.
    const h = harness();
    await orgWithPlan(h);

    const body = await (await call(h, "DELETE", "/a_bergen", { as: token("u_1", { a_bergen: "owner" }) })).json();
    assert.equal(body.plansReleased, 1);

    const meta = await h.raw.drills.get("catalog/e_1/meta.json");
    assert.equal(meta.published, true, "still published");
    assert.equal(meta.ownerId, "anon", "but unowned");
    // A grantee list names accounts granted access by an owner who no longer
    // exists — keeping it would leave a dangling grant.
    assert.equal(meta.accessPolicy, "public");
    assert.deepEqual(meta.sharedAccountIds, []);
});

test("the plan keeps its URL — the index key is not rewritten", async () => {
    // Moving the entry into `anon/` would change /d/<handle>/<slug> and break
    // every link already shared.
    const h = harness();
    await orgWithPlan(h);

    await call(h, "DELETE", "/a_bergen", { as: token("u_1", { a_bergen: "owner" }) });

    assert.ok(h.raw.index.data.has("a_bergen/vinter"), "the key is untouched");
    assert.equal((await h.raw.index.get("a_bergen/vinter")).ownerAccountId, null);
});

test("the handle is retired, not released", async () => {
    // Releasing it would point somebody's already-shared link at a stranger's
    // plan (ADR-0074).
    const h = harness();
    await orgWithPlan(h);

    await call(h, "DELETE", "/a_bergen", { as: token("u_1", { a_bergen: "owner" }) });

    const handle = await h.stores.handles().get("redcross-bergen", { type: "json" });
    assert.equal(handle.tombstone, true, "the handle must not be re-registrable");
});

test("deleting a personal account removes the user and their sessions", async () => {
    const h = harness();
    await h.stores.accounts().set("a_kari", JSON.stringify({ id: "a_kari", displayName: "Kari", type: "personal" }));
    await h.stores.users().set("u_1", JSON.stringify({ id: "u_1", displayName: "Kari", primaryEmail: "kari@example.com" }));
    await h.stores.identities().set("email/kari@example.com", JSON.stringify({ userId: "u_1", provider: "email" }));
    await h.stores.emailIndex().set("kari@example.com", JSON.stringify({ userId: "u_1" }));
    await h.stores.sessions().set("s_1", JSON.stringify({ sessionId: "s_1", userId: "u_1" }));
    await putMember("a_kari", "u_1", "owner", { acceptedAt: "2026-08-01" }, h.stores);

    assert.equal((await call(h, "DELETE", "/a_kari", { as: token("u_1", { a_kari: "owner" }) })).status, 200);

    assert.equal(await h.stores.users().get("u_1", { type: "json" }), null);
    assert.equal(await h.stores.identities().get("email/kari@example.com", { type: "json" }), null);
    assert.equal(await h.stores.emailIndex().get("kari@example.com", { type: "json" }), null);
    assert.equal(await h.stores.sessions().get("s_1", { type: "json" }), null, "no live session outlives the user");
});

test("deleting a personal account is refused while it is an organisation's only owner", async () => {
    // Otherwise a button reaches the unrecoverable state DESIGN-015 §4.4
    // exists to prevent.
    const h = harness();
    await orgWithPlan(h);
    await h.stores.accounts().set("a_kari", JSON.stringify({ id: "a_kari", displayName: "Kari", type: "personal" }));
    await putMember("a_kari", "u_1", "owner", { acceptedAt: "2026-08-01" }, h.stores);

    const res = await call(h, "DELETE", "/a_kari", {
        as: token("u_1", { a_kari: "owner", a_bergen: "owner" }),
    });
    assert.equal(res.status, 409);
    const body = await res.json();
    assert.equal(body.error, "sole_owner_of_organisation");
    // Named, so the user knows what to hand over first.
    assert.deepEqual(body.organisations, ["Red Cross Bergen"]);
    assert.ok(await h.stores.users().get("u_1", { type: "json" }), "nothing was deleted");
});

test("deleting an unknown account is 404", async () => {
    const h = harness();
    await orgWith(h, { u_1: "owner" });
    assert.equal((await call(h, "DELETE", "/a_nope", { as: token("u_1", { a_nope: "owner" }) })).status, 404);
});

// ---------- handle lookup ----------

test("lookup resolves a handle to the id that gets stored", async () => {
    // Ids are what a shared plan stores, because handles change and ids do
    // not (ADR-0074). Asking a person for an opaque id is asking them to fetch
    // something they have never seen.
    const h = harness();
    await orgWith(h, { u_1: "owner" });
    await h.stores.accounts().set("a_bergen", JSON.stringify({
        id: "a_bergen", displayName: "Red Cross Bergen", type: "organization", handle: "redcross-bergen",
    }));
    await h.stores.handles().set("redcross-bergen", JSON.stringify({ accountId: "a_bergen" }));

    const res = await call(h, "GET", "/lookup?handle=redcross-bergen", { as: token("u_1", { a_bergen: "owner" }) });
    assert.equal(res.status, 200);
    assert.deepEqual(await res.json(), {
        accountId: "a_bergen",
        displayName: "Red Cross Bergen",
        handle: "redcross-bergen",
        renamed: false,
    });
});

test("lookup requires signing in", async () => {
    // Handles are public — they are in every /d/<handle>/<slug> link — so this
    // is about keeping the endpoint away from drive-by scanning, not about the
    // handle being secret.
    const h = harness();
    assert.equal((await call(h, "GET", "/lookup?handle=redcross-bergen")).status, 401);
});

test("lookup tells you when a retired name was used", async () => {
    // Silently accepting a name that no longer exists would leave the user
    // sharing with something they cannot see under the name they typed.
    const h = harness();
    await orgWith(h, { u_1: "owner" });
    await h.stores.accounts().set("a_bergen", JSON.stringify({
        id: "a_bergen", displayName: "Red Cross Bergen", type: "organization", handle: "rk-bergen",
    }));
    await h.stores.handles().set("redcross-bergen", JSON.stringify({
        accountId: "a_bergen", tombstone: true, redirectsTo: "rk-bergen",
    }));

    const body = await (await call(h, "GET", "/lookup?handle=redcross-bergen", {
        as: token("u_1", { a_bergen: "owner" }),
    })).json();
    assert.equal(body.renamed, true);
    assert.equal(body.handle, "rk-bergen", "and names the current one");
});

test("lookup is exact — a prefix is not a search", async () => {
    // A prefix or fuzzy endpoint would be a tool for listing which
    // organisations exist. This deliberately is not one.
    const h = harness();
    await orgWith(h, { u_1: "owner" });
    await h.stores.handles().set("redcross-bergen", JSON.stringify({ accountId: "a_bergen" }));

    assert.equal((await call(h, "GET", "/lookup?handle=redcross", {
        as: token("u_1", { a_bergen: "owner" }),
    })).status, 404);
});

test("a handle whose account is gone does not resolve", async () => {
    // The tombstone still redirects existing links, but there is nothing left
    // to share with.
    const h = harness();
    await orgWith(h, { u_1: "owner" });
    await h.stores.handles().set("gone", JSON.stringify({ accountId: "a_deleted", tombstone: true }));

    assert.equal((await call(h, "GET", "/lookup?handle=gone", {
        as: token("u_1", { a_bergen: "owner" }),
    })).status, 404);
});
