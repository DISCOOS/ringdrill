// The hosted MCP endpoint (ADR-0060) — MCP over Streamable HTTP.
//
// Same tools as the local stdio server, from the same table (`mcp/tools.mjs`); only
// the transport and the backend differ. This exists because the local server needs a
// checkout and a Dart SDK, and a remote Cowork session cannot reach it at all — so
// stdio serves the person building RingDrill and this serves the person using it.
//
// ## Stateless on purpose
//
// Streamable HTTP allows a session (`Mcp-Session-Id`) and a held-open SSE stream for
// server-initiated messages. Every tool here is request/response and nothing is
// pushed, so neither is needed — which is exactly what lets this be a function
// rather than a service. A future tool that streamed progress would reopen that.
//
// ## Unauthenticated on purpose
//
// No tool needs a secret: each maps to a public CLI command, and `publish` is
// deliberately absent, so there is nothing to authorize. The catalog it reads is
// already public. That makes the problem abuse rather than authorization — handled
// by a document-size cap (`_mcp_backend.js`), a compile timeout
// (`_mcp_compiler.js`) and the body cap below. Adopting the MCP spec's OAuth story
// would be a large commitment buying nothing until a tool touches private state
// (ADR-0024/0025).
//
// ## Documents are not persisted
//
// A requirement of ADR-0060, not an implementation note: a plan can be marked
// staff-only. This function reads a request, compiles it and answers. There is no
// write path, and the only storage touched is a read of the public catalog.
import { corsPreflight, withCors } from "./_shared.js";
import { createCompilerBackend } from "./_mcp_backend.js";
import { handleMessage, PROTOCOL_VERSION, toolsFor } from "../../mcp/tools.mjs";

/// Largest request body accepted, in bytes.
///
/// Above the document cap so a legitimate `build_plan` at the limit still fits with
/// its JSON-RPC envelope, and low enough that a body this size is refused before
/// anything parses it.
const MAX_BODY_BYTES = 1024 * 1024;

export function createHandler({ backend = createCompilerBackend() } = {}) {
    const tools = toolsFor(backend);

    return async function (request) {
        const preflight = corsPreflight(request);
        if (preflight) return preflight;

        // GET is where a client would open the SSE stream for server-initiated
        // messages. Answering 405 is the spec's way of saying "this server has
        // nothing to push" — a stateless server is allowed to, and saying so is
        // better than holding a stream open that will never carry anything.
        if (request.method === "GET") {
            return withCors(
                request,
                json(
                    {
                        error: "this server is stateless and sends no " +
                            "server-initiated messages; POST JSON-RPC instead",
                    },
                    405,
                    { allow: "POST, OPTIONS" },
                ),
            );
        }

        if (request.method !== "POST") {
            return withCors(
                request,
                json({ error: "method not allowed" }, 405, {
                    allow: "POST, OPTIONS",
                }),
            );
        }

        const declared = Number(request.headers.get("content-length") ?? 0);
        if (declared > MAX_BODY_BYTES) {
            return withCors(
                request,
                json({ error: `body exceeds ${MAX_BODY_BYTES} bytes` }, 413),
            );
        }

        let body;
        try {
            const text = await request.text();
            if (text.length > MAX_BODY_BYTES) {
                return withCors(
                    request,
                    json({ error: `body exceeds ${MAX_BODY_BYTES} bytes` }, 413),
                );
            }
            body = JSON.parse(text);
        } catch {
            return withCors(request, rpcError(null, -32700, "Parse error"));
        }

        // A client may batch. Notifications produce no reply, so a batch of only
        // notifications answers 202 with no body, per the spec.
        const batched = Array.isArray(body);
        const messages = batched ? body : [body];
        if (messages.length === 0) {
            return withCors(request, rpcError(null, -32600, "Invalid Request"));
        }

        const responses = [];
        for (const message of messages) {
            const response = await handleMessage(message, tools);
            if (response) responses.push(response);
        }

        if (responses.length === 0) {
            return withCors(request, new Response(null, { status: 202 }));
        }

        return withCors(
            request,
            json(batched ? responses : responses[0], 200, {
                // Advertised so a client can detect a version change without
                // calling initialize.
                "mcp-protocol-version": PROTOCOL_VERSION,
            }),
        );
    };
}

function json(payload, status = 200, extraHeaders = {}) {
    return new Response(JSON.stringify(payload), {
        status,
        headers: {
            "content-type": "application/json",
            // Nothing here is cacheable: a compile result depends on the request
            // body, and the catalog tools have their own freshness needs.
            "cache-control": "no-store",
            ...extraHeaders,
        },
    });
}

function rpcError(id, code, message) {
    // JSON-RPC transport errors carry HTTP 200 with an error member, since the
    // request *was* received and answered — but a parse failure has no id to
    // correlate, hence null.
    return json({ jsonrpc: "2.0", id, error: { code, message } }, 200);
}

export default createHandler();
