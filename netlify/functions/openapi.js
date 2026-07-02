import { corsPreflight, withCors } from "./_shared.js";

// OpenAPI 3.0 description of the public + admin API. Served at
// /api/openapi.json (see netlify.toml) and consumed by the interactive
// viewer at /api/docs (api-docs.js).
const SPEC = {
    openapi: "3.0.3",
    info: {
        title: "RingDrill API",
        version: "1.0.0",
        description:
            "Drill file storage, deep links and the catalog feed. Public endpoints need no auth; admin endpoints require a bearer token.",
    },
    servers: [
        { url: "https://ringdrill.app", description: "Public apex (proxied to the API)" },
        { url: "https://api.ringdrill.app", description: "API origin" },
    ],
    tags: [
        { name: "catalog", description: "Public catalog and files" },
        { name: "admin", description: "Requires bearer token" },
    ],
    components: {
        securitySchemes: {
            bearerAuth: { type: "http", scheme: "bearer" },
        },
        schemas: {
            FeedItem: {
                type: "object",
                properties: {
                    programId: { type: "string" },
                    slug: { type: "string" },
                    name: { type: "string" },
                    tags: { type: "array", items: { type: "string" } },
                    latestUrl: { type: "string", format: "uri" },
                    updatedAt: { type: "string", format: "date-time", nullable: true },
                },
            },
            Feed: {
                type: "object",
                properties: {
                    items: { type: "array", items: { $ref: "#/components/schemas/FeedItem" } },
                    nextCursor: { type: "string", nullable: true },
                },
            },
            Error: {
                type: "object",
                properties: {
                    error: { type: "string" },
                    message: { type: "string" },
                },
            },
        },
    },
    paths: {
        "/api/market-feed": {
            get: {
                tags: ["catalog"],
                summary: "Published catalog feed",
                parameters: [
                    { name: "limit", in: "query", schema: { type: "integer", minimum: 1, maximum: 100, default: 50 } },
                    { name: "cursor", in: "query", schema: { type: "string" }, description: "Pagination cursor from a previous response" },
                ],
                responses: {
                    200: {
                        description: "Feed page",
                        content: { "application/json": { schema: { $ref: "#/components/schemas/Feed" } } },
                    },
                },
            },
        },
        "/api/drills-head/{slug}": {
            get: {
                tags: ["catalog"],
                summary: "Latest version metadata (headers only)",
                description: "Supports `{slug}@{version}`. Returns ETag/Content-Length in headers with an empty body. Sends 304 when If-None-Match matches.",
                parameters: [
                    { name: "slug", in: "path", required: true, schema: { type: "string" } },
                    { name: "If-None-Match", in: "header", schema: { type: "string" } },
                ],
                responses: {
                    200: { description: "Metadata in headers" },
                    304: { description: "Not modified" },
                    404: { description: "Unknown slug or version" },
                },
            },
        },
        "/d/{slug}": {
            get: {
                tags: ["catalog"],
                summary: "Download the .drill file",
                description: "Supports `{slug}@{version}`. Returns the archive with Content-Disposition: attachment.",
                parameters: [{ name: "slug", in: "path", required: true, schema: { type: "string" } }],
                responses: {
                    200: {
                        description: "The drill archive",
                        content: { "application/vnd.ringdrill+zip": { schema: { type: "string", format: "binary" } } },
                    },
                    404: { description: "Unknown slug or version" },
                },
            },
        },
        "/i/{slug}": {
            get: {
                tags: ["catalog"],
                summary: "Install / preview page",
                parameters: [{ name: "slug", in: "path", required: true, schema: { type: "string" } }],
                responses: {
                    200: { description: "HTML preview", content: { "text/html": {} } },
                    404: { description: "Unknown slug" },
                },
            },
        },
        "/brief/{uuid}": {
            get: {
                tags: ["catalog"],
                summary: "Brief link",
                parameters: [{ name: "uuid", in: "path", required: true, schema: { type: "string" } }],
                responses: { 302: { description: "Redirect to web.ringdrill.app" } },
            },
        },
        "/api/drills-admin": {
            get: {
                tags: ["admin"],
                summary: "Read-only admin (listall, versions)",
                security: [{ bearerAuth: [] }],
                parameters: [
                    { name: "action", in: "query", required: true, schema: { type: "string", enum: ["listall", "versions"] } },
                    { name: "slug", in: "query", schema: { type: "string" }, description: "Required for versions" },
                    { name: "limit", in: "query", schema: { type: "integer", minimum: 1, maximum: 200, default: 50 } },
                    { name: "cursor", in: "query", schema: { type: "string" } },
                ],
                responses: { 200: { description: "OK" }, 401: { description: "Missing or invalid token" } },
            },
            post: {
                tags: ["admin"],
                summary: "Mutating admin (publish, unpublish, deleteversion, deleteall)",
                security: [{ bearerAuth: [] }],
                parameters: [
                    { name: "action", in: "query", required: true, schema: { type: "string", enum: ["publish", "unpublish", "deleteversion", "deleteall"] } },
                    { name: "slug", in: "query", required: true, schema: { type: "string" } },
                    { name: "version", in: "query", schema: { type: "string" }, description: "Required for deleteversion" },
                ],
                responses: { 200: { description: "OK" }, 401: { description: "Missing or invalid token" }, 404: { description: "Unknown slug" } },
            },
        },
        "/api/drills-upload": {
            post: {
                tags: ["admin"],
                summary: "Upload or replace a drill",
                description: "Body is the .drill archive. name, description and tags are read from program.json inside it.",
                security: [{ bearerAuth: [] }],
                parameters: [
                    { name: "slug", in: "query", schema: { type: "string" } },
                    { name: "published", in: "query", schema: { type: "boolean", default: false } },
                    { name: "version", in: "query", schema: { type: "string" } },
                ],
                requestBody: {
                    required: true,
                    content: { "application/vnd.ringdrill+zip": { schema: { type: "string", format: "binary" } } },
                },
                responses: { 200: { description: "Stored" }, 401: { description: "Missing or invalid token" }, 409: { description: "Slug/version conflict" } },
            },
        },
    },
};

export default async function (request) {
    const preflight = corsPreflight(request);
    if (preflight) return preflight;

    return withCors(request, new Response(JSON.stringify(SPEC), {
        status: 200,
        headers: {
            "content-type": "application/json",
            "cache-control": "public, max-age=300",
        },
    }));
}
