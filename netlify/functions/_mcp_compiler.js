// Loads the cross-compiled source compiler and exposes it as a clean async API.
//
// `_mcp_compiler_bundle.js` is `dart compile js` output (ADR-0060): the same Dart
// the app and CLI use, running in-process so the hosted MCP server can be a
// function rather than a container. This file is the seam — the shim the bundle
// needs, the one-call JSON contract, and a timeout.
//
// Regenerate the bundle with `make mcp-bundle`. It is committed because a Netlify
// build has no Dart SDK.
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
        const here = dirname(fileURLToPath(import.meta.url));
        const path = join(here, BUNDLE_FILE);
        const code = await readFile(path, "utf8");
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
/// import specifier, and so `included_files` and this agree in one place.
const BUNDLE_FILE = "_mcp_compiler_bundle.js";

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
