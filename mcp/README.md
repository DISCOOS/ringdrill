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

**`publish` is deliberately absent.** The catalog is a shared, wiki-model corpus,
and an agent should not write to it unattended. Publishing stays a human running
`ringdrill publish`.

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

A checkout already carries [`.mcp.json`](../.mcp.json) at the repo root, so in
Claude Code the server is offered on approval with nothing to edit and no absolute
path to paste:

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

For a client configured by hand, `make mcp` prints the block with the absolute path
filled in.

`RINGDRILL_CLI` overrides the resolution above — pin a specific binary, or force
`dart run` when you want to skip the rebuild step:

```json
"env": { "RINGDRILL_CLI": "dart run /path/to/ringdrill/bin/ringdrill.dart" }
```

The server tolerates the `Running build hooks...` preamble `dart run` prints, so
that form works.

`RINGDRILL_BASE_URL` is read by the CLI itself and points the catalog tools at a
different backend — see [`docs/api.md`](../docs/api.md).

### Cowork, and why a local server is not enough

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
