#!/usr/bin/env node
// Post-deploy smoke test for the hosted MCP endpoint (ADR-0060).
//
//   node tools/mcp-smoke.mjs                          https://api.ringdrill.app/mcp
//   node tools/mcp-smoke.mjs https://other/mcp        a deploy preview
//
// Every other suite runs against a checkout. This runs against whatever is
// actually serving, which is the only thing that can catch a fault introduced
// between `git push` and the URL a client uses — a missing `included_files`, a
// redirect that stopped resolving, a blob store that lost its binding, a bundle
// that was never rebuilt.
//
// It exists because the endpoint spent an unknown number of weeks answering
// `initialize`, `tools/list`, `resources/list` and `search_catalog` correctly
// while every compiler tool returned `ENOENT: no such file or directory, open
// '/var/task/netlify/functions/mcp-compiler-bundle.js'`. A client connected, listed
// the tools, reported the server healthy, and only failed when someone asked it to
// build a plan. Nothing was watching, so the report came from a user.
//
// So the rule this encodes: introspection passing is not the endpoint working. Each
// check below calls something that has to do real work — reach the cross-compiled
// compiler, read a file included at package time, or read the catalog.
//
// Exits non-zero on the first failed check, printing the reply, so it can be the
// step after `netlify deploy` in a workflow.
import process from "node:process";

const DEFAULT_ENDPOINT = "https://api.ringdrill.app/mcp";

/// Generous, because a cold start evaluates ~700 KB of cross-compiled JavaScript
/// before it can answer — and a slow first call is not a failure.
const TIMEOUT_MS = 30_000;

const endpoint = process.argv[2] ?? DEFAULT_ENDPOINT;

let nextId = 0;

/// One JSON-RPC round trip. Throws on transport faults so a check body can assume
/// it has a reply to look at.
async function rpc(method, params) {
    const response = await fetch(endpoint, {
        method: "POST",
        headers: {
            "content-type": "application/json",
            // Some clients negotiate SSE; the server answers JSON either way, and
            // sending both is what a real MCP client does.
            accept: "application/json, text/event-stream",
        },
        body: JSON.stringify({
            jsonrpc: "2.0",
            id: ++nextId,
            method,
            ...(params ? { params } : {}),
        }),
        signal: AbortSignal.timeout(TIMEOUT_MS),
    });
    if (!response.ok) {
        throw new Error(`HTTP ${response.status} ${response.statusText}`);
    }
    return response.json();
}

/// A tools/call that must succeed, returning the text payload.
///
/// `isError: true` is the trap this whole script is about: it arrives inside an
/// HTTP 200 with a well-formed JSON-RPC result, so anything checking only the
/// transport sees a healthy server.
async function callTool(name, args = {}) {
    const reply = await rpc("tools/call", { name, arguments: args });
    if (reply.error) {
        throw new Error(`JSON-RPC error: ${JSON.stringify(reply.error)}`);
    }
    const text = reply.result?.content?.[0]?.text ?? "";
    if (reply.result?.isError) {
        throw new Error(`tool ${name} failed: ${text}${blameDocument(text)}`);
    }
    return text;
}

/// Distinguishes "the endpoint is broken" from "this script's document is".
///
/// A document with an error compiles to a clean `ok: false` and a diagnostic — a
/// *correct* answer that this script nonetheless reports as a failure, because it
/// expects DOCUMENT to be valid. That is a real trap: the first version of DOCUMENT
/// had two teams and one station, and the resulting red looked like an outage.
function blameDocument(text) {
    try {
        const payload = JSON.parse(text);
        if (payload.ok === false && payload.diagnostics?.length) {
            return (
                "\n        ^ the compiler answered correctly — DOCUMENT in this " +
                "script is invalid, the endpoint is not necessarily broken"
            );
        }
    } catch {
        // Not JSON, so not a diagnostics payload. Nothing to add.
    }
    return "";
}

/// A tools/call whose payload is JSON, parsed.
async function callJsonTool(name, args = {}) {
    return JSON.parse(await callTool(name, args));
}

function assert(condition, message) {
    if (!condition) throw new Error(message);
}

/// Enough of a failing result to diagnose it, without pasting a whole compiled
/// plan into a workflow log.
function brief(value) {
    return JSON.stringify(value).slice(0, 400);
}

/// A document small enough to post and complete enough to exercise the parts of
/// the compiler that differ between the Dart VM and dart2js — a rotation schedule
/// and a projected coordinate.
///
/// Two stations, because `mode` defaults to `ring` and a ring needs at least one
/// station per team. The first version of this had two teams and one station, which
/// compiles to a clean `ok: false` with a diagnostic — a *correct* answer that this
/// script then reported as a failure. Change it and re-validate through the real
/// compiler (`node mcp/dev-call.mjs build_plan document=@file`) before committing:
/// a smoke test that cries wolf is worse than none.
const DOCUMENT = `
plan:
  name: "Smoke"
  language: nb
exercises:
  - name: "Førsteinnsats søk"
    startTime: "09:00"
    numberOfTeams: 2
    numberOfRounds: 2
    executionTime: 15
    evaluationTime: 5
    rotationTime: 5
    method: "Teiglederen fordeler mannskapet og melder inn funn fortløpende."
    stations:
      - name: "Teigsøk"
        description: "Systematisk søk i skogsteig etter savnet person."
        situation: "Meldt savnet for to timer siden, sist sett ved parkeringen."
        position: { lat: 59.096857, lng: 10.401633 }
      - name: "Førstehjelp"
        description: "Behandling og bæring av skadd person ut av teigen."
        situation: "Den savnede er funnet nedkjølt og kan ikke gå selv."
        position: { lat: 59.098120, lng: 10.404410 }
`.trim();

const checks = [
    [
        "initialize advertises the protocol and server",
        async () => {
            const reply = await rpc("initialize", {});
            assert(reply.result?.protocolVersion, "no protocolVersion");
            assert(
                reply.result?.serverInfo?.name === "ringdrill",
                `unexpected serverInfo: ${JSON.stringify(reply.result?.serverInfo)}`,
            );
        },
    ],
    [
        "tools/list returns every tool the client needs",
        async () => {
            const reply = await rpc("tools/list");
            const names = (reply.result?.tools ?? []).map((tool) => tool.name);
            for (const expected of [
                "schema",
                "create_plan",
                "build_plan",
                "analyze_plan",
                "render_plan",
                "search_catalog",
                "get_plan",
            ]) {
                assert(
                    names.includes(expected),
                    `tool ${expected} is missing (got ${names.join(", ")})`,
                );
            }
            // `publish` is deliberately absent (ADR-0060) — the endpoint is
            // unauthenticated, so a write tool appearing here is a real problem.
            assert(
                !names.includes("publish"),
                "publish is exposed on an unauthenticated endpoint",
            );
        },
    ],
    [
        "schema reaches the cross-compiled compiler",
        async () => {
            // The check the outage would have failed. It is first among the
            // compiler tools because it is what a client calls before writing
            // anything.
            const schema = await callJsonTool("schema");
            assert(
                schema.$id === "https://ringdrill.app/schema/source/1.0",
                `unexpected $id: ${schema.$id}`,
            );
        },
    ],
    [
        "create_plan scaffolds a document",
        async () => {
            const result = await callJsonTool("create_plan", { name: "Smoke" });
            assert(result.ok, `create_plan not ok: ${brief(result)}`);
            assert(
                /^# RingDrill source document/.test(result.document),
                "scaffold does not look like a source document",
            );
        },
    ],
    [
        "build_plan compiles a document end to end",
        async () => {
            // The deepest call there is: parses, validates, derives the schedule,
            // projects the coordinate and hashes the result. If the committed
            // bundle is stale or the compiler is broken, this is where it shows.
            const result = await callJsonTool("build_plan", { document: DOCUMENT });
            assert(result.ok, `build_plan not ok: ${brief(result)}`);
            assert(result.contentHash, "compiled plan carries no contentHash");
            assert(
                result.archive?.kind === "url" && result.archive.url,
                `build_plan answered no download handle: ${brief(result.archive)}`,
            );
        },
    ],
    [
        "the download handle build_plan returns actually serves the archive",
        async () => {
            // The check that would have caught what a cold run from ChatGPT found: the
            // build succeeded and there was no way to obtain the file (ADR-0070). Two
            // things here only exist in a deploy — the `/mcp/artifact/*` redirect and
            // the blob store binding — so a checkout suite cannot see either. A stale
            // redirect would serve the SPA shell with HTTP 200, which is why the
            // content type is asserted and not just the status.
            const result = await callJsonTool("build_plan", { document: DOCUMENT });
            assert(result.archive?.url, "no archive URL to follow");

            const response = await fetch(result.archive.url, {
                signal: AbortSignal.timeout(TIMEOUT_MS),
            });
            assert(
                response.ok,
                `GET ${result.archive.url} -> HTTP ${response.status}`,
            );
            const type = response.headers.get("content-type") ?? "";
            assert(
                type.startsWith("application/vnd.ringdrill"),
                `download served ${type} — a redirect serving the app shell answers ` +
                    "200 with text/html, so the status alone proves nothing",
            );
            assert(
                /^attachment/.test(response.headers.get("content-disposition") ?? ""),
                "download is not marked as an attachment, so a browser will render it",
            );
            const bytes = Buffer.from(await response.arrayBuffer());
            assert(
                bytes.subarray(0, 2).toString() === "PK",
                "downloaded file is not a zip, so it is not a .drill",
            );
        },
    ],
    [
        "analyze_plan reports on a document",
        async () => {
            const result = await callJsonTool("analyze_plan", { document: DOCUMENT });
            assert(result.ok, `analyze_plan not ok: ${brief(result)}`);
            assert(
                result.errors === 0,
                `analyze_plan found ${result.errors} error(s): ${brief(result.diagnostics)}`,
            );
        },
    ],
    [
        "render_plan produces a brief",
        async () => {
            const result = await callJsonTool("render_plan", {
                document: DOCUMENT,
                audience: "director",
            });
            assert(result.ok, `render_plan not ok: ${brief(result)}`);
            // The rotation has to appear, or the brief rendered an empty plan and
            // still called it a success — `bytes > 0` alone would not catch that.
            assert(
                result.markdown?.includes("Teigsøk"),
                `rendered brief is missing the station: ${brief(result.markdown)}`,
            );
        },
    ],
    [
        "the guide resources are readable",
        async () => {
            // Read from files shipped by `included_files`, the same mechanism the
            // compiler bundle uses — so this is the second half of the packaging
            // check, and it fails independently.
            const list = await rpc("resources/list");
            const uris = (list.result?.resources ?? []).map((r) => r.uri);
            assert(uris.length > 0, "no resources advertised");
            for (const uri of uris) {
                const reply = await rpc("resources/read", { uri });
                const text = reply.result?.contents?.[0]?.text ?? "";
                assert(
                    text.length > 0,
                    `resource ${uri} came back empty: ${brief(reply)}`,
                );
            }
        },
    ],
    [
        "prompts are listed and retrievable",
        async () => {
            const list = await rpc("prompts/list");
            const names = (list.result?.prompts ?? []).map((p) => p.name);
            assert(names.length > 0, "no prompts advertised");
            const reply = await rpc("prompts/get", {
                name: names[0],
                arguments: { brief: "smoke" },
            });
            assert(
                (reply.result?.messages ?? []).length > 0,
                `prompt ${names[0]} returned no messages`,
            );
        },
    ],
    [
        "search_catalog reads the published catalog",
        async () => {
            // Reaches Netlify Blobs, which is a binding rather than a file — a
            // different failure mode from everything above, and invisible locally
            // because the tests fake the store.
            const result = await callJsonTool("search_catalog");
            assert(Array.isArray(result.items), "catalog returned no items array");
        },
    ],
    [
        "GET is refused with a usable message",
        async () => {
            // The server is stateless and says so (405) rather than holding open an
            // SSE stream that will never carry anything. A client that follows the
            // spec probes this, so a regression here breaks connection, not a tool.
            const response = await fetch(endpoint, {
                method: "GET",
                signal: AbortSignal.timeout(TIMEOUT_MS),
            });
            assert(
                response.status === 405,
                `expected 405 for GET, got ${response.status}`,
            );
        },
    ],
];

console.log(`smoke: ${endpoint}\n`);

let failed = 0;
for (const [name, check] of checks) {
    const started = Date.now();
    try {
        await check();
        console.log(`  ok    ${name} (${Date.now() - started}ms)`);
    } catch (error) {
        failed += 1;
        console.error(`  FAIL  ${name} (${Date.now() - started}ms)`);
        console.error(`        ${error.message}`);
    }
}

console.log(
    `\n${checks.length - failed}/${checks.length} checks passed against ${endpoint}`,
);
process.exit(failed === 0 ? 0 : 1);
