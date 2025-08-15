import crypto from "node:crypto";
import {getStore} from "@netlify/blobs";

export const NS = {DRILLS: "drills", SLUG_INDEX: "slug-index"};
export const MIME_DRILL = "application/vnd.ringdrill+json";
export const DRILL_EXT = ".drill";

let _drillsStore, _slugIndexStore;

export function getDrillsStore() {
    _drillsStore ||= getStore(NS.DRILLS);
    return _drillsStore;
}

export function getSlugIndexStore() {
    _slugIndexStore ||= getStore(NS.SLUG_INDEX);
    return _slugIndexStore;
}

export async function readBinary(key) {
    const drills = getDrillsStore();
    const ab = await drills.get(key, {type: "arrayBuffer"});
    return ab ? Buffer.from(ab) : null;
}

export async function writeBinary(key, bytes, contentType) {
    const drills = getDrillsStore();
    await drills.set(key, bytes, {contentType});
    return {ok: true};
}

export async function readJson(key, fallback = null) {
    const drills = getDrillsStore();
    const obj = await drills.get(key, {type: "json"});
    return obj ?? fallback;
}

export async function writeJson(key, data) {
    const drills = getDrillsStore();
    await drills.set(key, JSON.stringify(data), {contentType: "application/json"});
    return {ok: true};
}

export async function getSlugRecord(slug) {
    const store = getSlugIndexStore();
    const rec = await store.get(slug, {type: "json"});
    return rec ?? null;
}

export async function setSlugRecord(slug, record) {
    const store = getSlugIndexStore();
    await store.set(slug, JSON.stringify(record), {contentType: "application/json"});
}

export function keysFor({ownerId, programId, version}) {
    return {
        versioned: `drills/${ownerId}/${programId}/${version}${DRILL_EXT}`,
        latest: `drills/${ownerId}/${programId}/latest${DRILL_EXT}`,
        meta: `drills/${ownerId}/${programId}/meta.json`,
    };
}

export function sha256Hex(buf) {
    return crypto.createHash("sha256").update(buf).digest("hex");
}

export function toStrongEtag(hex) {
    return `"${hex}"`;
}

export function sanitizeSlug(s) {
    return (s || "").toLowerCase().trim()
        .replace(/\s+/g, "-").replace(/[^a-z0-9\-]/g, "-").replace(/\-+/g, "-")
        .replace(/^\-|\-$/g, "");
}

export function nowIso() {
    return new Date().toISOString();
}

// v2 helper: get absolute origin from the Request
export function originFromRequest(request) {
    return new URL(request.url).origin;
}

// Heuristic base64-or-binary decoder for v2 (supports your base64 | --data-binary @- trick)
export async function readDrillBytes(request) {
    const cloned = request.clone();
    const raw = new Uint8Array(await request.arrayBuffer());
    // If any byte is non-ASCII, treat as binary
    if (raw.some(b => b > 127)) return Buffer.from(raw);
    const text = await cloned.text();
    const s = text.trim();
    const looksB64 = /^[A-Za-z0-9+/=\r\n]+$/.test(s) && s.length % 4 === 0;
    if (!looksB64) return Buffer.from(raw);
    try {
        return Buffer.from(s, "base64");
    } catch {
        return Buffer.from(raw);
    }
}
