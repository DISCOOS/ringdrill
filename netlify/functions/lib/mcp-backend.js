// The hosted backend: the six MCP operations, served in-process (ADR-0060).
//
// Paired with `mcp/backend-cli.mjs`, which shells out to the `ringdrill` binary
// locally. Same operations and same return shapes, so `mcp/tools.mjs` cannot tell
// which one it has — one tool table, two implementations.
//
// The compiler operations go through the cross-compiled Dart in
// `mcp-compiler.js`. The catalog operations read Netlify Blobs directly, which is
// the reason ADR-0060 chose Netlify over a Worker: here they are a local call, and
// they reuse `metaToFeedItem` so the hosted `search_catalog` and the CLI's `feed`
// project the same shape from the same stored metadata rather than agreeing by
// coincidence.
//
// **No document is retained unless the caller asks.** ADR-0060 made that a
// requirement — a plan can be marked staff-only, and an author needs to know that
// sending it here compiles it and nothing more — and ADR-0064 amends it rather than
// dropping it: a call may pass `cache: true`, and only then is the document held,
// under its own content hash, for `DOC_CACHE_TTL_MS`. Retention is off by default,
// so the original promise still describes every caller who does not opt in.
//
// Three properties keep that safe without an account, which this endpoint does not
// have: the key is the server's own hash of the content, so a client cannot choose
// keys and the cache cannot be used as a general store; a hash is obtainable only by
// having already held the document, making it a capability key; and an entry expires.
// The dead-drop consequence — whoever holds a hash holds the document until it
// expires — is real and stated in the ADR.
//
// **What it *builds* for you is held, briefly, by default.** ADR-0070 narrows the
// sentence above for exactly one tool: `build_plan` puts the archive in
// `ARTIFACT_CACHE_NS` under the plan's own `contentHash` and answers with a URL, so
// ~100 KB of base64 no agent reads never enters the response — and so a chat client
// that truncates a long text block can still obtain the file. The asymmetry with the
// document cache is deliberate and argued in the ADR: a document is retained to save
// resending something the caller already has, an archive exists only because this
// server made it, and holding it for minutes *is* how it gets delivered. `inline:
// true` retains nothing and is the supported way to say so.
import {
    getDrillsStore as _getDrillsStore,
    getSlugRecord as _getSlugRecord,
    keysFor,
    latestVersionEntry,
    metaToFeedItem,
    readBinary as _readBinary,
    readJson as _readJson,
} from "./shared.js";
import {
    ARTIFACT_CACHE_NS,
    ARTIFACT_TTL_MS,
    archiveFileName,
    artifactKey,
} from "./mcp-artifact-store.js";
import { invoke as _invoke } from "./mcp-compiler.js";
import { createHash } from "node:crypto";
import { getStore } from "@netlify/blobs";

/// Largest source document accepted, in characters.
///
/// An abuse control from ADR-0060, and the cheapest one: the compiler is
/// synchronous, so a huge document is CPU the function cannot yield during. Well
/// above anything real — the seven-exercise anchor plan decompiles to about 12 KB —
/// so this bounds abuse without bounding use.
export const MAX_DOCUMENT_CHARS = 512 * 1024;

/// How long an opted-in document is held (ADR-0064).
///
/// The order of an authoring session, not a day. Long enough that an analyze-fix-
/// render-build loop keeps hitting, short enough that "held briefly" is honest.
export const DOC_CACHE_TTL_MS = 30 * 60 * 1000;

/// Namespace for the opt-in document cache, separate from the catalog's stores so
/// nothing here can collide with a published plan.
const DOC_CACHE_NS = "mcp-doc-cache";

/// Constructed per call, never memoized — the store bakes in an access token that
/// Netlify refreshes per invocation, and caching the client across a warm container
/// is the bug documented at length in `shared.js`.
function docCacheStore() {
    return getStore(DOC_CACHE_NS);
}

function artifactCacheStore() {
    return getStore(ARTIFACT_CACHE_NS);
}

/// The key a document is held under: the server's own hash of the exact bytes.
///
/// Server-computed on purpose. A client that could choose keys would turn this into
/// a general key-value store; content addressing means a retrieval can only ever
/// return what was stored under that content.
export function documentHash(document) {
    return createHash("sha256").update(document, "utf8").digest("hex");
}

/// Builds the hosted backend. Dependencies are injectable so the tests can drive
/// it without Netlify Blobs, matching the `createHandler({ deps })` shape the
/// other functions in this directory use.
export function createCompilerBackend({
    invoke = _invoke,
    getDrillsStore = _getDrillsStore,
    getSlugRecord = _getSlugRecord,
    readBinary = _readBinary,
    readJson = _readJson,
    origin = "https://api.ringdrill.app",
    docCache = docCacheStore,
    artifactCache = artifactCacheStore,
} = {}) {
    /// Rejects an oversized document before it reaches the compiler.
    ///
    /// Thrown rather than returned as a diagnostic: this is not a problem with the
    /// author's plan, it is a refusal to try, and conflating the two would have an
    /// agent hunting its document for a mistake that is not there.
    /// A path is meaningful only to a server on the caller's machine (ADR-0064).
    ///
    /// Refused explicitly rather than ignored: falling through to "a source
    /// document is required" would send an agent hunting for an argument it did
    /// supply.
    function rejectPath(documentPath) {
        if (documentPath === undefined) return;
        throw new Error(
            "document_path is meaningful only to a local server: this endpoint " +
                "has no access to your filesystem. Send `document` instead, or " +
                "use the stdio server (see mcp/README.md).",
        );
    }

    /// The same refusal for `output_path` (ADR-0070).
    ///
    /// Kept separate from `rejectPath` so the message can name what this server does
    /// *instead* — an agent that asked for a file wants to hear about the URL, not
    /// just that its argument was wrong.
    function rejectOutputPath(outputPath) {
        if (outputPath === undefined) return;
        throw new Error(
            "output_path is meaningful only to a local server: this endpoint " +
                "cannot write to your filesystem. Omit it and use the " +
                "`archive.url` this server answers with, or use the stdio server " +
                "(see mcp/README.md).",
        );
    }

    /// Turns the compiler's `drillBase64` into the `archive` handle a client reads
    /// (ADR-0070).
    ///
    /// `inline` short-circuits and retains nothing, which is both the old behaviour
    /// and the escape hatch for an author who will not have a derived artifact held.
    /// Otherwise the bytes are held under the plan's own content hash and replaced by
    /// a URL — the whole point being that ~100 KB of base64 no agent reads never
    /// enters the response.
    ///
    /// A build that did not produce an archive (a refusal under `strict`, a document
    /// with errors) passes through untouched: there is nothing to hand over, and
    /// inventing an `archive` for it would have an agent following a link to a file
    /// that was never built.
    /// Falls back to the bytes, saying why.
    ///
    /// Only reachable when a handle cannot be produced, and typed `inline` in every
    /// case so an agent reads what it got rather than inferring it. `note` exists
    /// because "you asked for a URL and received base64" needs a reason attached —
    /// without one, a client cannot tell a deliberate `inline: true` from a
    /// degradation, and would report a working build as a broken one.
    function inlineArchive(rest, base64, note) {
        return {
            ...rest,
            archive: { kind: "inline", base64, ...(note ? { note } : {}) },
        };
    }

    async function deliverArchive(result, { inline }) {
        const { drillBase64, ...rest } = result;
        if (!drillBase64) return rest;
        if (inline) return inlineArchive(rest, drillBase64);

        const hash = result.contentHash;
        if (!hash) {
            // Content addressing is the only key this cache has, so without a hash
            // there is nowhere safe to put the bytes — inventing a key would make one
            // a client could then guess at.
            return inlineArchive(
                rest,
                drillBase64,
                "returned inline because this build carries no contentHash to " +
                    "address the archive by",
            );
        }

        const storedAt = Date.now();
        try {
            await artifactCache().setJSON(artifactKey(hash), {
                base64: drillBase64,
                storedAt,
                fileName: archiveFileName(result.name),
            });
        } catch (e) {
            // The compile is the expensive part and it succeeded. Discarding it
            // because the *delivery* mechanism failed would turn a storage hiccup
            // into a lost ten-second build, so hand over what we have and name the
            // reason. The bytes are large and that is the cost this normally avoids —
            // which is exactly why the note says what happened.
            return inlineArchive(
                rest,
                drillBase64,
                `returned inline because the archive could not be held for ` +
                    `download: ${e?.message ?? e}`,
            );
        }

        return {
            ...rest,
            archive: {
                kind: "url",
                url: `${origin}/mcp/artifact/${hash}.drill`,
                expires_at: new Date(storedAt + ARTIFACT_TTL_MS).toISOString(),
            },
        };
    }

    /// Resolves the document for a call: the text, or the one held under a hash.
    ///
    /// Returns `{ document, hash }`, where `hash` is set only when the caller asked
    /// for the document to be held — the response reports it so a later call can
    /// send the hash instead of the text.
    ///
    /// A miss is a *result*, not a transport failure: a cold or expired cache should
    /// cost a resend, not an unexplained error. So the message says exactly what to
    /// do, which is the whole reason the miss is typed at all.
    async function resolveDocument({ document, document_hash, cache }) {
        if (document === undefined && document_hash !== undefined) {
            const store = docCache();
            const entry = await store.get(`doc/${document_hash}`, {
                type: "json",
            });
            const age = entry ? Date.now() - (entry.storedAt ?? 0) : Infinity;
            if (!entry || age > DOC_CACHE_TTL_MS) {
                // Delete on an expired read rather than only on a sweep: the promise
                // is that an entry does not outlive its window, and the read is the
                // moment we know it has.
                if (entry) await store.delete(`doc/${document_hash}`);
                throw new Error(
                    `no document is held under ${document_hash} — it was never ` +
                        `cached, or it has expired (documents are held for ` +
                        `${Math.round(DOC_CACHE_TTL_MS / 60000)} minutes). Send ` +
                        `\`document\` again, with \`cache: true\` to hold it.`,
                );
            }
            return { document: entry.document, hash: document_hash };
        }

        checkDocument(document);
        if (!cache) return { document, hash: undefined };

        const hash = documentHash(document);
        await docCache().setJSON(`doc/${hash}`, {
            document,
            storedAt: Date.now(),
        });
        return { document, hash };
    }

    function checkDocument(document) {
        if (typeof document !== "string" || document.length === 0) {
            throw new Error("a source document is required");
        }
        if (document.length > MAX_DOCUMENT_CHARS) {
            throw new Error(
                `document is ${document.length} characters; this endpoint accepts ` +
                    `up to ${MAX_DOCUMENT_CHARS}. Use the local server for ` +
                    `something this large (see mcp/README.md).`,
            );
        }
    }

    return {
        schema: async () => {
            const result = await invoke({ op: "schema" });
            // The CLI's `schema --json` prints the schema itself, not a wrapper, so
            // the hosted tool has to unwrap to match.
            return result.schema ?? result;
        },

        create: (args) =>
            invoke({
                op: "create",
                name: args.name,
                exercises: args.exercises,
                teams: args.teams,
                stations: args.stations,
                rounds: args.rounds,
                lang: args.lang,
                bare: args.bare,
            }),

        analyze: async (args) => {
            rejectPath(args.document_path);
            const { document, hash } = await resolveDocument(args);
            const result = await invoke({
                op: "analyze",
                document,
                strict: args.strict,
            });
            return hash ? { ...result, document_hash: hash } : result;
        },

        build: async (args) => {
            rejectPath(args.document_path);
            rejectOutputPath(args.output_path);
            const { document, hash } = await resolveDocument(args);
            const result = await invoke({
                op: "build",
                document,
                strict: args.strict,
                fileName: "plan",
            });
            const delivered = await deliverArchive(result, {
                inline: args.inline,
            });
            return hash ? { ...delivered, document_hash: hash } : delivered;
        },

        render: async (args) => {
            rejectPath(args.document_path);
            const { document, hash } = await resolveDocument(args);
            const result = await invoke({
                op: "render",
                document,
                audience: args.audience,
                lang: args.lang,
                exercise: args.exercise,
                station: args.station,
                format: args.format,
            });
            return hash ? { ...result, document_hash: hash } : result;
        },

        /// The published catalog, projected exactly as `market-feed.js` does.
        searchCatalog: async ({ limit, cursor }) => {
            const pageSize = Math.min(100, Math.max(1, Number(limit) || 50));
            const drills = getDrillsStore();
            const items = [];
            let next = cursor || undefined;
            let nextCursor;

            while (items.length < pageSize) {
                const page = await drills.list({
                    prefix: "drills/",
                    cursor: next,
                    limit: 100,
                });
                next = page.cursor;

                const metaKeys = (page.blobs || [])
                    .map((b) => b.key)
                    .filter((k) => k.endsWith("/meta.json"));
                const metas = await Promise.all(
                    metaKeys.map((k) => drills.get(k, { type: "json" })),
                );

                for (const m of metas) {
                    if (!m || !m.published) continue;
                    items.push(metaToFeedItem(m, { origin }));
                    if (items.length >= pageSize) break;
                }

                if (!next || items.length >= pageSize) {
                    nextCursor = next;
                    break;
                }
            }

            items.sort((a, b) =>
                String(b.updatedAt).localeCompare(String(a.updatedAt)),
            );
            return nextCursor ? { items, nextCursor } : { items };
        },

        /// A published plan as a source document.
        ///
        /// Reads the archive straight out of blob storage and decompiles it in
        /// process — no HTTP hop to `/d/<slug>` and back, which is what makes this
        /// one call rather than two.
        getPlan: async ({ slug, version }) => {
            if (!slug) throw new Error("a slug is required");
            const record = await getSlugRecord(slug);
            if (!record) throw new Error(`no published plan with slug "${slug}"`);

            const { ownerId, programId } = record;
            let wanted = version ? String(version) : "latest";
            if (wanted === "latest") {
                // Resolve to the concrete version so the answer names what it read,
                // rather than "whatever latest was at the time".
                const { meta } = keysFor({ ownerId, programId, version: "latest" });
                const m = await readJson(meta);
                wanted = latestVersionEntry(m?.versions)?.v ?? "latest";
            }

            const keys = keysFor({ ownerId, programId, version: wanted });
            const bytes =
                (await readBinary(keys.versioned)) ??
                (await readBinary(keys.latest));
            if (!bytes) {
                throw new Error(
                    `no archive stored for "${slug}" version ${wanted}`,
                );
            }

            const result = await invoke({
                op: "decompile",
                drillBase64: Buffer.from(bytes).toString("base64"),
                header:
                    `Decompiled from the RingDrill catalog (${slug}, version ` +
                    `${wanted}).\nEdit freely, then build it.\nDerived fields are ` +
                    `omitted — the compiler fills them. uuids are kept so a ` +
                    `rebuild lands on the same plan rather than a copy.`,
            });
            return { ...result, slug, version: wanted };
        },
    };
}
