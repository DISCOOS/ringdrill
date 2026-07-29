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
