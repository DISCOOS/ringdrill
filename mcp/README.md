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

## Requirements

Node ≥ 22.13 (matching the repo's `engines`) and the `ringdrill` CLI on `PATH`:

```bash
dart pub global activate -s path .
```

No npm dependencies. The server speaks MCP over stdio directly — the surface it
needs is `initialize`, `tools/list` and `tools/call`, which is less code than the
SDK dependency would be, and this repo's `package.json` is the Netlify functions
package, so adding one there would couple the backend's dependency tree to an
agent-tooling concern.

## Configuring a client

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

`RINGDRILL_CLI` overrides how the CLI is invoked — useful in a checkout, where the
globally activated copy may be stale:

```json
"env": { "RINGDRILL_CLI": "dart run /path/to/ringdrill/bin/ringdrill.dart" }
```

The server tolerates the `Running build hooks...` preamble `dart run` prints, so
that form works; a compiled binary (`dart build cli`) is faster per call.

`RINGDRILL_BASE_URL` is read by the CLI itself and points the catalog tools at a
different backend — see [`docs/api.md`](../docs/api.md).

## Testing it by hand

The stdio protocol is newline-delimited JSON-RPC, so a pipe is enough:

```bash
printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' \
  | node mcp/ringdrill-mcp.mjs
```

`npm test` runs the server's own tests (`mcp/tests/`), which drive it the same way
over a real pipe rather than by importing its internals — the transport is part of
what can break.
