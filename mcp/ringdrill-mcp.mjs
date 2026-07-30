#!/usr/bin/env node
// RingDrill MCP server — the DESIGN-014 stage 4 deployment surface.
//
// Wraps the `ringdrill` CLI so an agent can search the catalog, read a published
// plan as a source document, scaffold, check, compile and render one. The CLI is
// the only implementation: this file marshals arguments and JSON, and owns no
// knowledge of the source format. That is deliberate — the format already has
// three descriptions too many (the Dart field table, the JSON Schema it
// generates, and the JS in the Netlify publish path), and a fourth living here
// would drift the moment the table changed.
//
// `publish` is deliberately absent. The catalog is a wiki-model shared corpus and
// an agent should not write to it unattended (DESIGN-014); publishing stays a
// human running `ringdrill publish`.
//
// Speaks MCP over stdio directly rather than through the SDK: the protocol
// surface needed here is `initialize`, `tools/list` and `tools/call`, which is
// less code than the dependency would be — and this repo's package.json is the
// Netlify functions package, so adding one there would couple the backend's
// dependency tree to an agent-tooling concern.
import { spawn } from 'node:child_process';
import { mkdtemp, rm, writeFile, readFile } from 'node:fs/promises';
import { existsSync, readdirSync, statSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { createInterface } from 'node:readline';
import { fileURLToPath } from 'node:url';

const PROTOCOL_VERSION = '2024-11-05';
const SERVER_INFO = { name: 'ringdrill', version: '1.0.0' };

const repoRoot = dirname(dirname(fileURLToPath(import.meta.url)));

/// Locates the CLI, preferring whatever is fastest and most likely to be current.
///
/// `dart run` costs ~2.9s per call against ~0.6s for a compiled binary, and
/// `get_plan` alone makes two calls — so from a checkout the difference between
/// "configured well" and "not" is the difference between usable and not. Resolving
/// it here rather than making everyone set RINGDRILL_CLI is the whole point:
/// `make mcp` builds the binary, and this finds it.
///
/// Order: an explicit override, then a locally built binary, then a globally
/// activated one, then `dart run` as the always-works fallback.
function resolveCli() {
    if (process.env.RINGDRILL_CLI) {
        return { command: process.env.RINGDRILL_CLI, source: 'RINGDRILL_CLI' };
    }

    // `dart build cli` writes build/cli/<platform>/bundle/bin/ringdrill; the
    // platform segment varies by host, so glob rather than hardcode it.
    const cliDir = join(repoRoot, 'build', 'cli');
    if (existsSync(cliDir)) {
        for (const platform of readdirSync(cliDir)) {
            const binary = join(cliDir, platform, 'bundle', 'bin', 'ringdrill');
            if (!existsSync(binary)) continue;
            return { command: binary, source: 'build/cli', path: binary };
        }
    }

    return {
        command: `dart run ${join(repoRoot, 'bin', 'ringdrill.dart')}`,
        source: 'dart run (slow — run `make mcp` to build a binary)',
    };
}

/// Warns when a built binary predates the Dart sources.
///
/// The footgun this exists for: edit Dart, forget to rebuild, spend twenty
/// minutes testing the previous version's behaviour. Cheap to check and it costs
/// nothing when the binary is current.
function warnIfStale(resolved) {
    if (!resolved.path) return;
    const built = statSync(resolved.path).mtimeMs;
    let newest = 0;
    let newestPath = '';
    const walk = (dir) => {
        for (const entry of readdirSync(dir, { withFileTypes: true })) {
            const full = join(dir, entry.name);
            if (entry.isDirectory()) {
                walk(full);
            } else if (entry.name.endsWith('.dart')) {
                const at = statSync(full).mtimeMs;
                if (at > newest) {
                    newest = at;
                    newestPath = full;
                }
            }
        }
    };
    for (const dir of ['lib', 'bin']) {
        const full = join(repoRoot, dir);
        if (existsSync(full)) walk(full);
    }
    if (newest > built) {
        const relative = newestPath.slice(repoRoot.length + 1);
        process.stderr.write(
            `ringdrill-mcp: the built CLI is older than ${relative}. ` +
                'Run `make mcp` to rebuild, or you are testing stale code.\n',
        );
    }
}

const resolved = resolveCli();
const CLI = resolved.command;
// To stderr, never stdout: stdout is the JSON-RPC stream. Which CLI is in use is
// the first thing you want to know when a tool behaves unexpectedly.
process.stderr.write(`ringdrill-mcp: using CLI from ${resolved.source}\n`);
warnIfStale(resolved);

/** Runs the CLI and returns its parsed `--json` output. */
async function cli(args, { input } = {}) {
    const argv = [...args, '--json'];
    const parts = CLI.split(' ');
    const child = spawn(parts[0], [...parts.slice(1), ...argv], {
        stdio: ['pipe', 'pipe', 'pipe'],
    });
    if (input !== undefined) child.stdin.write(input);
    child.stdin.end();

    let stdout = '';
    let stderr = '';
    child.stdout.on('data', (d) => (stdout += d));
    child.stderr.on('data', (d) => (stderr += d));
    const code = await new Promise((resolve, reject) => {
        child.on('error', reject);
        child.on('close', resolve);
    });

    // `dart run` prints "Running build hooks..." to stdout before the program's
    // own output, so the payload cannot be assumed to start at byte zero. Take
    // from the first brace; if there is none, there is no JSON to find.
    const parse = (text) => {
        const start = text.indexOf('{');
        if (start < 0) return null;
        try {
            return JSON.parse(text.slice(start));
        } catch {
            return null;
        }
    };

    const payload = parse(stdout) ?? parse(stderr);
    if (code !== 0) {
        // A non-zero exit with diagnostics is a *result*, not a transport failure:
        // "your document has three errors" is exactly what the agent asked for.
        // Only a run that produced no JSON at all is an error.
        if (payload) return { ...payload, ok: false, exitCode: code };
        throw new Error(
            `ringdrill ${argv.join(' ')} failed (exit ${code}): ` +
                `${stderr.trim() || stdout.trim() || 'no output'}`,
        );
    }
    if (!payload) {
        throw new Error(
            `ringdrill ${argv.join(' ')} produced no JSON: ${stdout.trim()}`,
        );
    }
    return payload;
}

/** Runs `fn` with a temp file holding `content`, then removes it. */
async function withTempFile(content, extension, fn) {
    const dir = await mkdtemp(join(tmpdir(), 'ringdrill-mcp-'));
    const path = join(dir, `document${extension}`);
    await writeFile(path, content, 'utf8');
    try {
        return await fn(path, dir);
    } finally {
        await rm(dir, { recursive: true, force: true });
    }
}

const SOURCE_DOCUMENT_ARG = {
    type: 'string',
    description:
        'The source document, as YAML text. Call `schema` for its shape, or ' +
        '`create_plan` for a starting point.',
};

// The tool surface. Descriptions are the agent's only documentation, so they say
// what the tool is *for* and which mistake it prevents — not just what it does.
const TOOLS = [
    {
        name: 'schema',
        description:
            "The source format's JSON Schema. Read this before writing a " +
            'document: it is generated from the same field table the compiler ' +
            'validates against, so it cannot describe a field `build_plan` will ' +
            'reject. Note especially that derived fields (schedule, endTime, ' +
            'indices, uuids, contentHash) are absent by design — the compiler ' +
            'fills them, and numbering comes from list position, never from a name.',
        inputSchema: { type: 'object', properties: {} },
        run: () => cli(['schema']),
    },
    {
        name: 'search_catalog',
        description:
            'List published plans in the open catalog, with their tags. The ' +
            'catalog is the corpus: read a few plans with `get_plan` before ' +
            'writing one, so a generated plan matches how real ones are written.',
        inputSchema: {
            type: 'object',
            properties: {
                limit: { type: 'integer', description: 'Page size. Default 50.' },
                cursor: { type: 'string', description: 'Pagination cursor.' },
                query: {
                    type: 'string',
                    description:
                        'Case-insensitive filter over name, slug and tags. ' +
                        'Applied to the page fetched, not server-side.',
                },
            },
        },
        run: async ({ limit, cursor, query }) => {
            const args = ['feed'];
            if (limit) args.push(`--limit=${limit}`);
            if (cursor) args.push(`--cursor=${cursor}`);
            const page = await cli(args);
            if (!query) return page;
            const needle = query.toLowerCase();
            return {
                ...page,
                items: (page.items ?? []).filter((i) =>
                    [i.name, i.slug, ...(i.tags ?? [])]
                        .join(' ')
                        .toLowerCase()
                        .includes(needle),
                ),
            };
        },
    },
    {
        name: 'get_plan',
        description:
            'Download a published plan and return it as a *source document* — ' +
            'the same format you write, not the raw archive. This is how to read ' +
            'the corpus: the uuids it carries mean an edited copy rebuilds onto ' +
            'the same plan rather than a duplicate.',
        inputSchema: {
            type: 'object',
            properties: {
                slug: { type: 'string', description: 'Catalog slug.' },
                version: { type: 'integer', description: 'Default: latest.' },
            },
            required: ['slug'],
        },
        run: async ({ slug, version }) => {
            const dir = await mkdtemp(join(tmpdir(), 'ringdrill-mcp-'));
            const drill = join(dir, `${slug}.drill`);
            try {
                const args = ['download', slug, `--out=${drill}`];
                if (version) args.push(`--version=${version}`);
                await cli(args);
                return await cli(['decompile', drill]);
            } finally {
                await rm(dir, { recursive: true, force: true });
            }
        },
    },
    {
        name: 'create_plan',
        description:
            'Scaffold a starting source document. Faster and safer than writing ' +
            'one from scratch: it builds clean as-is and demonstrates the ' +
            'scenario layer (a station-owned location and person addressed by ' +
            'slug, prose referencing them, a role play portraying the person).',
        inputSchema: {
            type: 'object',
            properties: {
                name: { type: 'string', description: 'Plan name.' },
                exercises: { type: 'integer', description: 'Default 1.' },
                teams: { type: 'integer', description: 'Default 4.' },
                stations: {
                    type: 'integer',
                    description:
                        'Stations per exercise. Default: the team count, the ' +
                        'fewest a rotation can have.',
                },
                rounds: {
                    type: 'integer',
                    description: 'Default: the station count.',
                },
                lang: {
                    type: 'string',
                    description: "ISO 639-1 content language. Default 'en'.",
                },
                bare: {
                    type: 'boolean',
                    description: 'Omit the worked scenario example.',
                },
            },
            required: ['name'],
        },
        run: async ({ name, exercises, teams, stations, rounds, lang, bare }) => {
            const args = ['create', `--name=${name}`, '--out=-'];
            if (exercises) args.push(`--exercises=${exercises}`);
            if (teams) args.push(`--teams=${teams}`);
            if (stations) args.push(`--stations=${stations}`);
            if (rounds) args.push(`--rounds=${rounds}`);
            if (lang) args.push(`--lang=${lang}`);
            if (bare) args.push('--bare');
            // --out=- writes the document to stdout rather than JSON, because the
            // document *is* the result.
            const parts = CLI.split(' ');
            const child = spawn(parts[0], [...parts.slice(1), ...args]);
            let out = '';
            child.stdout.on('data', (d) => (out += d));
            let err = '';
            child.stderr.on('data', (d) => (err += d));
            const code = await new Promise((resolve, reject) => {
                child.on('error', reject);
                child.on('close', resolve);
            });
            if (code !== 0) {
                throw new Error(`create failed (exit ${code}): ${err.trim()}`);
            }
            // Strip the `dart run` build-hooks preamble, which is not YAML.
            const start = out.indexOf('#');
            return { document: start < 0 ? out : out.slice(start) };
        },
    },
    {
        name: 'analyze_plan',
        description:
            'Check a source document without building it. Catches what compiles ' +
            'fine but will not render: a {{var.x}} naming no declared variable, ' +
            'a {{station.loc.x}} on a station that owns no such location, a ' +
            'misspelled or wrong-scope reference. Always run this before ' +
            'presenting a document as finished — tokens are stored raw, so these ' +
            'mistakes are invisible until a reader is holding the brief.',
        inputSchema: {
            type: 'object',
            properties: {
                document: SOURCE_DOCUMENT_ARG,
                strict: {
                    type: 'boolean',
                    description: 'Treat warnings as errors.',
                },
            },
            required: ['document'],
        },
        run: ({ document, strict }) =>
            withTempFile(document, '.yaml', (path) =>
                cli(['analyze', path, ...(strict ? ['--strict'] : [])]),
            ),
    },
    {
        name: 'build_plan',
        description:
            'Compile a source document to a .drill archive and return it ' +
            'base64-encoded, plus the plan summary and content hash. Does not ' +
            'publish: the catalog is a shared corpus, so putting a plan in it ' +
            'stays a human step.',
        inputSchema: {
            type: 'object',
            properties: {
                document: SOURCE_DOCUMENT_ARG,
                strict: {
                    type: 'boolean',
                    description: 'Refuse to build if there are warnings.',
                },
            },
            required: ['document'],
        },
        run: ({ document, strict }) =>
            withTempFile(document, '.yaml', async (path, dir) => {
                const out = join(dir, 'plan.drill');
                const result = await cli([
                    'build',
                    path,
                    `--out=${out}`,
                    ...(strict ? ['--strict'] : []),
                ]);
                if (result.ok === false) return result;
                const bytes = await readFile(out);
                return { ...result, drillBase64: bytes.toString('base64') };
            }),
    },
    {
        name: 'render_plan',
        description:
            'Render the markdown brief for a source document — what a ' +
            'participant, instructor or director actually reads. The fastest way ' +
            'to check that a plan makes sense: unresolved tokens and thin ' +
            'sections are obvious in the brief and invisible in the source.',
        inputSchema: {
            type: 'object',
            properties: {
                document: SOURCE_DOCUMENT_ARG,
                audience: {
                    type: 'string',
                    enum: ['participant', 'instructor', 'director'],
                    description: 'Default participant.',
                },
                lang: {
                    type: 'string',
                    description: "Default: the plan's own content language.",
                },
                exercise: {
                    type: 'integer',
                    description:
                        '1-based exercise number to scope to. Default: whole plan.',
                },
            },
            required: ['document'],
        },
        run: ({ document, audience, lang, exercise }) =>
            withTempFile(document, '.yaml', (path) => {
                const args = ['render', path];
                if (audience) args.push(`--audience=${audience}`);
                if (lang) args.push(`--lang=${lang}`);
                if (exercise) args.push(`--exercise=${exercise}`);
                return cli(args);
            }),
    },
];

const TOOLS_BY_NAME = new Map(TOOLS.map((t) => [t.name, t]));

function respond(id, result) {
    process.stdout.write(
        `${JSON.stringify({ jsonrpc: '2.0', id, result })}\n`,
    );
}

function respondError(id, code, message) {
    process.stdout.write(
        `${JSON.stringify({ jsonrpc: '2.0', id, error: { code, message } })}\n`,
    );
}

async function handle(message) {
    const { id, method, params } = message;
    // A notification (no id) needs no reply; `notifications/initialized` is the
    // only one a client sends us.
    if (id === undefined || id === null) return;

    switch (method) {
        case 'initialize':
            return respond(id, {
                protocolVersion: PROTOCOL_VERSION,
                capabilities: { tools: {} },
                serverInfo: SERVER_INFO,
            });

        case 'tools/list':
            return respond(id, {
                tools: TOOLS.map(({ name, description, inputSchema }) => ({
                    name,
                    description,
                    inputSchema,
                })),
            });

        case 'tools/call': {
            const tool = TOOLS_BY_NAME.get(params?.name);
            if (!tool) {
                return respondError(
                    id,
                    -32602,
                    `Unknown tool "${params?.name}". Have: ` +
                        `${[...TOOLS_BY_NAME.keys()].join(', ')}.`,
                );
            }
            try {
                const result = await tool.run(params.arguments ?? {});
                return respond(id, {
                    content: [
                        { type: 'text', text: JSON.stringify(result, null, 2) },
                    ],
                    // Diagnostics are a result, not a failure — but flag a build
                    // or analysis that did not pass so the agent does not read a
                    // rejection as a success.
                    isError: result?.ok === false,
                });
            } catch (e) {
                // Reported as tool content rather than a protocol error so the
                // agent can react to it (fix the document, install the CLI)
                // instead of just seeing the call fail.
                return respond(id, {
                    content: [{ type: 'text', text: String(e.message ?? e) }],
                    isError: true,
                });
            }
        }

        case 'ping':
            return respond(id, {});

        default:
            return respondError(id, -32601, `Method not found: ${method}`);
    }
}

const lines = createInterface({ input: process.stdin });
for await (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed) continue;
    let message;
    try {
        message = JSON.parse(trimmed);
    } catch {
        respondError(null, -32700, 'Parse error');
        continue;
    }
    await handle(message);
}
