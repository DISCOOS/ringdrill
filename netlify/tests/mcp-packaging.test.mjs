// The hosted MCP endpoint, driven as Netlify actually packages it.
//
// `mcp-endpoint.test.mjs` imports the handler from the checkout, which is a
// different program from the one that gets deployed: Netlify's bundler inlines every
// local import into a single `netlify/functions/mcp.mjs` and copies
// `included_files` in beside it at their repo-relative paths. Anything that depends
// on where a file *is* — and this function reads two kinds of file at runtime — is
// therefore untested by every other suite here.
//
// It cost an outage to learn that. `lib/mcp-compiler.js` resolved the cross-compiled
// bundle relative to `import.meta.url`, true in a checkout and false once inlined,
// and every compiler tool on the live endpoint answered `ENOENT: no such file or
// directory, open '/var/task/netlify/functions/mcp-compiler-bundle.js'` while
// `initialize`, `tools/list`, `resources/read` and `search_catalog` kept working —
// so the server introspected as healthy and failed only when asked to do its job.
//
// This packages the real function with the real `netlify.toml`, then calls it with
// the package root as the working directory, which is what Netlify does. It is the
// slowest test in the suite (a few seconds) and worth it: it is the only one that
// sees the deployed layout.
//
// Requires the bundle. Run `make mcp-bundle` if this fails to load.
import { test } from "node:test";
import assert from "node:assert/strict";
import { access, mkdtemp } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import { resolveConfig } from "@netlify/config";
import { zipFunction } from "@netlify/zip-it-and-ship-it";

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
const ENDPOINT = "https://api.ringdrill.app/mcp";

/// Packages `netlify/functions/mcp.js` the way a deploy does and returns the
/// bundler's own result, whose `.path` is the unpacked directory — the equivalent of
/// `/var/task`.
///
/// Note that the tool calls below run through the real default export, so they meet
/// the real rate limiter with no Blobs environment behind it. It degrades open by
/// design (lib/mcp-rate-limit.js), which is what keeps this suite about packaging.
///
/// `archiveFormat: "none"` skips the zip step, so the result can be inspected and
/// imported directly. The function config comes from the real `netlify.toml` via
/// Netlify's own resolver rather than a literal here, because a wrong
/// `included_files` is one of the failures this is meant to catch — a copy of the
/// list would agree with itself and with nothing that ships.
async function packageFunction() {
    const { config } = await resolveConfig({
        repositoryRoot: repoRoot,
        cwd: repoRoot,
        mode: "cli",
        // No network, no site lookup: this is a pure read of the committed config.
        offline: true,
    });
    const functions = Object.fromEntries(
        Object.entries(config.functions ?? {}).map(([name, value]) => [
            name,
            { includedFiles: value.included_files ?? [] },
        ]),
    );

    const dest = await mkdtemp(join(tmpdir(), "ringdrill-mcp-pkg-"));
    const source = join(repoRoot, "netlify/functions/mcp.js");
    const result = await zipFunction(source, dest, {
        archiveFormat: "none",
        basePath: repoRoot,
        repositoryRoot: repoRoot,
        config: functions,
    });
    assert.ok(result, "zip-it-and-ship-it produced no package for mcp");
    return result;
}

/// Packaged once and shared: bundling is the expensive part, and every test here
/// wants the same artefact.
const packaged = packageFunction();

/// Imports the packaged function and calls it with `cwd` set to the package root,
/// which is the one detail that makes this different from importing the source.
async function callPackaged(body) {
    const { path: root } = await packaged;
    const previousCwd = process.cwd();
    process.chdir(root);
    try {
        const { default: handler } = await import(
            join(root, "netlify/functions/mcp.mjs")
        );
        const response = await handler(
            new Request(ENDPOINT, {
                method: "POST",
                headers: { "content-type": "application/json" },
                body: JSON.stringify(body),
            }),
        );
        return await response.json();
    } finally {
        process.chdir(previousCwd);
    }
}

/// Unwraps a tools/call reply, failing loudly on `isError` so a packaging fault
/// reads as "the bundle was not found" rather than "the schema looked wrong".
function toolText(reply) {
    assert.ok(!reply.error, () => `JSON-RPC error: ${JSON.stringify(reply.error)}`);
    const text = reply.result?.content?.[0]?.text;
    assert.notEqual(
        reply.result?.isError,
        true,
        () => `tool reported an error: ${text}`,
    );
    return text;
}

test("the package contains every file the function reads at runtime", async () => {
    const { path: root } = await packaged;

    // The compiler bundle and the two guide resources (ADR-0060, ADR-0065). Their
    // paths are asserted, not just their presence: the outage was a path
    // disagreement, and a file present somewhere else is still a broken deploy.
    for (const relative of [
        "netlify/functions/lib/mcp-compiler-bundle.js",
        "skills/ringdrill-plan-authoring/SKILL.md",
        "skills/ringdrill-plan-authoring/reference/format.md",
        // The entry point, at the path whose directory is *not* where the bundle
        // lives. If this ever moves next to lib/, the resolution comment in
        // lib/mcp-compiler.js needs revisiting.
        "netlify/functions/mcp.mjs",
    ]) {
        await assert.doesNotReject(
            () => access(join(root, relative)),
            `${relative} is missing from the deployed package`,
        );
    }
});

test("the compiler tools work in the deployed layout", async () => {
    // `schema` is the cheapest call that has to reach the cross-compiled bundle,
    // and it is the one a client makes first — it was the first thing to fail.
    const schema = JSON.parse(
        toolText(
            await callPackaged({
                jsonrpc: "2.0",
                id: 1,
                method: "tools/call",
                params: { name: "schema", arguments: {} },
            }),
        ),
    );
    assert.equal(schema.$id, "https://ringdrill.app/schema/source/1.0");

    // And one that compiles, so this covers more than reading the file.
    const created = JSON.parse(
        toolText(
            await callPackaged({
                jsonrpc: "2.0",
                id: 2,
                method: "tools/call",
                params: { name: "create_plan", arguments: { name: "Packaging" } },
            }),
        ),
    );
    assert.equal(created.ok, true);
    assert.match(created.document, /^# RingDrill source document/);
});

test("the guide resources are readable in the deployed layout", async () => {
    const reply = await callPackaged({
        jsonrpc: "2.0",
        id: 3,
        method: "resources/read",
        params: { uri: "ringdrill://guide/authoring" },
    });
    assert.ok(!reply.error, () => `JSON-RPC error: ${JSON.stringify(reply.error)}`);
    assert.match(
        reply.result.contents[0].text,
        /name: ringdrill-plan-authoring/,
        "the authoring guide did not come back from the packaged function",
    );
});
