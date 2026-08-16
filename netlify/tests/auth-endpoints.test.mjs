/**
 * The auth surface end to end, under AUTH_MODE=mock with the mail channel
 * short-circuited (ADR-0073) — no provider, no mailbox, real code path.
 *
 * This is the test that justifies the adapter: the full sign-in round trip runs
 * in CI, against the same endpoints and the same claim assembly production uses.
 */
import { test } from "node:test";
import assert from "node:assert/strict";

import { createHandler } from "../functions/auth.js";
import { createMockAdapter } from "../functions/lib/mail/index.js";
import { createAdapter, generateKeypair, verifyJwt, ISSUER, AUDIENCE } from "../functions/lib/auth/index.js";
import { putMember } from "../functions/lib/identity.js";

const KEYS = generateKeypair();

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
            data.set(key, value);
            return { modified: true };
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
        accounts: fakeStore(), users: fakeStore(), identities: fakeStore(), members: fakeStore(), memberIndex: fakeStore(),
        emailIndex: fakeStore(), handles: fakeStore(), sessions: fakeStore(), sessionIndex: fakeStore(), challenges: fakeStore(),
    };
    const stores = {
        accounts: () => raw.accounts, users: () => raw.users, identities: () => raw.identities,
        members: () => raw.members, memberIndex: () => raw.memberIndex,
        emailIndex: () => raw.emailIndex, handles: () => raw.handles,
        sessions: () => raw.sessions, sessionIndex: () => raw.sessionIndex,
    };
    const mailer = createMockAdapter();
    const handler = createHandler({
        env: {
            AUTH_MODE: "mock",
            AUTH_SIGNING_KEY_PRIVATE: KEYS.privateKey,
            AUTH_SIGNING_KEY_PUBLIC: KEYS.publicKey,
            PUBLIC_APP_ORIGIN: "https://ringdrill.app",
        },
        stores,
        challengeStore: () => raw.challenges,
        sessionStore: () => raw.sessions,
        sessionIndexStore: () => raw.sessionIndex,
        mailer,
    });
    return { handler, stores, raw, mailer };
}

const post = (route, body, headers = {}) =>
    new Request(`https://api.ringdrill.app/api/auth/${route}`, {
        method: "POST", headers: { "content-type": "application/json", ...headers }, body: JSON.stringify(body),
    });

async function signIn(h, email = "kari@example.com") {
    const started = await (await h.handler(post("start-email", { email, locale: "nb" }))).json();
    const done = await h.handler(post("callback", { challengeId: started.challengeId, code: started.code, deviceLabel: "iPhone 15" }));
    return { started, session: await done.json(), status: done.status };
}

// ---------- start-email ----------

test("start-email sends the template and returns the code only under mock", async () => {
    const h = harness();
    const res = await h.handler(post("start-email", { email: "Kari@Example.com ", locale: "nb" }));
    const body = await res.json();

    assert.equal(res.status, 200);
    assert.ok(body.challengeId);
    assert.ok(body.code, "mock returns the code so the flow runs with no mail provider");

    assert.equal(h.mailer.outbox.length, 1);
    assert.equal(h.mailer.outbox[0].to, "kari@example.com", "the address is normalised before anything is stored");
    assert.match(h.mailer.outbox[0].subject, /Innloggingslenken/, "locale is honoured");
    assert.match(h.mailer.outbox[0].text, new RegExp(body.code));
});

test("start-email rejects an obviously invalid address", async () => {
    const h = harness();
    assert.equal((await h.handler(post("start-email", { email: "not-an-email" }))).status, 400);
});

// ---------- callback ----------

test("callback mints a verifiable access token and opens a session", async () => {
    const h = harness();
    const { session, status } = await signIn(h);

    assert.equal(status, 200);
    assert.ok(session.refreshToken);
    assert.ok(session.sessionId);
    assert.equal(session.accountCreated, true);

    // The property that matters is that the token the server issued is one the
    // *active adapter* accepts. Under mock that is a test token, under live a
    // signed JWT — asserting the format would test the mode, not the loop.
    const adapter = await createAdapter({ env: { AUTH_MODE: "mock" } });
    const principal = await adapter.authenticate(
        new Request("https://api.ringdrill.app/x", { headers: { authorization: `Bearer ${session.accessToken}` } }),
    );
    assert.equal(principal.ok, true);
    assert.equal(principal.anonymous, false);
    assert.equal(principal.userId, session.user.id);
    assert.equal(principal.accounts.length, 1, "a personal account, created on first sign-in");
    assert.equal(principal.role, "owner");
});

test("callback refuses a wrong code and reports the attempts left", async () => {
    const h = harness();
    const started = await (await h.handler(post("start-email", { email: "kari@example.com" }))).json();
    const res = await h.handler(post("callback", { challengeId: started.challengeId, code: "ZZZZZZ" }));
    assert.equal(res.status, 401);
    assert.equal((await res.json()).attemptsLeft, 4);
});

test("a second sign-in with the same address is the same user and account", async () => {
    const h = harness();
    const first = await signIn(h);
    const second = await signIn(h);
    assert.equal(second.session.user.id, first.session.user.id);
    assert.equal(second.session.accountCreated, false);
    assert.equal(h.raw.accounts.data.size, 1);
});

// ---------- refresh ----------

test("refresh rotates the token and re-reads roles, so a change lands without signing out", async () => {
    const h = harness();
    const { session } = await signIn(h);

    // Somebody adds this user to an organisation between token mints.
    await putMember("a_bergen", session.user.id, "guest", { acceptedAt: "2026-08-08" }, h.stores);

    const res = await h.handler(post("refresh", { sessionId: session.sessionId, refreshToken: session.refreshToken }));
    const body = await res.json();
    assert.equal(res.status, 200);
    assert.notEqual(body.refreshToken, session.refreshToken, "rotated on every use");

    const adapter = await createAdapter({ env: { AUTH_MODE: "mock" } });
    const principal = await adapter.authenticate(
        new Request("https://api.ringdrill.app/x", { headers: { authorization: `Bearer ${body.accessToken}` } }),
    );
    assert.ok(principal.accounts.includes("a_bergen"));
    assert.equal(principal.roles.a_bergen, "guest");
});

test("REPLAY: reusing a rotated refresh token is 401 and the session is gone", async () => {
    const h = harness();
    const { session } = await signIn(h);
    await h.handler(post("refresh", { sessionId: session.sessionId, refreshToken: session.refreshToken }));

    const replay = await h.handler(post("refresh", { sessionId: session.sessionId, refreshToken: session.refreshToken }));
    assert.equal(replay.status, 401);
    assert.equal((await replay.json()).error, "replayed");

    // The session is ended, not merely refused — but it is kept as a
    // tombstone so `me` can still report it and the user learns their refresh
    // token was replayed.
    const rec = await h.raw.sessions.get(session.sessionId, { type: "json" });
    assert.equal(rec.endedReason, "replayed");
    assert.equal(rec.refreshHash, undefined);

    const me = await (await h.handler(new Request("https://api.ringdrill.app/api/auth/me", {
        headers: { authorization: `Bearer ${session.accessToken}` },
    }))).json();
    assert.equal(me.devices.length, 1);
    assert.equal(me.devices[0].endedReason, "replayed");
});

// ---------- logout ----------

test("logout is 204 whether or not the session existed", async () => {
    const h = harness();
    const { session } = await signIn(h);
    assert.equal((await h.handler(post("logout", {
        sessionId: session.sessionId, refreshToken: session.refreshToken,
    }))).status, 204);
    // Telling a caller which session ids are real is free reconnaissance.
    assert.equal((await h.handler(post("logout", { sessionId: "never-existed" }))).status, 204);
});

test("a bare session id does not end anybody's session", async () => {
    // This used to work. A 144-bit id is not guessable, but an endpoint that
    // destroys server state on an attacker-supplied identifier should not rest
    // on that alone — an id leaked through a screenshot, a log line or a
    // support ticket was a forced-logout capability for whoever saw it.
    const h = harness();
    const { session } = await signIn(h);

    const res = await h.handler(post("logout", { sessionId: session.sessionId }));

    // Still 204: the refusal must not be distinguishable from success, or the
    // endpoint becomes an oracle for which ids are real.
    assert.equal(res.status, 204);
    assert.equal(h.raw.sessions.data.size, 1, "the session must survive");
});

test("the refresh token proves ownership, so a stale client can still sign out", async () => {
    // By the time somebody signs out their access token may well have expired.
    // Requiring a live one would leave the session alive for the full 60-day
    // refresh window.
    const h = harness();
    const { session } = await signIn(h);

    await h.handler(post("logout", {
        sessionId: session.sessionId, refreshToken: session.refreshToken,
    }));
    assert.equal(h.raw.sessions.data.size, 0);
});

test("a wrong refresh token does not end the session", async () => {
    const h = harness();
    const { session } = await signIn(h);

    await h.handler(post("logout", {
        sessionId: session.sessionId, refreshToken: "not-the-token",
    }));
    assert.equal(h.raw.sessions.data.size, 1);
});

test("an access token proves ownership too", async () => {
    const h = harness();
    const { session } = await signIn(h);

    await h.handler(post("logout", { sessionId: session.sessionId }, {
        authorization: `Bearer ${session.accessToken}`,
    }));
    assert.equal(h.raw.sessions.data.size, 0);
});

// ---------- sessions/revoke ----------

test("revoke ends another of my own devices", async () => {
    // The answer to "my phone was stolen" (DESIGN-015 §4.3).
    const h = harness();
    const first = await signIn(h);
    const second = await signIn(h);
    assert.equal(h.raw.sessions.data.size, 2);

    const res = await h.handler(post("sessions/revoke", {
        sessionId: second.session.sessionId,
    }, { authorization: `Bearer ${first.session.accessToken}` }));

    assert.equal(res.status, 204);
    assert.equal(h.raw.sessions.data.size, 1);
    assert.ok(h.raw.sessions.data.has(first.session.sessionId), "mine survives");
});

test("revoke will not touch somebody else's session", async () => {
    // The whole point of the ownership check: a session list is per-user, and
    // an id from one user must be inert against another's token.
    const h = harness();
    const mine = await signIn(h, "kari@example.com");
    const theirs = await signIn(h, "ola@example.com");

    const res = await h.handler(post("sessions/revoke", {
        sessionId: theirs.session.sessionId,
    }, { authorization: `Bearer ${mine.session.accessToken}` }));

    assert.equal(res.status, 204, "and not a 403 — that would confirm it exists");
    assert.ok(h.raw.sessions.data.has(theirs.session.sessionId), "theirs survives");
});

test("revoke requires a live session, not just a refresh token", async () => {
    // Presenting the refresh token would mean holding the very device being
    // revoked, which is not what this endpoint is for.
    const h = harness();
    const { session } = await signIn(h);

    const res = await h.handler(post("sessions/revoke", {
        sessionId: session.sessionId, refreshToken: session.refreshToken,
    }));

    assert.equal(res.status, 401);
    assert.equal(h.raw.sessions.data.size, 1);
});

// ---------- me ----------

test("me returns the user, their accounts with roles, and their devices", async () => {
    const h = harness();
    const { session } = await signIn(h);
    await putMember("a_bergen", session.user.id, "member", { acceptedAt: "2026-08-08" }, h.stores);
    await h.stores.accounts().set("a_bergen", JSON.stringify({
        id: "a_bergen", displayName: "Red Cross Bergen", type: "organization", handle: "redcross-bergen",
    }));

    // A fresh token so the new membership is in the claims.
    const refreshed = await (await h.handler(post("refresh", { sessionId: session.sessionId, refreshToken: session.refreshToken }))).json();

    const res = await h.handler(new Request("https://api.ringdrill.app/api/auth/me", {
        headers: { authorization: `Bearer ${refreshed.accessToken}` },
    }));
    const body = await res.json();

    assert.equal(res.status, 200);
    assert.equal(body.user.email, "kari@example.com");
    const org = body.accounts.find((a) => a.id === "a_bergen");
    assert.equal(org.handle, "redcross-bergen");
    assert.equal(org.role, "member");
    assert.deepEqual(body.devices.map((d) => d.deviceLabel), ["iPhone 15"]);
    for (const d of body.devices) assert.equal(d.refreshHash, undefined);
});

test("me is 401 without a token", async () => {
    const h = harness();
    const res = await h.handler(new Request("https://api.ringdrill.app/api/auth/me"));
    assert.equal(res.status, 401);
});

test("an unknown route under /api/auth is 404, not a 500", async () => {
    const h = harness();
    assert.equal((await h.handler(post("nope", {}))).status, 404);
});

test("under AUTH_MODE=live the server signs a real JWT, verifiable with the public key", async () => {
    // The complement of the mock case: the same claim assembly, the other
    // format. Together they are the ADR-0073 claim — one code path, two modes.
    const h = harness();
    const live = createHandler({
        env: {
            AUTH_MODE: "live",
            AUTH_SIGNING_KEY_PRIVATE: KEYS.privateKey,
            AUTH_SIGNING_KEY_PUBLIC: KEYS.publicKey,
            PUBLIC_APP_ORIGIN: "https://ringdrill.app",
        },
        stores: h.stores,
        challengeStore: () => h.raw.challenges,
        sessionStore: () => h.raw.sessions,
        sessionIndexStore: () => h.raw.sessionIndex,
        mailer: h.mailer,
    });

    const started = await (await live(post("start-email", { email: "kari@example.com" }))).json();
    // In live the code is never in the response — it would be the credential.
    assert.equal(started.code, undefined);
    const code = h.mailer.outbox.at(-1).text.match(/[A-Z2-9]{6}/)[0];

    const session = await (await live(post("callback", { challengeId: started.challengeId, code }))).json();
    const verified = verifyJwt(session.accessToken, [KEYS.publicKey], { issuer: ISSUER, audience: AUDIENCE });
    assert.equal(verified.ok, true);
    assert.equal(verified.claims.sub, session.user.id);
    assert.equal(verified.claims.roles[verified.claims.act], "owner");
});

// ---------- PATCH me ----------

test("a user sets their own names, and the personal account follows", async () => {
    // The personal account is created carrying the user's name and exists to be
    // "you". Leaving it on the old one would show two names for one person on
    // the same screen.
    const h = harness();
    const { session } = await signIn(h);

    const res = await h.handler(new Request("https://api.ringdrill.app/api/auth/me", {
        method: "PATCH",
        headers: { "content-type": "application/json", authorization: `Bearer ${session.accessToken}` },
        body: JSON.stringify({ displayName: "Kari Nordmann", shortName: "Kari" }),
    }));
    assert.equal(res.status, 200);
    const body = await res.json();
    assert.equal(body.user.displayName, "Kari Nordmann");
    assert.equal(body.user.shortName, "Kari");

    const me = await (await h.handler(new Request("https://api.ringdrill.app/api/auth/me", {
        headers: { authorization: `Bearer ${session.accessToken}` },
    }))).json();
    assert.equal(me.accounts[0].displayName, "Kari Nordmann", "the personal account renamed with them");
});

test("renaming yourself never renames an organisation", async () => {
    const h = harness();
    const { session } = await signIn(h);
    await h.stores.accounts().set("a_bergen", JSON.stringify({
        id: "a_bergen", displayName: "Red Cross Bergen", type: "organization",
    }));
    await putMember("a_bergen", session.user.id, "owner", { acceptedAt: "2026-08-08" }, h.stores);

    await h.handler(new Request("https://api.ringdrill.app/api/auth/me", {
        method: "PATCH",
        headers: { "content-type": "application/json", authorization: `Bearer ${session.accessToken}` },
        body: JSON.stringify({ displayName: "Kari Nordmann" }),
    }));

    const org = await h.stores.accounts().get("a_bergen", { type: "json" });
    assert.equal(org.displayName, "Red Cross Bergen");
});

test("a short name starts empty rather than guessed", async () => {
    // A provider gives a full name or nothing, and never what a person is
    // called on the day. Deriving one would produce the local part of an email
    // for anybody who signed in with a code.
    const h = harness();
    const { session } = await signIn(h);
    assert.equal(session.user.shortName, "");
});

test("a display name cannot be cleared, but a short name can", async () => {
    const h = harness();
    const { session } = await signIn(h);
    const patch = (body) => h.handler(new Request("https://api.ringdrill.app/api/auth/me", {
        method: "PATCH",
        headers: { "content-type": "application/json", authorization: `Bearer ${session.accessToken}` },
        body: JSON.stringify(body),
    }));

    // Blank is the fallback chain from creation, so clearing it would leave
    // this person nameless on every screen.
    assert.equal((await patch({ displayName: "  " })).status, 400);
    assert.equal((await patch({})).status, 400, "nothing to update is a mistake, not a no-op");
    assert.equal((await patch({ shortName: "" })).status, 200, "empty is a short name's legitimate state");
});

test("PATCH me renames only the caller", async () => {
    // The id comes from the verified token and is never read from the body.
    const h = harness();
    const { session } = await signIn(h);
    const res = await h.handler(new Request("https://api.ringdrill.app/api/auth/me", {
        method: "PATCH",
        headers: { "content-type": "application/json", authorization: `Bearer ${session.accessToken}` },
        body: JSON.stringify({ userId: "u_someone_else", displayName: "Hacked" }),
    }));
    assert.equal(res.status, 200);
    assert.equal((await res.json()).user.id, session.user.id);
});

test("PATCH me is refused when signed out", async () => {
    const h = harness();
    const res = await h.handler(new Request("https://api.ringdrill.app/api/auth/me", {
        method: "PATCH",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ displayName: "Nobody" }),
    }));
    assert.equal(res.status, 401);
});
