/**
 * Tests for the `member-index` and `session-index` reverse indexes.
 *
 * The point of these indexes is a cost, not a behaviour: `membershipsOf` runs on
 * every access-token mint and `sessionsOf` on every Devices list, and both used
 * to walk every membership — or every session — *in the system* to answer a
 * question about one user. Correctness was never in doubt; the failure mode was
 * a function timeout once the store grew, and it arrives for every tenant at
 * once because the scan is global.
 *
 * So the assertions here come in two kinds, and the first kind is the one that
 * would otherwise rot: **the store is never listed without a prefix**. A
 * refactor that quietly reinstates the scan keeps every behavioural test green,
 * which is exactly why the read pattern itself is asserted.
 */
import { test } from "node:test";
import assert from "node:assert/strict";

import {
    deleteAccount, defaultStores, membershipsOf, memberIndexKey, putMember, removeMember,
    resolveIdentity, sessionIndexKey,
} from "../functions/lib/identity.js";
import { createSession, endSession, endSessionOwnedBy, sessionsOf } from "../functions/lib/auth/session.js";
import { backfillIndexes, backfillMemberIndex } from "../functions/lib/backfill-indexes.js";

/**
 * The blobs slice these modules use, plus a log of every `list` call so a test
 * can assert *how* an answer was reached and not only what it was.
 */
function fakeStore() {
    const data = new Map();
    const lists = [];
    return {
        data,
        lists,
        /** Listings that scanned the whole store rather than a prefix. */
        fullScans: () => lists.filter((p) => !p),
        async get(key, opts) {
            const raw = data.get(key);
            if (raw === undefined) return null;
            return opts?.type === "json" ? JSON.parse(raw) : raw;
        },
        async set(key, value, opts = {}) {
            if (opts.onlyIfNew && data.has(key)) return { modified: false };
            data.set(key, value);
            return { modified: true };
        },
        async delete(key) { data.delete(key); },
        async list({ prefix = "", cursor } = {}) {
            lists.push(prefix);
            if (cursor) return { blobs: [], cursor: undefined };
            return {
                blobs: [...data.keys()].filter((k) => k.startsWith(prefix)).map((key) => ({ key })),
                cursor: undefined,
            };
        },
    };
}

function fakeStores() {
    const s = {
        accounts: fakeStore(), users: fakeStore(), identities: fakeStore(),
        members: fakeStore(), memberIndex: fakeStore(), emailIndex: fakeStore(),
        handles: fakeStore(), sessions: fakeStore(), sessionIndex: fakeStore(),
    };
    return {
        raw: s,
        accounts: () => s.accounts, users: () => s.users, identities: () => s.identities,
        members: () => s.members, memberIndex: () => s.memberIndex,
        emailIndex: () => s.emailIndex, handles: () => s.handles,
        sessions: () => s.sessions, sessionIndex: () => s.sessionIndex,
    };
}

const ACCEPTED = { acceptedAt: "2026-08-01T00:00:00.000Z" };

// ---------- member-index ----------

test("membershipsOf answers from the index without scanning every membership", async () => {
    const stores = fakeStores();
    await putMember("a_1", "u_kari", "owner", ACCEPTED, stores);
    await putMember("a_2", "u_kari", "member", ACCEPTED, stores);
    // Nine hundred other tenants. Under the old layout every one of these was a
    // `get` on the way to answering a question about Kari.
    for (let i = 0; i < 900; i++) await putMember(`a_other_${i}`, `u_other_${i}`, "owner", ACCEPTED, stores);

    stores.raw.members.lists.length = 0;
    const { accounts, roles } = await membershipsOf("u_kari", stores);

    assert.deepEqual(accounts.sort(), ["a_1", "a_2"]);
    assert.equal(roles.a_1, "owner");
    assert.equal(roles.a_2, "member");
    assert.deepEqual(stores.raw.members.fullScans(), [], "the members store must never be scanned whole");
    assert.deepEqual(stores.raw.memberIndex.lists, ["u_kari/"], "the index is read by this user's prefix only");
});

test("the role comes from the canonical row, so a demotion cannot be outvoted by the index", async () => {
    // The index deliberately stores no role (see memberIndexKey). This is the
    // test that would fail if someone denormalised one into it and then let the
    // two writes drift apart: a demoted owner keeping owner rights in their
    // token is the exact bug the layout is chosen to make impossible.
    const stores = fakeStores();
    await putMember("a_1", "u_kari", "owner", ACCEPTED, stores);
    await putMember("a_1", "u_kari", "member", ACCEPTED, stores);

    const { roles } = await membershipsOf("u_kari", stores);
    assert.equal(roles.a_1, "member");
});

test("an invitation that has not been accepted is indexed but grants nothing", async () => {
    const stores = fakeStores();
    await putMember("a_1", "u_kari", "member", { invitedAt: "2026-08-01T00:00:00.000Z", acceptedAt: null }, stores);

    assert.ok(await stores.memberIndex().get(memberIndexKey("u_kari", "a_1"), { type: "json" }));
    const { accounts, roles } = await membershipsOf("u_kari", stores);
    assert.deepEqual(accounts, [], "acceptedAt is a state, not a role (DESIGN-015 §6.2)");
    assert.deepEqual(roles, {});
});

test("removeMember takes the index entry with it", async () => {
    const stores = fakeStores();
    await putMember("a_1", "u_kari", "owner", ACCEPTED, stores);
    await removeMember("a_1", "u_kari", stores);

    assert.equal(await stores.memberIndex().get(memberIndexKey("u_kari", "a_1"), { type: "json" }), null);
    assert.deepEqual((await membershipsOf("u_kari", stores)).accounts, []);
});

test("an index entry whose membership is gone is dropped rather than re-read forever", async () => {
    const stores = fakeStores();
    await putMember("a_1", "u_kari", "owner", ACCEPTED, stores);
    await putMember("a_2", "u_kari", "member", ACCEPTED, stores);
    // The canonical row goes behind the index's back — the shape left by an
    // interrupted delete, or by a store edited out of band.
    await stores.members().delete("a_1/u_kari");

    const { accounts } = await membershipsOf("u_kari", stores);
    assert.deepEqual(accounts, ["a_2"]);
    assert.equal(await stores.memberIndex().get(memberIndexKey("u_kari", "a_1"), { type: "json" }), null,
        "the stale pointer is cleaned up on the read that noticed it");
});

test("a user with no index entries still gets their memberships, and is indexed on the way out", async () => {
    // The pre-backfill state. Reading from the index alone here would report
    // "no accounts" for every existing user, which is a total loss of access
    // dressed up as a successful deploy.
    const stores = fakeStores();
    await stores.members().set("a_1/u_kari", JSON.stringify({
        accountId: "a_1", userId: "u_kari", role: "owner", invitedAt: null, acceptedAt: ACCEPTED.acceptedAt,
    }));

    const { accounts, roles } = await membershipsOf("u_kari", stores);
    assert.deepEqual(accounts, ["a_1"]);
    assert.equal(roles.a_1, "owner");
    assert.ok(await stores.memberIndex().get(memberIndexKey("u_kari", "a_1"), { type: "json" }),
        "the fallback heals the index so the next mint is cheap");

    stores.raw.members.lists.length = 0;
    await membershipsOf("u_kari", stores);
    assert.deepEqual(stores.raw.members.fullScans(), [], "and the scan does not happen twice");
});

test("signing up indexes the personal account it creates", async () => {
    const stores = fakeStores();
    const res = await resolveIdentity(
        { provider: "email", subject: "kari@example.com", email: "kari@example.com", emailVerified: true },
        stores,
        { now: () => "2026-08-01T00:00:00.000Z", makeId: (p) => `${p}_kari` },
    );
    assert.equal(res.ok, true);

    stores.raw.members.lists.length = 0;
    const { accounts, roles } = await membershipsOf("u_kari", stores);
    assert.deepEqual(accounts, ["a_kari"]);
    assert.equal(roles.a_kari, "owner");
    assert.deepEqual(stores.raw.members.fullScans(), [], "a brand new user never needs the fallback");
});

// ---------- session-index ----------

test("sessionsOf answers from the index without scanning every session", async () => {
    const stores = fakeStores();
    const index = stores.sessionIndex();
    const sessions = stores.sessions();
    const mine = await createSession(sessions, { userId: "u_kari", deviceLabel: "iPhone", index });
    for (let i = 0; i < 500; i++) await createSession(sessions, { userId: `u_other_${i}`, index });

    sessions.lists.length = 0;
    const devices = await sessionsOf(sessions, "u_kari", { index });

    assert.equal(devices.length, 1);
    assert.equal(devices[0].sessionId, mine.sessionId);
    assert.equal(devices[0].deviceLabel, "iPhone");
    assert.deepEqual(sessions.fullScans(), [], "the sessions store must never be scanned whole");
});

test("a session record never leaves the server carrying its refresh hash", async () => {
    const stores = fakeStores();
    const index = stores.sessionIndex();
    await createSession(stores.sessions(), { userId: "u_kari", index });

    const [device] = await sessionsOf(stores.sessions(), "u_kari", { index });
    assert.equal(device.refreshHash, undefined);
});

test("signing out removes the index entry as well as the session", async () => {
    const stores = fakeStores();
    const index = stores.sessionIndex();
    const { sessionId, refreshToken } = await createSession(stores.sessions(), { userId: "u_kari", index });

    // Ordinary sign-out proves ownership with the refresh token and passes no
    // user id at all, so the index key has to come off the record.
    assert.equal(await endSessionOwnedBy(stores.sessions(), { sessionId, refreshToken, index }), true);
    assert.equal(await index.get(sessionIndexKey("u_kari", sessionId), { type: "json" }), null);
    assert.deepEqual(await sessionsOf(stores.sessions(), "u_kari", { index }), []);
});

test("endSession removes the index entry it cannot derive from the id alone", async () => {
    const stores = fakeStores();
    const index = stores.sessionIndex();
    const { sessionId } = await createSession(stores.sessions(), { userId: "u_kari", index });

    await endSession(stores.sessions(), sessionId, { index });
    assert.equal(await index.get(sessionIndexKey("u_kari", sessionId), { type: "json" }), null);
});

test("an index entry whose session is gone is dropped on the read that noticed", async () => {
    const stores = fakeStores();
    const index = stores.sessionIndex();
    const { sessionId } = await createSession(stores.sessions(), { userId: "u_kari", index });
    await stores.sessions().delete(sessionId);

    assert.deepEqual(await sessionsOf(stores.sessions(), "u_kari", { index }), []);
    assert.equal(await index.get(sessionIndexKey("u_kari", sessionId), { type: "json" }), null);
});

test("an index entry pointing at somebody else's session shows nobody that session", async () => {
    // The record is the authority on ownership, not the key that led to it.
    const stores = fakeStores();
    const index = stores.sessionIndex();
    const { sessionId } = await createSession(stores.sessions(), { userId: "u_other", index });
    await index.set(sessionIndexKey("u_kari", sessionId), JSON.stringify({ indexed: true }));

    assert.deepEqual(await sessionsOf(stores.sessions(), "u_kari", { index }), []);
});

test("sessions with no index entries are still listed, and indexed on the way out", async () => {
    const stores = fakeStores();
    const index = stores.sessionIndex();
    await stores.sessions().set("s_legacy", JSON.stringify({
        sessionId: "s_legacy", userId: "u_kari", expiresAt: Date.now() + 60_000,
    }));

    const devices = await sessionsOf(stores.sessions(), "u_kari", { index });
    assert.deepEqual(devices.map((d) => d.sessionId), ["s_legacy"]);
    assert.ok(await index.get(sessionIndexKey("u_kari", "s_legacy"), { type: "json" }));
});

test("an expired session is filtered out but its index entry is not treated as stale", async () => {
    const stores = fakeStores();
    const index = stores.sessionIndex();
    const { sessionId } = await createSession(stores.sessions(), { userId: "u_kari", index, now: () => 0 });

    assert.deepEqual(await sessionsOf(stores.sessions(), "u_kari", { index }), []);
    assert.ok(await index.get(sessionIndexKey("u_kari", sessionId), { type: "json" }),
        "the record still exists, so the pointer to it is not the thing that is wrong");
});

// ---------- deletion does not trust derived data ----------

test("deleting an account erases sessions the index never knew about", async () => {
    // The regression this file exists to hold: reads may treat a missing index
    // entry as "scan instead", but a deletion that did the same would leave a
    // live refresh token belonging to a user who asked to be erased.
    const stores = fakeStores();
    await stores.accounts().set("a_kari", JSON.stringify({ id: "a_kari", displayName: "Kari", type: "personal" }));
    await stores.users().set("u_kari", JSON.stringify({ id: "u_kari", primaryEmail: "kari@example.com" }));
    await putMember("a_kari", "u_kari", "owner", ACCEPTED, stores);
    // Written straight to the store, as a session created before the index existed was.
    await stores.sessions().set("s_unindexed", JSON.stringify({ sessionId: "s_unindexed", userId: "u_kari" }));

    const res = await deleteAccount("a_kari", { deleteUser: "u_kari" }, stores);
    assert.equal(res.ok, true);

    assert.equal(await stores.sessions().get("s_unindexed", { type: "json" }), null,
        "no live session outlives the user, indexed or not");
    assert.equal(await stores.users().get("u_kari", { type: "json" }), null);
    assert.equal(await stores.memberIndex().get(memberIndexKey("u_kari", "a_kari"), { type: "json" }), null);
});

// ---------- backfill ----------

test("the backfill builds both indexes and is idempotent", async () => {
    const stores = fakeStores();
    await stores.members().set("a_1/u_kari", JSON.stringify({ accountId: "a_1", userId: "u_kari", role: "owner", acceptedAt: ACCEPTED.acceptedAt }));
    await stores.members().set("a_1/pending:ola@example.com", JSON.stringify({ accountId: "a_1", email: "ola@example.com", role: "member" }));
    await stores.sessions().set("s_1", JSON.stringify({ sessionId: "s_1", userId: "u_kari" }));

    const dry = await backfillIndexes({ dryRun: true, stores });
    assert.equal(dry.members.indexed, 1);
    assert.equal(dry.members.skipped, 1, "a pending invitation has no user to index");
    assert.equal(stores.raw.memberIndex.data.size, 0, "a dry run writes nothing");

    const first = await backfillIndexes({ dryRun: false, stores });
    assert.equal(first.members.indexed, 1);
    assert.equal(first.sessions.indexed, 1);
    assert.ok(await stores.memberIndex().get(memberIndexKey("u_kari", "a_1"), { type: "json" }));
    assert.ok(await stores.sessionIndex().get(sessionIndexKey("u_kari", "s_1"), { type: "json" }));

    const second = await backfillIndexes({ dryRun: false, stores });
    assert.deepEqual(second.members.errors, []);
    assert.equal(stores.raw.memberIndex.data.size, 1, "re-running rewrites the same key rather than adding one");
});

test("a session with no owner is reported rather than silently skipped", async () => {
    const stores = fakeStores();
    await stores.sessions().set("s_orphan", JSON.stringify({ sessionId: "s_orphan" }));

    const report = await backfillIndexes({ dryRun: false, stores });
    assert.equal(report.sessions.indexed, 0);
    assert.deepEqual(report.sessions.errors, [{ key: "s_orphan", error: "session_without_user" }]);
});

test("the backfill leaves the canonical stores untouched", async () => {
    const stores = fakeStores();
    await putMember("a_1", "u_kari", "owner", ACCEPTED, stores);
    const before = new Map(stores.raw.members.data);

    await backfillMemberIndex({ dryRun: false, stores });
    assert.deepEqual([...stores.raw.members.data.entries()], [...before.entries()]);
});

test("defaultStores exposes both index stores", () => {
    // The handlers reach for `stores.memberIndex?.()`; a typo there would fall
    // back to the scan silently, which is the one failure this whole change is
    // meant to remove.
    assert.equal(typeof defaultStores.memberIndex, "function");
    assert.equal(typeof defaultStores.sessionIndex, "function");
});
