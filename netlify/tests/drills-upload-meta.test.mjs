/**
 * Tests for catalog name/description resolution in drills-upload.js.
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
    stripActorsAndValidate,
} from "../functions/drills-upload.js";

const enc = (obj) => new TextEncoder().encode(JSON.stringify(obj));

// ---------- programInfoFromArchive ----------

test("programInfoFromArchive: reads name and description from program.json", () => {
    const files = { "program.json": enc({ uuid: "p1", name: "Winter SAR", description: "Plan-level text" }) };
    assert.deepEqual(programInfoFromArchive(files), { name: "Winter SAR", description: "Plan-level text" });
});

test("programInfoFromArchive: missing program.json → nulls", () => {
    assert.deepEqual(programInfoFromArchive({}), { name: null, description: null });
});

test("programInfoFromArchive: missing description field → null description", () => {
    const files = { "program.json": enc({ uuid: "p1", name: "Only name" }) };
    assert.deepEqual(programInfoFromArchive(files), { name: "Only name", description: null });
});

test("programInfoFromArchive: malformed program.json → nulls, never throws", () => {
    const files = { "program.json": new TextEncoder().encode("{not json") };
    assert.deepEqual(programInfoFromArchive(files), { name: null, description: null });
});

test("programInfoFromArchive: non-string fields ignored", () => {
    const files = { "program.json": enc({ name: 42, description: { nested: true } }) };
    assert.deepEqual(programInfoFromArchive(files), { name: null, description: null });
});

// ---------- resolveCatalogFields ----------

const program = { name: "Program Name", description: "Program description" };

test("resolveCatalogFields: query params win over program.json", () => {
    const r = resolveCatalogFields({ nameParam: "Q Name", descriptionParam: "Q desc", program, slug: "s" });
    assert.deepEqual(r, { name: "Q Name", description: "Q desc" });
});

test("resolveCatalogFields: falls back to program.json when query absent", () => {
    const r = resolveCatalogFields({ nameParam: null, descriptionParam: null, program, slug: "s" });
    assert.deepEqual(r, { name: "Program Name", description: "Program description" });
});

test("resolveCatalogFields: name falls back to slug when neither query nor program", () => {
    const r = resolveCatalogFields({ nameParam: null, descriptionParam: null, program: { name: null, description: null }, slug: "my-slug" });
    assert.equal(r.name, "my-slug");
    assert.equal(r.description, "");
});

test("resolveCatalogFields: empty ?description= is honoured as an explicit override", () => {
    const r = resolveCatalogFields({ nameParam: null, descriptionParam: "", program, slug: "s" });
    assert.equal(r.description, "", "explicit empty query clears the description");
});

test("resolveCatalogFields: whitespace-only name param falls through to program", () => {
    const r = resolveCatalogFields({ nameParam: "   ", descriptionParam: null, program, slug: "s" });
    assert.equal(r.name, "Program Name");
});

test("resolveCatalogFields: description absent everywhere → empty string", () => {
    const r = resolveCatalogFields({ nameParam: "N", descriptionParam: null, program: { name: null, description: null }, slug: "s" });
    assert.equal(r.description, "");
});

// ---------- stripActorsAndValidate returns program info ----------

test("stripActorsAndValidate: returns { name, description } from program.json", () => {
    const files = {
        "metadata.json": enc({ version: "1.0", schema: "1.2" }),
        "program.json": enc({ uuid: "p1", name: "Eidene 2026", description: "Full plan" }),
    };
    const bytes = Buffer.from(zipSync(files));
    const { strippedBytes, program, error } = stripActorsAndValidate(null, bytes);
    assert.equal(error, undefined);
    assert.deepEqual(program, { name: "Eidene 2026", description: "Full plan" });
    // program.json survives the strip
    assert.ok(unzipSync(new Uint8Array(strippedBytes))["program.json"]);
});

test("stripActorsAndValidate: program read happens before actors are stripped, description intact", () => {
    const files = {
        "metadata.json": enc({ version: "1.0", schema: "1.2" }),
        "program.json": enc({ uuid: "p1", name: "N", description: "D" }),
        "actors/a1.json": enc({ uuid: "a1", realName: "Kari" }),
    };
    const bytes = Buffer.from(zipSync(files));
    const { strippedBytes, program } = stripActorsAndValidate(null, bytes);
    assert.equal(program.description, "D");
    const result = unzipSync(new Uint8Array(strippedBytes));
    assert.ok(!result["actors/a1.json"], "actors still stripped");
});
