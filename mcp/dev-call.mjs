#!/usr/bin/env node
// Call one MCP tool from the shell, for manual testing.
//
//   node mcp/dev-call.mjs                                   list the tools
//   node mcp/dev-call.mjs schema
//   node mcp/dev-call.mjs create_plan name="LSOR 2027" teams=4 lang=nb
//   node mcp/dev-call.mjs analyze_plan document=@plan.yaml
//   node mcp/dev-call.mjs render_plan document=@plan.yaml audience=director --raw
//
// Exists because the alternative is hand-writing JSON-RPC frames into a pipe,
// which is fine once and miserable the tenth time — and the tenth time is when
// you are actually debugging something. `--raw` prints the tool's text payload
// unwrapped, so a rendered brief or a scaffolded document is readable rather than
// JSON-escaped.
//
// This is a development harness, not part of the server. A client never uses it.
import { spawn } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const server = join(here, 'ringdrill-mcp.mjs');

const argv = process.argv.slice(2);
const raw = argv.includes('--raw');
const positional = argv.filter((a) => a !== '--raw');
const tool = positional[0];

/** `key=value` pairs into an arguments object. */
function parseArgs(pairs) {
    const out = {};
    for (const pair of pairs) {
        const eq = pair.indexOf('=');
        if (eq < 0) {
            console.error(`Ignoring "${pair}": expected key=value.`);
            continue;
        }
        const key = pair.slice(0, eq);
        let value = pair.slice(eq + 1);
        // `@path` reads a file — the only ergonomic way to pass a whole source
        // document on a command line.
        if (value.startsWith('@')) {
            out[key] = readFileSync(value.slice(1), 'utf8');
            continue;
        }
        if (value === 'true' || value === 'false') {
            out[key] = value === 'true';
            continue;
        }
        if (/^-?\d+$/.test(value)) {
            out[key] = Number(value);
            continue;
        }
        out[key] = value;
    }
    return out;
}

const requests = [
    { jsonrpc: '2.0', id: 1, method: 'initialize', params: {} },
    tool
        ? {
              jsonrpc: '2.0',
              id: 2,
              method: 'tools/call',
              params: { name: tool, arguments: parseArgs(positional.slice(1)) },
          }
        : { jsonrpc: '2.0', id: 2, method: 'tools/list' },
];

const child = spawn('node', [server], {
    cwd: join(here, '..'),
    // stderr inherited: the server reports which CLI it resolved, and warns about
    // a stale one. That is exactly what you want to see while testing.
    stdio: ['pipe', 'pipe', 'inherit'],
});

let stdout = '';
child.stdout.on('data', (d) => (stdout += d));

for (const request of requests) {
    child.stdin.write(`${JSON.stringify(request)}\n`);
}
child.stdin.end();

child.on('close', (code) => {
    const responses = new Map();
    for (const line of stdout.split('\n')) {
        if (!line.trim()) continue;
        try {
            const message = JSON.parse(line);
            responses.set(message.id, message);
        } catch {
            console.error(`Unparseable line from server: ${line}`);
        }
    }

    const response = responses.get(2);
    if (!response) {
        console.error(`No response (server exited ${code}).`);
        process.exit(1);
    }
    if (response.error) {
        console.error(`Error ${response.error.code}: ${response.error.message}`);
        process.exit(1);
    }

    if (!tool) {
        for (const t of response.result.tools) {
            console.log(`${t.name}`);
            const params = Object.entries(t.inputSchema.properties ?? {});
            const required = new Set(t.inputSchema.required ?? []);
            for (const [name, spec] of params) {
                const mark = required.has(name) ? '*' : ' ';
                console.log(`  ${mark} ${name.padEnd(12)} ${spec.type ?? ''}`);
            }
        }
        console.log('\n* required.  Usage: node mcp/dev-call.mjs <tool> key=value …');
        process.exit(0);
    }

    const text = response.result.content?.[0]?.text ?? '';
    if (raw) {
        // Tools return JSON; --raw unwraps the one field a human wants to read.
        try {
            const parsed = JSON.parse(text);
            const body =
                parsed.document ?? parsed.markdown ?? parsed.yaml ?? null;
            process.stdout.write(body ?? text);
            if (body && !body.endsWith('\n')) process.stdout.write('\n');
        } catch {
            process.stdout.write(`${text}\n`);
        }
    } else {
        console.log(text);
    }

    // A tool that reported a problem should fail the shell command, so this
    // composes in a script.
    process.exit(response.result.isError ? 1 : 0);
});
