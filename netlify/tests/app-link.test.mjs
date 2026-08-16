/**
 * The browser fallback for emailed links (ADR-0080).
 *
 * The assertion that matters most is a negative one: this endpoint **redeems
 * nothing**. It is reached by mail scanners as well as people, and a challenge
 * is single-use — acting on a `GET` would spend somebody's sign-in before they
 * ever saw it, and report to them as "this link has already been used".
 */
import { test } from "node:test";
import assert from "node:assert/strict";

import { createHandler, parseLinkPath } from "../functions/app-link.js";

const ENV = {
    PUBLIC_APP_ORIGIN: "https://ringdrill.app",
    PUBLIC_PWA_ORIGIN: "https://web.ringdrill.app",
};

const get = (path) => new Request(`https://ringdrill.app${path}`);

test("a sign-in link is handed to the PWA unchanged", async () => {
    const res = await createHandler({ env: ENV })(get("/s/c_abc/9FAQLX"));
    assert.equal(res.status, 302);
    assert.equal(res.headers.get("location"), "https://web.ringdrill.app/s/c_abc/9FAQLX");
});

test("an invitation link is handed over the same way", async () => {
    const res = await createHandler({ env: ENV })(get("/j/inv_xyz"));
    assert.equal(res.status, 302);
    assert.equal(res.headers.get("location"), "https://web.ringdrill.app/j/inv_xyz");
});

test("the redirect is never cached", async () => {
    // The URL contains a single-use credential. A cached redirect is a copy of
    // it sitting in somebody's proxy.
    const res = await createHandler({ env: ENV })(get("/s/c_abc/9FAQLX"));
    assert.equal(res.headers.get("cache-control"), "no-store");
});

test("the function path Netlify always serves is understood too", async () => {
    // `/.netlify/functions/<name>/…` is served whether or not a redirect names
    // it, so it has to parse the same way or the fallback has a hole.
    const res = await createHandler({ env: ENV })(
        new Request("https://api.ringdrill.app/.netlify/functions/app-link/s/c_abc/9FAQLX"),
    );
    assert.equal(res.headers.get("location"), "https://web.ringdrill.app/s/c_abc/9FAQLX");
});

test("a malformed link is 404, not a redirect to somewhere odd", async () => {
    const h = createHandler({ env: ENV });
    for (const path of ["/s/only-one-segment", "/s/a/b/c", "/j/", "/x/abc", "/"]) {
        assert.equal((await h(get(path))).status, 404, path);
    }
});

test("a missing origin fails loudly rather than guessing a host", async () => {
    // Guessing would send a single-use sign-in credential to whatever host was
    // hardcoded — which is the failure the required-origin rule exists for.
    const h = createHandler({ env: { PUBLIC_APP_ORIGIN: "https://ringdrill.app" } });
    await assert.rejects(() => h(get("/s/c_abc/9FAQLX")), /PUBLIC_PWA_ORIGIN is unset/);
});

test("parseLinkPath keeps the two shapes apart", () => {
    assert.deepEqual(parseLinkPath("/s/c_1/ABC123"), { kind: "s", path: "/s/c_1/ABC123" });
    assert.deepEqual(parseLinkPath("/j/tok"), { kind: "j", path: "/j/tok" });
    assert.equal(parseLinkPath("/i/some-slug"), null, "the install link is not ours");
});
