import { corsPreflight, withCors } from "./lib/shared.js";

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
        { name: "accounts", description: "Accounts, members and their plans (ADR-0024)" },
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
                    programId: { type: "string", deprecated: true, description: "Use planId. Kept for callers that haven't migrated yet (ADR-0055)." },
                    planId: { type: "string" },
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
                description: "Supports `{slug}@{version}`. Returns ETag/Content-Length/x-version in headers with an empty body. Sends 304 when If-None-Match matches.",
                parameters: [
                    { name: "slug", in: "path", required: true, schema: { type: "string" } },
                    { name: "If-None-Match", in: "header", schema: { type: "string" } },
                ],
                responses: {
                    200: {
                        description: "Metadata in headers",
                        headers: {
                            "x-version": { description: "The catalog publish version (e.g. \"5\")", schema: { type: "string" } },
                        },
                    },
                    304: {
                        description: "Not modified",
                        headers: {
                            "x-version": { description: "The catalog publish version (e.g. \"5\")", schema: { type: "string" } },
                        },
                    },
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
                        headers: {
                            "x-version": { description: "The catalog publish version (e.g. \"5\")", schema: { type: "string" } },
                        },
                        content: { "application/vnd.ringdrill+zip": { schema: { type: "string", format: "binary" } } },
                    },
                    304: {
                        description: "Not modified",
                        headers: {
                            "x-version": { description: "The catalog publish version (e.g. \"5\")", schema: { type: "string" } },
                        },
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
                tags: ["catalog"],
                summary: "Upload or replace a drill",
                description:
                    "Body is the .drill archive. name, description and tags are read from program.json inside it.\n\n"
                    + "Authentication is **optional**: anonymous publishing keeps working, and a public plan stays "
                    + "writable by anyone. Signing in buys protection, it is not the price of publishing "
                    + "(ADR-0025). The owner is taken from the verified token; the legacy `ownerId` query "
                    + "parameter is ignored.",
                // Two entries: `{}` is "no auth", the second is "bearer token".
                // Listing both is how OpenAPI spells optional — a single
                // bearerAuth entry would claim anonymous upload is rejected.
                security: [{}, { bearerAuth: [] }],
                parameters: [
                    { name: "slug", in: "query", schema: { type: "string" } },
                    { name: "published", in: "query", schema: { type: "boolean", default: false } },
                    { name: "version", in: "query", schema: { type: "string" } },
                    {
                        name: "accessPolicy",
                        in: "query",
                        description:
                            "Applies to a **new** plan only, so an ordinary update can never widen access as a "
                            + "side effect. Anonymous new plans are always public. `shared` is refused here — it "
                            + "names grantee accounts and is set afterwards via /api/drills/policy.",
                        schema: { type: "string", enum: ["account", "public"] },
                    },
                ],
                requestBody: {
                    required: true,
                    content: { "application/vnd.ringdrill+zip": { schema: { type: "string", format: "binary" } } },
                },
                responses: {
                    200: { description: "Stored" },
                    400: { description: "Unusable slug, archive or requested policy" },
                    403: { description: "Not permitted to write this plan" },
                    409: { description: "Slug/version conflict" },
                },
            },
        },
        "/api/invitations/{token}": {
            get: {
                tags: ["accounts"],
                summary: "What this invitation is, and what state it is in",
                description:
                    "**Anonymous on purpose.** The landing page has to say \"sign in as ola@example.com to "
                    + "accept\" before anyone has signed in, which it cannot do if reading the invitation "
                    + "already requires being the right person.\n\n"
                    + "The link is not a credential: it identifies which invitation is being answered and "
                    + "grants nothing on its own (DESIGN-015 §6.4).",
                security: [{}],
                parameters: [{ name: "token", in: "path", required: true, schema: { type: "string" } }],
                responses: {
                    200: {
                        description:
                            "`state` is one of `pending`, `accepted`, `withdrawn`, `expired`, "
                            + "`organisation_deleted` — each rendered differently by the page",
                    },
                    404: { description: "No such invitation" },
                },
            },
        },
        "/api/invitations/{token}/accept": {
            post: {
                tags: ["accounts"],
                summary: "Accept an invitation",
                description:
                    "Requires the signed-in user to hold a **verified** identity for the address the "
                    + "invitation was sent to. Binding to whoever opens the link would turn a forwarded "
                    + "email into account access.\n\n"
                    + "Single-use, but the token is marked rather than deleted, so a second visit reports "
                    + "`accepted` instead of `not_found` — the same link is routinely opened on two devices.",
                security: [{ bearerAuth: [] }],
                parameters: [{ name: "token", in: "path", required: true, schema: { type: "string" } }],
                responses: {
                    200: { description: "Joined — `{ accepted, accountId, organisation, role }`" },
                    401: { description: "Not signed in — following the link is not accepting it" },
                    403: { description: "`wrong_identity`, with the invited address and organisation so the page can offer both remedies" },
                    404: { description: "No such invitation" },
                    409: { description: "Already accepted" },
                    410: { description: "Withdrawn, expired, or the organisation was deleted" },
                },
            },
        },
        "/api/accounts/{id}/plans": {
            get: {
                tags: ["accounts"],
                summary: "List an account's plans",
                description:
                    "The Library's fourth tab (DESIGN-015 §5.7). Any member may read it, guests included: "
                    + "guest is a personal-data tier, so what a guest does not get is the roster inside a "
                    + "plan (ADR-0072), not the plan's existence.\n\n"
                    + "Unlike the public feed this includes **unpublished** plans, and each item says which "
                    + "it is — an account library showing only what had been published would omit exactly "
                    + "the drafts the tab exists for.",
                security: [{ bearerAuth: [] }],
                parameters: [
                    { name: "id", in: "path", required: true, schema: { type: "string" } },
                    { name: "limit", in: "query", schema: { type: "integer", minimum: 1, maximum: 100, default: 50 } },
                    { name: "cursor", in: "query", schema: { type: "string" } },
                ],
                responses: {
                    200: { description: "`{ items: [...], nextCursor? }`" },
                    401: { description: "Not signed in" },
                    403: { description: "Not a member of this account" },
                },
            },
        },
        "/api/drills/policy": {
            post: {
                tags: ["catalog"],
                summary: "Change a plan's access policy",
                description:
                    "Owner-only, and deliberately separate from upload: publishing and re-deciding who may see a "
                    + "plan are different decisions, and folding them together is how an update silently widens "
                    + "access (ADR-0025).",
                security: [{ bearerAuth: [] }],
                parameters: [
                    { name: "slug", in: "query", required: true, schema: { type: "string" } },
                ],
                requestBody: {
                    required: true,
                    content: {
                        "application/json": {
                            schema: {
                                type: "object",
                                required: ["accessPolicy"],
                                properties: {
                                    accessPolicy: { type: "string", enum: ["account", "shared", "public"] },
                                    sharedAccountIds: {
                                        type: "array",
                                        items: { type: "string" },
                                        description: "Required and non-empty when accessPolicy is `shared`. Cleared when it is not.",
                                    },
                                },
                            },
                        },
                    },
                },
                responses: {
                    200: { description: "Updated" },
                    400: { description: "Unknown policy, or `shared` with no grantee accounts" },
                    401: { description: "Not signed in" },
                    403: { description: "Not the owner, or the plan is anon-owned and has no owner to check" },
                    404: { description: "Unknown slug" },
                    412: { description: "Changed concurrently — re-read and retry" },
                },
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
