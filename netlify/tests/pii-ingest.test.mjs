/**
 * The enumerating guard ADR-0072 asks for.
 *
 * The PII strip used to sit at `drills-upload`'s call site: correct, and
 * remembered rather than structural. A second endpoint that accepted archive
 * bytes would have had to know to call it, and forgetting is silent — PII
 * reaches a publicly readable blob, nothing errors, no test fails, and we hear
 * about it from somebody else.
 *
 * So this test does not check that today's code is right. It checks that
 * *tomorrow's* code cannot quietly be wrong: it scans every Netlify function
 * for one that reads a request body as archive bytes, and fails unless that
 * function goes through `readCatalogArchive`.
 *
 * It is coarse on purpose. It recognises a shape rather than an intent, so a
 * sufficiently different endpoint could evade it — but it fails for the person
 * most likely to get this wrong, which is somebody adding an upload path who
 * has not read ADR-0072.
 */
import { test } from "node:test";
import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

import { PII_FOLDERS, readCatalogArchive, stripPiiFolders } from "../functions/lib/drill-pii.js";
import { zipSync, unzipSync } from "fflate";

const FUNCTIONS_DIR = join(dirname(fileURLToPath(import.meta.url)), "..", "functions");

/**
 * Functions that read a request body but are not catalog-bound, with the reason
 * each is exempt. Adding a name here is a deliberate act that shows up in
 * review — which is the point of an allowlist over a heuristic.
 */
const NOT_CATALOG_BOUND = new Map([
    ["mcp.js", "JSON-RPC bodies, and the MCP endpoint cannot publish (ADR-0060)"],
]);

const enc = (obj) => new TextEncoder().encode(JSON.stringify(obj));

function archiveWithStaff() {
    return Buffer.from(zipSync({
        "program.json": enc({ uuid: "p1", name: "Plan" }),
        "metadata.json": enc({ schema: "1.2" }),
        "exercises/e1.json": enc({ uuid: "e1" }),
        "staff/s1.json": enc({ uuid: "s1", realName: "Kari Nordmann", phone: "+47 900 00 000" }),
        "actors/a1.json": enc({ uuid: "a1", realName: "Ola Nordmann" }),
    }));
}

// ---------- the structural guard ----------

test("every function reading a request body is catalog-bound through readCatalogArchive, or explicitly exempt", () => {
    const offenders = [];

    for (const file of readdirSync(FUNCTIONS_DIR).filter((f) => f.endsWith(".js"))) {
        const src = readFileSync(join(FUNCTIONS_DIR, file), "utf8");

        // The shapes that get raw bytes out of a request.
        const readsBody = /request\.arrayBuffer\(|request\.blob\(|readDrillBytes\s*\(/.test(src);
        if (!readsBody) continue;

        if (NOT_CATALOG_BOUND.has(file)) continue;

        if (!src.includes("readCatalogArchive")) {
            offenders.push(file);
        }
    }

    assert.deepEqual(
        offenders, [],
        "These functions read a request body without going through readCatalogArchive.\n" +
        "Either route them through it (ADR-0072: the strip is a property of accepting\n" +
        "an archive, not of the publish endpoint), or add them to NOT_CATALOG_BOUND\n" +
        "with the reason they cannot reach the catalog.",
    );
});

test("the exemption list stays small and every entry names a real file", () => {
    const present = new Set(readdirSync(FUNCTIONS_DIR));
    for (const name of NOT_CATALOG_BOUND.keys()) {
        assert.ok(present.has(name), `exempt file ${name} no longer exists — drop the exemption`);
    }
});

// ---------- the strip itself ----------

test("readCatalogArchive strips both PII folder names, at the read", async () => {
    const request = new Request("https://api.ringdrill.app/upload", { method: "POST", body: archiveWithStaff() });
    const { bytes, stripped } = await readCatalogArchive(request);

    assert.equal(stripped, true);
    const files = unzipSync(new Uint8Array(bytes));
    const names = Object.keys(files);

    // Both names, permanently: drills-upload deploys on its own cadence, so a
    // new app writing staff/ to a function stripping only actors/ would publish
    // the PII (ADR-0018's DESIGN-011 amendment).
    assert.ok(!names.some((n) => n.startsWith("staff/")), `staff/ survived: ${names}`);
    assert.ok(!names.some((n) => n.startsWith("actors/")), `actors/ survived: ${names}`);
    assert.ok(names.includes("program.json"));
    assert.ok(names.includes("roleplays/") === false);
    assert.ok(names.includes("exercises/e1.json"), "publishable content must survive");
});

test("PII_FOLDERS is the single list, and covers both names", () => {
    assert.deepEqual([...PII_FOLDERS].sort(), ["actors/", "staff/"]);
});

test("stripping is idempotent, so a second strip downstream is harmless", () => {
    const files = unzipSync(new Uint8Array(archiveWithStaff()));
    const once = stripPiiFolders(files);
    const twice = stripPiiFolders(once);
    assert.deepEqual(Object.keys(once).sort(), Object.keys(twice).sort());
});

test("a body that is not an archive is handed back with stripped:false rather than pretending", async () => {
    // The caller produces its own "invalid archive" 400. What must not happen
    // is a caller mistaking an unreadable body for a clean read.
    const request = new Request("https://api.ringdrill.app/upload", { method: "POST", body: Buffer.from("not a zip") });
    const { stripped } = await readCatalogArchive(request);
    assert.equal(stripped, false);
});

test("an archive with no PII folders passes through intact", async () => {
    const clean = Buffer.from(zipSync({ "program.json": enc({ uuid: "p1" }), "exercises/e1.json": enc({ uuid: "e1" }) }));
    const request = new Request("https://api.ringdrill.app/upload", { method: "POST", body: clean });
    const { bytes } = await readCatalogArchive(request);
    assert.deepEqual(Object.keys(unzipSync(new Uint8Array(bytes))).sort(), ["exercises/e1.json", "program.json"]);
});
