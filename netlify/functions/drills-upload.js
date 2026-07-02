import { unzipSync, strFromU8, zipSync } from "fflate";
import {
    keysFor, readJson, sanitizeSlug,
    getSlugRecord, claimSlug, sha256Hex,
    toStrongEtag, nowIso, originFromRequest, readDrillBytes,
    writeBinaryConditional, writeJsonConditional,
    corsPreflight, withCors
} from "./_shared.js";

// The highest schema version this function accepts. Bumping this requires
// coordinated changes to the Flutter app and this handler (AGENTS.md).
const KNOWN_SCHEMA_MAX = "1.2";

// Count top-level `exercises/<uuid>.json` archive entries. Per-station
// markdown lives at `exercises/<uuid>/stations/<index>/<field>.md` (see
// DrillFile.fromBytes in lib/data/drill_file.dart) and must not be counted,
// hence the "no further slash after the uuid" requirement.
function countExerciseFiles(files) {
    if (!files) return 0;
    return Object.keys(files).filter(k => /^exercises\/[^/]+\.json$/.test(k)).length;
}

/**
 * Read the plan-level name, description and tags from a `program.json`
 * entry, plus the exercise count derived from the archive's exercise files
 * (ADR-0040).
 *
 * `files` is the already-unzipped archive map (name -> Uint8Array), so this
 * reuses the unzip stripActorsAndValidate already did rather than opening the
 * archive a second time. Returns { name, description, tags, exerciseCount }
 * with name/description either a non-null value or null when absent/
 * unparseable, tags either the array or [] — never throws.
 *
 * `exerciseCount` counts top-level `exercises/<uuid>.json` entries rather
 * than `program.json.exercises`: DrillFile.build() always serializes
 * exercises out to individual files and writes `program.exercises: []` (see
 * lib/data/drill_file.dart), so the embedded array is never populated and
 * counting it would always yield 0. Counting files is a real measurement of
 * the unzipped archive, so it is always an integer — never null, even when
 * program.json is missing or malformed.
 */
export function programInfoFromArchive(files) {
    const exerciseCount = countExerciseFiles(files);
    const entry = files?.["program.json"];
    if (!entry) return { name: null, description: null, tags: [], exerciseCount };
    try {
        const p = JSON.parse(strFromU8(entry));
        return {
            name: typeof p?.name === "string" ? p.name : null,
            description: typeof p?.description === "string" ? p.description : null,
            tags: Array.isArray(p?.tags) ? p.tags : [],
            exerciseCount,
        };
    } catch {
        return { name: null, description: null, tags: [], exerciseCount };
    }
}

/**
 * Resolve the `author` and `accessPolicy` to write into meta.json at publish
 * time (ADR-0040). `author` mirrors `ownerId` today — opaque and usually
 * "anon" — until ADR-0024 resolves it to an account display name.
 * `accessPolicy` defaults per ADR-0025: anon-owned plans are `public`,
 * everything else is `account`, until a signed-in publish flow sets a real
 * value explicitly.
 */
export function resolvePublishPolicy({ ownerId }) {
    return {
        author: ownerId,
        accessPolicy: ownerId === "anon" ? "public" : "account",
    };
}

/**
 * Resolve the catalog `name`, `description` and `tags` solely from the plan's
 * own program.json. The query string no longer overrides plan content fields
 * (ADR-0043): name, description and tags have a single source of truth.
 *
 * name  = program.name when non-empty, else slug.
 * description = program.description ?? "".
 * tags  = program.tags (already [] when absent).
 */
export function resolveCatalogFields({ program, slug }) {
    const name = (program?.name && program.name.trim()) ? program.name : slug;
    const description = program?.description ?? "";
    const tags = Array.isArray(program?.tags) ? program.tags : [];
    return { name, description, tags };
}

/**
 * Strip the actors/ folder from a .drill archive and validate the schema.
 * Returns { strippedBytes, program, error } where error is a Response when
 * invalid and program is the { name, description } read from program.json.
 *
 * Actors are local PII (phone, real name) and must never reach the catalog.
 * The strip happens here rather than in the client because the same .drill
 * may legitimately carry actors/ peer-to-peer (USB, AirDrop, email).
 */
export function stripActorsAndValidate(request, bytes) {
    let files;
    try {
        files = unzipSync(new Uint8Array(bytes));
    } catch (e) {
        return { error: withCors(request, new Response(
            `Invalid archive: ${e.message}`,
            { status: 400 }
        )) };
    }

    // Read and validate schema from metadata.json
    const metadataEntry = files["metadata.json"];
    if (metadataEntry) {
        let metadata;
        try {
            metadata = JSON.parse(strFromU8(metadataEntry));
        } catch (_) {
            // malformed metadata.json is not a schema violation; continue
        }
        if (metadata?.schema) {
            const clientSchema = String(metadata.schema);
            // Simple semver-like comparison for 1.x schemas.
            // Reject if client schema > our max.
            if (compareSchemas(clientSchema, KNOWN_SCHEMA_MAX) > 0) {
                return { error: withCors(request, new Response(
                    JSON.stringify({ error: "unsupported_schema", schema: clientSchema, max: KNOWN_SCHEMA_MAX }),
                    { status: 415, headers: { "content-type": "application/json" } }
                )) };
            }
        }
    }

    // Plan-level name/description live in program.json — read them here while
    // the archive is unzipped so the caller can seed catalog meta from the
    // authoritative source instead of relying only on query params.
    const program = programInfoFromArchive(files);

    // Strip actors/ folder entries (PII — never published to catalog)
    const stripped = {};
    for (const [name, data] of Object.entries(files)) {
        if (!name.startsWith("actors/")) {
            stripped[name] = data;
        }
    }

    return { strippedBytes: Buffer.from(zipSync(stripped)), program };
}

/**
 * Compare two "major.minor" schema strings.
 * Returns negative if a < b, 0 if equal, positive if a > b.
 */
function compareSchemas(a, b) {
    const [aMaj, aMin] = a.split(".").map(Number);
    const [bMaj, bMin] = b.split(".").map(Number);
    if (aMaj !== bMaj) return aMaj - bMaj;
    return (aMin || 0) - (bMin || 0);
}

export default async function (request) {
    const preflight = corsPreflight(request);
    if (preflight) return preflight;

    try {
        if (request.method !== "POST") return withCors(request, new Response("Method Not Allowed", { status: 405 }));

        const url = new URL(request.url);
        const qs = url.searchParams;

        const nameOrSlug = qs.get("slug") || qs.get("name");
        const slug = sanitizeSlug(nameOrSlug || "program");

        // Look up existing mapping (if any) BEFORE deciding ownerId/programId
        const existing = await getSlugRecord(slug);

        // Use provided IDs if present; otherwise reuse existing; otherwise defaults
        const ownerIdParam   = qs.get("ownerId");
        const programIdParam = qs.get("programId");

        const ownerId = ownerIdParam ?? existing?.ownerId ?? "anon";
        const programId = programIdParam ?? existing?.programId
            ?? (globalThis.crypto?.randomUUID?.() || Math.random().toString(36).slice(2) + Date.now().toString(36));

        const explicitVersion = qs.get("version");
        const published = (qs.get("published") || "false").toLowerCase() === "true";

        const rawBytes = await readDrillBytes(request);

        // ---- Strip actors/ and validate schema ----
        // actors/ contains PII (phone, real name) and must never reach the
        // catalog. The strip is server-side only; peer-to-peer .drill files
        // legitimately carry actors/.
        const { strippedBytes, program, error: archiveError } = stripActorsAndValidate(request, rawBytes);
        if (archiveError) return archiveError;
        const bytes = strippedBytes;

        // Plan content (name, description, tags) comes solely from program.json.
        // The query string carries only operation params (ADR-0043).
        const { name, description, tags } = resolveCatalogFields({ program, slug });

        // ---- Slug claim / ownership check ----
        const slugTakenResponse = () => withCors(request, new Response(
            `Slug '${slug}' already in use`,
            { status: 409, headers: { "x-conflict-kind": "slug" } }
        ));
        if (!existing) {
            // Atomic create (onlyIfNew)
            const claimed = await claimSlug(slug, { ownerId, programId, createdAt: nowIso() });
            if (!claimed) {
                // someone else created between our read and write → verify ownership
                const now = await getSlugRecord(slug);
                if (!now || now.ownerId !== ownerId || now.programId !== programId) {
                    return slugTakenResponse();
                }
            }
        } else {
            // Slug exists — enforce same mapping unless caller explicitly changed it
            if (existing.ownerId !== ownerId || existing.programId !== programId) {
                return slugTakenResponse();
            }
        }

        const { latest, meta } = keysFor({ ownerId, programId, version: "_" });
        const currentMeta = await readJson(meta, {
            programId, slug, name, ownerId, description, published: false, tags: [], versions: []
        });

        // Sort meta.versions once — used by the OCC check and the "is this a
        // no-op?" check.
        const sortedVersions = (currentMeta.versions || [])
            .slice()
            .sort((a, b) => a.v.localeCompare(b.v, undefined, { numeric: true }));
        const currentLatest = sortedVersions.length
            ? sortedVersions[sortedVersions.length - 1]
            : null;
        const currentContentEtag = currentLatest?.etag ?? null;

        // ---- Optimistic concurrency check ----
        // The single OCC gate: the client's If-Match (a content etag = sha256
        // of the bytes they last saw as "latest") must match the most recent
        // version's content etag in meta. If yes, their view is fresh and we
        // proceed. If no, state has moved on and we return 412 — the client
        // should refresh + show a diff against the new remote state before
        // retrying. Subsequent writes (latest, meta) are unconditional
        // overwrites; we trust the gate above.
        const clientIfMatch = request.headers.get("if-match");
        if (clientIfMatch && clientIfMatch !== currentContentEtag) {
            return withCors(request, new Response(
                "Precondition failed (latest changed since you last saw it)",
                { status: 412 }
            ));
        }

        // ---- No-op check ----
        // If the bytes the client is uploading are byte-identical to the
        // current latest version, there's nothing to publish. Return 304 with
        // the existing etag/version — no new versioned blob, no meta change.
        // (Without this, repeated publishes of the same content accumulate
        // duplicate versioned blobs with the same content etag.)
        const incomingEtag = toStrongEtag(sha256Hex(bytes));
        if (currentLatest && currentLatest.etag === incomingEtag) {
            const origin = originFromRequest(request);
            return withCors(request, new Response(null, {
                status: 304,
                headers: {
                    "etag": incomingEtag,
                    "x-version": String(currentLatest.v),
                    "x-latest": `${origin}/d/${slug}`,
                    "x-versioned": `${origin}/d/${slug}@${currentLatest.v}`,
                    "x-program-id": String(programId),
                },
            }));
        }

        // ---- Write versioned blob ----
        // Auto-bump version: start at max(meta.versions) + 1, walk forward on
        // collision (orphan versioned blobs from previous failed uploads can
        // leave gaps where storage has the slot but meta does not). Bounded
        // retry. Explicit-version callers get the legacy "409 if taken"
        // behaviour without walking.
        const maxVersionRetries = 16;
        let version;
        let versioned;
        let vRes;
        let attemptVersion = explicitVersion
            ? null
            : (currentMeta.versions || []).reduce((acc, v) => {
                  const n = parseInt(v.v, 10);
                  return Number.isFinite(n) ? Math.max(acc, n) : acc;
              }, 0) + 1;
        for (let attempt = 0; ; attempt++) {
            version = explicitVersion ?? String(attemptVersion);
            versioned = keysFor({ ownerId, programId, version }).versioned;
            vRes = await writeBinaryConditional(versioned, bytes, { onlyIfNew: true });
            if (vRes.modified) break;
            if (explicitVersion || attempt >= maxVersionRetries) {
                return withCors(request, new Response(
                    `Version '${version}' already exists`,
                    { status: 409, headers: { "x-conflict-kind": "version" } }
                ));
            }
            attemptVersion += 1;
        }

        // ---- Update latest (unconditional overwrite) ----
        // The OCC gate above has already established that the client's view
        // is fresh. We don't second-guess with another storage-level lock.
        await writeBinaryConditional(latest, bytes, {});

        // ---- Update meta (unconditional overwrite) ----
        const etag = toStrongEtag(sha256Hex(bytes));
        currentMeta.slug = slug;
        currentMeta.name = name;
        currentMeta.description = description;
        currentMeta.published = !!published;
        currentMeta.tags = tags;
        currentMeta.exerciseCount = program.exerciseCount;
        const { author, accessPolicy } = resolvePublishPolicy({ ownerId });
        currentMeta.author = author;
        currentMeta.accessPolicy = accessPolicy;
        const without = (currentMeta.versions || []).filter(v => v.v !== version);
        currentMeta.versions = [
            ...without,
            { v: version, etag, size: bytes.length, updatedAt: nowIso() }
        ].sort((a, b) => a.v.localeCompare(b.v, undefined, { numeric: true }));
        await writeJsonConditional(meta, currentMeta, {});

        const origin = originFromRequest(request);
        return withCors(request, new Response(JSON.stringify({
            slug, programId, version, etag,
            latest:    `${origin}/d/${slug}`,
            versioned: `${origin}/d/${slug}@${version}`,
        }), { status: 200, headers: { "content-type": "application/json" } }));

    } catch (e) {
        return withCors(request, new Response(`Upload error: ${e.message || e}`, { status: 500 }));
    }
}
