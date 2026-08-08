/**
 * Answering an invitation (DESIGN-015 §6.4), under AUTH_MODE=mock.
 *
 * Two properties carry the weight, and both are security properties rather
 * than conveniences:
 *
 * * The link is **not a credential** — it says which invitation is being
 *   answered and grants nothing on its own.
 * * The **invited address** is what binds — a forwarded invitation must not
 *   become account access for whoever opens it.
 *
 * The rest is the state machine the landing page renders: accepted, withdrawn,
 * expired, organisation deleted, wrong person. Each is asserted by name,
 * because the page shows a different message for each and a generic 400 would
 * make them indistinguishable.
 */
import { test } from "node:test";
import assert from "node:assert/strict";

import { createHandler } from "../functions/invitations.js";
import { createHandler as createAccountsHandler } from "../functions/accounts.js";
import { createMockAdapter } from "../functions/lib/mail/index.js";
import { mintTestToken } from "../functions/lib/auth/mock.js";
import { AUDIENCE, ISSUER } from "../functions/lib/auth/index.js";

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

const ENV = { AUTH_MODE: "mock", PUBLIC_APP_ORIGIN: "https://ringdrill.app" };

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
    return {
        raw, stores, mailer,
        handler: createHandler({ env: ENV, stores, inviteStore: () => raw.invites }),
        accounts: createAccountsHandler({ env: ENV, stores, inviteStore: () => raw.invites, mailer }),
    };
}

const token = (userId, roles = {}) => mintTestToken({
    iss: ISSUER, aud: AUDIENCE, sub: userId,
    act: Object.keys(roles)[0] ?? null, acts: Object.keys(roles), roles,
    exp: Math.floor(Date.now() / 1000) + 3600,
});

const get = (h, t) => h.handler(new Request(`https://api.ringdrill.app/api/invitations/${encodeURIComponent(t)}`));
const accept = (h, t, as) => h.handler(new Request(
    `https://api.ringdrill.app/api/invitations/${encodeURIComponent(t)}/accept`,
    { method: "POST", headers: as ? { authorization: `Bearer ${as}` } : {} },
));

/**
 * An organisation with one owner, and a real invitation created through the
 * accounts endpoint rather than hand-written — so the two halves are proven to
 * agree on the token and the pending row.
 */
async function invited(h, { email = "ola@example.com", role = "member" } = {}) {
    await h.stores.accounts().set("a_bergen", JSON.stringify({ id: "a_bergen", displayName: "Red Cross Bergen", type: "organization" }));
    await h.stores.users().set("u_1", JSON.stringify({ id: "u_1", displayName: "Kari", primaryEmail: "kari@example.com" }));
    await h.stores.members().set("a_bergen/u_1", JSON.stringify({ accountId: "a_bergen", userId: "u_1", role: "owner", acceptedAt: "2026-08-01" }));

    const res = await h.accounts(new Request("https://api.ringdrill.app/api/accounts/a_bergen/members", {
        method: "POST",
        headers: { "content-type": "application/json", authorization: `Bearer ${token("u_1", { a_bergen: "owner" })}` },
        body: JSON.stringify({ email, role }),
    }));
    assert.equal(res.status, 201, "fixture: the invite must have been created");
    return [...h.raw.invites.data.keys()][0];
}

/** A signed-up user whose address is verified — the emailIndex is the proof. */
async function userWithVerifiedEmail(h, userId, email) {
    await h.stores.users().set(userId, JSON.stringify({
        id: userId, displayName: userId, primaryEmail: email, primaryEmailVerified: true,
    }));
    await h.stores.emailIndex().set(email, JSON.stringify({ userId }));
}

// ---------- describe ----------

test("the invitation can be read signed out — the page must render before sign-in", async () => {
    // If reading it required already being the right person, the page could
    // never say who to sign in as.
    const h = harness();
    const t = await invited(h);

    const res = await get(h, t);
    assert.equal(res.status, 200);
    const body = await res.json();
    assert.equal(body.state, "pending");
    assert.equal(body.organisation, "Red Cross Bergen");
    assert.equal(body.email, "ola@example.com");
    assert.equal(body.role, "member");
    assert.equal(body.inviterName, "Kari");
});

test("the invitation is never cached — its state changes underneath the page", async () => {
    const h = harness();
    const t = await invited(h);
    assert.equal((await get(h, t)).headers.get("cache-control"), "no-store");
});

test("an unknown token is 404", async () => {
    const h = harness();
    assert.equal((await get(h, "inv_nope")).status, 404);
});

// ---------- the link is not a credential ----------

test("following the link grants nothing — accepting requires signing in", async () => {
    const h = harness();
    const t = await invited(h);

    const res = await accept(h, t);
    assert.equal(res.status, 401);
    // The whole point: holding the link left no membership behind.
    assert.equal(await h.stores.members().get("a_bergen/u_2", { type: "json" }), null);
});

test("a forwarded invitation does not become account access", async () => {
    // Signed in, verified — just not as the person invited. This is the case
    // that turns a forwarded email into account access if it is allowed.
    const h = harness();
    const t = await invited(h);
    await userWithVerifiedEmail(h, "u_9", "someone.else@example.com");

    const res = await accept(h, t, token("u_9"));
    assert.equal(res.status, 403);
    const body = await res.json();
    assert.equal(body.error, "wrong_identity");
    // Both remedies §6.4 requires: which address to use, and who to ask.
    assert.equal(body.invitedEmail, "ola@example.com");
    assert.equal(body.organisation, "Red Cross Bergen");
    assert.equal(await h.stores.members().get("a_bergen/u_9", { type: "json" }), null);
});

test("an unverified address is not enough, even when it matches", async () => {
    // Without this, claiming an address is the same as owning it.
    const h = harness();
    const t = await invited(h);
    await h.stores.users().set("u_2", JSON.stringify({
        id: "u_2", displayName: "Ola", primaryEmail: "ola@example.com", primaryEmailVerified: false,
    }));

    assert.equal((await accept(h, t, token("u_2"))).status, 403);
});

// ---------- accepting ----------

test("the invited address binds, at the role the invitation named", async () => {
    const h = harness();
    const t = await invited(h, { role: "guest" });
    await userWithVerifiedEmail(h, "u_2", "ola@example.com");

    const res = await accept(h, t, token("u_2"));
    assert.equal(res.status, 200);
    assert.deepEqual(await res.json(), {
        accepted: true, accountId: "a_bergen", organisation: "Red Cross Bergen", role: "guest",
    });

    const member = await h.stores.members().get("a_bergen/u_2", { type: "json" });
    assert.equal(member.role, "guest");
    assert.ok(member.acceptedAt, "invited is a state, not a role — accepting is what clears it");
});

test("accepting clears the pending row, so the roster does not show them twice", async () => {
    const h = harness();
    const t = await invited(h);
    await userWithVerifiedEmail(h, "u_2", "ola@example.com");

    await accept(h, t, token("u_2"));
    assert.equal(await h.stores.members().get("a_bergen/pending:ola@example.com", { type: "json" }), null);
});

test("a second visit says already-accepted, not no-such-invitation", async () => {
    // The same link is routinely opened twice, on two devices. Deleting the
    // token on use would make the second visit indistinguishable from a
    // fabricated one.
    const h = harness();
    const t = await invited(h);
    await userWithVerifiedEmail(h, "u_2", "ola@example.com");
    await accept(h, t, token("u_2"));

    assert.equal((await get(h, t)).status, 200);
    assert.equal((await (await get(h, t)).json()).state, "accepted");

    const again = await accept(h, t, token("u_2"));
    assert.equal(again.status, 409);
    assert.equal((await again.json()).state, "accepted");
});

// ---------- the states the landing page renders ----------

test("an expired invitation is reported as expired", async () => {
    const h = harness();
    const t = await invited(h);
    const inv = await h.raw.invites.get(t, { type: "json" });
    await h.raw.invites.set(t, JSON.stringify({ ...inv, expiresAt: Date.now() - 1000 }));

    assert.equal((await (await get(h, t)).json()).state, "expired");
    await userWithVerifiedEmail(h, "u_2", "ola@example.com");
    assert.equal((await accept(h, t, token("u_2"))).status, 410);
});

test("a withdrawn invitation is withdrawn, not expired", async () => {
    // Telling the invitee it expired sends them to ask for a fresh link that
    // is never coming.
    const h = harness();
    const t = await invited(h);

    const res = await h.accounts(new Request(
        `https://api.ringdrill.app/api/accounts/a_bergen/members/${encodeURIComponent("pending:ola@example.com")}`,
        { method: "DELETE", headers: { authorization: `Bearer ${token("u_1", { a_bergen: "owner" })}` } },
    ));
    assert.equal(res.status, 204, "an owner must be able to withdraw a pending invitation");

    assert.equal((await (await get(h, t)).json()).state, "withdrawn");
    await userWithVerifiedEmail(h, "u_2", "ola@example.com");
    assert.equal((await accept(h, t, token("u_2"))).status, 410);
});

test("a deleted organisation is named, not a generic failure", async () => {
    const h = harness();
    const t = await invited(h);
    await h.stores.accounts().delete("a_bergen");

    assert.equal((await (await get(h, t)).json()).state, "organisation_deleted");
});

test("only an owner may withdraw a pending invitation", async () => {
    const h = harness();
    await invited(h);
    await h.stores.members().set("a_bergen/u_2", JSON.stringify({ accountId: "a_bergen", userId: "u_2", role: "member", acceptedAt: "2026-08-01" }));

    const res = await h.accounts(new Request(
        `https://api.ringdrill.app/api/accounts/a_bergen/members/${encodeURIComponent("pending:ola@example.com")}`,
        { method: "DELETE", headers: { authorization: `Bearer ${token("u_2", { a_bergen: "member" })}` } },
    ));
    assert.equal(res.status, 403);
});

test("withdrawing an invitation that is not there is 404", async () => {
    const h = harness();
    await invited(h);

    const res = await h.accounts(new Request(
        `https://api.ringdrill.app/api/accounts/a_bergen/members/${encodeURIComponent("pending:nobody@example.com")}`,
        { method: "DELETE", headers: { authorization: `Bearer ${token("u_1", { a_bergen: "owner" })}` } },
    ));
    assert.equal(res.status, 404);
});

test("an unrouted method or path is 404", async () => {
    const h = harness();
    const t = await invited(h);
    assert.equal((await h.handler(new Request(`https://api.ringdrill.app/api/invitations/${t}`, { method: "POST" }))).status, 404);
    assert.equal((await h.handler(new Request(`https://api.ringdrill.app/api/invitations/${t}/reject`, { method: "POST" }))).status, 404);
    assert.equal((await h.handler(new Request("https://api.ringdrill.app/api/invitations"))).status, 404);
});

test("a malformed escape is a bad URL, not a 500", async () => {
    const h = harness();
    assert.equal((await h.handler(new Request("https://api.ringdrill.app/api/invitations/%ZZ"))).status, 404);
});
