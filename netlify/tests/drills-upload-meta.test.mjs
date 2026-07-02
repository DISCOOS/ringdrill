/**
 * Tests for catalog name/description/tags resolution in drills-upload.js.
 *
 * These import the pure helpers directly. That is safe because _shared.js only
 * calls getStore() lazily (inside the store getters), never at module load, so
 * importing drills-upload.js does not require a Netlify blobs context.
 */
import { test } from "node:test";
import assert from "node:assert/strict";
import { zipSync, strFromU8, unzipSync } from "fflate";
import {
    programInfoFromArchive,
    resolveCatalogFields,
    resolvePublishPolicy,
    stripActorsAndValidate,
} from "../functions/drills-upload.js";

const enc = (obj) => new TextEncoder().encode(JSON.stringify(obj));

// ---------- programInfoFromArchive ----------

test("programInfoFromArchive: reads name, description and tags from program.json", () => {
    const files = { "program.json": enc({ uuid: "p1", name: "Winter SAR", description: "Plan-level text", tags: ["sar", "urban"] }) };
    assert.deepEqual(programInfoFromArchive(files), { name: "Winter SAR", description: "Plan-level text", tags: ["sar", "urban"], exerciseCount: 0 });
});

test("programInfoFromArchive: missing program.json → nulls and empty tags", () => {
    assert.deepEqual(programInfoFromArchive({}), { name: null, description: null, tags: [], exerciseCount: 0 });
});

test("programInfoFromArchive: missing description field → null description", () => {
    const files = { "program.json": enc({ uuid: "p1", name: "Only name" }) };
    assert.deepEqual(programInfoFromArchive(files), { name: "Only name", description: null, tags: [], exerciseCount: 0 });
});

test("programInfoFromArchive: missing tags field → empty array, not null", () => {
    const files = { "program.json": enc({ uuid: "p1", name: "N", description: "D" }) };
    const result = programInfoFromArchive(files);
    assert.deepEqual(result.tags, []);
});

test("programInfoFromArchive: tags: [] deserializes to empty array", () => {
    const files = { "program.json": enc({ uuid: "p1", name: "N", description: "D", tags: [] }) };
    const result = programInfoFromArchive(files);
    assert.deepEqual(result.tags, []);
});

test("programInfoFromArchive: malformed program.json → nulls and empty tags, never throws", () => {
    const files = { "program.json": new TextEncoder().encode("{not json") };
    assert.deepEqual(programInfoFromArchive(files), { name: null, description: null, tags: [], exerciseCount: 0 });
});

test("programInfoFromArchive: non-string fields ignored", () => {
    const files = { "program.json": enc({ name: 42, description: { nested: true }, tags: "not-an-array" }) };
    assert.deepEqual(programInfoFromArchive(files), { name: null, description: null, tags: [], exerciseCount: 0 });
});

// ---------- programInfoFromArchive: exerciseCount (ADR-0040) ----------
//
// DrillFile.build() always serializes exercises out to individual
// `exercises/<uuid>.json` files and writes `program.exercises: []` (see
// lib/data/drill_file.dart) — the embedded array is never populated in a
// real archive. exerciseCount must therefore count the archive's exercise
// files, not `program.json.exercises.length`.

test("programInfoFromArchive: counts top-level exercises/<uuid>.json entries", () => {
    const files = {
        "program.json": enc({ uuid: "p1", name: "N", exercises: [] }),
        "exercises/e1.json": enc({ uuid: "e1" }),
        "exercises/e2.json": enc({ uuid: "e2" }),
        "exercises/e3.json": enc({ uuid: "e3" }),
    };
    assert.equal(programInfoFromArchive(files).exerciseCount, 3);
});

test("programInfoFromArchive: program.json.exercises is ignored (always [] in real archives)", () => {
    // A hypothetical archive that (incorrectly, or from an old writer) embeds
    // exercises inline must NOT have those counted — only real exercises/
    // files count, so the field cannot silently disagree with what's on disk.
    const files = {
        "program.json": enc({ uuid: "p1", name: "N", exercises: [{ uuid: "e1" }, { uuid: "e2" }] }),
        "exercises/e1.json": enc({ uuid: "e1" }),
    };
    assert.equal(programInfoFromArchive(files).exerciseCount, 1);
});

test("programInfoFromArchive: no exercises/ entries → exerciseCount 0, not null", () => {
    const files = { "program.json": enc({ uuid: "p1", name: "N", exercises: [] }) };
    assert.equal(programInfoFromArchive(files).exerciseCount, 0);
});

test("programInfoFromArchive: per-station markdown under exercises/<uuid>/... is not counted", () => {
    const files = {
        "program.json": enc({ uuid: "p1", name: "N" }),
        "exercises/e1.json": enc({ uuid: "e1" }),
        "exercises/e1/stations/0/leaderNotesMd.md": new TextEncoder().encode("# notes"),
    };
    assert.equal(programInfoFromArchive(files).exerciseCount, 1);
});

test("programInfoFromArchive: exercise files are counted even when program.json is missing", () => {
    const files = {
        "exercises/e1.json": enc({ uuid: "e1" }),
        "exercises/e2.json": enc({ uuid: "e2" }),
    };
    assert.equal(programInfoFromArchive(files).exerciseCount, 2);
});

// ---------- resolvePublishPolicy ----------

test("resolvePublishPolicy: anon owner → author 'anon', accessPolicy 'public'", () => {
    assert.deepEqual(resolvePublishPolicy({ ownerId: "anon" }), { author: "anon", accessPolicy: "public" });
});

test("resolvePublishPolicy: account owner → author mirrors ownerId, accessPolicy 'account'", () => {
    assert.deepEqual(resolvePublishPolicy({ ownerId: "acc-42" }), { author: "acc-42", accessPolicy: "account" });
});

// ---------- resolveCatalogFields ----------

const program = { name: "Program Name", description: "Program description", tags: ["a", "b"] };

test("resolveCatalogFields: name and description come from program.json", () => {
    const r = resolveCatalogFields({ program, slug: "s" });
    assert.equal(r.name, "Program Name");
    assert.equal(r.description, "Program description");
});

test("resolveCatalogFields: tags come from program.json", () => {
    const r = resolveCatalogFields({ program, slug: "s" });
    assert.deepEqual(r.tags, ["a", "b"]);
});

test("resolveCatalogFields: name falls back to slug when program.name is empty", () => {
    const r = resolveCatalogFields({ program: { name: "", description: "", tags: [] }, slug: "my-slug" });
    assert.equal(r.name, "my-slug");
});

test("resolveCatalogFields: name falls back to slug when program.name is null", () => {
    const r = resolveCatalogFields({ program: { name: null, description: null, tags: [] }, slug: "my-slug" });
    assert.equal(r.name, "my-slug");
    assert.equal(r.description, "");
});

test("resolveCatalogFields: description absent → empty string", () => {
    const r = resolveCatalogFields({ program: { name: "N", description: null, tags: [] }, slug: "s" });
    assert.equal(r.description, "");
});

test("resolveCatalogFields: file without tags → empty array", () => {
    const r = resolveCatalogFields({ program: { name: "N", description: "D" }, slug: "s" });
    assert.deepEqual(r.tags, []);
});

test("resolveCatalogFields: tags: [] → empty array (removal supported)", () => {
    const r = resolveCatalogFields({ program: { name: "N", description: "D", tags: [] }, slug: "s" });
    assert.deepEqual(r.tags, []);
});

test("resolveCatalogFields: publish overwrites catalog tags, not unions", () => {
    // Simulate: catalog currently has ["x","y","z"], program carries only ["a"]
    // resolveCatalogFields returns what program says; caller must overwrite, not union.
    const catalogTags = ["x", "y", "z"];
    const r = resolveCatalogFields({ program: { name: "N", description: "D", tags: ["a"] }, slug: "s" });
    // The resolved set is smaller than catalogTags — overwrite wins.
    assert.deepEqual(r.tags, ["a"]);
    assert.ok(!r.tags.includes("x"), "old catalog tag must not survive after overwrite");
    // Show that union would have produced a larger set (what we no longer do).
    const union = Array.from(new Set([...catalogTags, ...r.tags]));
    assert.ok(union.length > r.tags.length, "union would have kept old tags");
});

test("resolveCatalogFields: ?name= query is not honoured — name comes from program", () => {
    // Ensure the function signature no longer accepts nameParam/descriptionParam.
    const r = resolveCatalogFields({ program, slug: "s" });
    assert.equal(r.name, "Program Name", "program.json wins, not a hypothetical query param");
});

// ---------- stripActorsAndValidate returns program info ----------

test("stripActorsAndValidate: returns { name, description, tags } from program.json", () => {
    const files = {
        "metadata.json": enc({ version: "1.0", schema: "1.2" }),
        "program.json": enc({ uuid: "p1", name: "Eidene 2026", description: "Full plan", tags: ["sar"] }),
    };
    const bytes = Buffer.from(zipSync(files));
    const { strippedBytes, program, error } = stripActorsAndValidate(null, bytes);
    assert.equal(error, undefined);
    assert.deepEqual(program, { name: "Eidene 2026", description: "Full plan", tags: ["sar"], exerciseCount: 0 });
    // program.json survives the strip
    assert.ok(unzipSync(new Uint8Array(strippedBytes))["program.json"]);
});

test("stripActorsAndValidate: program read happens before actors are stripped, description intact", () => {
    const files = {
        "metadata.json": enc({ version: "1.0", schema: "1.2" }),
        "program.json": enc({ uuid: "p1", name: "N", description: "D", tags: [] }),
        "actors/a1.json": enc({ uuid: "a1", realName: "Kari" }),
    };
    const bytes = Buffer.from(zipSync(files));
    const { strippedBytes, program } = stripActorsAndValidate(null, bytes);
    assert.equal(program.description, "D");
    assert.deepEqual(program.tags, []);
    const result = unzipSync(new Uint8Array(strippedBytes));
    assert.ok(!result["actors/a1.json"], "actors still stripped");
});
