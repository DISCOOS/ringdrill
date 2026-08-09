/**
 * Challenges and refresh sessions (ADR-0024, ADR-0025).
 *
 * The two properties worth the most here are that nothing usable is stored —
 * a leak of the blob store must yield no credential — and that a replayed
 * refresh token ends the session rather than merely being refused.
 */
import { test } from "node:test";
import assert from "node:assert/strict";

import {
    CHALLENGE_TTL_MS,
    MAX_CODE_ATTEMPTS,
    createSession,
    endSession,
    hash,
    newCode,
    redeemChallenge,
    rotateSession,
    sessionsOf,
    startChallenge,
} from "../functions/lib/auth/session.js";

function fakeStore() {
    const data = new Map();
    return {
        data,
        async get(key, opts) {
            const raw = data.get(key);
            return raw === undefined ? null : (opts?.type === "json" ? JSON.parse(raw) : raw);
        },
        async set(key, value) { data.set(key, value); return { modified: true }; },
        async delete(key) { data.delete(key); },
        async list({ cursor } = {}) {
            if (cursor) return { blobs: [], cursor: undefined };
            return { blobs: [...data.keys()].map((key) => ({ key })), cursor: undefined };
        },
    };
}

// ---------- codes ----------

test("codes avoid characters people mistype off a screen", () => {
    for (let i = 0; i < 200; i++) {
        const code = newCode();
        assert.equal(code.length, 6);
        assert.doesNotMatch(code, /[IO01]/, `${code} contains a confusable character`);
    }
});

// ---------- challenges ----------

test("a challenge stores only a hash of its code", async () => {
    const store = fakeStore();
    const { challengeId, code } = await startChallenge(store, { email: "kari@example.com" });
    const stored = JSON.parse(store.data.get(challengeId));

    assert.equal(stored.codeHash, hash(code));
    // A store leak must not yield a usable credential.
    assert.ok(!JSON.stringify(stored).includes(code), "the code itself must never be at rest");
});

test("redeeming succeeds once, and the challenge is gone afterwards", async () => {
    const store = fakeStore();
    const { challengeId, code } = await startChallenge(store, { email: "kari@example.com", locale: "nb" });

    const first = await redeemChallenge(store, { challengeId, code });
    assert.equal(first.ok, true);
    assert.equal(first.email, "kari@example.com");
    assert.equal(first.locale, "nb");

    const second = await redeemChallenge(store, { challengeId, code });
    assert.equal(second.ok, false, "single use");
    assert.equal(second.reason, "unknown_or_used");
});

test("codes are accepted case-insensitively and trimmed, because people retype them", async () => {
    const store = fakeStore();
    const { challengeId, code } = await startChallenge(store, { email: "k@e.com" });
    const res = await redeemChallenge(store, { challengeId, code: `  ${code.toLowerCase()} ` });
    assert.equal(res.ok, true);
});

test("an expired challenge is refused and deleted", async () => {
    const store = fakeStore();
    let t = 1_000_000;
    const { challengeId, code } = await startChallenge(store, { email: "k@e.com", now: () => t });
    t += CHALLENGE_TTL_MS + 1;
    const res = await redeemChallenge(store, { challengeId, code, now: () => t });
    assert.equal(res.reason, "expired");
    assert.equal(store.data.size, 0);
});

test("guessing is capped, and the challenge burns when the cap is hit", async () => {
    // ~30 bits of entropy only holds up with a cap on guesses.
    const store = fakeStore();
    const { challengeId } = await startChallenge(store, { email: "k@e.com" });

    for (let i = 1; i < MAX_CODE_ATTEMPTS; i++) {
        const res = await redeemChallenge(store, { challengeId, code: "XXXXXX" });
        assert.equal(res.reason, "bad_code");
        assert.equal(res.attemptsLeft, MAX_CODE_ATTEMPTS - i);
    }
    const last = await redeemChallenge(store, { challengeId, code: "XXXXXX" });
    assert.equal(last.reason, "too_many_attempts");
    assert.equal(store.data.size, 0, "a burned challenge cannot be retried");
});

// ---------- sessions ----------

test("a session stores only a hash of its refresh token", async () => {
    const store = fakeStore();
    const { sessionId, refreshToken } = await createSession(store, { userId: "u_1", deviceLabel: "iPhone" });
    const stored = JSON.parse(store.data.get(sessionId));
    assert.equal(stored.refreshHash, hash(refreshToken));
    assert.ok(!JSON.stringify(stored).includes(refreshToken));
});

test("rotation issues a new token and invalidates the old one", async () => {
    const store = fakeStore();
    const { sessionId, refreshToken } = await createSession(store, { userId: "u_1" });

    const first = await rotateSession(store, { sessionId, refreshToken });
    assert.equal(first.ok, true);
    assert.notEqual(first.refreshToken, refreshToken);

    const withNew = await rotateSession(store, { sessionId, refreshToken: first.refreshToken });
    assert.equal(withNew.ok, true);
});

test("REPLAY: presenting a rotated token ends the session entirely", async () => {
    // Refusing but leaving the session alive would let an attacker keep trying
    // against a session the rightful owner is still using. The owner being
    // signed out is the cost, and it is the correct trade.
    const store = fakeStore();
    const { sessionId, refreshToken } = await createSession(store, { userId: "u_1" });
    await rotateSession(store, { sessionId, refreshToken });

    const replay = await rotateSession(store, { sessionId, refreshToken });
    assert.equal(replay.ok, false);
    assert.equal(replay.reason, "replayed");
    assert.equal(replay.sessionEnded, true);
    assert.equal(replay.userId, "u_1", "the caller needs this to log the signal");

    // Ended, but not erased. The record survives as a tombstone so the person
    // it happened to can be *told* — a session that silently disappears from
    // the device list explains nothing (DESIGN-015 §4.3).
    const tomb = await store.get(sessionId, { type: "json" });
    assert.equal(tomb.endedReason, "replayed");
    assert.ok(tomb.endedAt, "and when");
    // The credential is what must be gone.
    assert.equal(tomb.refreshHash, undefined, "no credential derivative survives");
});

test("REPLAY: a tombstoned session is unusable, and replaying again does not 500", async () => {
    // `refreshHash` is absent on a tombstone, and Buffer.from(undefined) throws
    // — so the compare has to be skipped rather than relied upon to fail.
    const store = fakeStore();
    const { sessionId, refreshToken } = await createSession(store, { userId: "u_1" });
    await rotateSession(store, { sessionId, refreshToken });
    await rotateSession(store, { sessionId, refreshToken });

    const again = await rotateSession(store, { sessionId, refreshToken });
    assert.equal(again.ok, false);
    assert.equal(again.reason, "unknown_session");
});

test("a tombstone stops being reported once it would have expired", async () => {
    // By then the live session would have expired too, so there is nothing
    // left to explain — and tombstones must not accumulate forever.
    const store = fakeStore();
    let t = 1_000_000;
    const { sessionId, refreshToken } = await createSession(store, { userId: "u_1", now: () => t });
    await rotateSession(store, { sessionId, refreshToken, now: () => t });
    await rotateSession(store, { sessionId, refreshToken, now: () => t });

    assert.equal((await sessionsOf(store, "u_1", { now: () => t })).length, 1);
    t += 61 * 24 * 60 * 60 * 1000;
    assert.equal((await sessionsOf(store, "u_1", { now: () => t })).length, 0);
});

test("an expired session is refused and removed", async () => {
    const store = fakeStore();
    let t = 1_000_000;
    const { sessionId, refreshToken } = await createSession(store, { userId: "u_1", now: () => t });
    t += 61 * 24 * 60 * 60 * 1000;
    const res = await rotateSession(store, { sessionId, refreshToken, now: () => t });
    assert.equal(res.reason, "expired");
    assert.equal(store.data.size, 0);
});

test("an unknown session is refused without revealing whether it ever existed", async () => {
    const res = await rotateSession(fakeStore(), { sessionId: "nope", refreshToken: "x" });
    assert.equal(res.reason, "unknown_session");
});

test("sessionsOf lists a user's devices and never leaks the token hash", async () => {
    const store = fakeStore();
    await createSession(store, { userId: "u_1", deviceLabel: "iPhone 15" });
    await createSession(store, { userId: "u_1", deviceLabel: "MacBook Pro" });
    await createSession(store, { userId: "u_2", deviceLabel: "Someone else" });

    const mine = await sessionsOf(store, "u_1");
    assert.equal(mine.length, 2);
    assert.deepEqual(mine.map((s) => s.deviceLabel).sort(), ["MacBook Pro", "iPhone 15"]);
    // This is rendered in the app; a credential derivative has no business
    // leaving the server.
    for (const s of mine) assert.equal(s.refreshHash, undefined);
});

test("endSession removes exactly one device", async () => {
    const store = fakeStore();
    const a = await createSession(store, { userId: "u_1", deviceLabel: "A" });
    await createSession(store, { userId: "u_1", deviceLabel: "B" });
    await endSession(store, a.sessionId);
    assert.deepEqual((await sessionsOf(store, "u_1")).map((s) => s.deviceLabel), ["B"]);
});
