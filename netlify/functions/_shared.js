import crypto from "node:crypto";
import { getBlob, setBlob, listBlobs } from "@netlify/blobs";

// Namespaces/keys
export const NS = {
    SLUG_INDEX: "slug-index", // key: slug -> { ownerId, programId }
};

export const MIME_DRILL = "application/vnd.ringdrill+json";
export const DRILL_EXT = ".drill";

// -------- Blobs helpers --------
export async function readBlob(key) {
    const res = await getBlob({ key });
    if (!res) return null;
    // getBlob returns { body, contentType, etag } in modern SDKs
    return res;
}

export async function writeBlob(key, bytes, contentType) {
    // setBlob returns { etag } (and may expose url in newer SDKs)
    const res = await setBlob({ key, data: bytes, contentType });
    return res;
}

export async function readJson(key, fallback = null) {
    const res = await readBlob(key);
    if (!res?.body) return fallback;
    return JSON.parse(Buffer.from(res.body).toString("utf8"));
}

export async function writeJson(key, obj) {
    const bytes = Buffer.from(JSON.stringify(obj, null, 2), "utf8");
    return await writeBlob(key, bytes, "application/json");
}

// -------- Slug index --------
export async function getSlugRecord(slug) {
    const key = `${NS.SLUG_INDEX}/${slug}.json`;
    return await readJson(key, null);
}

export async function setSlugRecord(slug, record) {
    const key = `${NS.SLUG_INDEX}/${slug}.json`;
    await writeJson(key, record);
}

// -------- Program keys --------
export function keysFor({ ownerId, programId, version }) {
    return {
        versioned: `drills/${ownerId}/${programId}/${version}${DRILL_EXT}`,
        latest: `drills/${ownerId}/${programId}/latest${DRILL_EXT}`,
        meta: `drills/${ownerId}/${programId}/meta.json`
    };
}

// -------- ETag / hashing --------
export function sha256Hex(buf) {
    return crypto.createHash("sha256").update(buf).digest("hex");
}

export function toStrongEtag(hex) {
    return `"${hex}"`;
}

// -------- Utilities --------
export function sanitizeSlug(s) {
    return (s || "")
        .toLowerCase()
        .trim()
        .replace(/\s+/g, "-")
        .replace(/[^a-z0-9\-]/g, "-")
        .replace(/\-+/g, "-")
        .replace(/^\-|\-$/g, "");
}

export function nowIso() {
    return new Date().toISOString();
}
