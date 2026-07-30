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

/// Imports the bundle once per process, returning `globalThis.ringdrillInvoke`.
///
/// Netlify reuses a warm function instance, so this is paid on a cold start only —
/// which matters, since parsing ~700 KB of JavaScript is the bulk of the work for
/// a small document.
function load() {
    ready ??= (async () => {
        installBrowserGlobals();
        await import("./_mcp_compiler_bundle.js");
        if (typeof globalThis.ringdrillInvoke !== "function") {
            throw new Error(
                "_mcp_compiler_bundle.js did not install ringdrillInvoke — " +
                    "regenerate it with `make mcp-bundle`",
            );
        }
        return globalThis.ringdrillInvoke;
    })();
    return ready;
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
