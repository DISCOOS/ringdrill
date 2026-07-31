// The hosted MCP endpoint (ADR-0060), driven as a client would: real Request
// objects into the real handler, JSON-RPC in the body.
//
// The compiler operations run against the actual cross-compiled bundle rather than a
// stub — that is the point, since the whole decision rests on it working in-process.
// Only the catalog is faked, because Netlify Blobs are not available here.
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

import { createHandler } from "../functions/mcp.js";
import { INSTRUCTIONS } from "../../mcp/tools.mjs";
import {
    createCompilerBackend,
    MAX_DOCUMENT_CHARS,
} from "../functions/lib/mcp-backend.js";

const ENDPOINT = "https://api.ringdrill.app/mcp";

/// A catalog of one published plan, in the shape the blob store returns.
function fakeCatalog({ archive } = {}) {
    const meta = {
        programId: "prog-1",
        ownerId: "anon",
        slug: "test-plan",
        name: "Test Plan",
        tags: ["søk og redning"],
        published: true,
        updatedAt: "2026-07-01T00:00:00.000Z",
        versions: [
            {
                v: "1",
                etag: '"abc"',
                size: 10,
                updatedAt: "2026-07-01T00:00:00.000Z",
            },
        ],
    };
    return {
        getDrillsStore: () => ({
            list: async () => ({
                blobs: [{ key: "drills/anon/prog-1/meta.json" }],
            }),
            get: async () => meta,
        }),
        getSlugRecord: async (slug) =>
            slug === "test-plan"
                ? { ownerId: "anon", programId: "prog-1" }
                : null,
        readJson: async () => meta,
        readBinary: async () => archive ?? null,
    };
}

function handlerWith(overrides = {}) {
    return createHandler({
        backend: createCompilerBackend({ ...fakeCatalog(), ...overrides }),
    });
}

/// POSTs one JSON-RPC message (or a batch) and returns {status, headers, body}.
async function rpc(handler, message, { headers = {} } = {}) {
    const response = await handler(
        new Request(ENDPOINT, {
            method: "POST",
            headers: { "content-type": "application/json", ...headers },
            body:
                typeof message === "string" ? message : JSON.stringify(message),
        }),
    );
    const text = await response.text();
    return {
        status: response.status,
        headers: response.headers,
        body: text ? JSON.parse(text) : null,
    };
}

/// The parsed payload of a tools/call result.
function payload(body) {
    assert.ok(body.result, `expected a result, got ${JSON.stringify(body)}`);
    return JSON.parse(body.result.content[0].text);
}

const DOCUMENT = `
plan:
  name: "Hosted"
  language: nb
exercises:
  - name: "Ex"
    startTime: "09:00"
    numberOfTeams: 2
    numberOfRounds: 2
    executionTime: 15
    evaluationTime: 5
    rotationTime: 2
    stations:
      - name: "Post 1"
        situation: "Noe skjer."
      - name: "Post 2"
        situation: "Noe annet."
`;

test("initialize answers with the shared protocol version and server info", async () => {
    const { status, body } = await rpc(handlerWith(), {
        jsonrpc: "2.0",
        id: 1,
        method: "initialize",
        params: {},
    });
    assert.equal(status, 200);
    assert.equal(body.result.serverInfo.name, "ringdrill");
    assert.ok(body.result.capabilities.tools);
    // The one channel most clients inject into the system prompt (ADR-0065), so
    // it is the only guidance certain to reach an MCP-only client.
    assert.match(body.result.instructions, /sentence ends/);
});

test("instructions do not drift from the skill they summarise", async () => {
    // ADR-0065 splits the conventions across channels: a short always-read string
    // here, the full guide in the skill. Two copies of a rule is two things to keep
    // true, so the rules named in one must still be present in the other.
    const skill = await readFile(
        new URL("../../skills/ringdrill-plan-authoring/SKILL.md", import.meta.url),
        "utf8",
    );
    const reference = await readFile(
        new URL(
            "../../skills/ringdrill-plan-authoring/reference/format.md",
            import.meta.url,
        ),
        "utf8",
    );
    const guide = skill + reference;

    for (const rule of [
        /sentence end/i,
        /numbering/i,
        /never invent staff|real person|real people/i,
        /numberOfTeams/,
    ]) {
        assert.match(guide, rule, `the skill no longer covers ${rule}`);
        assert.match(INSTRUCTIONS, rule, `instructions no longer cover ${rule}`);
    }
});

test("tools/list matches the stdio server's table, and omits publish", async () => {
    // Same table by construction (mcp/tools.mjs), asserted so a future divergence
    // shows up here rather than as an agent finding different tools depending on
    // which server it reached.
    const { body } = await rpc(handlerWith(), {
        jsonrpc: "2.0",
        id: 1,
        method: "tools/list",
    });
    const names = body.result.tools.map((t) => t.name).sort();
    assert.deepEqual(names, [
        "analyze_plan",
        "build_plan",
        "create_plan",
        "get_plan",
        "render_plan",
        "schema",
        "search_catalog",
    ]);
    assert.ok(!names.includes("publish"));
});

test("the compiler runs in-process: build returns an archive and a hash", async () => {
    const { body } = await rpc(handlerWith(), {
        jsonrpc: "2.0",
        id: 1,
        method: "tools/call",
        params: { name: "build_plan", arguments: { document: DOCUMENT } },
    });
    const result = payload(body);
    assert.equal(result.ok, true, JSON.stringify(result));
    assert.match(result.contentHash, /^[0-9a-f]{64}$/);
    const bytes = Buffer.from(result.drillBase64, "base64");
    assert.equal(bytes.subarray(0, 2).toString(), "PK");
});

test("render produces the brief, with tokens resolved", async () => {
    const { body } = await rpc(handlerWith(), {
        jsonrpc: "2.0",
        id: 1,
        method: "tools/call",
        params: {
            name: "render_plan",
            arguments: { document: DOCUMENT, audience: "director" },
        },
    });
    const result = payload(body);
    assert.match(result.markdown, /# Hosted/);
    assert.ok(!result.markdown.includes("{{"));
});

test("analyze reports a bad reference as a result, flagged", async () => {
    const broken = DOCUMENT.replace(
        '"Noe skjer."',
        '"Samband på {{var.nope}}."',
    );
    const { body } = await rpc(handlerWith(), {
        jsonrpc: "2.0",
        id: 1,
        method: "tools/call",
        params: { name: "analyze_plan", arguments: { document: broken } },
    });
    assert.equal(body.result.isError, true);
    const result = payload(body);
    assert.equal(result.errors, 1);
    assert.match(result.diagnostics[0].message, /no variable named "nope"/);
});

test("build_plan keeps a key's type across outcomes", async () => {
    // `diagnostics` is the array, `errors`/`warnings` are counts — in both the
    // success and the refusal path, and the same for analyze_plan. A tool whose
    // key changes type with its outcome forces a caller to branch on success
    // before it can read the result.
    const stale = DOCUMENT.replace(
        '"Noe skjer."',
        '"Sist sett {{station.loc.lkp.utm}}."',
    ).replace(
        '      - name: "Post 1"',
        '      - name: "Post 1"\n        locations: [{slug: lkp, label: "LKP", position: {lat: 59.1, lng: 10.4}}]',
    );

    const call = async (args) =>
        payload(
            (
                await rpc(handlerWith(), {
                    jsonrpc: "2.0",
                    id: 1,
                    method: "tools/call",
                    params: { name: "build_plan", arguments: args },
                })
            ).body,
        );

    const ok = await call({ document: stale });
    assert.equal(typeof ok.errors, "number");
    assert.equal(typeof ok.warnings, "number");
    assert.ok(Array.isArray(ok.diagnostics));
    assert.ok(ok.warnings > 0, "a removed facet is a warning, not silence");

    const refused = await call({ document: stale, strict: true });
    assert.equal(typeof refused.errors, "number");
    assert.equal(typeof refused.warnings, "number");
    assert.ok(Array.isArray(refused.diagnostics));
    assert.ok(!refused.drillBase64, "strict refuses rather than returning an archive");
});

test("schema is the schema itself, not a wrapper", async () => {
    // The CLI prints the schema directly, so the hosted tool has to unwrap the
    // bundle's {ok, schema} envelope or the two would return different shapes for
    // the same tool name.
    const { body } = await rpc(handlerWith(), {
        jsonrpc: "2.0",
        id: 1,
        method: "tools/call",
        params: { name: "schema", arguments: {} },
    });
    const schema = payload(body);
    assert.equal(schema.type, "object");
    assert.deepEqual(schema.required, ["plan"]);
});

test("search_catalog projects the catalog like the feed does", async () => {
    const { body } = await rpc(handlerWith(), {
        jsonrpc: "2.0",
        id: 1,
        method: "tools/call",
        params: { name: "search_catalog", arguments: {} },
    });
    const result = payload(body);
    assert.equal(result.items.length, 1);
    assert.equal(result.items[0].slug, "test-plan");
    // metaToFeedItem's contract (ADR-0040/0055): both id names are carried.
    assert.equal(result.items[0].planId, "prog-1");
});

test("get_plan resolves latest to a concrete version and decompiles", async () => {
    // Build an archive with the real compiler, then hand it back as the stored blob:
    // exercises the actual decompile path rather than a fixture that might not
    // resemble what the compiler writes.
    const built = payload(
        (
            await rpc(handlerWith(), {
                jsonrpc: "2.0",
                id: 1,
                method: "tools/call",
                params: {
                    name: "build_plan",
                    arguments: { document: DOCUMENT },
                },
            })
        ).body,
    );

    const handler = handlerWith(
        fakeCatalog({ archive: Buffer.from(built.drillBase64, "base64") }),
    );
    const { body } = await rpc(handler, {
        jsonrpc: "2.0",
        id: 1,
        method: "tools/call",
        params: { name: "get_plan", arguments: { slug: "test-plan" } },
    });
    const result = payload(body);
    assert.equal(result.ok, true, JSON.stringify(result));
    assert.equal(result.version, "1", "latest should resolve to a named version");
    assert.match(result.document, /^# Decompiled from the RingDrill catalog/m);
    assert.equal(result.contentHash, built.contentHash);
});

test("an unknown slug is reported, not a 500", async () => {
    const { status, body } = await rpc(handlerWith(), {
        jsonrpc: "2.0",
        id: 1,
        method: "tools/call",
        params: { name: "get_plan", arguments: { slug: "nope" } },
    });
    assert.equal(status, 200);
    assert.equal(body.result.isError, true);
    assert.match(body.result.content[0].text, /no published plan with slug/);
});

test("an oversized document is refused as a refusal, not a diagnostic", async () => {
    // Conflating the two would send an agent hunting its plan for a mistake that is
    // not there.
    const { body } = await rpc(handlerWith(), {
        jsonrpc: "2.0",
        id: 1,
        method: "tools/call",
        params: {
            name: "analyze_plan",
            arguments: { document: "x".repeat(MAX_DOCUMENT_CHARS + 1) },
        },
    });
    assert.equal(body.result.isError, true);
    assert.match(body.result.content[0].text, /accepts up to/);
    assert.match(body.result.content[0].text, /local server/);
});

test("an oversized body is refused before parsing", async () => {
    const handler = handlerWith();
    const response = await handler(
        new Request(ENDPOINT, {
            method: "POST",
            headers: {
                "content-type": "application/json",
                "content-length": String(64 * 1024 * 1024),
            },
            body: "{}",
        }),
    );
    assert.equal(response.status, 413);
});

test("GET says the server is stateless rather than holding a stream open", async () => {
    const response = await handlerWith()(
        new Request(ENDPOINT, { method: "GET" }),
    );
    assert.equal(response.status, 405);
    assert.match(await response.text(), /stateless/);
    assert.equal(response.headers.get("allow"), "POST, OPTIONS");
});

test("a batch is answered as a batch, and notifications get 202", async () => {
    const handler = handlerWith();

    const { body } = await rpc(handler, [
        { jsonrpc: "2.0", id: 1, method: "initialize", params: {} },
        { jsonrpc: "2.0", id: 2, method: "tools/list" },
    ]);
    assert.ok(Array.isArray(body));
    assert.deepEqual(
        body.map((m) => m.id),
        [1, 2],
    );

    // A batch of only notifications has nothing to reply with.
    const notified = await handler(
        new Request(ENDPOINT, {
            method: "POST",
            headers: { "content-type": "application/json" },
            body: JSON.stringify([
                { jsonrpc: "2.0", method: "notifications/initialized" },
            ]),
        }),
    );
    assert.equal(notified.status, 202);
});

test("malformed JSON is a parse error, not a crash", async () => {
    const { status, body } = await rpc(handlerWith(), "{not json");
    assert.equal(status, 200);
    assert.equal(body.error.code, -32700);
});

test("responses are not cacheable", async () => {
    // A compile result depends on the request body; a cached one would be served to
    // the wrong document.
    const { headers } = await rpc(handlerWith(), {
        jsonrpc: "2.0",
        id: 1,
        method: "tools/list",
    });
    assert.equal(headers.get("cache-control"), "no-store");
});
