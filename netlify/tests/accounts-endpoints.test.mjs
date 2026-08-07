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
import { putMember } from "../functions/lib/identity.js";

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

function harness() {
    const raw = {
        accounts: fakeStore(), users: fakeStore(), identities: fakeStore(), members: fakeStore(),
        emailIndex: fakeStore(), handles: fakeStore(), sessions: fakeStore(), invites: fakeStore(),
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
