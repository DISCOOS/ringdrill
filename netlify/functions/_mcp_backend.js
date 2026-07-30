// The hosted backend: the six MCP operations, served in-process (ADR-0060).
//
// Paired with `mcp/backend-cli.mjs`, which shells out to the `ringdrill` binary
// locally. Same operations and same return shapes, so `mcp/tools.mjs` cannot tell
// which one it has — one tool table, two implementations.
//
// The compiler operations go through the cross-compiled Dart in
// `_mcp_compiler.js`. The catalog operations read Netlify Blobs directly, which is
// the reason ADR-0060 chose Netlify over a Worker: here they are a local call, and
// they reuse `metaToFeedItem` so the hosted `search_catalog` and the CLI's `feed`
// project the same shape from the same stored metadata rather than agreeing by
// coincidence.
//
// **No document is persisted.** ADR-0060 makes that a requirement rather than an
// implementation note: a plan can be marked staff-only, and an author needs to know
// that sending it here compiles it and nothing more. The compiler is a pure
// function over the request, there is no write path in this file, and the only
// storage touched is a read of the public catalog.
import {
    getDrillsStore as _getDrillsStore,
    getSlugRecord as _getSlugRecord,
    keysFor,
    latestVersionEntry,
    metaToFeedItem,
    readBinary as _readBinary,
    readJson as _readJson,
} from "./_shared.js";
import { invoke as _invoke } from "./_mcp_compiler.js";

/// Largest source document accepted, in characters.
///
/// An abuse control from ADR-0060, and the cheapest one: the compiler is
/// synchronous, so a huge document is CPU the function cannot yield during. Well
/// above anything real — the seven-exercise anchor plan decompiles to about 12 KB —
/// so this bounds abuse without bounding use.
export const MAX_DOCUMENT_CHARS = 512 * 1024;

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
} = {}) {
    /// Rejects an oversized document before it reaches the compiler.
    ///
    /// Thrown rather than returned as a diagnostic: this is not a problem with the
    /// author's plan, it is a refusal to try, and conflating the two would have an
    /// agent hunting its document for a mistake that is not there.
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

        analyze: ({ document, strict }) => {
            checkDocument(document);
            return invoke({ op: "analyze", document, strict });
        },

        build: ({ document, strict }) => {
            checkDocument(document);
            return invoke({ op: "build", document, strict, fileName: "plan" });
        },

        render: ({ document, audience, lang, exercise }) => {
            checkDocument(document);
            return invoke({ op: "render", document, audience, lang, exercise });
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
