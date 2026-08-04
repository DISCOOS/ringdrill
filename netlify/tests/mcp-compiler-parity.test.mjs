// The cross-compiled compiler must agree with the VM, not merely run.
//
// ADR-0060 names this as the gap the decision opens: the whole Dart suite runs on
// the VM, so nothing exercised the JavaScript target — and this code computes
// coordinate projections and a SHA-256, which are exactly where two Dart backends
// could diverge without either looking wrong. dart2js represents ints as
// doubles, so a numeric difference is a real possibility rather than a
// theoretical one.
//
// The assertion that matters is the content hash: it is a fingerprint over the
// entire compiled plan, so if any derived value differed anywhere — a schedule
// time, a flipped coordinate, a sorted list — the hashes would not match. One
// comparison covers the whole pipeline.
//
// Requires the bundle. Run `make mcp-bundle` if this fails to load.
import { test } from "node:test";
import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

import { invoke } from "../functions/lib/mcp-compiler.js";
import { check } from "../../tools/mcp-bundle-stamp.mjs";

const run = promisify(execFile);
const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(here, "..", "..");

/// A document with something of everything the compiler derives: a rotation, a
/// coordinate that goes through UTM projection, a station-owned location and
/// person, a variable with a scope override, and a role play inheriting identity.
const DOCUMENT = `
plan:
  name: "Parity"
  language: nb
  variables:
    talegruppe: { value: "RK-VFOLD-ØV2" }
exercises:
  - uuid: fixed-ex-1
    name: "Førsteinnsats søk"
    startTime: "09:45"
    numberOfTeams: 2
    numberOfRounds: 6
    executionTime: 15
    evaluationTime: 10
    rotationTime: 5
    stations:
      - name: "Barn 4-6 år"
        position: { lat: 59.096857, lng: 10.401633 }
        variableOverrides: { talegruppe: "RK-VFOLD-ØV3" }
        locations:
          - slug: lkp
            kind: lkp
            label: "Sist kjent posisjon"
            position: { lat: 59.09672, lng: 10.40201 }
        persons:
          - slug: magnus
            name: "Magnus Damslet"
            age: 6
            locSlug: lkp
        situation: |
          {{station.person.magnus}} ({{station.person.magnus.age}} år).
          Sist sett {{station.loc.lkp.utm}}. Samband på {{var.talegruppe}}.
        roleplays:
          - uuid: fixed-rp-1
            personRef: magnus
            behavior: |
              Gjemmer seg.
      - name: "Løper"
        position: { lat: 59.098841, lng: 10.40428 }
        situation: "Ine Vigerdal (42) – søk treningsløype."
teams:
  - { uuid: fixed-team-1, name: "Larvik 21" }
  - { uuid: fixed-team-2, name: "Tønsberg 21" }
`;

/// The VM's answer, via the CLI. Every uuid in DOCUMENT is fixed, so nothing is
/// minted and the hash is reproducible across both backends.
async function viaVm(args, { input } = {}) {
    const path = join(repoRoot, "netlify", "tests", ".parity-tmp.yaml");
    const { writeFile, rm } = await import("node:fs/promises");
    await writeFile(path, input ?? DOCUMENT, "utf8");
    try {
        const { stdout } = await run(
            "dart",
            ["run", join(repoRoot, "bin", "ringdrill.dart"), ...args, path, "--json"],
            { cwd: repoRoot, maxBuffer: 32 * 1024 * 1024 },
        );
        // `dart run` prints a build-hooks preamble before the program's output.
        return JSON.parse(stdout.slice(stdout.indexOf("{")));
    } finally {
        await rm(path, { force: true });
    }
}

test("build: the JS target produces the VM's content hash", async () => {
    const js = await invoke({ op: "build", document: DOCUMENT, fileName: "parity" });
    assert.equal(js.ok, true, JSON.stringify(js));

    const vm = await viaVm(["build", "--out=/dev/null"]);

    assert.equal(
        js.contentHash,
        vm.contentHash,
        "a differing hash means some derived value differs between the two Dart " +
            "backends — a schedule time, a coordinate, a sort order",
    );
    // Corroborate the shape too, so a hash that matched for the wrong reason
    // (both empty, say) could not pass.
    assert.equal(js.exercises, vm.exercises);
    assert.equal(js.stations, vm.stations);
    assert.equal(js.teams, vm.teams);
    assert.equal(js.rolePlays, vm.rolePlays);
    assert.match(js.contentHash, /^[0-9a-f]{64}$/);
});

test("render: the JS target produces the VM's brief, byte for byte", async () => {
    // Covers UTM projection through proj4dart and the ICU plural handling in the
    // headless labels — the two places most likely to differ between backends.
    const js = await invoke({
        op: "render",
        document: DOCUMENT,
        audience: "director",
    });
    assert.equal(js.ok, true, JSON.stringify(js));

    const vm = await viaVm(["render", "--audience=director"]);

    assert.equal(js.markdown, vm.markdown);
    assert.match(js.markdown, /32V/, "expected a projected UTM coordinate");
    assert.ok(!js.markdown.includes("{{"), "a token was left unresolved");
});

test("analyze: the JS target agrees on diagnostics", async () => {
    const broken = DOCUMENT.replace("{{var.talegruppe}}", "{{var.typo}}");

    const js = await invoke({ op: "analyze", document: broken });
    const vm = await viaVm(["analyze"], { input: broken }).catch((e) => {
        // analyze exits 65 on errors, which execFile treats as a failure; the
        // payload is still on stdout.
        return JSON.parse(e.stdout.slice(e.stdout.indexOf("{")));
    });

    assert.equal(js.errors, vm.errors);
    assert.deepEqual(
        js.diagnostics.map((d) => d.message),
        vm.diagnostics.map((d) => d.message),
    );
    assert.match(js.diagnostics[0].message, /no variable named "typo"/);
});

test("schema: the JS target produces the VM's schema", async () => {
    const js = await invoke({ op: "schema" });
    const { stdout } = await run(
        "dart",
        ["run", join(repoRoot, "bin", "ringdrill.dart"), "schema", "--json"],
        { cwd: repoRoot, maxBuffer: 32 * 1024 * 1024 },
    );
    const vm = JSON.parse(stdout.slice(stdout.indexOf("{")));
    assert.deepEqual(js.schema, vm);
});

test("decompile: a built archive round-trips through the JS target", async () => {
    // The round-trip contract, evaluated entirely inside the JS backend: it has to
    // hold there too, or `get_plan` on the hosted server would hand an agent a
    // document that rebuilds into a different plan.
    const built = await invoke({ op: "build", document: DOCUMENT, fileName: "parity" });
    const decompiled = await invoke({
        op: "decompile",
        drillBase64: built.drillBase64,
    });
    assert.equal(decompiled.ok, true, JSON.stringify(decompiled));
    assert.equal(decompiled.contentHash, built.contentHash);

    const rebuilt = await invoke({
        op: "build",
        document: decompiled.document,
        fileName: "parity",
    });
    assert.equal(
        rebuilt.contentHash,
        built.contentHash,
        "build(decompile(d)) must preserve the hash in the JS target too",
    );
});

test("create: the JS target scaffolds a document that analyzes clean", async () => {
    const created = await invoke({ op: "create", name: "JS Scaffold", teams: 2 });
    assert.match(created.document, /^# RingDrill source document/);
    const analysis = await invoke({
        op: "analyze",
        document: created.document,
        strict: true,
    });
    assert.equal(analysis.errors, 0, JSON.stringify(analysis.diagnostics));
    assert.equal(analysis.warnings, 0, JSON.stringify(analysis.diagnostics));
});

test("a document problem is a result, not a rejection", async () => {
    const result = await invoke({ op: "analyze", document: "not: a plan\n" });
    assert.equal(result.ok, false);
    assert.ok(Array.isArray(result.diagnostics));
});

test("an unknown op is reported rather than thrown", async () => {
    const result = await invoke({ op: "nonsense" });
    assert.equal(result.ok, false);
    assert.match(result.error, /unknown op/);
});

test("the bundle is not stale relative to the Dart sources", async () => {
    // The other consequence ADR-0060 names: a stale bundle serves old compiler
    // behaviour with no symptom.
    //
    // Content, not mtime — and dart2js's own dependency list, not a set of source
    // roots guessed here. Both halves of that were learned the hard way, and the
    // header of tools/mcp-bundle-stamp.mjs has the detail; the short version is
    // that this assertion used to fail after a plain `make i18n`, on a file
    // (lib/l10n/app_localizations.dart) that the bundle does not import at all.
    const { missingStamp, changed } = await check();

    assert.ok(
        !missingStamp,
        "netlify/functions/lib/mcp-compiler-bundle.sources.json is missing — " +
            "run `make mcp-bundle`",
    );
    assert.deepEqual(
        changed,
        [],
        `mcp-compiler-bundle.js was built before these changed:\n  ` +
            `${changed.join("\n  ")}\n` +
            "Run `make mcp-bundle` — the hosted endpoint would serve stale " +
            "compiler behaviour with no other symptom.",
    );
});
