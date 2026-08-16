import crypto from "node:crypto";
import { getStore } from "@netlify/blobs";
import * as Sentry from "@sentry/node";

export const NS = { DRILLS: "drills", SLUG_INDEX: "slug-index" };
export const MIME_DRILL = "application/vnd.ringdrill+zip";
export const DRILL_EXT = ".drill";

// DO NOT memoize the return value of getStore() across invocations (no
// `let x; x ||= getStore(...)` here) — that pattern shipped in the very
// first getStore()-based version of this file (2025-08-15) and stayed
// broken for ~11 months before being diagnosed. It looks like ordinary,
// harmless lazy-init memoization, which is exactly why it's easy to
// reintroduce during a future refactor. It is NOT harmless for this
// specific dependency:
//
// @netlify/blobs's Store bakes its access token in at construction time
// (InternalClientOptions/Store in node_modules/@netlify/blobs/dist/main.d.ts),
// read from a per-invocation environment context that Netlify's runtime
// refreshes on every request (connectLambda -> setEnvironmentContext in the
// same package). Caching the Store instance means a warm function container
// keeps reusing whichever token was current on its *first* invocation —
// once that token expires, every request through that same warm container
// fails with "Netlify Blobs has generated an internal error (Failed to
// decode token: Token expired)" until the container is recycled, while a
// different (or freshly cold-started) container keeps working. That's what
// makes the failure look intermittent/random rather than a plain bug.
//
// getStore() itself is a cheap, synchronous client construction with no
// network I/O — there is no performance reason to cache it. Full writeup:
// docs/notes/netlify-blobs-store-caching-token-expiry.md
//
// `_getStore` on all four accessors is a test seam, not a feature. Asserting which
// consistency each one asks for is the only guard against the strong flag being
// dropped in a refactor, or added to the cached read paths by mistake.
export function getDrillsStore(_getStore = getStore) { return _getStore(NS.DRILLS); }
export function getSlugIndexStore(_getStore = getStore) { return _getStore(NS.SLUG_INDEX); }

// ---------------------------------------------------------------------------
// Strong reads, for the paths where a read decides a write
// ---------------------------------------------------------------------------
//
// **Netlify Blobs reads are eventually consistent by default.** A write lands and a
// read moments later can still return the previous value, or nothing at all. That is
// fine for serving the catalog and fatal for anything that reads a value in order to
// decide what to write.
//
// It cost two outages to learn, in the MCP rate limiter, where a counter would not
// accumulate and two separate ETag compare-and-swaps "failed" — the ETags were simply
// stale reads. Three diagnoses, none of which named the default. Full writeup in
// netlify/functions/lib/mcp-rate-limit.js and ADR-0060.
//
// Not the default here, because it is not free: a strong read gives up the edge cache,
// and the read-heavy public paths (market feed, /d/<slug>, drills-head, the MCP
// catalog tools) are exactly what that cache is for. Those paths only display what
// they read, so a value a moment out of date is harmless.
//
// The rule, then: **if what you read determines what you write, read it strong.**
// `getBlobEtag` is unconditionally strong because feeding a conditional write is its
// only purpose. For values, use `readJsonStrong` / `getSlugRecordStrong`.
const STRONG_READ = { consistency: "strong" };

// `_getStore` is injectable for the tests only. Asserting these accessors ask for
// strong consistency is the one guard against the flag being quietly dropped in a
// refactor — and a dropped flag is invisible until production undercounts or a
// conditional write starts failing for no reason.
export function getDrillsStoreStrong(_getStore = getStore) {
    return _getStore(NS.DRILLS, STRONG_READ);
}
export function getSlugIndexStoreStrong(_getStore = getStore) {
    return _getStore(NS.SLUG_INDEX, STRONG_READ);
}

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

/// `readBinary` for bytes that are about to be written somewhere else.
///
/// The case is `deleteversion` promoting an archive to the `latest` pointer: it reads a
/// versioned blob and writes those bytes back under another key. Versioned blobs are
/// immutable once written (`onlyIfNew`), so the risk is not a stale value but a missing
/// one — an eventually consistent read of a recently uploaded version answers null, and
/// the caller reports "New latest bytes not found" for an archive that is right there.
export async function readBinaryStrong(key) {
    const s = getDrillsStoreStrong();
    const ab = await s.get(key, { type: "arrayBuffer" });
    return ab ? Buffer.from(ab) : null;
}

/// `readJson` for a value that is about to decide a write.
///
/// Same result, read strongly — so the value reflects every completed write rather
/// than whatever the edge cache last saw. Use this and not `readJson` whenever the
/// object read is mutated and written back, or a lost update is silent: two callers
/// each read a version of `meta` without the other's change, and the later write
/// erases it.
export async function readJsonStrong(key, fallback = null) {
    const s = getDrillsStoreStrong();
    const obj = await s.get(key, { type: "json" });
    return obj ?? fallback;
}

/* ---------- Concurrency helpers ---------- */
// Netlify Docs notes: store.set(key, value, { onlyIfMatch, onlyIfNew }) supports atomic
// conditional writes and returns { modified, etag }. Use store.getMetadata(key) to read
// a blob’s ETag without fetching the value.

/// Return the current ETag for a blob key, or null if missing.
///
/// Strong, always. An ETag exists here for exactly one reason — to be handed to
/// `onlyIfMatch` — so an eventually consistent one is never the right answer. A stale
/// ETag makes a conditional write fail with nothing having changed, and the caller
/// then reports a precondition failure that did not happen.
///
/// Read the ETag *before* the value it guards, never after. If a write lands between
/// the two reads, that order leaves the value newer than the ETag, so the conditional
/// write fails and the caller retries — safe. The reverse lets a stale value pass a
/// fresh ETag, and the write silently erases whatever landed in between.
export async function getBlobEtag(key) {
    const s = getDrillsStoreStrong();
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

// `getSlugRecord` / `getSlugRecordStrong` lived here and read the index by bare
// slug. Both went with the ADR-0074 migration on 2026-08-12: an entry is
// identified by `(namespace, slug)` now, so a lookup that takes a slug alone
// cannot name one. `findEntry` in lib/catalog.js is the replacement, and it
// takes both. The strong-read reasoning the second one carried has not been
// lost — it moved to `findEntry`'s `strong` option, and lib/identity.js opens
// with the general version of the same warning.

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

/* ---------- Deprecation telemetry (ADR-0055) ---------- */
// Tracks callers still sending the legacy `programId` param/field instead of
// `planId` (Program -> Plan rename), so we know when it's safe to drop
// `programId` support entirely. No-op without SENTRY_DSN configured — this
// must never make the API depend on Sentry being reachable.

let sentryInitialized = false;
function ensureSentryInit() {
    if (sentryInitialized) return;
    sentryInitialized = true;
    const dsn = process.env.SENTRY_DSN;
    if (!dsn) return;
    Sentry.init({ dsn, tracesSampleRate: 0 });
}

// Call once per request that used the deprecated `programId` name instead of
// `planId`. Awaited so the event is actually flushed before the serverless
// function returns (this only runs for legacy callers, so the extra latency
// never touches an already-migrated client). Never throws.
export async function reportLegacyProgramIdUsage(context) {
    if (!process.env.SENTRY_DSN) return;
    try {
        ensureSentryInit();
        Sentry.captureMessage("legacy programId param used", {
            level: "info",
            tags: { legacy_program_id: "true" },
            extra: context,
        });
        await Sentry.flush(2000);
    } catch {
        // Telemetry must never break the request it's reporting on.
    }
}

/* ---------- Outgoing links ---------- */

/**
 * The origin every emailed link is built from.
 *
 * **Required, with no fallback, and that is the point.** Both links RingDrill
 * sends — the sign-in link and the invitation — are absolute URLs into the app,
 * and both used to fall back to a hardcoded `https://ringdrill.app` when this
 * was unset. That fallback defeats the only reason the variable exists: the day
 * the apex moves, the setting changes and two files keep cheerfully mailing the
 * old host, with nothing failing and nobody told. The links would resolve to
 * somebody else's domain, or to nothing, and the first report would come from a
 * user who could not sign in.
 *
 * So an unset value is an error at the point of use rather than a default. It
 * takes out sending, which is loud, instead of taking out the *destination*,
 * which is silent.
 *
 * Trailing slashes are trimmed, because `https://ringdrill.app/` and the path
 * that follows would otherwise meet as `//s/…`.
 */
export function appOrigin(env = process.env) {
    const origin = String(env.PUBLIC_APP_ORIGIN ?? "").trim().replace(/\/+$/, "");
    if (!origin) {
        throw new Error(
            "PUBLIC_APP_ORIGIN is unset. Every link RingDrill emails is built from it — "
            + "the sign-in link and the invitation both. Refusing to guess: a hardcoded "
            + "default would keep mailing the old host after the apex moves, which is the "
            + "failure this variable exists to prevent. Set it on the API site.",
        );
    }
    return origin;
}

/**
 * Where the PWA is served, for handing an emailed link to it (ADR-0080).
 *
 * Separate from [appOrigin] because they are different hosts and only one of
 * them is where links *point*: the apex owns the association files and so must
 * be what the mail contains, while the browser fallback has to send the visitor
 * somewhere that can actually run the app. Collapsing them into one variable
 * would work today and break the moment either moves.
 *
 * Required, with no fallback, for the reason appOrigin gives at length.
 */
export function pwaOrigin(env = process.env) {
    const origin = String(env.PUBLIC_PWA_ORIGIN ?? "").trim().replace(/\/+$/, "");
    if (!origin) {
        throw new Error(
            "PUBLIC_PWA_ORIGIN is unset. The browser fallback for an emailed link "
            + "redirects there, and guessing it would send somebody's single-use "
            + "sign-in credential to whatever host was hardcoded. Set it on the API site.",
        );
    }
    return origin;
}

/* ---------- Keys & misc ---------- */

// `keysFor` built the owner-scoped `drills/<ownerId>/<planId>/` keys. That
// layout was deleted by the ADR-0074 migration; `keysForEntry` in
// lib/catalog.js is the only way to name a catalog blob.

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
// public for anon plans else account, per ADR-0025; missing/malformed
// mapCenter → null, per ADR-0040's map-center addendum; missing/malformed
// mapBounds/place → null, per ADR-0040's bounding-box addendum;
// missing/malformed languageCode → null, per ADR-0007's languageCode
// addendum).
//
// `accessPolicy` is enforced as of the account release: drills-upload applies
// ADR-0025's matrix before OCC, and `ownerId` is taken from the verified
// principal rather than a query parameter. The value here is therefore a real
// property of the plan, not a label.
export function metaToFeedItem(meta, { origin, namespace = null }) {
    const latest = latestVersionEntry(meta.versions);
    return {
        // planId is the Plan-rename name; programId stays too until every
        // real client has moved off it (ADR-0055 — track via
        // reportLegacyProgramIdUsage's Sentry telemetry, then drop).
        planId: meta.programId,
        programId: meta.programId,
        slug: meta.slug,
        name: meta.name,
        description: typeof meta.description === "string" ? meta.description : "",
        exerciseCount: Number.isInteger(meta.exerciseCount) ? meta.exerciseCount : null,
        author: meta.author ?? meta.ownerId ?? null,
        accessPolicy: meta.accessPolicy ?? (meta.ownerId === "anon" ? "public" : "account"),
        mapCenter: (meta.mapCenter && Number.isFinite(meta.mapCenter.lat) && Number.isFinite(meta.mapCenter.lng))
            ? { lat: meta.mapCenter.lat, lng: meta.mapCenter.lng }
            : null,
        mapBounds: (meta.mapBounds
            && Number.isFinite(meta.mapBounds.north) && Number.isFinite(meta.mapBounds.south)
            && Number.isFinite(meta.mapBounds.east) && Number.isFinite(meta.mapBounds.west))
            ? {
                north: meta.mapBounds.north, south: meta.mapBounds.south,
                east: meta.mapBounds.east, west: meta.mapBounds.west,
            }
            : null,
        place: (typeof meta.place === "string" && meta.place) ? meta.place : null,
        languageCode: typeof meta.languageCode === "string" ? meta.languageCode : null,
        tags: Array.isArray(meta.tags) ? meta.tags : [],
        // The namespace an entry lives in (ADR-0074 §2). `anon` is omitted from
        // the path, so every link published before namespaces existed keeps
        // exactly the shape it had.
        namespace: namespace && namespace !== "anon" ? namespace : null,
        latestUrl: `${origin}/d/${namespace && namespace !== "anon" ? `${namespace}/` : ""}${meta.slug}`,
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
        "access-control-expose-headers": "etag, content-type, content-disposition, last-modified, cache-control, x-conflict-kind, x-version, x-latest, x-versioned, x-program-id, x-plan-id",
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
