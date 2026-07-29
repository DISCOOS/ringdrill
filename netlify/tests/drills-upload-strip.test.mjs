/**
 * Tests for the PII strip and schema gate in `_drill_pii.js`.
 *
 * These import the real functions. They used to re-implement them — "copied
 * verbatim from drills-upload.js", by the old comment — so the one test guarding
 * personal data could not detect a divergence in the code it claimed to cover:
 * production could stop stripping and this file would stay green. That is why the
 * strip lives in its own module now.
 *
 * The handler is still not imported directly; it pulls in @netlify/blobs and needs
 * a Netlify context. `stripActorsAndValidate` composes unzip + schema gate + strip,
 * and the two halves it composes are what matter here, so they are exercised
 * through the same small composition below.
 */
import { test } from "node:test";
import assert from "node:assert/strict";
import { zipSync, strFromU8, unzipSync } from "fflate";
import {
    KNOWN_SCHEMA_MAX,
    compareSchemas,
    isSchemaTooNew,
    stripPiiFolders,
} from "../functions/_drill_pii.js";

/**
 * The handler's own sequence: unzip, reject a too-new schema, strip the PII
 * folders. Kept to the shape of `stripActorsAndValidate` so these tests read
 * against the endpoint's behaviour, while every rule they assert comes from the
 * imported module rather than a copy.
 */
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
        if (isSchemaTooNew(metadata?.schema)) {
            return { error: new Response(
                JSON.stringify({ error: "unsupported_schema" }),
                { status: 415, headers: { "content-type": "application/json" } }
            ) };
        }
    }

    return { strippedBytes: Buffer.from(zipSync(stripPiiFolders(files))) };
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

// Straight at the module, with no archive in the way. The composition above proves
// the endpoint wires these together; these prove the rules themselves, which is the
// part that must never regress.
test("stripPiiFolders removes both PII folder names and nothing else", () => {
    const files = {
        "program.json": new Uint8Array([1]),
        "actors/a.json": new Uint8Array([2]),
        "staff/b.json": new Uint8Array([3]),
        "staff/b/notes.md": new Uint8Array([4]),
        "roleplays/rp.json": new Uint8Array([5]),
        // Not a PII folder: the prefix must match a folder, not any substring.
        "staffing-notes.json": new Uint8Array([6]),
    };

    assert.deepEqual(Object.keys(stripPiiFolders(files)).sort(), [
        "program.json",
        "roleplays/rp.json",
        "staffing-notes.json",
    ]);
});

test("isSchemaTooNew gates on the known max", () => {
    assert.equal(isSchemaTooNew(null), false, "no marker means a 1.0 archive");
    assert.equal(isSchemaTooNew(undefined), false);
    assert.equal(isSchemaTooNew("1.0"), false);
    assert.equal(isSchemaTooNew(KNOWN_SCHEMA_MAX), false);
    assert.equal(isSchemaTooNew("2.0"), true);
    assert.equal(compareSchemas("1.10", "1.9") > 0, true, "minor is numeric");
});

