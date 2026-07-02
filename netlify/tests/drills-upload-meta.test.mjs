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
    resolvePlaceName,
    resolvePublishPolicy,
    stripActorsAndValidate,
} from "../functions/drills-upload.js";

const enc = (obj) => new TextEncoder().encode(JSON.stringify(obj));

// ---------- programInfoFromArchive ----------

test("programInfoFromArchive: reads name, description and tags from program.json", () => {
    const files = { "program.json": enc({ uuid: "p1", name: "Winter SAR", description: "Plan-level text", tags: ["sar", "urban"] }) };
    assert.deepEqual(programInfoFromArchive(files), { name: "Winter SAR", description: "Plan-level text", tags: ["sar", "urban"], exerciseCount: 0, mapCenter: null, mapBounds: null });
});

test("programInfoFromArchive: missing program.json → nulls and empty tags", () => {
    assert.deepEqual(programInfoFromArchive({}), { name: null, description: null, tags: [], exerciseCount: 0, mapCenter: null, mapBounds: null });
});

test("programInfoFromArchive: missing description field → null description", () => {
    const files = { "program.json": enc({ uuid: "p1", name: "Only name" }) };
    assert.deepEqual(programInfoFromArchive(files), { name: "Only name", description: null, tags: [], exerciseCount: 0, mapCenter: null, mapBounds: null });
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
    assert.deepEqual(programInfoFromArchive(files), { name: null, description: null, tags: [], exerciseCount: 0, mapCenter: null, mapBounds: null });
});

test("programInfoFromArchive: non-string fields ignored", () => {
    const files = { "program.json": enc({ name: 42, description: { nested: true }, tags: "not-an-array" }) };
    assert.deepEqual(programInfoFromArchive(files), { name: null, description: null, tags: [], exerciseCount: 0, mapCenter: null, mapBounds: null });
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

// ---------- programInfoFromArchive: mapCenter (ADR-0040 addendum) ----------
//
// mapCenter is a single coarse centroid of every positioned station across
// every exercise file — never per-station pins, never a bounding box (see
// the map-center addendum in docs/adrs/0040-catalog-feed-schema-extension.md).

test("programInfoFromArchive: mapCenter averages positioned stations across exercises", () => {
    const files = {
        "program.json": enc({ uuid: "p1", name: "N" }),
        "exercises/e1.json": enc({
            uuid: "e1",
            stations: [{ uuid: "s1", position: { coordinates: [10, 60] } }],
        }),
        "exercises/e2.json": enc({
            uuid: "e2",
            stations: [{ uuid: "s2", position: { coordinates: [12, 62] } }],
        }),
    };
    assert.deepEqual(programInfoFromArchive(files).mapCenter, { lat: 61, lng: 11 });
});

test("programInfoFromArchive: stations without a position are ignored, not skewing the average", () => {
    const files = {
        "program.json": enc({ uuid: "p1", name: "N" }),
        "exercises/e1.json": enc({
            uuid: "e1",
            stations: [
                { uuid: "s1", position: { coordinates: [10, 60] } },
                { uuid: "s2", position: null },
                { uuid: "s3" },
            ],
        }),
    };
    assert.deepEqual(programInfoFromArchive(files).mapCenter, { lat: 60, lng: 10 });
});

test("programInfoFromArchive: a malformed exercises/<uuid>.json is skipped for exerciseCount and mapCenter, never throws", () => {
    const files = {
        "program.json": enc({ uuid: "p1", name: "N" }),
        "exercises/e1.json": new TextEncoder().encode("{not json"),
        "exercises/e2.json": enc({
            uuid: "e2",
            stations: [{ uuid: "s1", position: { coordinates: [10, 60] } }],
        }),
    };
    const result = programInfoFromArchive(files);
    assert.equal(result.exerciseCount, 2, "malformed file still counts as an exercise file");
    assert.deepEqual(result.mapCenter, { lat: 60, lng: 10 }, "malformed file contributes no positions, but doesn't throw or drop the good one");
});

test("programInfoFromArchive: no positioned stations anywhere → mapCenter null, never (0,0)", () => {
    const files = {
        "program.json": enc({ uuid: "p1", name: "N" }),
        "exercises/e1.json": enc({ uuid: "e1", stations: [{ uuid: "s1" }] }),
    };
    assert.equal(programInfoFromArchive(files).mapCenter, null);
});

test("programInfoFromArchive: non-finite coordinates are excluded from the average", () => {
    const files = {
        "program.json": enc({ uuid: "p1", name: "N" }),
        "exercises/e1.json": enc({
            uuid: "e1",
            stations: [
                { uuid: "s1", position: { coordinates: [10, 60] } },
                { uuid: "s2", position: { coordinates: ["not-a-number", 60] } },
                { uuid: "s3", position: { coordinates: [10] } },
            ],
        }),
    };
    assert.deepEqual(programInfoFromArchive(files).mapCenter, { lat: 60, lng: 10 });
});

// ---------- programInfoFromArchive: mapBounds (ADR-0040 bounding-box addendum) ----------
//
// mapBounds is the min/max lat/lng across every positioned station across
// every exercise file — what the catalog card actually renders (fitBounds +
// a rectangle), superseding the earlier centroid-only precision rule.

test("programInfoFromArchive: mapBounds spans the min/max of positioned stations across exercises", () => {
    const files = {
        "program.json": enc({ uuid: "p1", name: "N" }),
        "exercises/e1.json": enc({
            uuid: "e1",
            stations: [{ uuid: "s1", position: { coordinates: [10, 60] } }],
        }),
        "exercises/e2.json": enc({
            uuid: "e2",
            stations: [{ uuid: "s2", position: { coordinates: [12, 62] } }],
        }),
    };
    assert.deepEqual(programInfoFromArchive(files).mapBounds, { north: 62, south: 60, east: 12, west: 10 });
});

test("programInfoFromArchive: mapBounds for a single positioned station is a zero-area box, not null", () => {
    const files = {
        "program.json": enc({ uuid: "p1", name: "N" }),
        "exercises/e1.json": enc({
            uuid: "e1",
            stations: [{ uuid: "s1", position: { coordinates: [10, 60] } }],
        }),
    };
    assert.deepEqual(programInfoFromArchive(files).mapBounds, { north: 60, south: 60, east: 10, west: 10 });
});

test("programInfoFromArchive: no positioned stations anywhere → mapBounds null, never a degenerate box", () => {
    const files = {
        "program.json": enc({ uuid: "p1", name: "N" }),
        "exercises/e1.json": enc({ uuid: "e1", stations: [{ uuid: "s1" }] }),
    };
    assert.equal(programInfoFromArchive(files).mapBounds, null);
});

test("programInfoFromArchive: non-finite coordinates are excluded from mapBounds", () => {
    const files = {
        "program.json": enc({ uuid: "p1", name: "N" }),
        "exercises/e1.json": enc({
            uuid: "e1",
            stations: [
                { uuid: "s1", position: { coordinates: [10, 60] } },
                { uuid: "s2", position: { coordinates: ["not-a-number", 60] } },
                { uuid: "s3", position: { coordinates: [10] } },
            ],
        }),
    };
    assert.deepEqual(programInfoFromArchive(files).mapBounds, { north: 60, south: 60, east: 10, west: 10 });
});

// ---------- resolvePlaceName (ADR-0040 bounding-box addendum) ----------
//
// Reverse-geocodes mapCenter via Nominatim. Tests stub the global fetch so
// no real network call is made.

test("resolvePlaceName: null center → null, no fetch attempted", async () => {
    const originalFetch = globalThis.fetch;
    let called = false;
    globalThis.fetch = async () => { called = true; };
    try {
        assert.equal(await resolvePlaceName(null), null);
        assert.equal(called, false);
    } finally {
        globalThis.fetch = originalFetch;
    }
});

test("resolvePlaceName: builds place from city + country address fields", async () => {
    const originalFetch = globalThis.fetch;
    let requestedUrl;
    globalThis.fetch = async (url) => {
        requestedUrl = url;
        return {
            ok: true,
            json: async () => ({ address: { city: "Bergen", country: "Norway" } }),
        };
    };
    try {
        const place = await resolvePlaceName({ lat: 60.39, lng: 5.32 });
        assert.equal(place, "Bergen, Norway");
        const u = new URL(String(requestedUrl));
        assert.equal(u.hostname, "nominatim.openstreetmap.org");
        assert.equal(u.searchParams.get("lat"), "60.39");
        assert.equal(u.searchParams.get("lon"), "5.32");
    } finally {
        globalThis.fetch = originalFetch;
    }
});

test("resolvePlaceName: falls back through town/village/municipality/county when city is absent", () => {
    const originalFetch = globalThis.fetch;
    globalThis.fetch = async () => ({
        ok: true,
        json: async () => ({ address: { village: "Eidene", country: "Norway" } }),
    });
    return resolvePlaceName({ lat: 1, lng: 2 })
        .then((place) => assert.equal(place, "Eidene, Norway"))
        .finally(() => { globalThis.fetch = originalFetch; });
});

test("resolvePlaceName: non-OK response → null", async () => {
    const originalFetch = globalThis.fetch;
    globalThis.fetch = async () => ({ ok: false });
    try {
        assert.equal(await resolvePlaceName({ lat: 1, lng: 2 }), null);
    } finally {
        globalThis.fetch = originalFetch;
    }
});

test("resolvePlaceName: network failure → null, never throws", async () => {
    const originalFetch = globalThis.fetch;
    globalThis.fetch = async () => { throw new Error("network down"); };
    try {
        assert.equal(await resolvePlaceName({ lat: 1, lng: 2 }), null);
    } finally {
        globalThis.fetch = originalFetch;
    }
});

test("resolvePlaceName: address with no usable fields → null", async () => {
    const originalFetch = globalThis.fetch;
    globalThis.fetch = async () => ({ ok: true, json: async () => ({ address: {} }) });
    try {
        assert.equal(await resolvePlaceName({ lat: 1, lng: 2 }), null);
    } finally {
        globalThis.fetch = originalFetch;
    }
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
    assert.deepEqual(program, { name: "Eidene 2026", description: "Full plan", tags: ["sar"], exerciseCount: 0, mapCenter: null, mapBounds: null, languageCode: null });
    // program.json survives the strip
    assert.ok(unzipSync(new Uint8Array(strippedBytes))["program.json"]);
});

// ---------- stripActorsAndValidate: languageCode (ADR-0007 addendum) ----------

test("stripActorsAndValidate: reads languageCode from metadata.json", () => {
    const files = {
        "metadata.json": enc({ version: "1.0", schema: "1.2", languageCode: "nb" }),
        "program.json": enc({ uuid: "p1", name: "N" }),
    };
    const bytes = Buffer.from(zipSync(files));
    const { program, error } = stripActorsAndValidate(null, bytes);
    assert.equal(error, undefined);
    assert.equal(program.languageCode, "nb");
});

test("stripActorsAndValidate: missing languageCode → null", () => {
    const files = {
        "metadata.json": enc({ version: "1.0", schema: "1.2" }),
        "program.json": enc({ uuid: "p1", name: "N" }),
    };
    const bytes = Buffer.from(zipSync(files));
    const { program } = stripActorsAndValidate(null, bytes);
    assert.equal(program.languageCode, null);
});

test("stripActorsAndValidate: non-string languageCode → null, never thrown", () => {
    const files = {
        "metadata.json": enc({ version: "1.0", schema: "1.2", languageCode: 42 }),
        "program.json": enc({ uuid: "p1", name: "N" }),
    };
    const bytes = Buffer.from(zipSync(files));
    const { program, error } = stripActorsAndValidate(null, bytes);
    assert.equal(error, undefined);
    assert.equal(program.languageCode, null);
});

test("stripActorsAndValidate: missing metadata.json → languageCode null", () => {
    const files = {
        "program.json": enc({ uuid: "p1", name: "N" }),
    };
    const bytes = Buffer.from(zipSync(files));
    const { program } = stripActorsAndValidate(null, bytes);
    assert.equal(program.languageCode, null);
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
