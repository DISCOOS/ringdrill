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
import { mkdtemp, mkdir, writeFile, rm, cp } from 'node:fs/promises';
import { tmpdir } from 'node:os';
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

/// Copies the server and the modules it imports into `<root>/mcp/`.
///
/// The two tests below run the server from a temp tree so a fake `build/cli`
/// cannot disturb the real one — the server derives its repo root from
/// `import.meta.url`, so where the file sits *is* the root it looks under. Every
/// sibling module has to come along, which is why this is a list rather than one
/// `cp`: forgetting one fails as a module-not-found with no hint that the sandbox
/// is what is incomplete.
async function copyServerInto(root) {
    await mkdir(join(root, 'mcp'), { recursive: true });
    for (const file of ['ringdrill-mcp.mjs', 'tools.mjs', 'backend-cli.mjs']) {
        await cp(join(here, '..', file), join(root, 'mcp', file));
    }
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

test('an unrunnable build/cli binary is rejected, not used', async () => {
    // The case that produced "Syntax error: word unexpected" from a Linux sandbox
    // holding a macOS build: existence is not runnability, and the error that
    // reached the agent named no cause. The server must reject the binary, say
    // which one and why, and fall through to a CLI that works.
    //
    // Run against a copy of the repo so a fake build/cli cannot disturb the real
    // one: the tree is symlinked except build/, which holds only the bad binary.
    const sandbox = await mkdtemp(join(tmpdir(), 'ringdrill-mcp-badcli-'));
    try {
        await copyServerInto(sandbox);
        // repoRoot comes from import.meta.url, so the server will look for
        // <sandbox>/build/cli and <sandbox>/bin/ringdrill.dart.
        const badDir = join(sandbox, 'build', 'cli', 'someother_arch', 'bundle', 'bin');
        await mkdir(badDir, { recursive: true });
        // Not a valid executable in any format — the same shape of failure as a
        // Mach-O binary on Linux or a truncated build.
        await writeFile(join(badDir, 'ringdrill'), 'not-an-executable\n', { mode: 0o755 });

        const child = spawn('node', [join(sandbox, 'mcp', 'ringdrill-mcp.mjs')], {
            cwd: repoRoot,
        });
        let stderr = '';
        child.stderr.on('data', (d) => (stderr += d));
        child.stdin.write(
            `${JSON.stringify({ jsonrpc: '2.0', id: 1, method: 'tools/list' })}\n`,
        );
        child.stdin.end();
        await new Promise((resolve) => child.on('close', resolve));

        assert.match(
            stderr,
            /ignoring .*someother_arch.*ringdrill —/,
            `expected the rejected path and reason on stderr, got: ${stderr}`,
        );
        // Fell through rather than committing to the unusable binary.
        assert.match(stderr, /using CLI from (?!build\/cli)/);
    } finally {
        await rm(sandbox, { recursive: true, force: true });
    }
});

test('the host platform segment is preferred over another that is present', async () => {
    // Ordering, not just probing: a stale directory for a different arch must not
    // be tried first even when it happens to be executable.
    const sandbox = await mkdtemp(join(tmpdir(), 'ringdrill-mcp-hostpick-'));
    try {
        await copyServerInto(sandbox);

        const host = `${{ darwin: 'macos', linux: 'linux', win32: 'windows' }[process.platform]}_${process.arch}`;
        // Both "binaries" are shell scripts that exit 0, so both pass the probe —
        // which is the point: only the ordering can distinguish them.
        for (const [segment, marker] of [[host, 'HOST'], ['zz_other_arch', 'OTHER']]) {
            const dir = join(sandbox, 'build', 'cli', segment, 'bundle', 'bin');
            await mkdir(dir, { recursive: true });
            await writeFile(
                join(dir, 'ringdrill'),
                `#!/bin/sh\necho '{"marker":"${marker}"}'\n`,
                { mode: 0o755 },
            );
        }

        const child = spawn('node', [join(sandbox, 'mcp', 'ringdrill-mcp.mjs')], {
            cwd: repoRoot,
        });
        let stdout = '';
        child.stdout.on('data', (d) => (stdout += d));
        child.stdin.write(
            `${JSON.stringify({
                jsonrpc: '2.0',
                id: 1,
                method: 'tools/call',
                params: { name: 'schema', arguments: {} },
            })}\n`,
        );
        child.stdin.end();
        await new Promise((resolve) => child.on('close', resolve));

        const message = JSON.parse(stdout.trim().split('\n').pop());
        assert.equal(
            JSON.parse(message.result.content[0].text).marker,
            'HOST',
            'the host-matching segment should be chosen',
        );
    } finally {
        await rm(sandbox, { recursive: true, force: true });
    }
});

test('a client that closes stdout mid-conversation gets a clean exit', async () => {
    // Writing to a pipe whose reader has gone raises an unhandled 'error' event,
    // which killed the process with a stack trace — a worse signal than a clean
    // exit, because nothing is actually wrong on this side.
    //
    // Destroying the read end from here rather than relying on a `head -c` makes
    // it deterministic: with a small response the write can fit the pipe buffer and
    // never fail at all, which is why this was easy to miss.
    const child = spawn('node', [server], {
        cwd: repoRoot,
        env: {
            ...process.env,
            RINGDRILL_CLI: `dart run ${join(repoRoot, 'bin', 'ringdrill.dart')}`,
        },
    });

    let stderr = '';
    child.stderr.on('data', (d) => (stderr += d));

    // One exchange so the transport is live, then take the reader away.
    child.stdin.write(
        `${JSON.stringify({ jsonrpc: '2.0', id: 1, method: 'initialize', params: {} })}\n`,
    );
    await new Promise((resolve) => child.stdout.once('data', resolve));
    child.stdout.destroy();

    // Keep talking. Every reply now has nowhere to go.
    for (let id = 2; id < 8; id++) {
        child.stdin.write(
            `${JSON.stringify({ jsonrpc: '2.0', id, method: 'tools/list' })}\n`,
        );
    }
    child.stdin.end();

    const code = await new Promise((resolve) => child.on('close', resolve));

    assert.equal(code, 0, `expected a clean exit, got ${code}: ${stderr}`);
    assert.ok(
        !stderr.includes('write EPIPE') && !stderr.includes('at respond'),
        `expected no stack trace on stderr, got: ${stderr}`,
    );
});
