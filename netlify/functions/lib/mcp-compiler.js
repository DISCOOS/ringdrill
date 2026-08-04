// Loads the cross-compiled source compiler and exposes it as a clean async API.
//
// `mcp-compiler-bundle.js` is `dart compile js` output (ADR-0060): the same Dart
// the app and CLI use, running in-process so the hosted MCP server can be a
// function rather than a container. This file is the seam — the shim the bundle
// needs, the one-call JSON contract, and a timeout.
//
// Regenerate the bundle with `make mcp-bundle`. It is committed because a Netlify
// build has no Dart SDK.
//
// In `lib/` rather than beside the functions, and that matters: Netlify treats every
// *top-level* file in the functions directory as a function of its own. As
// `_mcp_compiler.js` this was bundled a second time as an endpoint, where esbuild
// chose CJS and warned that `import.meta` would be empty — harmless for the real
// function, which bundles as ESM, but alarming, wasteful, and it published a helper
// at `/.netlify/functions/_mcp_compiler`. A subdirectory is how Netlify is told
// "not a function"; the `_` prefix was only ever a convention to us.
import { webcrypto } from "node:crypto";
import { readFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { runInThisContext } from "node:vm";

/// dart2js targets browsers, where `self` and `crypto` are globals. Node has
/// neither by default, and `Random.secure()` compiles to code that reads `self` —
/// so without this, minting a uuid throws `ReferenceError: self is not defined`.
///
/// The failure mode is what makes this worth a comment: inside an async entry
/// point it is swallowed, and the process exits 0 having produced nothing. Two
/// lines, applied before the bundle is imported, because its `main()` runs on
/// import.
function installBrowserGlobals() {
    globalThis.self ??= globalThis;
    globalThis.crypto ??= webcrypto;
}

let ready;

/// Evaluates the bundle once per process, returning `globalThis.ringdrillInvoke`.
///
/// Read and evaluated rather than `import`ed, and that is load-bearing: **dart2js
/// output must not be re-bundled.** Netlify's esbuild step inlines an imported
/// module into the function, and doing that to this bundle breaks Dart's runtime
/// type information — every `analyze_plan` came back as
/// `type 'minified:z2' is not a subtype of type 'minified:z'` while `create_plan`,
/// which touches no generic collection, worked fine. Verified by driving the
/// esbuild-produced file directly outside Netlify: it fails there too, so it is the
/// bundling and not the runtime.
///
/// `runInThisContext` executes the script against the current global, which is
/// exactly what the bundle expects — it is a script that assigns to globals, not a
/// module. The path is built at runtime so esbuild cannot see a dependency to
/// follow; `netlify.toml`'s `included_files` is what actually ships the file.
///
/// Netlify reuses a warm instance, so this is paid on a cold start only — which
/// matters, since evaluating ~700 KB of JavaScript is the bulk of the work for a
/// small document.
function load() {
    ready ??= (async () => {
        installBrowserGlobals();
        const { path, code } = await resolveBundle();
        runInThisContext(code, { filename: path });
        if (typeof globalThis.ringdrillInvoke !== "function") {
            throw new Error(
                `${BUNDLE_FILE} did not install ringdrillInvoke — regenerate it ` +
                    "with `make mcp-bundle`",
            );
        }
        return globalThis.ringdrillInvoke;
    })();
    return ready;
}

/// Split out so the name is not a string literal esbuild could resolve as an
/// import specifier, and so `netlify.toml`'s `included_files` and this agree in one
/// place.
const BUNDLE_FILE = "mcp-compiler-bundle.js";

/// Where the bundle sits relative to the package root — the path `included_files`
/// ships it under, and the path it has in a checkout.
const BUNDLE_FROM_ROOT = ["netlify", "functions", "lib", BUNDLE_FILE];

/// The places the bundle can be, most-deployed-like first.
///
/// Two layouts exist and they disagree, which is the bug this list exists to close:
/// esbuild **inlines this module into `netlify/functions/mcp.mjs`**, so in a deployed
/// package `import.meta.url` names the function at the functions *root* — one
/// directory above the bundle — and resolving beside it looked for
/// `netlify/functions/mcp-compiler-bundle.js` and got ENOENT on every compiler tool
/// while the catalog tools, which read no files, kept working. `included_files`
/// preserves the repo-relative path inside the package and Netlify runs the function
/// with the package root as cwd, so cwd-relative is what holds there — the same
/// resolution `mcp.js` already uses for the guide resources.
///
/// Module-relative stays as the fallback because it is the one that holds when this
/// file is imported unbundled from an arbitrary working directory, which is how the
/// tests and `mcp/dev-call.mjs` load it.
///
/// Parameterised rather than reading the two globals directly so the layouts can be
/// tested without a deploy; see `netlify/tests/mcp-compiler-path.test.mjs`.
export function bundleCandidates({
    cwd = process.cwd(),
    moduleDir = dirname(fileURLToPath(import.meta.url)),
} = {}) {
    return [join(cwd, ...BUNDLE_FROM_ROOT), join(moduleDir, BUNDLE_FILE)];
}

/// First candidate that exists, read. Rejects naming every path tried, because the
/// failure this replaced reported one path and gave no hint which layout was wrong.
export async function resolveBundle(options) {
    const candidates = bundleCandidates(options);
    for (const path of candidates) {
        try {
            return { path, code: await readFile(path, "utf8") };
        } catch (error) {
            if (error.code !== "ENOENT") throw error;
        }
    }
    throw new Error(
        `${BUNDLE_FILE} not found — tried ${candidates.join(", ")}. ` +
            "Run `make mcp-bundle`; if this is a deployed function, check " +
            "`[functions.\"mcp\"] included_files` in netlify.toml.",
    );
}

/// Milliseconds a single compile may take before it is abandoned.
///
/// An abuse control from ADR-0060, and a real bound: the compiler is synchronous
/// Dart, so a pathological document would otherwise hold the function's whole
/// event loop until the platform killed it, with no diagnostic.
export const COMPILE_TIMEOUT_MS = 10_000;

/// Runs one operation. `request` is the shape `tools/mcp-ops.mjs` documents;
/// the resolved value is the parsed response object.
///
/// Never rejects for a *document* problem — those come back as
/// `{ok: false, diagnostics: [...]}`, because "your document has three errors" is
/// an answer, not a transport failure. Rejects only when the compiler itself could
/// not run.
export async function invoke(request, { timeoutMs = COMPILE_TIMEOUT_MS } = {}) {
    const ringdrillInvoke = await load();

    let timer;
    const timeout = new Promise((_, reject) => {
        timer = setTimeout(
            () => reject(new Error(`compile timed out after ${timeoutMs}ms`)),
            timeoutMs,
        );
    });

    try {
        const raw = await Promise.race([
            ringdrillInvoke(JSON.stringify(request)),
            timeout,
        ]);
        return JSON.parse(raw);
    } finally {
        clearTimeout(timer);
    }
}
