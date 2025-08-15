import crypto from "node:crypto";
import { getStore } from "@netlify/blobs";

export const NS = {
    DRILLS: "drills",
    SLUG_INDEX: "slug-index",
};

export const MIME_DRILL = "application/vnd.ringdrill+json";
export const DRILL_EXT = ".drill";

// Lazy stores (safe for Functions v2 / Blobs v10)
let _drillsStore;
let _slugIndexStore;
export function getDrillsStore() {
    _drillsStore ||= getStore(NS.DRILLS);
    return _drillsStore;
}
export function getSlugIndexStore() {
    _slugIndexStore ||= getStore(NS.SLUG_INDEX);
    return _slugIndexStore;
}

// ---- Blob helpers (v10 getStore API) ----
export async function readBinary(key) {
    const drills = getDrillsStore();
    const ab = await drills.get(key, { type: "arrayBuffer" });
    return ab ? Buffer.from(ab) : null;
}
export async function writeBinary(key, bytes, contentType) {
    const drills = getDrillsStore();
    await drills.set(key, bytes, { contentType });
    return { ok: true };
}
export async function readJson(key, fallback = null) {
    const drills = getDrillsStore();
    const obj = await drills.get(key, { type: "json" });
    return obj ?? fallback;
}
export async function writeJson(key, data) {
    const drills = getDrillsStore();
    await drills.set(key, JSON.stringify(data), { contentType: "application/json" });
    return { ok: true };
}

// ---- Slug index (small JSON docs) ----
export async function getSlugRecord(slug) {
    const store = getSlugIndexStore();
    const rec = await store.get(slug, { type: "json" });
    return rec ?? null;
}
export async function setSlugRecord(slug, record) {
    const store = getSlugIndexStore();
    await store.set(slug, JSON.stringify(record), { contentType: "application/json" });
}

// ---- Keys & helpers ----
export function keysFor({ ownerId, programId, version }) {
    return {
        versioned: `drills/${ownerId}/${programId}/${version}${DRILL_EXT}`,
        latest:    `drills/${ownerId}/${programId}/latest${DRILL_EXT}`,
        meta:      `drills/${ownerId}/${programId}/meta.json`,
    };
}

export function sha256Hex(buf) {
    return crypto.createHash("sha256").update(buf).digest("hex");
}
export function toStrongEtag(hex) {
    return `"${hex}"`;
}

export function sanitizeSlug(s) {
    return (s || "")
        .toLowerCase().trim()
        .replace(/\s+/g, "-")
        .replace(/[^a-z0-9\-]/g, "-")
        .replace(/\-+/g, "-")
        .replace(/^\-|\-$/g, "");
}
export function nowIso() { return new Date().toISOString(); }
export function absoluteOrigin(event) {
    const h = event.headers || {};
    const proto = h["x-forwarded-proto"] || "https";
    const host  = h["x-forwarded-host"]  || h["host"];
    return `${proto}://${host}`;
}

// Accept base64 or raw string
export function decodeBody(event) {
    if (!event || typeof event.body !== "string") throw new Error("Missing body");
    if (event.isBase64Encoded) return Buffer.from(event.body, "base64");
    const ct = (event.headers?.["content-type"] || event.headers?.["Content-Type"] || "").toLowerCase();
    const s = event.body;
    const looksB64 = /^[A-Za-z0-9+/=\r\n]+$/.test(s.trim()) && s.trim().length % 4 === 0;
    if (looksB64) { try { return Buffer.from(s, "base64"); } catch { /* ignore */ } }
    return Buffer.from(s, ct.includes("json") ? "utf8" : "latin1");
}
