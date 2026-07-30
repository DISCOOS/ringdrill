// Drives the MCP server the way a client does: over a real stdio pipe, with
// newline-delimited JSON-RPC. Importing its internals would skip the transport,
// which is a meaningful part of what can break — a stray console.log on stdout
// corrupts the stream and no unit test would notice.
//
// The CLI is invoked through `dart run`, which prints "Running build hooks..."
// before the program's own output. That is deliberate: it is the awkward case the
// server has to tolerate, so testing against it keeps the tolerance honest.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(here, '..', '..');
const server = join(here, '..', 'ringdrill-mcp.mjs');

/** Sends `requests` to a fresh server and returns the responses, keyed by id. */
async function rpc(requests, { timeoutMs = 180_000 } = {}) {
    const child = spawn('node', [server], {
        cwd: repoRoot,
        env: {
            ...process.env,
            RINGDRILL_CLI: `dart run ${join(repoRoot, 'bin', 'ringdrill.dart')}`,
        },
    });

    let stdout = '';
    child.stdout.on('data', (d) => (stdout += d));
    let stderr = '';
    child.stderr.on('data', (d) => (stderr += d));

    for (const request of requests) {
        child.stdin.write(`${JSON.stringify(request)}\n`);
    }
    child.stdin.end();

    const code = await new Promise((resolve, reject) => {
        const timer = setTimeout(() => {
            child.kill();
            reject(new Error(`server timed out after ${timeoutMs}ms`));
        }, timeoutMs);
        child.on('error', reject);
        child.on('close', (c) => {
            clearTimeout(timer);
            resolve(c);
        });
    });

    assert.equal(code, 0, `server exited ${code}: ${stderr}`);

    const byId = new Map();
    for (const line of stdout.split('\n')) {
        if (!line.trim()) continue;
        const message = JSON.parse(line);
        byId.set(message.id, message);
    }
    return byId;
}

/** The parsed JSON payload of a tools/call result. */
function payload(response) {
    assert.ok(response, 'no response');
    assert.ok(response.result, `expected a result, got ${JSON.stringify(response)}`);
    return JSON.parse(response.result.content[0].text);
}

test('initialize advertises tools', async () => {
    const responses = await rpc([
        { jsonrpc: '2.0', id: 1, method: 'initialize', params: {} },
    ]);
    const result = responses.get(1).result;
    assert.equal(result.serverInfo.name, 'ringdrill');
    assert.ok(result.capabilities.tools);
    assert.match(result.protocolVersion, /^\d{4}-\d{2}-\d{2}$/);
});

test('tools/list describes every tool, and omits publish', async () => {
    const responses = await rpc([
        { jsonrpc: '2.0', id: 1, method: 'tools/list' },
    ]);
    const tools = responses.get(1).result.tools;
    const names = tools.map((t) => t.name).sort();
    assert.deepEqual(names, [
        'analyze_plan',
        'build_plan',
        'create_plan',
        'get_plan',
        'render_plan',
        'schema',
        'search_catalog',
    ]);

    // publish is withheld on purpose: the catalog is a shared corpus and an agent
    // must not write to it unattended (DESIGN-014).
    assert.ok(!names.includes('publish'));

    for (const tool of tools) {
        assert.ok(tool.description?.length > 40, `${tool.name} needs a real description`);
        assert.equal(tool.inputSchema.type, 'object');
    }
});

test('an unknown method is a protocol error, an unknown tool is reported', async () => {
    const responses = await rpc([
        { jsonrpc: '2.0', id: 1, method: 'nope/nope' },
        {
            jsonrpc: '2.0',
            id: 2,
            method: 'tools/call',
            params: { name: 'not_a_tool', arguments: {} },
        },
    ]);
    assert.equal(responses.get(1).error.code, -32601);
    // An unknown tool name lists what does exist, so the agent can correct itself
    // rather than guessing again.
    assert.match(responses.get(2).error.message, /build_plan/);
});

test('notifications get no reply', async () => {
    const responses = await rpc([
        { jsonrpc: '2.0', method: 'notifications/initialized' },
        { jsonrpc: '2.0', id: 1, method: 'ping' },
    ]);
    assert.equal(responses.size, 1);
    assert.ok(responses.has(1));
});

test('schema returns the generated JSON Schema', async () => {
    const responses = await rpc([
        {
            jsonrpc: '2.0',
            id: 1,
            method: 'tools/call',
            params: { name: 'schema', arguments: {} },
        },
    ]);
    const schema = payload(responses.get(1));
    assert.equal(schema.type, 'object');
    assert.deepEqual(schema.required, ['plan']);
    assert.ok(schema.$defs.exercise);
    // The preamble `dart run` prints is not JSON; if the server stopped stripping
    // it, this parse would have failed above.
});

test('create_plan returns a document that analyze_plan finds clean', async () => {
    const responses = await rpc([
        {
            jsonrpc: '2.0',
            id: 1,
            method: 'tools/call',
            params: {
                name: 'create_plan',
                arguments: { name: 'MCP Test', teams: 2, lang: 'en' },
            },
        },
    ]);
    const { document } = payload(responses.get(1));
    assert.match(document, /^# RingDrill source document/);
    assert.match(document, /CHANGE-ME/);

    const analysis = await rpc([
        {
            jsonrpc: '2.0',
            id: 1,
            method: 'tools/call',
            params: {
                name: 'analyze_plan',
                arguments: { document, strict: true },
            },
        },
    ]);
    const result = payload(analysis.get(1));
    assert.equal(result.errors, 0, JSON.stringify(result.diagnostics));
    assert.equal(result.warnings, 0, JSON.stringify(result.diagnostics));
    assert.equal(result.ok, true);
});

test('analyze_plan reports a bad reference as a result, not a crash', async () => {
    // A document with errors is what the agent asked about; the call must succeed
    // and carry the diagnostics, flagged so a rejection is not read as a pass.
    const document = [
        'plan:',
        '  name: "Broken"',
        'exercises:',
        '  - name: "Ex"',
        '    startTime: "09:00"',
        '    numberOfTeams: 1',
        '    numberOfRounds: 1',
        '    executionTime: 15',
        '    evaluationTime: 5',
        '    rotationTime: 2',
        '    stations:',
        '      - name: "Post"',
        '        situation: "Comms on {{var.nope}}."',
        '',
    ].join('\n');

    const responses = await rpc([
        {
            jsonrpc: '2.0',
            id: 1,
            method: 'tools/call',
            params: { name: 'analyze_plan', arguments: { document } },
        },
    ]);
    const response = responses.get(1);
    assert.equal(response.result.isError, true);
    const result = payload(response);
    assert.equal(result.errors, 1);
    assert.match(result.diagnostics[0].message, /no variable named "nope"/);
});

test('build_plan returns the archive base64-encoded', async () => {
    const created = await rpc([
        {
            jsonrpc: '2.0',
            id: 1,
            method: 'tools/call',
            params: {
                name: 'create_plan',
                arguments: { name: 'MCP Build', teams: 2 },
            },
        },
    ]);
    const { document } = payload(created.get(1));

    const built = await rpc([
        {
            jsonrpc: '2.0',
            id: 1,
            method: 'tools/call',
            params: { name: 'build_plan', arguments: { document } },
        },
    ]);
    const result = payload(built.get(1));
    assert.equal(result.name, 'MCP Build');
    assert.equal(result.exercises, 1);
    assert.match(result.contentHash, /^[0-9a-f]{64}$/);

    const bytes = Buffer.from(result.drillBase64, 'base64');
    // A .drill is a ZIP; "PK" is the signature DrillFile itself sniffs for.
    assert.equal(bytes.subarray(0, 2).toString(), 'PK');
    assert.equal(bytes.length, result.size);
});

test('render_plan produces the brief a director reads', async () => {
    const created = await rpc([
        {
            jsonrpc: '2.0',
            id: 1,
            method: 'tools/call',
            params: {
                name: 'create_plan',
                arguments: { name: 'MCP Render', teams: 2, lang: 'en' },
            },
        },
    ]);
    const { document } = payload(created.get(1));

    const rendered = await rpc([
        {
            jsonrpc: '2.0',
            id: 1,
            method: 'tools/call',
            params: {
                name: 'render_plan',
                arguments: { document, audience: 'director' },
            },
        },
    ]);
    const result = payload(rendered.get(1));
    assert.equal(result.audience, 'director');
    assert.match(result.markdown, /# MCP Render/);
    // Director-only content is present, and the scaffold's tokens resolved.
    assert.match(result.markdown, /Instructor-only notes/);
    assert.ok(!result.markdown.includes('{{'), 'a token was left unresolved');
});
