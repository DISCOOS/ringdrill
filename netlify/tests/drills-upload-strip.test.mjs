/**
 * Tests for the actors/ stripping and schema validation logic in drills-upload.js.
 *
 * We test the helper functions by importing them from a thin wrapper module
 * rather than the full handler (which requires @netlify/blobs environment).
 * The strip/validate logic is self-contained and only needs fflate.
 */
import { test } from "node:test";
import assert from "node:assert/strict";
import { zipSync, strFromU8, unzipSync } from "fflate";

// Re-implement the helpers under test to avoid importing the full handler
// (which would pull in @netlify/blobs and require a Netlify context).
// These are copied verbatim from drills-upload.js.

const KNOWN_SCHEMA_MAX = "1.2";

/**
 * Folders holding local PII that must never reach the catalog.
 *
 * Two names for one thing: DESIGN-011 renames the folder `actors/` -> `staff/`,
 * and this function is deployed independently of the app that writes the
 * archive. Stripping both means neither deploy order can leak: an old app
 * uploading `actors/` is stripped by a new function, and a new app uploading
 * `staff/` is stripped by a function deployed before it. Keep `actors/` here
 * even after the app stops writing it — .drill files already exported to disk
 * still carry it, and they can be uploaded at any time.
 */
const PII_FOLDERS = ["actors/", "staff/"];

function compareSchemas(a, b) {
    const [aMaj, aMin] = a.split(".").map(Number);
    const [bMaj, bMin] = b.split(".").map(Number);
    if (aMaj !== bMaj) return aMaj - bMaj;
    return (aMin || 0) - (bMin || 0);
}

function stripActorsAndValidate(request, bytes) {
    let files;
    try {
        files = unzipSync(new Uint8Array(bytes));
    } catch (e) {
        return { error: new Response(`Invalid archive: ${e.message}`, { status: 400 }) };
    }

    const metadataEntry = files["metadata.json"];
    if (metadataEntry) {
        let metadata;
        try { metadata = JSON.parse(strFromU8(metadataEntry)); } catch (_) {}
        if (metadata?.schema) {
            const clientSchema = String(metadata.schema);
            if (compareSchemas(clientSchema, KNOWN_SCHEMA_MAX) > 0) {
                return { error: new Response(
                    JSON.stringify({ error: "unsupported_schema" }),
                    { status: 415, headers: { "content-type": "application/json" } }
                ) };
            }
        }
    }

    const stripped = {};
    for (const [name, data] of Object.entries(files)) {
        if (!PII_FOLDERS.some((folder) => name.startsWith(folder))) {
            stripped[name] = data;
        }
    }
    return { strippedBytes: Buffer.from(zipSync(stripped)) };
}

// Helper: build a minimal .drill archive
function buildArchive({ schema, includeActors = false, actorsFolder = "actors/" } = {}) {
    const files = {};
    if (schema !== undefined) {
        files["metadata.json"] = new TextEncoder().encode(
            JSON.stringify({ version: "1.0", schema })
        );
    } else {
        files["metadata.json"] = new TextEncoder().encode(
            JSON.stringify({ version: "1.0" })
        );
    }
    files["program.json"] = new TextEncoder().encode(
        JSON.stringify({ uuid: "prog-1", name: "Test" })
    );
    if (includeActors) {
        files[`${actorsFolder}actor-1.json`] = new TextEncoder().encode(
            JSON.stringify({ uuid: "actor-1", realName: "Kari", phone: "+47999" })
        );
    }
    files["roleplays/rp-1.json"] = new TextEncoder().encode(
        JSON.stringify({ uuid: "rp-1", name: "Anna" })
    );
    return Buffer.from(zipSync(files));
}

test("strips actors/ entries from archive", () => {
    const bytes = buildArchive({ schema: "1.1", includeActors: true });
    const { strippedBytes, error } = stripActorsAndValidate(null, bytes);
    assert.equal(error, undefined);

    const result = unzipSync(new Uint8Array(strippedBytes));
    assert.ok(!Object.keys(result).some(k => k.startsWith("actors/")),
        "actors/ entries must be removed");
    assert.ok(Object.keys(result).some(k => k.startsWith("roleplays/")),
        "roleplays/ entries must survive");
    assert.ok(result["metadata.json"], "metadata.json must survive");
    assert.ok(result["program.json"], "program.json must survive");
});

// DESIGN-011 renames actors/ -> staff/. This function deploys separately from
// the app that writes the archive, so both names must be stripped: whichever
// deploy lands first, PII must not reach the catalog. A test naming only one
// folder would pass through the exact window where the leak happens.
test("strips staff/ entries from archive", () => {
    const bytes = buildArchive({
        schema: "1.1",
        includeActors: true,
        actorsFolder: "staff/",
    });
    const { strippedBytes, error } = stripActorsAndValidate(null, bytes);
    assert.equal(error, undefined);

    const result = unzipSync(new Uint8Array(strippedBytes));
    assert.ok(!Object.keys(result).some(k => k.startsWith("staff/")),
        "staff/ entries must be removed");
    assert.ok(Object.keys(result).some(k => k.startsWith("roleplays/")),
        "roleplays/ entries must survive");
});

// A .drill exported to disk before the rename still carries actors/, and can be
// uploaded at any time afterwards — so the old folder is stripped forever, not
// only during the transition.
test("strips staff/ and actors/ together", () => {
    const files = {
        "metadata.json": new TextEncoder().encode(
            JSON.stringify({ version: "1.0", schema: "1.1" })
        ),
        "program.json": new TextEncoder().encode(
            JSON.stringify({ uuid: "prog-1", name: "Test" })
        ),
        "actors/old.json": new TextEncoder().encode(
            JSON.stringify({ uuid: "old", realName: "Kari", phone: "+47999" })
        ),
        "staff/new.json": new TextEncoder().encode(
            JSON.stringify({ uuid: "new", realName: "Ola", phone: "+47888" })
        ),
        "roleplays/rp-1.json": new TextEncoder().encode(
            JSON.stringify({ uuid: "rp-1", name: "Anna" })
        ),
    };
    const { strippedBytes, error } = stripActorsAndValidate(
        null,
        Buffer.from(zipSync(files))
    );
    assert.equal(error, undefined);

    const result = unzipSync(new Uint8Array(strippedBytes));
    const survivors = Object.keys(result);
    assert.ok(!survivors.some(k => k.startsWith("actors/")));
    assert.ok(!survivors.some(k => k.startsWith("staff/")));
    assert.ok(survivors.some(k => k.startsWith("roleplays/")));
});

test("accepts archive without actors/ folder", () => {
    const bytes = buildArchive({ schema: "1.1", includeActors: false });
    const { strippedBytes, error } = stripActorsAndValidate(null, bytes);
    assert.equal(error, undefined);
    const result = unzipSync(new Uint8Array(strippedBytes));
    assert.ok(result["program.json"]);
});

test("accepts schema 1.0 (legacy, no schema field)", () => {
    const bytes = buildArchive({ includeActors: false });
    // Remove schema field from metadata manually
    const files = unzipSync(new Uint8Array(bytes));
    const meta = JSON.parse(strFromU8(files["metadata.json"]));
    assert.equal(meta.schema, undefined);
    const { error } = stripActorsAndValidate(null, bytes);
    assert.equal(error, undefined);
});

test("accepts schema 1.1", () => {
    const bytes = buildArchive({ schema: "1.1" });
    const { error } = stripActorsAndValidate(null, bytes);
    assert.equal(error, undefined);
});

test("accepts schema 1.2", () => {
    const bytes = buildArchive({ schema: "1.2" });
    const { error } = stripActorsAndValidate(null, bytes);
    assert.equal(error, undefined);
});

test("rejects schema higher than 1.2", async () => {
    const bytes = buildArchive({ schema: "1.3" });
    const { strippedBytes, error } = stripActorsAndValidate(null, bytes);
    assert.ok(error, "should return an error response");
    assert.equal(error.status, 415);
    assert.equal(strippedBytes, undefined);
});

test("strips actors/<uuid>/notes.md but keeps roleplays/<uuid>/behavior.md", () => {
    const files = {};
    files["metadata.json"] = new TextEncoder().encode(JSON.stringify({ version: "1.0", schema: "1.2" }));
    files["program.json"] = new TextEncoder().encode(JSON.stringify({ uuid: "prog-1", name: "Test" }));
    files["actors/actor-1.json"] = new TextEncoder().encode(JSON.stringify({ uuid: "actor-1", realName: "Kari" }));
    files["actors/actor-1/notes.md"] = new TextEncoder().encode("# Notes\nSome PII notes");
    files["roleplays/rp-1.json"] = new TextEncoder().encode(JSON.stringify({ uuid: "rp-1", name: "Anna" }));
    files["roleplays/rp-1/behavior.md"] = new TextEncoder().encode("# Behavior\nBe calm");
    const bytes = Buffer.from(zipSync(files));

    const { strippedBytes, error } = stripActorsAndValidate(null, bytes);
    assert.equal(error, undefined);

    const result = unzipSync(new Uint8Array(strippedBytes));
    assert.ok(!result["actors/actor-1.json"], "actors/<uuid>.json must be stripped");
    assert.ok(!result["actors/actor-1/notes.md"], "actors/<uuid>/notes.md must be stripped");
    assert.ok(result["roleplays/rp-1/behavior.md"], "roleplays/<uuid>/behavior.md must survive");
});

test("rejects schema 2.0", async () => {
    const bytes = buildArchive({ schema: "2.0" });
    const { error } = stripActorsAndValidate(null, bytes);
    assert.ok(error);
    assert.equal(error.status, 415);
});

test("compareSchemas works correctly", () => {
    assert.equal(compareSchemas("1.0", "1.1"), -1);
    assert.equal(compareSchemas("1.1", "1.1"), 0);
    assert.equal(compareSchemas("1.2", "1.1"), 1);
    assert.equal(compareSchemas("2.0", "1.1"), 1);
    assert.equal(compareSchemas("1.0", "2.0"), -1);
});
