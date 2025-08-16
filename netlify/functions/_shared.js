import crypto from "node:crypto";
import { getStore } from "@netlify/blobs";

export const NS = { DRILLS: "drills", SLUG_INDEX: "slug-index" };
export const MIME_DRILL = "application/vnd.ringdrill+json";
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

export function sanitizeSlug(s) {
    return (s || "").toLowerCase().trim()
        .replace(/\s+/g, "-")
        .replace(/[^a-z0-9\-]/g, "-")
        .replace(/\-+/g, "-")
        .replace(/^\-|\-$/g, "");
}
export function nowIso() { return new Date().toISOString(); }
export function originFromRequest(request) { return new URL(request.url).origin; }

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
