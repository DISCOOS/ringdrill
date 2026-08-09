/**
 * Every row of ADR-0025's authorisation matrix, plus the amendments that
 * changed two of them.
 *
 * This is the module with security consequences, so the tests are exhaustive
 * rather than representative — including the cases that are *permissive*, since
 * a rule that accidentally tightens breaks every phone in the field just as
 * surely as one that accidentally loosens lets a stranger in.
 */
import { test } from "node:test";
import assert from "node:assert/strict";

import {
    ACCESS_POLICIES,
    ANON_OWNER,
    authorizeCatalogWrite,
    authorizePolicyChange,
    readAccessPolicy,
} from "../functions/lib/authorize.js";

const anonymous = { ok: true, anonymous: true };
const member = (accounts, roles) => ({ ok: true, anonymous: false, userId: "u_1", accountId: accounts[0], accounts, roles });

const bergenOwner = member(["a_bergen"], { a_bergen: "owner" });
const bergenMember = member(["a_bergen"], { a_bergen: "member" });
const bergenGuest = member(["a_bergen"], { a_bergen: "guest" });
const outsider = member(["a_other"], { a_other: "owner" });

const slug = (ownerId) => ({ ownerId, programId: "p_1" });
const metaFor = (ownerId, accessPolicy, extra = {}) => ({ ownerId, accessPolicy, ...extra });

// ---------- readAccessPolicy ----------

test("readAccessPolicy: absent reads as public, matching every plan published before accounts", () => {
    assert.equal(readAccessPolicy({ ownerId: ANON_OWNER }), ACCESS_POLICIES.PUBLIC);
    assert.equal(readAccessPolicy(null), ACCESS_POLICIES.PUBLIC);
});

test("readAccessPolicy: absent on an owned plan reads as account", () => {
    assert.equal(readAccessPolicy({ ownerId: "a_bergen" }), ACCESS_POLICIES.ACCOUNT);
});

test("readAccessPolicy: the legacy `wiki` name is accepted as public", () => {
    // Those blobs were written before the rename and will not rewrite
    // themselves (ADR-0025, one release of alias).
    assert.equal(readAccessPolicy({ accessPolicy: "wiki" }), ACCESS_POLICIES.PUBLIC);
});

test("readAccessPolicy: an unrecognised value falls back rather than throwing", () => {
    assert.equal(readAccessPolicy({ ownerId: ANON_OWNER, accessPolicy: "nonsense" }), ACCESS_POLICIES.PUBLIC);
});

// ---------- new slug ----------

test("new slug, ANONYMOUS: allowed, and lands anon/public — this is the row that keeps old apps working", () => {
    // ADR-0025 amended 2026-08-05. Without it, enabling enforcement breaks
    // every un-updated app, and during App Store review that is every phone.
    const d = authorizeCatalogWrite({ principal: anonymous, existing: null, meta: null });
    assert.equal(d.ok, true);
    assert.equal(d.ownerId, ANON_OWNER);
    assert.equal(d.accessPolicy, ACCESS_POLICIES.PUBLIC);
    assert.equal(d.claimed, true);
});

test("new slug, authenticated: claimed for the active account at account policy", () => {
    const d = authorizeCatalogWrite({ principal: bergenMember, existing: null, meta: null });
    assert.equal(d.ok, true);
    assert.equal(d.ownerId, "a_bergen");
    assert.equal(d.accessPolicy, ACCESS_POLICIES.ACCOUNT);
});

test("new slug, authenticated with no active account: refused rather than silently landing in anon", () => {
    const noActive = { ok: true, anonymous: false, userId: "u_1", accountId: null, accounts: [], roles: {} };
    const d = authorizeCatalogWrite({ principal: noActive, existing: null, meta: null });
    assert.equal(d.ok, false);
    assert.equal(d.status, 403);
});

// ---------- existing slug: public ----------

test("existing public plan: anyone may publish, signed in or not", () => {
    const existing = slug(ANON_OWNER);
    const meta = metaFor(ANON_OWNER, ACCESS_POLICIES.PUBLIC);
    for (const [name, principal] of [["anonymous", anonymous], ["outsider", outsider], ["member", bergenMember]]) {
        const d = authorizeCatalogWrite({ principal, existing, meta });
        assert.equal(d.ok, true, name);
        assert.equal(d.ownerId, ANON_OWNER, name);
    }
});

test("an account-owned plan set to public is still writable by anyone — public means public", () => {
    const d = authorizeCatalogWrite({
        principal: outsider, existing: slug("a_bergen"), meta: metaFor("a_bergen", ACCESS_POLICIES.PUBLIC),
    });
    assert.equal(d.ok, true);
    assert.equal(d.ownerId, "a_bergen", "ownership is unchanged by a stranger publishing");
});

// ---------- existing slug: account ----------

test("account policy: EVERY member may publish, including a guest", () => {
    // ADR-0024 amended 2026-08-05: what guest withholds is the staff roster,
    // not the ability to work. A rank check here would be the bug.
    const existing = slug("a_bergen");
    const meta = metaFor("a_bergen", ACCESS_POLICIES.ACCOUNT);
    for (const [name, principal] of [["owner", bergenOwner], ["member", bergenMember], ["guest", bergenGuest]]) {
        assert.equal(authorizeCatalogWrite({ principal, existing, meta }).ok, true, name);
    }
});

test("account policy: a non-member is 403, and an anonymous caller is 401", () => {
    const existing = slug("a_bergen");
    const meta = metaFor("a_bergen", ACCESS_POLICIES.ACCOUNT);

    const stranger = authorizeCatalogWrite({ principal: outsider, existing, meta });
    assert.equal(stranger.status, 403);
    assert.equal(stranger.reason, "not_a_member");

    // 401 rather than 403: the caller offered no credential, so "who are you"
    // is the honest answer, and a client can act on it by signing in.
    const anon = authorizeCatalogWrite({ principal: anonymous, existing, meta });
    assert.equal(anon.status, 401);
});

// ---------- existing slug: shared ----------

test("shared policy: members of the owning account and of any grantee may publish", () => {
    const existing = slug("a_bergen");
    const meta = metaFor("a_bergen", ACCESS_POLICIES.SHARED, { sharedAccountIds: ["a_fjell"] });

    assert.equal(authorizeCatalogWrite({ principal: bergenGuest, existing, meta }).ok, true, "owning account");

    const fjell = member(["a_fjell"], { a_fjell: "member" });
    assert.equal(authorizeCatalogWrite({ principal: fjell, existing, meta }).ok, true, "grantee account");

    assert.equal(authorizeCatalogWrite({ principal: outsider, existing, meta }).status, 403, "neither");
});

test("shared policy with a malformed grantee list denies rather than throwing", () => {
    const meta = metaFor("a_bergen", ACCESS_POLICIES.SHARED, { sharedAccountIds: "not-an-array" });
    assert.equal(authorizeCatalogWrite({ principal: outsider, existing: slug("a_bergen"), meta }).status, 403);
});

// ---------- policy change ----------

test("policy change: owner only — this is the one place rank matters", () => {
    const existing = slug("a_bergen");
    const meta = metaFor("a_bergen", ACCESS_POLICIES.ACCOUNT);

    assert.equal(authorizePolicyChange({ principal: bergenOwner, existing, meta }).ok, true);
    // Publishing follows from membership; deciding who else may publish is
    // administration, which is what owner means.
    assert.equal(authorizePolicyChange({ principal: bergenMember, existing, meta }).reason, "owner_role_required");
    assert.equal(authorizePolicyChange({ principal: bergenGuest, existing, meta }).reason, "owner_role_required");
    assert.equal(authorizePolicyChange({ principal: outsider, existing, meta }).reason, "not_a_member");
    assert.equal(authorizePolicyChange({ principal: anonymous, existing, meta }).status, 401);
});

test("policy change on an anon plan is refused — there is deliberately no path from anon to owned", () => {
    // ADR-0025 chose fork-to-leave over in-place adoption, so an anon plan has
    // no owner to be and none can be claimed.
    const d = authorizePolicyChange({
        principal: bergenOwner, existing: slug(ANON_OWNER), meta: metaFor(ANON_OWNER, ACCESS_POLICIES.PUBLIC),
    });
    assert.equal(d.ok, false);
    assert.equal(d.reason, "anon_plan_has_no_owner");
});

test("policy change on an unknown slug is 404", () => {
    assert.equal(authorizePolicyChange({ principal: bergenOwner, existing: null, meta: null }).status, 404);
});

// ---------- refusals from the auth layer ----------

test("a refused principal is treated as unauthenticated, never as authorised", () => {
    // authenticate() returns { ok: false } for a bad token. If that leaked
    // through as "authenticated", a forged token would be better than none.
    const refused = { ok: false, status: 401, reason: "bad_signature" };
    const d = authorizeCatalogWrite({
        principal: refused, existing: slug("a_bergen"), meta: metaFor("a_bergen", ACCESS_POLICIES.ACCOUNT),
    });
    assert.equal(d.ok, false);
});

test("a refused principal on a new slug lands anon/public rather than claiming an account", () => {
    const refused = { ok: false, status: 401, reason: "expired" };
    const d = authorizeCatalogWrite({ principal: refused, existing: null, meta: null });
    assert.equal(d.ownerId, ANON_OWNER);
});

// ---------- publishing a new plan openly, on purpose (DESIGN-015 §5.8) ----------

test("a signed-in user may publish a NEW plan as public", async () => {
    // Defaulting to `account` is the protective choice, but forcing it would
    // mean nobody who signs in can contribute to the shared corpus again —
    // and ADR-0025 keeps the wiki model as a first-class option, not a legacy
    // one.
    const d = authorizeCatalogWrite({
        principal: bergenMember, existing: null, meta: null, requestedAccessPolicy: "public",
    });
    assert.equal(d.ok, true);
    assert.equal(d.ownerId, "a_bergen", "still owned by the account that published it");
    assert.equal(d.accessPolicy, ACCESS_POLICIES.PUBLIC);
});

test("the default is still account when nothing is requested", () => {
    const d = authorizeCatalogWrite({ principal: bergenMember, existing: null, meta: null });
    assert.equal(d.accessPolicy, ACCESS_POLICIES.ACCOUNT);
});

test("`shared` is refused at publish time rather than silently downgraded", () => {
    // It names specific grantee accounts, which is a decision made after the
    // plan exists.
    const d = authorizeCatalogWrite({
        principal: bergenMember, existing: null, meta: null, requestedAccessPolicy: "shared",
    });
    assert.equal(d.ok, false);
    assert.equal(d.status, 400);
    assert.equal(d.reason, "invalid_access_policy");
});

test("nonsense is refused, not ignored", () => {
    const d = authorizeCatalogWrite({
        principal: bergenMember, existing: null, meta: null, requestedAccessPolicy: "everyone-lol",
    });
    assert.equal(d.reason, "invalid_access_policy");
});

test("a requested policy cannot change an EXISTING plan's policy", () => {
    // Widening access must go through /api/drills/policy, never as a side
    // effect of an ordinary publish.
    const d = authorizeCatalogWrite({
        principal: bergenOwner,
        existing: slug("a_bergen"),
        meta: metaFor("a_bergen", ACCESS_POLICIES.ACCOUNT),
        requestedAccessPolicy: "public",
    });
    assert.equal(d.ok, true);
    assert.equal(d.accessPolicy, ACCESS_POLICIES.ACCOUNT, "unchanged");
});

test("an anonymous publish is public regardless of what it asks for", () => {
    const d = authorizeCatalogWrite({
        principal: anonymous, existing: null, meta: null, requestedAccessPolicy: "account",
    });
    assert.equal(d.ownerId, ANON_OWNER);
    assert.equal(d.accessPolicy, ACCESS_POLICIES.PUBLIC, "there is no account to scope it to");
});
