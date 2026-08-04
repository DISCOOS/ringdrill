// The two backends answer with the same shape, or one tool table is a fiction.
//
// ADR-0060 requires that the stdio server and the hosted function "share one tool
// table", and `tools.mjs` is it. Sharing the table only buys anything if the results
// match: an agent is told what a tool returns once, and reads whichever backend it
// happens to be talking to.
//
// They had drifted, in both directions, and nothing here compared them:
//
//   - `ok` was absent from a *successful* create/build/render on the CLI backend,
//     which injects `ok: false` on failure and nothing on success. So the obvious
//     `if (result.ok)` was false on success over stdio and true over HTTP. Caught
//     only when a smoke test written against the hosted endpoint was pointed at a
//     document that failed to compile.
//   - `source` and `out` were echoed by the CLI backend and unproducible by the
//     hosted one — and by the time a client read them, the scratch directory they
//     named had already been deleted in a `finally`.
//
// Comparing *keys* rather than values is the point: the values legitimately differ
// (different planId, different timings), the shape must not. A backend is allowed to
// answer with less than it could; it is not allowed to answer with a field its
// counterpart cannot produce.
//
// Scope, stated rather than silently assumed: the five document operations. The
// catalog tools (`search_catalog`, `get_plan`) read genuinely different stores — the
// hosted one goes to Netlify Blobs, the CLI to the public API over the network — so
// comparing them here would test a fixture, not the contract. They are covered
// separately in mcp-endpoint.test.mjs.
//
// Requires the cross-compiled bundle (`make mcp-bundle`) and shells out to the CLI,
// so it is one of the slower files in the suite.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

import { toolsFor } from '../tools.mjs';
import { createCliBackend, resolveCli } from '../backend-cli.mjs';
import { createCompilerBackend } from '../../netlify/functions/lib/mcp-backend.js';

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), '..', '..');

/// Two stations for two teams, because `mode` defaults to `ring`. Small enough to
/// compile quickly, complete enough that every operation has something to say.
const DOCUMENT = `
plan:
  name: "Parity"
  language: nb
exercises:
  - name: "Førsteinnsats søk"
    startTime: "09:00"
    numberOfTeams: 2
    numberOfRounds: 2
    executionTime: 15
    evaluationTime: 5
    rotationTime: 5
    method: "Teiglederen fordeler mannskapet og melder inn funn fortløpende."
    stations:
      - name: "Teigsøk"
        description: "Systematisk søk i skogsteig etter savnet person."
        situation: "Meldt savnet for to timer siden, sist sett ved parkeringen."
        position: { lat: 59.096857, lng: 10.401633 }
      - name: "Førstehjelp"
        description: "Behandling og bæring av skadd person ut av teigen."
        situation: "Den savnede er funnet nedkjølt og kan ikke gå selv."
        position: { lat: 59.098120, lng: 10.404410 }
`.trim();

const CASES = [
    ['schema', {}],
    ['create_plan', { name: 'Parity' }],
    ['build_plan', { document: DOCUMENT }],
    ['analyze_plan', { document: DOCUMENT }],
    ['render_plan', { document: DOCUMENT, audience: 'director' }],
];

function backends() {
    return {
        hosted: createCompilerBackend(),
        cli: createCliBackend({
            cli: resolveCli(repoRoot).command,
            cwd: repoRoot,
        }),
    };
}

/// Runs one tool on one backend through the shared table, so the comparison covers
/// `tools.mjs`'s own normalisation and not just the backend beneath it.
async function callTool(backend, name, args) {
    const tool = toolsFor(backend).find((t) => t.name === name);
    assert.ok(tool, `no tool named ${name}`);
    return tool.run(structuredClone(args));
}

for (const [name, args] of CASES) {
    test(`${name} answers with the same shape from both backends`, async () => {
        const { hosted, cli } = backends();
        const [fromHosted, fromCli] = await Promise.all([
            callTool(hosted, name, args),
            callTool(cli, name, args),
        ]);

        assert.deepEqual(
            Object.keys(fromCli).sort(),
            Object.keys(fromHosted).sort(),
            `${name} returns different fields depending on which backend serves ` +
                'it — an agent is told the shape once and reads whichever it gets',
        );
    });
}

test('every document operation reports ok: true on success', async () => {
    // The regression that started this. Asserted as a value, not a key, because
    // `ok` being *present and false* on a successful call is the failure mode —
    // a key-set comparison alone would call that a match.
    const { hosted, cli } = backends();
    for (const [name, args] of CASES) {
        if (name === 'schema') continue; // answers with the schema, not a verdict
        for (const [label, backend] of [
            ['hosted', hosted],
            ['cli', cli],
        ]) {
            const result = await callTool(backend, name, args);
            assert.equal(
                result.ok,
                true,
                `${name} on the ${label} backend succeeded but reported ` +
                    `ok: ${JSON.stringify(result.ok)}`,
            );
        }
    }
});

test('a document that does not compile is ok: false on both', async () => {
    // Two teams, one station, default `ring` mode: a real diagnostic rather than a
    // transport failure. `verdict()` must not paper over it.
    const broken = DOCUMENT.split('      - name: "Førstehjelp"')[0].trimEnd();
    const { hosted, cli } = backends();

    for (const [label, backend] of [
        ['hosted', hosted],
        ['cli', cli],
    ]) {
        const result = await callTool(backend, 'analyze_plan', {
            document: broken,
        });
        assert.equal(
            result.ok,
            false,
            `${label} reported ok: ${JSON.stringify(result.ok)} for a document ` +
                'with an error',
        );
        assert.ok(
            result.diagnostics?.length > 0,
            `${label} reported no diagnostics for a document with an error`,
        );
    }
});

test('neither backend leaks a path that no longer exists', async () => {
    // `source` and `out` named a scratch directory deleted in a `finally`, so the
    // client received a path to nothing. Asserted by name because that is what a
    // future `run()` would reintroduce.
    const { hosted, cli } = backends();
    for (const [name, args] of CASES) {
        for (const [label, backend] of [
            ['hosted', hosted],
            ['cli', cli],
        ]) {
            const result = await callTool(backend, name, args);
            for (const leaked of ['source', 'out']) {
                assert.ok(
                    !(leaked in result),
                    `${name} on the ${label} backend still returns \`${leaked}\``,
                );
            }
        }
    }
});
