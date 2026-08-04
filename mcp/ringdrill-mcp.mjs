#!/usr/bin/env node
// RingDrill MCP server, stdio transport — the DESIGN-014 stage 4 local surface.
//
// Wraps the `ringdrill` CLI so an agent can search the catalog, read a published
// plan as a source document, scaffold, check, compile and render one.
//
// This file is only the transport and the CLI resolution. The tools themselves —
// names, descriptions, schemas, and the JSON-RPC dispatch — live in `tools.mjs`,
// shared with the hosted Netlify endpoint (ADR-0060), so a description improved
// here is improved there and a tool cannot exist in one and not the other. The
// operations are in `backend-cli.mjs`, which owns no knowledge of the source
// format: the format already has enough descriptions without one living here.
//
// `publish` is deliberately absent. The catalog is a wiki-model shared corpus and
// an agent should not write to it unattended (DESIGN-014); publishing stays a
// human running `ringdrill publish`.
//
// Speaks MCP over stdio directly rather than through the SDK: the protocol
// surface needed is `initialize`, `tools/list` and `tools/call`, which is less
// code than the dependency would be — and this repo's package.json is the Netlify
// functions package, so adding one there would couple the backend's dependency
// tree to an agent-tooling concern.
import { readFile } from 'node:fs/promises';
import { createInterface } from 'node:readline';
import { dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

import { createCliBackend, resolveCli } from './backend-cli.mjs';
import { handleMessage, toolsFor } from './tools.mjs';

const repoRoot = dirname(dirname(fileURLToPath(import.meta.url)));

// To stderr, never stdout: stdout is the JSON-RPC stream, and a stray write to it
// corrupts the transport. Which CLI is in use is the first thing you want to know
// when a tool behaves unexpectedly; in Claude Desktop this lands in
// ~/Library/Logs/Claude/mcp-server-ringdrill.log.
const log = (message) => process.stderr.write(`ringdrill-mcp: ${message}\n`);

const resolved = resolveCli(repoRoot, { log });
log(`using CLI from ${resolved.source}`);

/// Reads a guide resource out of the checkout this server runs from (ADR-0065).
///
/// `mcp/` sits one level under the repo root, so the skill files are a fixed hop
/// away — no configuration, and it is the same tree the CLI was built from.
async function readResource(resource) {
    return readFile(new URL(`../${resource.file}`, import.meta.url), 'utf8');
}

const tools = toolsFor(
    createCliBackend({ cli: resolved.command, cwd: repoRoot }),
);

// A client that goes away mid-call closes the read end of stdout, and Node raises
// an unhandled 'error' event that kills the process with a stack trace. A crash
// dump is a worse signal than a clean exit: nothing is wrong on this side, the
// conversation simply ended. Anything that is not EPIPE is a real fault and still
// throws.
process.stdout.on('error', (e) => {
    if (e.code === 'EPIPE') process.exit(0);
    throw e;
});

// Same for stdin: the loop below ends when the stream closes, but a reset
// connection surfaces as an error rather than an end.
process.stdin.on('error', (e) => {
    if (e.code === 'EPIPE' || e.code === 'ECONNRESET') process.exit(0);
    throw e;
});

const lines = createInterface({ input: process.stdin });
for await (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed) continue;
    let message;
    try {
        message = JSON.parse(trimmed);
    } catch {
        process.stdout.write(
            `${JSON.stringify({
                jsonrpc: '2.0',
                id: null,
                error: { code: -32700, message: 'Parse error' },
            })}\n`,
        );
        continue;
    }
    const response = await handleMessage(message, tools, { readResource });
    // Null for a notification, which takes no reply.
    if (response) process.stdout.write(`${JSON.stringify(response)}\n`);
}
