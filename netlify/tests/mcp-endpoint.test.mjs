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
    DOC_CACHE_TTL_MS,
    documentHash,
    MAX_DOCUMENT_CHARS,
} from "../functions/lib/mcp-backend.js";
import { artifactKey } from "../functions/lib/mcp-artifact-store.js";

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

/// Enough of the Netlify Blobs surface for the document cache, so the retention
/// behaviour is testable without the real store.
function memoryStore() {
    const map = new Map();
    return {
        get: async (key) => map.get(key) ?? null,
        setJSON: async (key, value) => void map.set(key, value),
        delete: async (key) => void map.delete(key),
        seed: (key, value) => map.set(key, value),
        get size() {
            return map.size;
        },
    };
}

function handlerWith(overrides = {}) {
    return createHandler({
        backend: createCompilerBackend({
            ...fakeCatalog(),
            // Defaulted, not opt-in: hosted `build_plan` writes the archive it hands
            // back a URL for (ADR-0070), so every build here would otherwise reach for
            // a real Netlify Blobs store. Same reasoning as `fakeCatalog` — a test that
            // is not about retention should not have to know retention happens.
            artifactCache: () => memoryStore(),
            ...overrides,
        }),
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
    assert.ok(body.result.capabilities.prompts);
    assert.ok(body.result.capabilities.resources);
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
        // ADR-0068: an override reaches the fields an entity inherits, so the
        // workaround two conversion runs found (writing the token into
        // `logistics`) must stay named in both channels.
        /applies to every field/i,
        // ADR-0070: an agent that keeps the download link to itself has produced a
        // build the author cannot obtain, which is the failure the handle exists to
        // fix — so "hand it over, and do not ask for the bytes" belongs in both.
        /handle in `archive`/i,
        /inline: true/,
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
    const artifacts = memoryStore();
    const { body } = await rpc(handlerWith({ artifactCache: () => artifacts }), {
        jsonrpc: "2.0",
        id: 1,
        method: "tools/call",
        params: {
            name: "build_plan",
            arguments: { document: DOCUMENT, inline: true },
        },
    });
    const result = payload(body);
    assert.equal(result.ok, true, JSON.stringify(result));
    assert.match(result.contentHash, /^[0-9a-f]{64}$/);
    const bytes = Buffer.from(result.archive.base64, "base64");
    assert.equal(bytes.subarray(0, 2).toString(), "PK");
    assert.equal(
        artifacts.size,
        0,
        "inline: true must retain nothing — that is what it is for (ADR-0070)",
    );
});

test("build answers with a download URL, and holds the archive behind it", async () => {
    // The failure ADR-0070 exists for: a real plan is ~100 KB of base64, which a chat
    // client truncates and no agent reads, so a successful build produced no file.
    const artifacts = memoryStore();
    const { body } = await rpc(handlerWith({ artifactCache: () => artifacts }), {
        jsonrpc: "2.0",
        id: 1,
        method: "tools/call",
        params: { name: "build_plan", arguments: { document: DOCUMENT } },
    });
    const result = payload(body);
    assert.equal(result.ok, true, JSON.stringify(result));
    assert.equal(result.archive.kind, "url");
    assert.equal(
        result.archive.url,
        `https://api.ringdrill.app/mcp/artifact/${result.contentHash}.drill`,
        "the URL is content-addressed, so it cannot name another plan's archive",
    );
    assert.ok(
        Date.parse(result.archive.expires_at) > Date.now(),
        "a handle with no stated expiry is a handle that looks permanent",
    );
    assert.ok(
        !("drillBase64" in result) && !JSON.stringify(result).includes("UEsDB"),
        "the bytes must not be in the response as well — that is the whole cost",
    );

    const held = await artifacts.get(artifactKey(result.contentHash));
    assert.equal(
        Buffer.from(held.base64, "base64").subarray(0, 2).toString(),
        "PK",
    );
    assert.equal(held.fileName, "hosted.drill", "named from the plan, not the hash");
});

test("a store that cannot hold the archive still yields the build", async () => {
    // The compile is the expensive part. A storage fault must not turn a successful
    // ten-second build into nothing — but the client has to be able to tell this
    // apart from a deliberate `inline: true`, hence the note.
    const { body } = await rpc(
        handlerWith({
            artifactCache: () => ({
                setJSON: async () => {
                    throw new Error("blob store unavailable");
                },
            }),
        }),
        {
            jsonrpc: "2.0",
            id: 1,
            method: "tools/call",
            params: { name: "build_plan", arguments: { document: DOCUMENT } },
        },
    );
    const result = payload(body);
    assert.equal(result.ok, true, JSON.stringify(result.error ?? result));
    assert.equal(result.archive.kind, "inline");
    assert.match(result.archive.note, /could not be held for download/);
    assert.match(result.archive.note, /blob store unavailable/);
    assert.equal(
        Buffer.from(result.archive.base64, "base64").subarray(0, 2).toString(),
        "PK",
    );
});

test("output_path is refused with a reason that names the alternative", async () => {
    // Same asymmetry as document_path (ADR-0064): the parameter keeps one meaning in
    // the shared table, and the transport that cannot honour it says so. The message
    // has to point at `archive.url`, or an agent that wanted a file hears only "no".
    const { body } = await rpc(handlerWith(), {
        jsonrpc: "2.0",
        id: 1,
        method: "tools/call",
        params: {
            name: "build_plan",
            arguments: { document: DOCUMENT, output_path: "/tmp/plan.drill" },
        },
    });
    assert.equal(body.result.isError, true);
    assert.match(body.result.content[0].text, /output_path/);
    assert.match(body.result.content[0].text, /archive\.url/);
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
    assert.ok(!refused.archive, "strict refuses rather than returning an archive");
});

test("document_path is refused with a reason, not ignored", async () => {
    // A path means nothing to a server with no access to the caller's filesystem
    // (ADR-0064). Falling through to "a source document is required" would send an
    // agent hunting for an argument it did supply.
    const { body } = await rpc(handlerWith(), {
        jsonrpc: "2.0",
        id: 1,
        method: "tools/call",
        params: {
            name: "analyze_plan",
            arguments: { document_path: "/tmp/plan.yaml" },
        },
    });
    assert.equal(body.result.isError, true);
    // A refusal is a plain message, not diagnostics, so it is not JSON — `payload`
    // would fail to parse it. That is the distinction the message itself draws:
    // this is not a problem with the document.
    const text = body.result.content[0].text;
    assert.match(text, /local server/);
    assert.match(text, /stdio/);
});

test("render_plan summary is a fraction of the full brief", async () => {
    const call = async (args) =>
        payload(
            (
                await rpc(handlerWith(), {
                    jsonrpc: "2.0",
                    id: 1,
                    method: "tools/call",
                    params: { name: "render_plan", arguments: args },
                })
            ).body,
        );

    const full = await call({ document: DOCUMENT, audience: "director" });
    const summary = await call({
        document: DOCUMENT,
        audience: "director",
        format: "summary",
    });

    assert.equal(summary.format, "summary");
    assert.ok(
        summary.bytes < full.bytes,
        `summary ${summary.bytes} should be smaller than full ${full.bytes}`,
    );
    // Names the shape without carrying the prose.
    assert.match(summary.markdown, /Station sections:|Station empty:/);
    assert.doesNotMatch(summary.markdown, /Noe skjer\./);
});

test("caching is opt-in, and a hash stands in for the document", async () => {
    // ADR-0064 amends ADR-0060's retention promise rather than dropping it: nothing
    // is held unless the caller asks, and then only under the server's own hash of
    // the content. These assertions are that promise.
    const store = memoryStore();
    const handler = handlerWith({ docCache: () => store });
    const call = async (args) =>
        payload(
            (
                await rpc(handler, {
                    jsonrpc: "2.0",
                    id: 1,
                    method: "tools/call",
                    params: { name: "analyze_plan", arguments: args },
                })
            ).body,
        );

    const plain = await call({ document: DOCUMENT });
    assert.equal(plain.document_hash, undefined);
    assert.equal(store.size, 0, "nothing is held unless asked");

    const cached = await call({ document: DOCUMENT, cache: true });
    assert.equal(cached.document_hash, documentHash(DOCUMENT));
    assert.equal(store.size, 1);

    const byHash = await call({ document_hash: cached.document_hash });
    assert.equal(byHash.name, plain.name);
    assert.equal(byHash.exercises, plain.exercises);
});

test("an unknown or expired hash asks for a resend, and does not linger", async () => {
    const store = memoryStore();
    const handler = handlerWith({ docCache: () => store });
    const call = async (args) => {
        const { body } = await rpc(handler, {
            jsonrpc: "2.0",
            id: 1,
            method: "tools/call",
            params: { name: "analyze_plan", arguments: args },
        });
        return body.result;
    };

    const unknown = await call({ document_hash: "deadbeef" });
    assert.equal(unknown.isError, true);
    assert.match(unknown.content[0].text, /never cached, or it has expired/);
    assert.match(unknown.content[0].text, /cache: true/);

    // Deleted on the read that found it stale: an entry must not outlive its window
    // just because nothing swept.
    const hash = documentHash(DOCUMENT);
    store.seed(`doc/${hash}`, {
        document: DOCUMENT,
        storedAt: Date.now() - (DOC_CACHE_TTL_MS + 1000),
    });
    const expired = await call({ document_hash: hash });
    assert.equal(expired.isError, true);
    assert.match(expired.content[0].text, /expired/);
    assert.equal(store.size, 0, "an expired entry is deleted when read");
});

test("the authoring guide is served as resources, from the skill itself", async () => {
    // ADR-0065: the resources are the skill's own markdown, so a convention cannot
    // be right in the skill and stale in the server.
    const list = await rpc(handlerWith(), {
        jsonrpc: "2.0",
        id: 1,
        method: "resources/list",
    });
    const uris = list.body.result.resources.map((r) => r.uri);
    assert.deepEqual(uris, [
        "ringdrill://guide/authoring",
        "ringdrill://guide/format",
    ]);

    const read = await rpc(handlerWith(), {
        jsonrpc: "2.0",
        id: 1,
        method: "resources/read",
        params: { uri: "ringdrill://guide/authoring" },
    });
    const text = read.body.result.contents[0].text;
    assert.match(text, /# Authoring a RingDrill plan/);
    assert.match(text, /sentence end/i);

    const unknown = await rpc(handlerWith(), {
        jsonrpc: "2.0",
        id: 1,
        method: "resources/read",
        params: { uri: "ringdrill://guide/nope" },
    });
    assert.match(unknown.body.error.message, /Unknown resource/);
});

test("the workflow is offered as a prompt, carrying the rules", async () => {
    const list = await rpc(handlerWith(), {
        jsonrpc: "2.0",
        id: 1,
        method: "prompts/list",
    });
    assert.deepEqual(
        list.body.result.prompts.map((p) => p.name),
        ["author_plan"],
    );

    const got = await rpc(handlerWith(), {
        jsonrpc: "2.0",
        id: 1,
        method: "prompts/get",
        params: {
            name: "author_plan",
            arguments: { brief: "Ledelse under henteoppdrag." },
        },
    });
    const text = got.body.result.messages[0].content.text;
    // Self-contained: it carries the rules rather than assuming resources work.
    assert.match(text, /sentence ends/);
    assert.match(text, /Ledelse under henteoppdrag\./);

    const unknown = await rpc(handlerWith(), {
        jsonrpc: "2.0",
        id: 1,
        method: "prompts/get",
        params: { name: "nope" },
    });
    assert.match(unknown.body.error.message, /Unknown prompt/);
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
                    // The bytes are the fixture here, so ask for them directly
                    // rather than following the handle (ADR-0070).
                    name: "build_plan",
                    arguments: { document: DOCUMENT, inline: true },
                },
            })
        ).body,
    );

    const handler = handlerWith(
        fakeCatalog({ archive: Buffer.from(built.archive.base64, "base64") }),
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
