// Finding the cross-compiled bundle must survive the deployed layout, not just a
// checkout.
//
// This is a regression test for a production outage in which every compiler tool on
// the hosted MCP endpoint answered `ENOENT: no such file or directory, open
// '/var/task/netlify/functions/mcp-compiler-bundle.js'` while `initialize`,
// `tools/list`, `resources/read` and `search_catalog` all worked — so the server
// looked healthy to a client until it was asked to compile something.
//
// The cause is that a deployed function has a different shape from the tree it was
// built from. `lib/mcp-compiler.js` is not a file at runtime: esbuild inlines it into
// `netlify/functions/mcp.mjs`, so `import.meta.url` names the function at the
// functions root, one directory above the bundle that `included_files` shipped at its
// repo-relative path. Every existing test imports the module directly from the
// checkout, where those two paths happen to coincide, which is exactly why nothing
// caught it.
//
// So the layouts are built as directories here rather than mocked. The bundle stands
// in as a small file — this asserts resolution, and `mcp-compiler-parity.test.mjs`
// asserts the real bundle computes the right answers.
import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdir, mkdtemp, readFile, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join, sep } from "node:path";
import { fileURLToPath } from "node:url";

import {
    bundleCandidates,
    resolveBundle,
} from "../functions/lib/mcp-compiler.js";

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
const BUNDLE = "mcp-compiler-bundle.js";
const FROM_ROOT = join("netlify", "functions", "lib", BUNDLE);

/// Writes `files` (path relative to the root -> contents) into a fresh temp root.
async function layout(files) {
    const root = await mkdtemp(join(tmpdir(), "ringdrill-bundle-"));
    for (const [relative, contents] of Object.entries(files)) {
        const path = join(root, relative);
        await mkdir(join(path, ".."), { recursive: true });
        await writeFile(path, contents, "utf8");
    }
    return root;
}

test("resolves the bundle in a deployed package", async () => {
    // What Netlify unpacks to /var/task: the function bundled at the functions
    // root with this module inlined into it, and the bundle where included_files
    // put it. cwd is the package root.
    const root = await layout({ [FROM_ROOT]: "// deployed" });
    const moduleDir = join(root, "netlify", "functions");

    const { path, code } = await resolveBundle({ cwd: root, moduleDir });

    assert.equal(path, join(root, FROM_ROOT));
    assert.equal(code, "// deployed");
});

test("resolves the bundle in a checkout, from any working directory", async () => {
    // Unbundled, this module really does sit next to the bundle — and the tests and
    // mcp/dev-call.mjs may be run from anywhere, so cwd must not be required to
    // point at the repo root.
    const root = await layout({ [FROM_ROOT]: "// checkout" });
    const moduleDir = join(root, "netlify", "functions", "lib");

    const { path, code } = await resolveBundle({ cwd: tmpdir(), moduleDir });

    assert.equal(path, join(root, "netlify", "functions", "lib", BUNDLE));
    assert.equal(code, "// checkout");
});

test("reports every path tried when the bundle is missing", async () => {
    const root = await layout({ "netlify/functions/.keep": "" });
    const moduleDir = join(root, "netlify", "functions");

    await assert.rejects(
        () => resolveBundle({ cwd: root, moduleDir }),
        (error) => {
            // The message the outage produced named one path and left it unclear
            // whether the file was missing or merely looked for in the wrong place.
            for (const candidate of bundleCandidates({ cwd: root, moduleDir })) {
                assert.match(error.message, new RegExp(escape(candidate)));
            }
            assert.match(error.message, /make mcp-bundle/);
            assert.match(error.message, /included_files/);
            return true;
        },
    );
});

test("netlify.toml ships the bundle at the path this module resolves", async () => {
    // included_files, the Makefile's output path and this module's idea of the
    // repo-relative path have to agree, and nothing else compares them. A future
    // move of the file that updates two of the three lands as an ENOENT in
    // production, not as a failing test.
    const toml = await readFile(join(repoRoot, "netlify.toml"), "utf8");
    const shipped = FROM_ROOT.split(sep).join("/");
    assert.match(
        toml,
        new RegExp(`included_files[^\\]]*"${escape(shipped)}"`),
        `netlify.toml must list "${shipped}" under [functions."mcp"] included_files`,
    );
});

function escape(value) {
    return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}
