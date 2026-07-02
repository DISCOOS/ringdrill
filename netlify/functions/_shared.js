import crypto from "node:crypto";
import { getStore } from "@netlify/blobs";

export const NS = { DRILLS: "drills", SLUG_INDEX: "slug-index" };
export const MIME_DRILL = "application/vnd.ringdrill+zip";
export const DRILL_EXT = ".drill";

let _drillsStore, _slugIndexStore;
export function getDrillsStore() { _drillsStore ||= getStore(NS.DRILLS); return _drillsStore; }
export function getSlugIndexStore() { _slugIndexStore ||= getStore(NS.SLUG_INDEX); return _slugIndexStore; }

/* ---------- Read/Write helpers ---------- */

export async function readBinary(key) {
    const s = getDrillsStore();
    const ab = await s.get(key, { type: "arrayBuffer" });
    return ab ? Buffer.from(ab) : null;
}
export async function readJson(key, fallback = null) {
    const s = getDrillsStore();
    const obj = await s.get(key, { type: "json" });
    return obj ?? fallback;
}

/* ---------- Concurrency helpers ---------- */
// Netlify Docs notes: store.set(key, value, { onlyIfMatch, onlyIfNew }) supports atomic
// conditional writes and returns { modified, etag }. Use store.getMetadata(key) to read
// a blob’s ETag without fetching the value.

// Return the current ETag for a blob key, or null if missing.
export async function getBlobEtag(key) {
    const s = getDrillsStore();
    const meta = await s.getMetadata(key); // returns { etag, metadata? } when present
    return meta?.etag ?? null;
}

// Conditional JSON write (optimistic concurrency)
export async function writeJsonConditional(key, obj, opts = {}) {
    const s = getDrillsStore();
    const cond = {};
    if (opts.onlyIfMatch != null) cond.onlyIfMatch = opts.onlyIfMatch;
    else if (opts.onlyIfNew === true) cond.onlyIfNew = true;
    const { modified, etag } = await s.set(key, JSON.stringify(obj), cond);
    return { modified, etag };
}
// Conditional binary write
export async function writeBinaryConditional(key, bytes, opts = {}) {
    const s = getDrillsStore();
    const cond = {};
    if (opts.onlyIfMatch != null) cond.onlyIfMatch = opts.onlyIfMatch;
    else if (opts.onlyIfNew === true) cond.onlyIfNew = true;
    const { modified, etag } = await s.set(key, bytes, cond);
    return { modified, etag };
}

/* ---------- Slug index helpers ---------- */

export async function getSlugRecord(slug) {
    const s = getSlugIndexStore();
    const rec = await s.get(slug, { type: "json" });
    return rec ?? null;
}

export async function claimSlug(slug, record) {
    // Create only if missing (atomic)
    const s = getSlugIndexStore();
    const { modified } = await s.set(slug, JSON.stringify(record), { onlyIfNew: true });
    return modified; // true = claimed, false = already existed
}

// Delete a slug from the slug-index store
export async function deleteSlugRecord(slug) {
    const s = getSlugIndexStore();
    await s.delete(slug);
}

/* ---------- Keys & misc ---------- */

export function keysFor({ ownerId, programId, version }) {
    return {
        versioned: `drills/${ownerId}/${programId}/${version}${DRILL_EXT}`,
        latest:    `drills/${ownerId}/${programId}/latest${DRILL_EXT}`,
        meta:      `drills/${ownerId}/${programId}/meta.json`,
    };
}

export function sha256Hex(buf) { return crypto.createHash("sha256").update(buf).digest("hex"); }
export function toStrongEtag(hex) { return `"${hex}"`; }

/* ---------- Catalog projection (ADR-0040) ---------- */

// The latest (highest-versioned) entry in a meta.json `versions` array, or
// null when there are none. Shared so the feed and metaToFeedItem agree on
// what "latest" means.
export function latestVersionEntry(versions) {
    if (!Array.isArray(versions) || versions.length === 0) return null;
    return versions.slice().sort((a, b) => a.v.localeCompare(b.v, undefined, { numeric: true })).pop();
}

// Project a stored meta.json blob into the public catalog item shape.
// Single source of truth for the feed / per-slug meta contract (ADR-0040).
// All derived fields degrade gracefully for legacy blobs written before
// ADR-0040 (missing exerciseCount → null, author → ownerId, accessPolicy →
// public for anon plans else account, per ADR-0025).
export function metaToFeedItem(meta, { origin }) {
    const latest = latestVersionEntry(meta.versions);
    return {
        programId: meta.programId,
        slug: meta.slug,
        name: meta.name,
        description: typeof meta.description === "string" ? meta.description : "",
        exerciseCount: Number.isInteger(meta.exerciseCount) ? meta.exerciseCount : null,
        author: meta.author ?? meta.ownerId ?? null,
        accessPolicy: meta.accessPolicy ?? (meta.ownerId === "anon" ? "public" : "account"),
        tags: Array.isArray(meta.tags) ? meta.tags : [],
        latestUrl: `${origin}/d/${meta.slug}`,
        updatedAt: latest?.updatedAt || null,
    };
}

export function sanitizeSlug(s) {
    return (s || "").toLowerCase().trim()
        .replace(/\s+/g, "-")
        .replace(/[^a-z0-9\-]/g, "-")
        .replace(/\-+/g, "-")
        .replace(/^\-|\-$/g, "");
}
export function nowIso() { return new Date().toISOString(); }
export function originFromRequest(request) { return new URL(request.url).origin; }

/* ---------- CORS ---------- */
// Production serves the PWA same-origin as the functions, so CORS headers
// are not strictly required for the production deploy. They are added here
// to enable the local dev workflow where the Flutter dev server runs on a
// different port than `netlify functions:serve` (see ADR-0013), and to
// allow Netlify deploy previews. We use an explicit allowlist of origins
// rather than `*`, so browsers cannot read responses from foreign sites.
// Non-browser clients (the CLI, native mobile apps, curl) do not send an
// Origin header and are unaffected.

const ALLOWED_ORIGIN_PATTERNS = [
    /^https:\/\/ringdrill\.netlify\.app$/,
    /^https:\/\/ringdrill\.app$/,
    /^https:\/\/web\.ringdrill\.app$/,
    /^https:\/\/[^/]+--ringdrill\.netlify\.app$/, // deploy previews / branch deploys
    /^http:\/\/localhost(:\d+)?$/,
    /^http:\/\/127\.0\.0\.1(:\d+)?$/,
];

function allowedOrigin(origin) {
    if (!origin) return null;
    return ALLOWED_ORIGIN_PATTERNS.some(rx => rx.test(origin)) ? origin : null;
}

function corsHeadersFor(request) {
    const origin = allowedOrigin(request.headers.get("origin"));
    if (!origin) return null;
    return {
        "access-control-allow-origin": origin,
        "access-control-allow-methods": "GET, POST, HEAD, OPTIONS",
        "access-control-allow-headers": "authorization, content-type, if-match, if-none-match, accept",
        "access-control-expose-headers": "etag, content-type, content-disposition, last-modified, cache-control, x-conflict-kind, x-version, x-latest, x-versioned, x-program-id",
        "access-control-max-age": "600",
        "vary": "Origin",
    };
}

// Return a 204 preflight response when the incoming request is OPTIONS.
// Otherwise return null so the handler can continue with its normal flow.
// Preflight from a non-allowlisted origin returns 204 with no CORS headers,
// which the browser then treats as a CORS failure.
export function corsPreflight(request) {
    if (request.method !== "OPTIONS") return null;
    const headers = corsHeadersFor(request) ?? {};
    return new Response(null, { status: 204, headers });
}

// Wrap a Response so CORS headers are present when the request's Origin is
// in the allowlist. When the origin is missing (non-browser client) or not
// allowlisted, the response is returned unchanged.
export function withCors(request, response) {
    const cors = corsHeadersFor(request);
    if (!cors) return response;
    const headers = new Headers(response.headers);
    for (const [k, v] of Object.entries(cors)) {
        headers.set(k, v);
    }
    return new Response(response.body, {
        status: response.status,
        statusText: response.statusText,
        headers,
    });
}

// Accept base64 or raw binary for v2
export async function readDrillBytes(request) {
    const cloned = request.clone();
    const raw = new Uint8Array(await request.arrayBuffer());
    if (raw.some(b => b > 127)) return Buffer.from(raw);
    const text = await cloned.text();
    const s = text.trim();
    const looksB64 = /^[A-Za-z0-9+/=\r\n]+$/.test(s) && s.length % 4 === 0;
    if (!looksB64) return Buffer.from(raw);
    try { return Buffer.from(s, "base64"); } catch { return Buffer.from(raw); }
}
