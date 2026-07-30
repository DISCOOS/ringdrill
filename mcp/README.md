# RingDrill MCP server

`ringdrill-mcp.mjs` exposes the source-format commands of the `ringdrill` CLI as
MCP tools, so an agent can read the catalog, scaffold, check, compile and render a
drill plan. This is the stage 4 deployment surface of
[DESIGN-014](../docs/design/014-source-format-and-plan-compiler.md); the authoring
knowledge that goes with it lives in the
[`ringdrill-plan-authoring` skill](../skills/ringdrill-plan-authoring/SKILL.md).

The server owns no knowledge of the source format. Every tool shells out to the
CLI and passes its `--json` output through — the format already has three
descriptions (the Dart field table, the JSON Schema generated from it, and the JS
in the Netlify publish path) and a fourth here would drift the moment the table
changed.

## Tools

| Tool | Wraps |
|---|---|
| `schema` | `ringdrill schema` |
| `search_catalog` | `ringdrill feed`, with client-side filtering |
| `get_plan` | `ringdrill download` + `decompile` |
| `create_plan` | `ringdrill create` |
| `analyze_plan` | `ringdrill analyze` |
| `build_plan` | `ringdrill build`, returning the archive base64-encoded |
| `render_plan` | `ringdrill render` |

The hosted deployment runs the same operations against a cross-compiled copy of the
same compiler rather than the binary — see *How the hosted endpoint is built*.

**`publish` is deliberately absent.** The catalog is a shared, wiki-model corpus,
and an agent should not write to it unattended. Publishing stays a human running
`ringdrill publish`.

## Hosted or local?

Two deployments, one tool table (`tools.mjs`), so an agent sees the same seven tools
either way. What differs is where your document goes.

|  | Hosted | Local (stdio) |
|---|---|---|
| Setup | a URL | a checkout, Dart SDK, Node, `make mcp` |
| Where the plan text goes | to `api.ringdrill.app` | nowhere — it stays on the machine |
| Works in ChatGPT, remote Cowork | yes | no |
| Works offline | no | yes |

**Use the local server for anything you would not email.** Real plans are marked
staff-only — the anchor plan in the catalog opens with "KUN FOR STAB" — and the
hosted endpoint necessarily receives the text you send it. It **does not persist
documents**: it compiles the request and answers, there is no write path, and the
only storage it touches is a read of the already-public catalog
([ADR-0060](../docs/adrs/0060-remote-mcp-server.md)). That is a design requirement,
not a courtesy — but "not stored" is still not the same as "never sent", and only
the local server gives you the latter.

The hosted endpoint accepts documents up to 512 KB and bounds a compile at 10
seconds. Beyond that, use the local server.

## Running it locally

```bash
make mcp
```

Builds the CLI and prints the client config to paste in. That is the whole setup —
the server locates the CLI itself.

Poke at it without a client:

```bash
make mcp-call
```

```bash
make mcp-call ARGS='create_plan name="LSOR 2027" teams=4 lang=nb --raw'
```

`ARGS` is `<tool> key=value …` (see [`dev-call.mjs`](dev-call.mjs)): `@path` reads
a file into an argument, and `--raw` prints the payload — a document, a brief —
unwrapped instead of JSON-escaped. A tool that reports a problem exits non-zero, so
it composes in a script.

```bash
make mcp-call ARGS='analyze_plan document=@plan.yaml'
make mcp-call ARGS='render_plan document=@plan.yaml audience=director --raw'
make mcp-test
```

### How the CLI is located

Each tool call shells out to `ringdrill` once — `get_plan` twice — so which copy
gets used is the difference between usable and irritating: **~0.6s** for a compiled
binary against **~2.9s** for `dart run`. Resolution order:

1. `RINGDRILL_CLI`, if set
2. a binary built by `dart build cli` (what `make mcp` produces), preferring the
   `build/cli` directory matching this host and **probing it before use**
3. `ringdrill` on `PATH` (`dart pub global activate -s path .`)
4. `dart run bin/ringdrill.dart` — always works, slowest

Existence is not runnability, which is why step 2 probes. A repo mounted or copied
across machines carries whatever `build/cli` it was built with, and running a macOS
binary on Linux fails in a way that names no cause — the kernel refuses the header,
the shell reads it as a script, and the caller gets
`Syntax error: word unexpected`. A truncated or half-written build fails the same
way, which a platform-name check alone would not catch. A rejected candidate is
named on stderr with the reason, so falling back to the slow path is visible.

The server also writes which CLI it chose to stderr, and warns when a built binary
is older than the newest `.dart` file — the twenty-minutes-testing-stale-code
footgun. stderr, never stdout: stdout is the JSON-RPC stream, and a stray write to
it corrupts the transport.

## Requirements

Node ≥ 22.13 (matching the repo's `engines`). No npm dependencies: the server
speaks MCP over stdio directly, because the surface it needs is `initialize`,
`tools/list` and `tools/call` — less code than the SDK dependency would be, and
this repo's `package.json` is the Netlify functions package, so adding one there
would couple the backend's dependency tree to an agent-tooling concern.

## Configuring a client

Every client below runs the server the same way — `node mcp/ringdrill-mcp.mjs` — and
differs only in where the configuration lives and what it calls the keys. Get the
absolute path from `make mcp`.

Two things apply everywhere. **Absolute paths are the safe default**: only Claude
Code resolves a relative one, and Claude Desktop's own troubleshooting says paths
must be absolute. And **the server's diagnostics go to stderr** — which CLI it
resolved, a rejected binary, a stale build — so that is where to look when a tool
misbehaves; in Claude Desktop it lands in
`~/Library/Logs/Claude/mcp-server-ringdrill.log`.

### Claude Code

Nothing to do. A checkout carries [`.mcp.json`](../.mcp.json) at the repo root, so
the server is offered on approval:

```json
{
  "mcpServers": {
    "ringdrill": {
      "command": "node",
      "args": ["mcp/ringdrill-mcp.mjs"]
    }
  }
}
```

That relative path is resolved by the *launcher*, not by the server — the server
itself is cwd-independent, since it derives the repo root from `import.meta.url`
and finds `build/cli` and `bin/` from there regardless of where it was started.
Verified: an absolute path works from any working directory. **Not** verified: which
working directory the client launches with. If the relative form fails to resolve,
use an absolute path, or `${CLAUDE_PROJECT_DIR}/mcp/ringdrill-mcp.mjs` if your
client expands that.

### Claude Desktop

`~/Library/Application Support/Claude/claude_desktop_config.json` on macOS,
`%APPDATA%\Claude\claude_desktop_config.json` on Windows. Restart the app fully
after editing — it only reads this at launch.

```json
{
  "mcpServers": {
    "ringdrill": {
      "command": "node",
      "args": ["/absolute/path/to/ringdrill/mcp/ringdrill-mcp.mjs"]
    }
  }
}
```

### Codex CLI

`~/.codex/config.toml`, or a project-scoped `.codex/config.toml` in a trusted
directory. `codex mcp add` does it interactively.

```toml
[mcp_servers.ringdrill]
command = "node"
args = ["/absolute/path/to/ringdrill/mcp/ringdrill-mcp.mjs"]
```

If it fails to start, the usual cause is `node` not being on the PATH Codex
inherits — give an absolute path to the node binary too.

### VS Code (GitHub Copilot)

`.vscode/mcp.json` in the workspace. Note the top-level key is `servers`, not
`mcpServers`:

```json
{
  "servers": {
    "ringdrill": {
      "type": "stdio",
      "command": "node",
      "args": ["mcp/ringdrill-mcp.mjs"]
    }
  }
}
```

Not committed here, since `.vscode/` is a matter of personal preference.

### Using the hosted endpoint instead

Any client that takes a remote MCP server takes this one — no command, no path:

```
https://api.ringdrill.app/mcp
```

Claude Code: `claude mcp add --transport http ringdrill https://api.ringdrill.app/mcp`.
Claude Desktop and Codex CLI take a `url` in place of `command`/`args`. In VS Code,
`.vscode/mcp.json` takes `{"type": "http", "url": "…"}`.

### ChatGPT

ChatGPT's MCP connectors take a **remote HTTPS endpoint** and cannot launch a local
stdio server, so the hosted endpoint above is the only way in — add it as a
connector in developer mode. Read the privacy note in *Hosted or local?* first: a
plan sent to ChatGPT reaches both OpenAI and this endpoint.

### Cowork

A local server reaches a Cowork session only through the desktop app, and not at all
in a remote one — see [the constraint below](#cowork-and-why-a-local-server-is-not-enough).
The hosted endpoint has neither limitation, which is what it is for.

### Environment overrides

`RINGDRILL_CLI` overrides the resolution above — pin a specific binary, or force
`dart run` when you want to skip the rebuild step:

```json
"env": { "RINGDRILL_CLI": "dart run /path/to/ringdrill/bin/ringdrill.dart" }
```

The server tolerates the `Running build hooks...` preamble `dart run` prints, so
that form works.

`RINGDRILL_BASE_URL` is read by the CLI itself and points the catalog tools at a
different backend — see [`docs/api.md`](../docs/api.md).

## Cowork, and why a local server is not enough

A stdio server does **not** run inside the Cowork sandbox. A server configured in
the desktop app's own config is bridged into the session by the desktop app and runs
on the *host*, which is how it reaches a locally built binary at all. Two
consequences worth knowing before you rely on it:

* It works in the **desktop app only**. A remote Cowork session gets no local
  servers, so there is nothing to bridge.
* Bundling the server in a plugin manifest is currently a dead end: `mcpServers` in
  `plugin.json` is dropped during parsing
  ([anthropics/claude-code#16143](https://github.com/anthropics/claude-code/issues/16143)).
  The workaround is a `.mcp.json` inside the plugin directory.

This is the second, independent reason the stdio server cannot reach a
non-developer — the first being the toolchain requirement — and both are why
[ADR-0060](../docs/adrs/0060-remote-mcp-server.md) accepts remote hosting.

## How the hosted endpoint is built

`netlify/functions/mcp.js` is the transport; `lib/mcp-backend.js` the operations. The
compiler is the *same Dart source* as the app and the CLI, cross-compiled by
`make mcp-bundle` to `lib/mcp-compiler-bundle.js` and run in-process — so the format
still has one implementation (ADR-0058), and there is no subprocess, which is what
lets this be a function rather than a container.

Two constraints worth knowing before touching it:

* **The bundle is committed.** A Netlify build has no Dart SDK, so it cannot be
  produced at deploy time — the same reason `headless_labels.g.dart` and
  `brief_templates.g.dart` are committed. `make mcp-bundle` after changing anything
  the compiler reaches; `npm test` fails when the bundle is older than those
  sources, and a parity test compares its output against the VM's through the CLI.
* **esbuild must not touch it.** Netlify's bundler inlines imported modules, and
  doing that to dart2js output breaks Dart's runtime type information — every
  `analyze_plan` failed with `type 'minified:z2' is not a subtype of type
  'minified:z'` while simpler tools worked. `lib/mcp-compiler.js` therefore reads and
  evaluates the file at runtime, and `netlify.toml`'s `included_files` is what ships
  it. Do not turn that back into an `import`.
* **The helpers live in `lib/`, not beside the function.** Netlify treats every
  *top-level* file in the functions directory as a function of its own. Sitting
  there, `_mcp_compiler.js` was bundled a second time as an endpoint, where esbuild
  chose CJS and warned that `import.meta` would be empty — harmless for the real
  function, which bundles as ESM, but it also published a helper at
  `/.netlify/functions/_mcp_compiler` and, because `included_files` under the global
  `[functions]` table applies to every function, copied the 700 KB bundle into all
  sixteen deployment packages. A subdirectory is how Netlify is told "not a
  function", and `[functions."mcp"]` is how the data file is scoped to the one that
  needs it. The same applied to `_shared.js` and `_drill_pii.js`, which predated
  this and were live in production as functions returning 502; they moved to
  `lib/shared.js` and `lib/drill-pii.js` for the same reason.

## The raw protocol

`make mcp-call` is the convenient path; this is what it does underneath. The stdio
transport is newline-delimited JSON-RPC, so a pipe is enough:

```bash
printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' \
  | node mcp/ringdrill-mcp.mjs
```

`make mcp-test` (also part of `npm test`) drives it the same way over a real pipe
rather than by importing its internals — the transport is part of what can break,
and a stray write to stdout would corrupt the stream without any unit test
noticing. The tests deliberately set `RINGDRILL_CLI` to a `dart run` invocation, so
the preamble the server has to tolerate stays exercised.
