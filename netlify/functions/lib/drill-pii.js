import { unzipSync, zipSync } from "fflate";
/**
 * The PII boundary for published .drill archives, and the schema gate beside it.
 *
 * Extracted so its tests can import the real code. `drills-upload-strip.test.mjs`
 * used to re-implement these functions — "copied verbatim from drills-upload.js",
 * by its own comment — which meant the one test guarding personal data could not
 * detect a divergence in the code it claimed to cover: production could stop
 * stripping and the copy would stay green. That risk grew with DESIGN-011, which
 * renamed the folder this module names.
 */

/**
 * Folders holding local PII that must never reach the catalog.
 *
 * Two names for one thing: DESIGN-011 renames the folder `actors/` -> `staff/`,
 * and this function is deployed independently of the app that writes the archive.
 * Stripping both means neither deploy order can leak — an old app uploading
 * `actors/` is stripped by a new function, and a new app uploading `staff/` is
 * stripped by a function deployed before it. Keep `actors/` here even after the
 * app stops writing it: .drill files already exported to disk still carry it, they
 * travel peer-to-peer by design (USB, AirDrop, email), and one can be uploaded at
 * any point in the future.
 */
export const PII_FOLDERS = ["actors/", "staff/"];

/** The highest schema version the upload endpoint accepts. */
export const KNOWN_SCHEMA_MAX = "1.2";

/**
 * Compare two "major.minor" schema strings.
 * Returns negative if a < b, 0 if equal, positive if a > b.
 */
export function compareSchemas(a, b) {
    const [aMaj, aMin] = a.split(".").map(Number);
    const [bMaj, bMin] = b.split(".").map(Number);
    if (aMaj !== bMaj) return aMaj - bMaj;
    return (aMin || 0) - (bMin || 0);
}

/**
 * Every entry of [files] except those under a [PII_FOLDERS] prefix.
 *
 * Pure and synchronous on purpose: the one operation that must never regress is
 * also the one easiest to test directly.
 */
export function stripPiiFolders(files) {
    const stripped = {};
    for (const [name, data] of Object.entries(files)) {
        if (!PII_FOLDERS.some((folder) => name.startsWith(folder))) {
            stripped[name] = data;
        }
    }
    return stripped;
}

/**
 * Whether [schema] is newer than this endpoint understands. Null/absent schema is
 * accepted — a 1.0 archive predates the marker.
 */
export function isSchemaTooNew(schema) {
    if (schema == null) return false;
    return compareSchemas(String(schema), KNOWN_SCHEMA_MAX) > 0;
}

/**
 * Read catalog-bound archive bytes, stripped at the door (ADR-0072).
 *
 * **This is the only sanctioned way for a catalog-bound handler to read an
 * uploaded archive.** The strip used to live at `drills-upload`'s call site,
 * which was correct and remembered rather than structural: a second endpoint
 * that accepted archive bytes would have had to know to call it, and the
 * failure mode of forgetting is silent — PII reaches a publicly readable blob,
 * nothing errors, no test fails, and we hear about it from someone else.
 *
 * Moving it to the read means unstripped catalog bytes are not something a
 * handler can obtain by accident. `netlify/tests/pii-ingest.test.mjs` enumerates
 * the functions that read request bodies and fails when a new one bypasses this.
 *
 * Downstream validation may strip again; `stripPiiFolders` is idempotent, so
 * the belt and the braces do not interfere.
 */
export async function readCatalogArchive(request, { readBytes } = {}) {
    const read = readBytes ?? (await import("./shared.js")).readDrillBytes;
    const rawBytes = await read(request);
    try {
        const files = unzipSync(new Uint8Array(rawBytes));
        return { bytes: Buffer.from(zipSync(stripPiiFolders(files))), stripped: true };
    } catch {
        // Not a readable archive. Hand the bytes back untouched so the caller
        // produces its own "invalid archive" 400 with the message it wants —
        // but say plainly that nothing was stripped, so no caller can mistake
        // this for a clean read.
        return { bytes: rawBytes, stripped: false };
    }
}
