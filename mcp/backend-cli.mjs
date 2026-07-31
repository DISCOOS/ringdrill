// The local backend: every operation shells out to the `ringdrill` CLI.
//
// Paired with `backend-compiler.js` on the hosted side (ADR-0060), which calls the
// cross-compiled Dart in-process instead. Same six operations, same return shapes,
// so `tools.mjs` does not know which one it has — which is what lets one tool table
// serve both.
//
// This one keeps the local server's defining property: the document never leaves
// the machine, and the CLI it runs is the one built from this checkout.
import { spawn, spawnSync } from 'node:child_process';
import { existsSync, readdirSync, statSync } from 'node:fs';
import { mkdtemp, rm, writeFile, readFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

/// The `build/cli` directory name `dart build cli` would use on this host, or null
/// for a platform/arch pair we have no mapping for.
function hostPlatformSegment() {
    const os = { darwin: 'macos', linux: 'linux', win32: 'windows' }[
        process.platform
    ];
    const arch = { arm64: 'arm64', x64: 'x64' }[process.arch];
    return os && arch ? `${os}_${arch}` : null;
}

/// Null when [binary] runs, otherwise why it does not.
///
/// Existence is not runnability. A repo mounted or copied across machines carries
/// whatever `build/cli` it was built with, and running a Mach-O binary on Linux
/// fails in a way that names no cause: the kernel refuses the header, the shell
/// falls back to reading it as a script, and the caller gets
/// `Syntax error: word unexpected`. Neither an agent nor a person can recover from
/// that message. A truncated or half-written binary fails the same way, which a
/// platform-name check alone would not catch — so probe rather than infer.
///
/// One spawn at startup, not per call, so this does not touch the latency budget
/// the resolution order exists to protect. `--help` exits 0 and writes only usage.
function whyNotExecutable(binary) {
    const probe = spawnSync(binary, ['--help'], { stdio: 'ignore' });
    if (probe.error) return probe.error.message;
    if (probe.status !== 0) return `exited ${probe.status}`;
    return null;
}

/// Locates the CLI, preferring whatever is fastest and most likely to be current.
///
/// `dart run` costs ~2.9s per call against ~0.6s for a compiled binary, and
/// `get_plan` alone makes two calls — so from a checkout the difference between
/// "configured well" and "not" is the difference between usable and not. Resolving
/// it here rather than making everyone set RINGDRILL_CLI is the whole point:
/// `make mcp` builds the binary, and this finds it.
///
/// Order: an explicit override, then a locally built binary that runs, then a
/// globally activated one, then `dart run` as the always-works fallback.
export function resolveCli(repoRoot, { log = () => {} } = {}) {
    if (process.env.RINGDRILL_CLI) {
        return { command: process.env.RINGDRILL_CLI, source: 'RINGDRILL_CLI' };
    }

    // `dart build cli` writes build/cli/<platform>/bundle/bin/ringdrill. Try the
    // segment matching this host first; keep a glob as a second pass so a segment
    // name we did not anticipate still works, and probe either way.
    const cliDir = join(repoRoot, 'build', 'cli');
    if (existsSync(cliDir)) {
        const host = hostPlatformSegment();
        const present = readdirSync(cliDir);
        const ordered = [
            ...present.filter((p) => p === host),
            ...present.filter((p) => p !== host),
        ];
        for (const platform of ordered) {
            const binary = join(cliDir, platform, 'bundle', 'bin', 'ringdrill');
            if (!existsSync(binary)) continue;
            const problem = whyNotExecutable(binary);
            if (problem) {
                // Say so: an unexplained fall-through to the slow path is the kind
                // of thing that gets diagnosed twice.
                log(
                    `ignoring ${binary} — ${problem}` +
                        `${platform === host ? '' : ` (built for ${platform}, host is ${host ?? 'unknown'})`}`,
                );
                continue;
            }
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
export function warnIfStale(repoRoot, resolved, log) {
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
        log(
            `the built CLI is older than ${newestPath.slice(repoRoot.length + 1)}. ` +
                'Run `make mcp` to rebuild, or you are testing stale code.',
        );
    }
}

/// A backend that runs the CLI as a subprocess.
export function createCliBackend({ cli, cwd }) {
    /** Runs the CLI and returns its parsed `--json` output. */
    async function run(args, { json = true } = {}) {
        const argv = json ? [...args, '--json'] : args;
        const parts = cli.split(' ');
        const child = spawn(parts[0], [...parts.slice(1), ...argv], {
            cwd,
            stdio: ['pipe', 'pipe', 'pipe'],
        });
        child.stdin.end();

        let stdout = '';
        let stderr = '';
        child.stdout.on('data', (d) => (stdout += d));
        child.stderr.on('data', (d) => (stderr += d));
        const code = await new Promise((resolve, reject) => {
            child.on('error', reject);
            child.on('close', resolve);
        });

        if (!json) {
            if (code !== 0) {
                throw new Error(
                    `ringdrill ${argv.join(' ')} failed (exit ${code}): ` +
                        `${stderr.trim() || 'no output'}`,
                );
            }
            return stdout;
        }

        // `dart run` prints "Running build hooks..." to stdout before the
        // program's own output, so the payload cannot be assumed to start at byte
        // zero. Take from the first brace; if there is none, there is no JSON.
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
            // A non-zero exit with diagnostics is a *result*, not a transport
            // failure: "your document has three errors" is exactly what the agent
            // asked for. Only a run that produced no JSON at all is an error.
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

    /// Runs `fn(documentPath, scratchDir)` for either input shape (ADR-0064).
    ///
    /// With `document_path` the author's own file goes straight to the CLI —
    /// nothing is copied, so a large document costs a filename rather than its
    /// own length on every call. A scratch directory is still provided, because
    /// `build` needs somewhere to write the archive.
    ///
    /// The path is not validated here: the CLI reports a missing or unreadable
    /// file better than this layer could, and reading it is the same capability
    /// the CLI has always had as this user.
    async function withDocument(args, fn) {
        // The hosted cache does not exist here, and does not need to: locally the
        // document is already a file, which `document_path` names directly and for
        // free (ADR-0064). `cache: true` is therefore a no-op — the response carries
        // no `document_hash`, so an agent has nothing to send back and corrects
        // itself — but a hash that arrived anyway must say what to do instead.
        if (args.document_hash !== undefined && args.document === undefined) {
            throw new Error(
                'document_hash names a document held by the hosted server; this ' +
                    'local server has no cache. Pass `document_path` instead — it ' +
                    'costs a filename, which is what the cache was for.',
            );
        }
        const path = args.document_path;
        if (!path) return withTempFile(args.document, '.yaml', fn);
        const dir = await mkdtemp(join(tmpdir(), 'ringdrill-mcp-'));
        try {
            return await fn(path, dir);
        } finally {
            await rm(dir, { recursive: true, force: true });
        }
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

    return {
        schema: () => run(['schema']),

        create: async (args) => {
            const argv = ['create', `--name=${args.name}`, '--out=-'];
            for (const [flag, value] of [
                ['exercises', args.exercises],
                ['teams', args.teams],
                ['stations', args.stations],
                ['rounds', args.rounds],
                ['lang', args.lang],
            ]) {
                if (value !== undefined && value !== null) {
                    argv.push(`--${flag}=${value}`);
                }
            }
            if (args.bare) argv.push('--bare');
            // --out=- writes the document to stdout rather than JSON, because the
            // document *is* the result.
            const out = await run(argv, { json: false });
            const start = out.indexOf('#');
            return { document: start < 0 ? out : out.slice(start) };
        },

        analyze: (args) =>
            withDocument(args, (path) =>
                run(['analyze', path, ...(args.strict ? ['--strict'] : [])]),
            ),

        build: (args) =>
            withDocument(args, async (path, dir) => {
                const out = join(dir, 'plan.drill');
                const result = await run([
                    'build',
                    path,
                    `--out=${out}`,
                    ...(args.strict ? ['--strict'] : []),
                ]);
                if (result.ok === false) return result;
                const bytes = await readFile(out);
                return { ...result, drillBase64: bytes.toString('base64') };
            }),

        render: (args) =>
            withDocument(args, (path) => {
                const argv = ['render', path];
                if (args.audience) argv.push(`--audience=${args.audience}`);
                if (args.lang) argv.push(`--lang=${args.lang}`);
                if (args.exercise) argv.push(`--exercise=${args.exercise}`);
                if (args.station) argv.push(`--station=${args.station}`);
                if (args.format) argv.push(`--format=${args.format}`);
                return run(argv);
            }),

        searchCatalog: ({ limit, cursor }) => {
            const argv = ['feed'];
            if (limit) argv.push(`--limit=${limit}`);
            if (cursor) argv.push(`--cursor=${cursor}`);
            return run(argv);
        },

        getPlan: async ({ slug, version }) => {
            const dir = await mkdtemp(join(tmpdir(), 'ringdrill-mcp-'));
            const drill = join(dir, `${slug}.drill`);
            try {
                const argv = ['download', slug, `--out=${drill}`];
                if (version) argv.push(`--version=${version}`);
                await run(argv);
                return await run(['decompile', drill]);
            } finally {
                await rm(dir, { recursive: true, force: true });
            }
        },
    };
}
