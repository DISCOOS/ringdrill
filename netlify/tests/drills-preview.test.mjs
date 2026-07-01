/**
 * Tests for drills-preview.js — HTML rendering, locale picking, 404 paths.
 *
 * We import createHandler, pickLocale and renderHtml directly from the
 * function module. The handler is instantiated with injected fake store
 * functions so @netlify/blobs is never actually called; the import is safe
 * because _shared.js only calls getStore() lazily (inside getDrillsStore /
 * getSlugRecord), never at module load time.
 */
import { test } from "node:test";
import assert from "node:assert/strict";
import { createHandler, pickLocale, renderHtml } from "../functions/drills-preview.js";

// ---------- Fake store fixtures ----------

const SLUG_RECORDS = {
    "test-7x": { ownerId: "anon", programId: "prog-abc" },
    "test-unpub": { ownerId: "anon", programId: "prog-unpub" },
};

const META_STORE = {
    "drills/anon/prog-abc/meta.json": {
        slug: "test-7x",
        name: "Testøvelse",
        published: true,
        tags: ["team", "intro"],
        versions: [],
    },
    "drills/anon/prog-unpub/meta.json": {
        slug: "test-unpub",
        name: "Upublisert",
        published: false,
        tags: [],
        versions: [],
    },
};

function makeHandler(slugRecords = SLUG_RECORDS, metaStore = META_STORE) {
    return createHandler({
        getSlugRecord: async (slug) => slugRecords[slug] ?? null,
        readJson: async (key, fallback = null) => metaStore[key] ?? fallback,
    });
}

function req(path, { method = "GET", headers = {} } = {}) {
    return new Request(`http://api.ringdrill.app${path}`, { method, headers });
}

// ---------- pickLocale ----------

test("pickLocale: ?lang=en returns en", () => {
    assert.equal(pickLocale(req("/?lang=en")), "en");
});

test("pickLocale: ?lang=nb returns nb", () => {
    assert.equal(pickLocale(req("/?lang=nb")), "nb");
});

test("pickLocale: ?lang takes precedence over Accept-Language", () => {
    assert.equal(pickLocale(req("/?lang=nb", { headers: { "accept-language": "en-US" } })), "nb");
});

test("pickLocale: Accept-Language en returns en", () => {
    assert.equal(pickLocale(req("/", { headers: { "accept-language": "en" } })), "en");
});

test("pickLocale: Accept-Language en-US returns en", () => {
    assert.equal(pickLocale(req("/", { headers: { "accept-language": "en-US,en;q=0.9" } })), "en");
});

test("pickLocale: Accept-Language nb-NO returns nb", () => {
    assert.equal(pickLocale(req("/", { headers: { "accept-language": "nb-NO,nb;q=0.9" } })), "nb");
});

test("pickLocale: first supported locale wins (nb-NO before en)", () => {
    assert.equal(pickLocale(req("/", { headers: { "accept-language": "nb-NO,en;q=0.5" } })), "nb");
});

test("pickLocale: first supported locale wins (en-GB before nb)", () => {
    assert.equal(pickLocale(req("/", { headers: { "accept-language": "en-GB,en;q=0.9,nb;q=0.8" } })), "en");
});

test("pickLocale: default is nb when no header or param", () => {
    assert.equal(pickLocale(req("/")), "nb");
});

test("pickLocale: unknown locale falls through to nb default", () => {
    assert.equal(pickLocale(req("/", { headers: { "accept-language": "zh-CN,zh;q=0.9" } })), "nb");
});

// ---------- renderHtml pure function ----------

const SAMPLE_META = { name: "Sprint", published: true, tags: ["pace", "agility"] };

test("renderHtml nb: contains h1 with name", () => {
    const html = renderHtml({ slug: "sprint-1", meta: SAMPLE_META, locale: "nb" });
    assert.ok(html.includes("<h1>Sprint</h1>"));
});

test("renderHtml nb: contains Norwegian button labels", () => {
    const html = renderHtml({ slug: "sprint-1", meta: SAMPLE_META, locale: "nb" });
    assert.ok(html.includes("Åpne planen"), "nb openOnWeb");
    assert.ok(html.includes("Last ned .drill"), "nb download");
    assert.ok(!html.includes("Åpne i app"), "no self-referential app CTA");
});

test("renderHtml en: contains English button labels", () => {
    const html = renderHtml({ slug: "sprint-1", meta: SAMPLE_META, locale: "en" });
    assert.ok(html.includes("Open the plan"), "en openOnWeb");
    assert.ok(html.includes("Download .drill"), "en download");
    assert.ok(!html.includes("Open in app"), "no self-referential app CTA");
});

test("renderHtml: og:url points at ringdrill.app/i/<slug>", () => {
    const html = renderHtml({ slug: "sprint-1", meta: SAMPLE_META, locale: "nb" });
    assert.ok(html.includes('content="https://ringdrill.app/i/sprint-1"'));
    assert.ok(!html.includes("api.ringdrill.app"), "no api subdomain in og:url");
});

test("renderHtml: canonical points at ringdrill.app/i/<slug>", () => {
    const html = renderHtml({ slug: "sprint-1", meta: SAMPLE_META, locale: "nb" });
    assert.ok(html.includes('rel="canonical"'));
    assert.ok(html.includes("https://ringdrill.app/i/sprint-1"));
});

test("renderHtml: hreflang alternate links present", () => {
    const html = renderHtml({ slug: "sprint-1", meta: SAMPLE_META, locale: "nb" });
    assert.ok(html.includes('hreflang="nb"'), "nb alternate");
    assert.ok(html.includes('hreflang="en"'), "en alternate");
    assert.ok(html.includes('hreflang="x-default"'), "x-default alternate");
});

test("renderHtml nb: og:locale is nb_NO", () => {
    const html = renderHtml({ slug: "sprint-1", meta: SAMPLE_META, locale: "nb" });
    assert.ok(html.includes('content="nb_NO"'));
});

test("renderHtml en: og:locale is en_US", () => {
    const html = renderHtml({ slug: "sprint-1", meta: SAMPLE_META, locale: "en" });
    assert.ok(html.includes('content="en_US"'));
});

test("renderHtml: html[lang] matches locale nb", () => {
    const html = renderHtml({ slug: "sprint-1", meta: SAMPLE_META, locale: "nb" });
    assert.ok(html.includes('<html lang="nb">'));
});

test("renderHtml: html[lang] matches locale en", () => {
    const html = renderHtml({ slug: "sprint-1", meta: SAMPLE_META, locale: "en" });
    assert.ok(html.includes('<html lang="en">'));
});

test("renderHtml: 'open on web' button links to web.ringdrill.app/i/<slug>", () => {
    const html = renderHtml({ slug: "sprint-1", meta: SAMPLE_META, locale: "nb" });
    assert.ok(html.includes("https://web.ringdrill.app/i/sprint-1"));
});

test("renderHtml: download link points at ringdrill.app/d/<slug>", () => {
    const html = renderHtml({ slug: "sprint-1", meta: SAMPLE_META, locale: "nb" });
    assert.ok(html.includes("https://ringdrill.app/d/sprint-1"));
});

test("renderHtml: exerciseCount shown when present", () => {
    const meta = { ...SAMPLE_META, exerciseCount: 5 };
    const html = renderHtml({ slug: "sprint-1", meta, locale: "nb" });
    assert.ok(html.includes("5 øvelser"));
});

test("renderHtml: exerciseCount absent when null", () => {
    const html = renderHtml({ slug: "sprint-1", meta: SAMPLE_META, locale: "nb" });
    assert.ok(!html.includes("øvelse"));
});

test("renderHtml: tags rendered in body", () => {
    const html = renderHtml({ slug: "sprint-1", meta: SAMPLE_META, locale: "nb" });
    assert.ok(html.includes("pace"));
    assert.ok(html.includes("agility"));
});

test("renderHtml: HTML-escapes name containing angle brackets", () => {
    const meta = { name: "<script>alert(1)</script>", published: true, tags: [] };
    const html = renderHtml({ slug: "x", meta, locale: "nb" });
    assert.ok(!html.includes("<script>"));
    assert.ok(html.includes("&lt;script&gt;"));
});

// ---------- Handler: 404 paths ----------

test("unknown slug → 404 with HTML body", async () => {
    const handler = makeHandler();
    const res = await handler(req("/.netlify/functions/drills-preview?slug=does-not-exist"));
    assert.equal(res.status, 404);
    assert.ok(res.headers.get("content-type")?.includes("text/html"));
    const body = await res.text();
    assert.ok(body.startsWith("<!DOCTYPE html"));
});

test("unpublished slug (meta.published: false) → 404", async () => {
    const handler = makeHandler();
    const res = await handler(req("/.netlify/functions/drills-preview?slug=test-unpub"));
    assert.equal(res.status, 404);
    const body = await res.text();
    assert.ok(body.startsWith("<!DOCTYPE html"));
});

// ---------- Handler: 200 paths ----------

test("published slug (default locale) → 200 nb", async () => {
    const handler = makeHandler();
    const res = await handler(req("/.netlify/functions/drills-preview?slug=test-7x"));
    assert.equal(res.status, 200);
    assert.ok(res.headers.get("content-type")?.includes("text/html"));
    const body = await res.text();
    assert.ok(body.includes('<html lang="nb">'), "html lang=nb");
    assert.equal(res.headers.get("content-language"), "nb");
    assert.ok(body.includes("Åpne planen"), "Norwegian open-plan label");
});

test("published slug with ?lang=en → 200 en", async () => {
    const handler = makeHandler();
    const res = await handler(req("/.netlify/functions/drills-preview?slug=test-7x&lang=en"));
    assert.equal(res.status, 200);
    const body = await res.text();
    assert.ok(body.includes('<html lang="en">'), "html lang=en");
    assert.equal(res.headers.get("content-language"), "en");
    assert.ok(body.includes("Open the plan"), "English open-plan label");
});

test("Accept-Language: en-GB,en;q=0.9 → English variant", async () => {
    const handler = makeHandler();
    const res = await handler(req("/.netlify/functions/drills-preview?slug=test-7x", {
        headers: { "accept-language": "en-GB,en;q=0.9" },
    }));
    const body = await res.text();
    assert.ok(body.includes('<html lang="en">'));
    assert.ok(body.includes("Open the plan"));
});

test("Accept-Language: nb-NO,en;q=0.5 → Norwegian variant (first supported wins)", async () => {
    const handler = makeHandler();
    const res = await handler(req("/.netlify/functions/drills-preview?slug=test-7x", {
        headers: { "accept-language": "nb-NO,en;q=0.5" },
    }));
    const body = await res.text();
    assert.ok(body.includes('<html lang="nb">'));
    assert.ok(body.includes("Åpne planen"));
});

// ---------- Handler: OG meta, canonical, hreflang ----------

test("200 response contains all required OG meta tags", async () => {
    const handler = makeHandler();
    const res = await handler(req("/.netlify/functions/drills-preview?slug=test-7x"));
    const body = await res.text();
    assert.ok(body.includes('property="og:title"'), "og:title");
    assert.ok(body.includes('property="og:description"'), "og:description");
    assert.ok(body.includes('property="og:url"'), "og:url");
    assert.ok(body.includes('property="og:type"'), "og:type");
    assert.ok(body.includes('property="og:locale"'), "og:locale");
});

test("og:locale is nb_NO for nb response", async () => {
    const handler = makeHandler();
    const res = await handler(req("/.netlify/functions/drills-preview?slug=test-7x"));
    const body = await res.text();
    assert.ok(body.includes("nb_NO"));
});

test("og:locale is en_US for en response", async () => {
    const handler = makeHandler();
    const res = await handler(req("/.netlify/functions/drills-preview?slug=test-7x&lang=en"));
    const body = await res.text();
    assert.ok(body.includes("en_US"));
});

test("canonical points at ringdrill.app/i/<slug>, not api subdomain", async () => {
    const handler = makeHandler();
    const res = await handler(req("/.netlify/functions/drills-preview?slug=test-7x"));
    const body = await res.text();
    assert.ok(body.includes('rel="canonical"'));
    assert.ok(body.includes("https://ringdrill.app/i/test-7x"), "canonical at apex");
    assert.ok(!body.match(/api\.ringdrill\.app\/i\//), "no api subdomain in canonical");
});

test("response contains hreflang nb, en and x-default alternate links", async () => {
    const handler = makeHandler();
    const res = await handler(req("/.netlify/functions/drills-preview?slug=test-7x"));
    const body = await res.text();
    assert.ok(body.includes('hreflang="nb"'));
    assert.ok(body.includes('hreflang="en"'));
    assert.ok(body.includes('hreflang="x-default"'));
});

// ---------- Handler: response headers ----------

test("200 response has Vary: Accept-Language", async () => {
    const handler = makeHandler();
    const res = await handler(req("/.netlify/functions/drills-preview?slug=test-7x"));
    assert.ok(res.headers.get("vary")?.toLowerCase().includes("accept-language"));
});

test("404 response also has Vary: Accept-Language", async () => {
    const handler = makeHandler();
    const res = await handler(req("/.netlify/functions/drills-preview?slug=does-not-exist"));
    assert.ok(res.headers.get("vary")?.toLowerCase().includes("accept-language"));
});

test("200 response has Cache-Control with s-maxage=600", async () => {
    const handler = makeHandler();
    const res = await handler(req("/.netlify/functions/drills-preview?slug=test-7x"));
    const cc = res.headers.get("cache-control") ?? "";
    assert.ok(cc.includes("s-maxage=600"), `cache-control was: ${cc}`);
});

// ---------- Handler: CORS preflight ----------

test("OPTIONS from allowed origin → 204", async () => {
    const handler = makeHandler();
    const res = await handler(req("/.netlify/functions/drills-preview?slug=test-7x", {
        method: "OPTIONS",
        headers: { "origin": "http://localhost:3000" },
    }));
    assert.equal(res.status, 204);
});
