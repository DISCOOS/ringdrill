/**
 * The abuse bound on `POST /api/auth/start-email` (ADR-0079).
 *
 * Two properties are load-bearing and neither is visible in an ordinary
 * success-path test:
 *
 * * **The recipient cap holds whoever asks.** That is the whole reason this
 *   exists — source-based limiting is defeated by the cheapest thing an abuser
 *   can do, so a test that only rotates requests from one origin proves nothing.
 * * **A refusal is indistinguishable from a send.** `start-email` answers the
 *   same for an address with an account and one without, and a visible 429
 *   would hand back the enumeration oracle that design avoids.
 */
import { test } from "node:test";
import assert from "node:assert/strict";

import { createHandler } from "../functions/auth.js";
import {
    createStartEmailLimiter, recipientKey, sourceKey,
} from "../functions/lib/auth/start-email-limit.js";
import { createMockAdapter } from "../functions/lib/mail/index.js";

/** A blob store good enough for a counter. */
function fakeStore() {
    const data = new Map();
    return {
        data,
        async get(key, opts) {
            const raw = data.get(key);
            if (raw === undefined) return null;
            return opts?.type === "json" ? JSON.parse(raw) : raw;
        },
        async set(key, value) { data.set(key, value); return { modified: true }; },
        async delete(key) { data.delete(key); },
        async list({ prefix = "" } = {}) {
            return { blobs: [...data.keys()].filter((k) => k.startsWith(prefix)).map((key) => ({ key })), cursor: undefined };
        },
    };
}

const headersFor = (ip) => new Headers({ "x-nf-client-connection-ip": ip });

function limiter(over = {}) {
    const blobs = fakeStore();
    let clock = 1_000_000;
    return {
        blobs,
        advance: (ms) => { clock += ms; },
        limiter: createStartEmailLimiter({
            blobs: () => blobs,
            now: () => clock,
            recipientLimit: 3,
            sourceLimit: 20,
            ...over,
        }),
    };
}

// ---------- the recipient cap ----------

test("one address cannot be mailed past its cap, however many sources ask", async () => {
    // The property the whole design turns on. Each request comes from a
    // different IP, so a source-only limiter would allow every one of them.
    const h = limiter();
    const results = [];
    for (let i = 0; i < 6; i++) {
        results.push(await h.limiter.allowSend({
            email: "victim@example.com",
            headers: headersFor(`203.0.113.${i}`),
        }));
    }

    assert.deepEqual(results.map((r) => r.allowed), [true, true, true, false, false, false]);
    assert.equal(results[3].reason, "recipient");
});

test("the cap is per address, so one person's flood does not block another", async () => {
    const h = limiter();
    for (let i = 0; i < 3; i++) {
        await h.limiter.allowSend({ email: "victim@example.com", headers: headersFor("203.0.113.1") });
    }

    assert.equal((await h.limiter.allowSend({ email: "victim@example.com", headers: headersFor("203.0.113.9") })).allowed, false);
    assert.equal((await h.limiter.allowSend({ email: "someone@example.com", headers: headersFor("203.0.113.9") })).allowed, true);
});

test("addresses are compared normalised, so case is not a way around the cap", async () => {
    const h = limiter();
    for (const e of ["Victim@Example.com", "victim@example.com", "  VICTIM@EXAMPLE.COM  "]) {
        await h.limiter.allowSend({ email: e, headers: headersFor("203.0.113.1") });
    }
    assert.equal((await h.limiter.allowSend({ email: "victim@example.com", headers: headersFor("203.0.113.2") })).allowed, false);
});

test("the window expires, so a real person is not locked out for ever", async () => {
    const h = limiter();
    for (let i = 0; i < 3; i++) {
        await h.limiter.allowSend({ email: "kari@example.com", headers: headersFor("203.0.113.1") });
    }
    assert.equal((await h.limiter.allowSend({ email: "kari@example.com", headers: headersFor("203.0.113.1") })).allowed, false);

    h.advance(60 * 60 * 1000 + 1);
    assert.equal((await h.limiter.allowSend({ email: "kari@example.com", headers: headersFor("203.0.113.1") })).allowed, true);
});

// ---------- the source cap ----------

test("one source cannot walk through unlimited addresses", async () => {
    const h = limiter({ sourceLimit: 5 });
    const allowed = [];
    for (let i = 0; i < 8; i++) {
        allowed.push((await h.limiter.allowSend({
            email: `person${i}@example.com`,
            headers: headersFor("198.51.100.7"),
        })).allowed);
    }
    assert.deepEqual(allowed, [true, true, true, true, true, false, false, false]);
});

test("an exhausted source does not spend the recipient's budget", async () => {
    // Otherwise a flood from one dead origin eats a real person's allowance,
    // and the counter that matters stops meaning anything.
    const h = limiter({ sourceLimit: 2 });
    for (let i = 0; i < 4; i++) {
        await h.limiter.allowSend({ email: "kari@example.com", headers: headersFor("198.51.100.7") });
    }

    // Two got through and two were refused on source. Kari has one left.
    assert.equal((await h.limiter.allowSend({ email: "kari@example.com", headers: headersFor("203.0.113.1") })).allowed, true);
    assert.equal((await h.limiter.allowSend({ email: "kari@example.com", headers: headersFor("203.0.113.2") })).allowed, false);
});

// ---------- keys ----------

test("neither the address nor the IP is stored in plaintext", async () => {
    const h = limiter();
    await h.limiter.allowSend({ email: "kari@example.com", headers: headersFor("203.0.113.1") });

    const keys = [...h.blobs.data.keys()].join("|");
    assert.doesNotMatch(keys, /kari@example\.com/);
    assert.doesNotMatch(keys, /203\.0\.113\.1/);
    assert.match(keys, /^to:|from:/);
});

test("the two keyspaces cannot collide", () => {
    assert.match(recipientKey("a@b.c"), /^to:/);
    assert.match(sourceKey(headersFor("1.2.3.4")), /^from:/);
});

test("a forged x-forwarded-for cannot displace the real peer", () => {
    // Netlify sets x-nf-client-connection-ip and a client cannot forge it;
    // x-forwarded-for is caller-supplied and only a local-dev fallback.
    const real = sourceKey(new Headers({ "x-nf-client-connection-ip": "203.0.113.1" }));
    const spoofed = sourceKey(new Headers({
        "x-nf-client-connection-ip": "203.0.113.1",
        "x-forwarded-for": "10.0.0.1",
    }));
    assert.equal(real, spoofed);
});

// ---------- fail open ----------

test("a broken store lets the mail through", async () => {
    // A limiter that can stop people signing in is a worse fault than the abuse
    // it prevents. Inherited from createRateLimiter, asserted here because this
    // caller is the one where the consequence is a lockout.
    const boom = () => { throw new Error("blobs unavailable"); };
    const l = createStartEmailLimiter({ blobs: boom, recipientLimit: 1, sourceLimit: 1 });

    for (let i = 0; i < 5; i++) {
        assert.equal((await l.allowSend({ email: "kari@example.com", headers: headersFor("203.0.113.1") })).allowed, true);
    }
});

// ---------- the endpoint ----------

function harness({ recipientLimit = 3, sourceLimit = 20 } = {}) {
    const blobs = fakeStore();
    const challenges = fakeStore();
    const mailer = createMockAdapter();
    return {
        mailer,
        handler: createHandler({
            env: {
                AUTH_MODE: "live",
                AUTH_SIGNING_KEY_PRIVATE: "unused-here",
                PUBLIC_APP_ORIGIN: "https://ringdrill.app",
            },
            challengeStore: () => challenges,
            mailer,
            startEmailLimiter: createStartEmailLimiter({
                blobs: () => blobs, recipientLimit, sourceLimit,
            }),
        }),
    };
}

const start = (email, ip) => new Request("https://api.ringdrill.app/api/auth/start-email", {
    method: "POST",
    headers: { "content-type": "application/json", "x-nf-client-connection-ip": ip },
    body: JSON.stringify({ email }),
});

test("a suppressed send is indistinguishable from a delivered one", async () => {
    // The enumeration property. A 429, a different body, or a missing
    // challengeId would each tell a caller which addresses are worth mailing.
    const h = harness({ recipientLimit: 1 });

    const first = await h.handler(start("kari@example.com", "203.0.113.1"));
    const second = await h.handler(start("kari@example.com", "203.0.113.2"));

    assert.equal(first.status, 200);
    assert.equal(second.status, 200);

    const a = await first.json();
    const b = await second.json();
    assert.deepEqual(Object.keys(a).sort(), Object.keys(b).sort());
    assert.equal(typeof b.challengeId, "string");
    assert.ok(b.challengeId.length > 0);
    assert.notEqual(a.challengeId, b.challengeId, "a real challenge either way");
    assert.equal(b.expiresInMs, a.expiresInMs);
});

test("only the mail is suppressed", async () => {
    const h = harness({ recipientLimit: 1 });
    await h.handler(start("kari@example.com", "203.0.113.1"));
    await h.handler(start("kari@example.com", "203.0.113.2"));
    await h.handler(start("kari@example.com", "203.0.113.3"));

    assert.equal(h.mailer.outbox.length, 1, "one address, one mail, three requests");
    assert.equal(h.mailer.outbox[0].to, "kari@example.com");
});

test("under AUTH_MODE=mock the limit does not apply", async () => {
    // A developer's own machine, and mock cannot load in production
    // (ADR-0073's CONTEXT guard). Three sign-ins an hour is the right bound for
    // a stranger and the wrong one for someone testing the flow.
    const blobs = fakeStore();
    const mailer = createMockAdapter();
    const handler = createHandler({
        env: { AUTH_MODE: "mock", PUBLIC_APP_ORIGIN: "https://ringdrill.app" },
        challengeStore: () => fakeStore(),
        mailer,
        startEmailLimiter: createStartEmailLimiter({ blobs: () => blobs, recipientLimit: 1, sourceLimit: 1 }),
    });

    for (let i = 0; i < 4; i++) await handler(start("kari@example.com", "203.0.113.1"));
    assert.equal(mailer.outbox.length, 4);
});
