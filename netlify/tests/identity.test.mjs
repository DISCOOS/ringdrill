/**
 * Tests for lib/identity.js — the Account / User / Identity / Member model
 * (ADR-0024) and account handles (ADR-0074).
 *
 * A fake store stands in for @netlify/blobs. It implements the slice the module
 * uses — get / set / delete / list — including `onlyIfNew`, because the atomic
 * claim is the whole defence against two people taking one handle or one email
 * index entry, and a fake that ignored the flag would test nothing.
 */
import { test } from "node:test";
import assert from "node:assert/strict";

import {
    acceptedOwners,
    claimHandle,
    membersOf,
    membershipsOf,
    normalizeEmail,
    putMember,
    removeMember,
    renameHandle,
    resolveHandle,
    resolveIdentity,
    upgradeToOrganisation,
    validateHandle,
} from "../functions/lib/identity.js";

function fakeStore() {
    const data = new Map();
    return {
        data,
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
        members: fakeStore(), memberIndex: fakeStore(), emailIndex: fakeStore(), handles: fakeStore(), sessions: fakeStore(), sessionIndex: fakeStore(),
    };
    return {
        raw: s,
        accounts: () => s.accounts, users: () => s.users, identities: () => s.identities,
        members: () => s.members, memberIndex: () => s.memberIndex, emailIndex: () => s.emailIndex, handles: () => s.handles,
        sessions: () => s.sessions, sessionIndex: () => s.sessionIndex,
    };
}

let seq = 0;
const deterministicId = (prefix) => `${prefix}_${String(++seq).padStart(3, "0")}`;
const opts = () => ({ now: () => "2026-08-08T00:00:00.000Z", makeId: deterministicId });

// ---------- identity linking (ADR-0024) ----------

test("first sign-in creates a user, a personal account, and an owner membership", async () => {
    const stores = fakeStores();
    const res = await resolveIdentity(
        { provider: "google", subject: "g-1", email: "Kari@Example.com", emailVerified: true, displayName: "Kari" },
        stores, opts(),
    );

    assert.equal(res.ok, true);
    assert.equal(res.created, true);
    assert.equal(res.linked, false);
    assert.equal(res.user.primaryEmail, "kari@example.com", "addresses are normalised before storage");
    assert.equal(res.account.type, "personal");

    const member = await stores.members().get(`${res.account.id}/${res.user.id}`, { type: "json" });
    assert.equal(member.role, "owner");
    assert.ok(member.acceptedAt, "your own personal account needs no acceptance step");
});

test("a known (provider, subject) returns the same user without creating anything", async () => {
    const stores = fakeStores();
    const first = await resolveIdentity(
        { provider: "google", subject: "g-1", email: "kari@example.com", emailVerified: true }, stores, opts(),
    );
    const again = await resolveIdentity(
        { provider: "google", subject: "g-1", email: "kari@example.com", emailVerified: true }, stores, opts(),
    );
    assert.equal(again.created, false);
    assert.equal(again.user.id, first.user.id);
    assert.equal(stores.raw.users.data.size, 1);
});

test("a second provider on a verified matching email links to the existing user, and says so", async () => {
    const stores = fakeStores();
    const first = await resolveIdentity(
        { provider: "google", subject: "g-1", email: "kari@example.com", emailVerified: true }, stores, opts(),
    );
    const second = await resolveIdentity(
        { provider: "apple", subject: "a-1", email: "kari@example.com", emailVerified: true }, stores, opts(),
    );

    assert.equal(second.user.id, first.user.id, "one person, one User");
    assert.equal(second.created, false);
    assert.equal(second.linked, true, "the caller has to be able to tell the user this happened");
    assert.equal(stores.raw.accounts.data.size, 1, "linking must not mint a second personal account");
});

test("an UNVERIFIED email never links — this is the sign-up squatting defence", async () => {
    const stores = fakeStores();
    const real = await resolveIdentity(
        { provider: "google", subject: "g-1", email: "kari@example.com", emailVerified: true }, stores, opts(),
    );
    const squatter = await resolveIdentity(
        { provider: "sketchy", subject: "s-1", email: "kari@example.com", emailVerified: false }, stores, opts(),
    );

    assert.notEqual(squatter.user.id, real.user.id, "an unverified claim must not inherit a verified identity");
    assert.equal(squatter.created, true);
});

test("an Apple relay address creates a second account, which is the duplicate DESIGN-015 §3.5 designs around", async () => {
    const stores = fakeStores();
    const google = await resolveIdentity(
        { provider: "google", subject: "g-1", email: "kari@example.com", emailVerified: true }, stores, opts(),
    );
    // The relay address is verified, but permanently different, so branch 2
    // cannot match. From here it is indistinguishable from a new person.
    const apple = await resolveIdentity(
        { provider: "apple", subject: "a-1", email: "xyz@privaterelay.appleid.com", emailVerified: true }, stores, opts(),
    );

    assert.notEqual(apple.user.id, google.user.id);
    assert.equal(apple.created, true, "the fix is the §4.2 reachable-address prompt, not anything this function can do");
});

test("an identity pointing at a missing user is corruption, not a sign-up", async () => {
    const stores = fakeStores();
    await stores.identities().set("google/g-1", JSON.stringify({ userId: "u_gone" }));
    const res = await resolveIdentity({ provider: "google", subject: "g-1" }, stores, opts());
    assert.equal(res.ok, false);
    assert.equal(res.reason, "dangling_identity");
});

test("a racing sign-up on the same address does not orphan the winner's account", async () => {
    const stores = fakeStores();
    const a = await resolveIdentity(
        { provider: "google", subject: "g-1", email: "kari@example.com", emailVerified: true }, stores, opts(),
    );
    // Simulate the loser of a race: the email index already exists, so its
    // onlyIfNew write is refused and the pointer keeps naming the first user.
    await resolveIdentity(
        { provider: "apple", subject: "a-9", email: "kari@example.com", emailVerified: true }, stores,
        { ...opts(), makeId: (p) => `${p}_race` },
    );
    const idx = await stores.emailIndex().get("kari@example.com", { type: "json" });
    assert.equal(idx.userId, a.user.id);
});

// ---------- memberships ----------

test("membershipsOf returns accepted memberships only — invited is a state, not a grant", async () => {
    const stores = fakeStores();
    await putMember("a_1", "u_1", "owner", { acceptedAt: "2026-08-01" }, stores);
    await putMember("a_2", "u_1", "guest", { acceptedAt: "2026-08-02" }, stores);
    await putMember("a_3", "u_1", "member", { invitedAt: "2026-08-03", acceptedAt: null }, stores);
    await putMember("a_1", "u_other", "member", { acceptedAt: "2026-08-01" }, stores);

    const { accounts, roles } = await membershipsOf("u_1", stores);
    assert.deepEqual(accounts.sort(), ["a_1", "a_2"]);
    assert.deepEqual(roles, { a_1: "owner", a_2: "guest" });
});

test("membersOf and acceptedOwners support the last-owner invariant", async () => {
    const stores = fakeStores();
    await putMember("a_1", "u_1", "owner", { acceptedAt: "x" }, stores);
    await putMember("a_1", "u_2", "owner", { invitedAt: "y", acceptedAt: null }, stores);
    await putMember("a_1", "u_3", "member", { acceptedAt: "z" }, stores);

    const members = await membersOf("a_1", stores);
    assert.equal(members.length, 3);
    // An invited owner cannot be the one keeping the account reachable.
    assert.deepEqual(acceptedOwners(members).map((m) => m.userId), ["u_1"]);

    await removeMember("a_1", "u_3", stores);
    assert.equal((await membersOf("a_1", stores)).length, 2);
});

// ---------- handles (ADR-0074) ----------

test("validateHandle: format, reserved names, and the trailing-dash case", () => {
    assert.equal(validateHandle("redcross-bergen").ok, true);
    assert.equal(validateHandle("RedCross-Bergen").handle, "redcross-bergen");
    assert.equal(validateHandle("a").ok, false, "too short");
    assert.equal(validateHandle("-leading").ok, false);
    assert.equal(validateHandle("trailing-").reason, "invalid_format");
    assert.equal(validateHandle("has_underscore").ok, false);
    assert.equal(validateHandle("anon").reason, "reserved", "anon is the unauthenticated namespace");
    assert.equal(validateHandle("support").reason, "reserved", "a link implying authority is a phishing surface");
});

test("claimHandle is atomic, and re-claiming your own is a no-op rather than an error", async () => {
    const stores = fakeStores();
    assert.equal((await claimHandle("redcross-bergen", "a_1", stores)).ok, true);
    assert.equal((await claimHandle("redcross-bergen", "a_2", stores)).reason, "taken");
    assert.equal((await claimHandle("redcross-bergen", "a_1", stores)).ok, true, "a retry must not fail");
});

test("renameHandle leaves a tombstone that redirects and can never be re-registered", async () => {
    const stores = fakeStores();
    await claimHandle("old-name", "a_1", stores);
    const res = await renameHandle("old-name", "new-name", "a_1", stores);
    assert.equal(res.ok, true);

    const old = await resolveHandle("old-name", stores);
    assert.equal(old.tombstone, true);
    assert.equal(old.redirectsTo, "new-name");

    // Releasing it would silently point an already-shared link at a stranger.
    assert.equal((await claimHandle("old-name", "a_2", stores)).reason, "taken");
    assert.equal((await resolveHandle("new-name", stores)).accountId, "a_1");
});

test("upgradeToOrganisation is idempotent and can claim a handle on the way", async () => {
    const stores = fakeStores();
    const created = await resolveIdentity(
        { provider: "google", subject: "g-1", email: "kari@example.com", emailVerified: true }, stores, opts(),
    );
    const id = created.account.id;

    const up = await upgradeToOrganisation(id, { displayName: "Red Cross Bergen", handle: "redcross-bergen" }, stores);
    assert.equal(up.ok, true);
    assert.equal(up.account.type, "organization");
    assert.equal(up.account.handle, "redcross-bergen");

    const again = await upgradeToOrganisation(id, {}, stores);
    assert.equal(again.ok, true, "already an organisation is success, not a conflict");
});

test("upgradeToOrganisation refuses a taken handle and leaves the account personal", async () => {
    const stores = fakeStores();
    await claimHandle("redcross-bergen", "a_someone", stores);
    const created = await resolveIdentity(
        { provider: "google", subject: "g-2", email: "ola@example.com", emailVerified: true }, stores, opts(),
    );
    const res = await upgradeToOrganisation(created.account.id, { handle: "redcross-bergen" }, stores);
    assert.equal(res.ok, false);
    assert.equal(res.reason, "taken");

    const account = await stores.accounts().get(created.account.id, { type: "json" });
    assert.equal(account.type, "personal", "a failed handle claim must not half-upgrade the account");
});

test("normalizeEmail trims and lowercases", () => {
    assert.equal(normalizeEmail("  Kari@Example.COM "), "kari@example.com");
    assert.equal(normalizeEmail(null), "");
});
