import crypto from "node:crypto";

/**
 * Sign-in challenges (the magic link and its code) and refresh sessions.
 *
 * **Nothing here stores a usable secret.** Challenge codes and refresh tokens
 * are held as SHA-256 hashes, so a leak of the blob store yields no credential.
 * The value is returned to the caller exactly once, at creation, and never
 * again — which is also why `startChallenge` returns the code rather than
 * offering a way to read it back.
 */

const CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // no I/O/0/1
export const CHALLENGE_TTL_MS = 10 * 60 * 1000;
export const REFRESH_TTL_MS = 60 * 24 * 60 * 60 * 1000;
export const ACCESS_TTL_S = 60 * 60;
export const MAX_CODE_ATTEMPTS = 5;

export function hash(value) {
    return crypto.createHash("sha256").update(String(value)).digest("hex");
}

function randomFrom(alphabet, length) {
    const bytes = crypto.randomBytes(length);
    let out = "";
    for (let i = 0; i < length; i++) out += alphabet[bytes[i] % alphabet.length];
    return out;
}

/**
 * A 6-character code, from an alphabet with no I, O, 0 or 1.
 *
 * People read these off a screen and type them somewhere else (DESIGN-015
 * §3.3), so the characters that get mistaken for each other are removed rather
 * than explained. 32^6 is ~30 bits, which needs the attempt limit below to be
 * meaningful — hence MAX_CODE_ATTEMPTS.
 */
export function newCode() {
    return randomFrom(CODE_ALPHABET, 6);
}

export function newToken(bytes = 32) {
    return crypto.randomBytes(bytes).toString("base64url");
}

/**
 * Start a sign-in. Returns the challenge id (held by the client that started
 * it) and the code (mailed, or returned in the body under AUTH_MODE=mock).
 *
 * The id is what makes "type the code where you started" work without an email
 * index: the waiting screen already holds it, so the code alone never has to
 * identify anything.
 */
export async function startChallenge(store, { email, locale = "en", now = Date.now }) {
    const id = newToken(18);
    const code = newCode();
    await store.set(id, JSON.stringify({
        email,
        codeHash: hash(code),
        locale,
        attempts: 0,
        expiresAt: now() + CHALLENGE_TTL_MS,
        createdAt: new Date(now()).toISOString(),
    }));
    return { challengeId: id, code, expiresInMs: CHALLENGE_TTL_MS };
}

/**
 * Redeem a challenge. Single-use: the record is deleted on success *and* on
 * running out of attempts, so a burned challenge cannot be retried.
 */
export async function redeemChallenge(store, { challengeId, code, now = Date.now }) {
    if (!challengeId || !code) return { ok: false, reason: "missing_fields" };
    const rec = await store.get(challengeId, { type: "json" });
    if (!rec) return { ok: false, reason: "unknown_or_used" };

    if (rec.expiresAt <= now()) {
        await store.delete(challengeId);
        return { ok: false, reason: "expired" };
    }

    // Constant-time compare so the code cannot be recovered a character at a
    // time from response timing. Both sides are fixed-length hex, so
    // timingSafeEqual's length precondition holds.
    const provided = Buffer.from(hash(String(code).trim().toUpperCase()), "hex");
    const expected = Buffer.from(rec.codeHash, "hex");
    if (provided.length !== expected.length || !crypto.timingSafeEqual(provided, expected)) {
        const attempts = (rec.attempts ?? 0) + 1;
        if (attempts >= MAX_CODE_ATTEMPTS) {
            // ~30 bits of entropy only holds up with a cap on guesses.
            await store.delete(challengeId);
            return { ok: false, reason: "too_many_attempts" };
        }
        await store.set(challengeId, JSON.stringify({ ...rec, attempts }));
        return { ok: false, reason: "bad_code", attemptsLeft: MAX_CODE_ATTEMPTS - attempts };
    }

    await store.delete(challengeId);
    return { ok: true, email: rec.email, locale: rec.locale };
}

/** Open a refresh session. The token is returned once and stored only as a hash. */
export async function createSession(store, { userId, deviceLabel = null, now = Date.now }) {
    const sessionId = newToken(18);
    const refreshToken = newToken(32);
    await store.set(sessionId, JSON.stringify({
        sessionId,
        userId,
        refreshHash: hash(refreshToken),
        deviceLabel,
        createdAt: new Date(now()).toISOString(),
        lastUsedAt: new Date(now()).toISOString(),
        expiresAt: now() + REFRESH_TTL_MS,
    }));
    return { sessionId, refreshToken };
}

/**
 * Rotate a refresh token (ADR-0025): every use issues a new one and invalidates
 * the old.
 *
 * **A token that does not match the stored hash ends the session.** That is not
 * over-reaction: the only ways to present a stale-but-well-formed refresh token
 * are a replay of one already rotated, or a guess. Both mean the session should
 * stop existing, and the alternative — refusing the request but leaving the
 * session alive — lets an attacker keep trying against a session the rightful
 * owner is still using.
 *
 * The rightful owner is signed out too. That is the cost, and it is the correct
 * trade: a forced re-login is an inconvenience, a live session in someone
 * else's hands is not.
 */
export async function rotateSession(store, { sessionId, refreshToken, now = Date.now }) {
    if (!sessionId || !refreshToken) return { ok: false, reason: "missing_fields" };
    const rec = await store.get(sessionId, { type: "json" });
    if (!rec) return { ok: false, reason: "unknown_session" };

    // An ended session is a record with no credential in it. Checked before
    // the hash compare rather than relying on the compare to fail, because
    // `refreshHash` is absent on a tombstone and Buffer.from(undefined) throws
    // — a second replay would answer 500 instead of 401.
    if (rec.endedAt) return { ok: false, reason: "unknown_session" };

    if (rec.expiresAt <= now()) {
        await store.delete(sessionId);
        return { ok: false, reason: "expired" };
    }

    const provided = Buffer.from(hash(refreshToken), "hex");
    const expected = Buffer.from(rec.refreshHash, "hex");
    if (provided.length !== expected.length || !crypto.timingSafeEqual(provided, expected)) {
        // **Tombstoned, not deleted.** A replayed token means somebody had a
        // copy of this session's refresh token, which is the one event a user
        // most needs told about — and a session that simply disappears from
        // the device list tells them nothing (DESIGN-015 §4.3).
        //
        // The credential goes; only the fact remains. `expiresAt` is kept
        // untouched, so the tombstone ages out on the same clock the live
        // session would have and `sessionsOf` stops reporting it then.
        const { refreshHash, ...rest } = rec;
        await store.set(sessionId, JSON.stringify({
            ...rest,
            endedAt: new Date(now()).toISOString(),
            endedReason: "replayed",
        }));
        return { ok: false, reason: "replayed", sessionEnded: true, userId: rec.userId };
    }

    const next = newToken(32);
    await store.set(sessionId, JSON.stringify({
        ...rec,
        refreshHash: hash(next),
        lastUsedAt: new Date(now()).toISOString(),
    }));
    return { ok: true, userId: rec.userId, refreshToken: next, sessionId };
}

export async function endSession(store, sessionId) {
    if (sessionId) await store.delete(sessionId);
}

/**
 * End a session, but only for somebody entitled to end it.
 *
 * [endSession] takes an id and destroys it, which is right for an internal
 * caller that has already decided and wrong for anything reachable from the
 * network. Ownership is proved one of two ways, and both are needed:
 *
 * * **`userId`** — the authenticated principal owns the session. This is what
 *   the sessions list uses to revoke *another* device ("my phone was stolen",
 *   DESIGN-015 §4.3).
 * * **`refreshToken`** — the caller holds the session's own refresh token.
 *   This is what ordinary sign-out uses, and it is here because the access
 *   token may well have expired by the time somebody signs out. Requiring a
 *   live access token would mean a stale client could not revoke its own
 *   session, leaving it alive for the full 60-day refresh window.
 *
 * Returns whether anything was ended. Callers should **not** pass that to the
 * client: which session ids exist is free reconnaissance, and the answer is
 * useless to the legitimate caller, who already knows.
 */
export async function endSessionOwnedBy(store, { sessionId, userId = null, refreshToken = null }) {
    if (!sessionId) return false;
    const rec = await store.get(sessionId, { type: "json" });
    if (!rec) return false;

    const byOwner = userId != null && rec.userId === userId;
    // timingSafeEqual over two fixed-length hex digests: the comparison is on
    // hashes rather than tokens, but a short-circuiting `===` here still leaks
    // a prefix-match oracle for the stored hash.
    const byToken =
        refreshToken != null &&
        rec.refreshHash != null &&
        safeEqual(hash(refreshToken), rec.refreshHash);

    if (!byOwner && !byToken) return false;
    await store.delete(sessionId);
    return true;
}

function safeEqual(a, b) {
    const left = Buffer.from(String(a));
    const right = Buffer.from(String(b));
    if (left.length !== right.length) return false;
    return crypto.timingSafeEqual(left, right);
}

/** Every open session for a user — the Devices list in DESIGN-015 §4.3. */
/**
 * This user's sessions, live ones and recently-ended tombstones alike.
 *
 * A tombstone (`endedAt` set) is included on purpose: it is how a replayed
 * refresh token becomes visible to the person it happened to. Once it passes
 * `expiresAt` it stops being reported — the live session would have expired by
 * then too, so there is nothing left to explain.
 */
export async function sessionsOf(store, userId, { now = Date.now } = {}) {
    const out = [];
    let cursor;
    do {
        const page = await store.list({ cursor });
        cursor = page?.cursor;
        for (const blob of page?.blobs ?? []) {
            const rec = await store.get(blob.key, { type: "json" });
            if (rec?.userId !== userId) continue;
            if (typeof rec.expiresAt === "number" && rec.expiresAt <= now()) continue;
            // Never the hash: this is rendered in the app, and a credential
            // derivative has no business leaving the server. A tombstone has
            // none to begin with.
            const { refreshHash, ...safe } = rec;
            out.push(safe);
        }
    } while (cursor);
    return out;
}
