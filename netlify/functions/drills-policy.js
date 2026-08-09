import {
    corsPreflight, withCors,
    readJsonStrong as _readJsonStrong,
    writeJsonConditional as _writeJsonConditional,
    getBlobEtag as _getBlobEtag,
} from "./lib/shared.js";
import { authenticate } from "./lib/auth/index.js";
import { ACCESS_POLICIES, authorizePolicyChange } from "./lib/authorize.js";
import { findEntry as _findEntry, keysForEntry, parseCatalogPath, resolveNamespace as _resolveNamespace } from "./lib/catalog.js";

/**
 * `POST /api/drills/policy?slug=<slug>` — change a plan's access policy
 * (ADR-0025).
 *
 * Separate from upload on purpose. A publish must never widen or narrow who may
 * write, because that would let any authorised writer change access as a side
 * effect of an ordinary update; deciding *who else* may publish is
 * administration, and administration is what `owner` means.
 */

const json = (body, status = 200) =>
    new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });

export function createHandler({
    env = process.env,
    now = Date.now,
    findEntry = _findEntry,
    resolveNamespace = _resolveNamespace,
    readJsonStrong = _readJsonStrong,
    getBlobEtag = _getBlobEtag,
    writeJsonConditional = _writeJsonConditional,
} = {}) {
    return async function (request) {
        const preflight = corsPreflight(request);
        if (preflight) return preflight;

        try {
            if (request.method !== "POST") {
                return withCors(request, json({ error: "method_not_allowed" }, 405));
            }

            const url = new URL(request.url);
            const raw = (url.searchParams.get("slug") ?? "").trim();
            const parsed = parseCatalogPath(raw);
            if (!parsed) return withCors(request, json({ error: "missing_slug" }, 400));

            const body = await request.json().catch(() => ({}));
            const wanted = String(body.accessPolicy ?? "").toLowerCase();
            if (!Object.values(ACCESS_POLICIES).includes(wanted)) {
                return withCors(request, json({ error: "invalid_access_policy" }, 400));
            }

            // `shared` names grantee accounts, so it is meaningless without at
            // least one — silently storing an empty list would read as "shared"
            // in the UI while behaving as "account".
            const sharedAccountIds = Array.isArray(body.sharedAccountIds)
                ? body.sharedAccountIds.filter((s) => typeof s === "string")
                : [];
            if (wanted === ACCESS_POLICIES.SHARED && sharedAccountIds.length === 0) {
                return withCors(request, json({ error: "shared_requires_accounts" }, 400));
            }

            const ns = await resolveNamespace(parsed.explicitNamespace ? parsed.namespace : null, {});
            const entry = await findEntry({ namespace: ns.namespace, slug: parsed.slug }, { strong: true });
            if (!entry) return withCors(request, json({ error: "unknown_slug" }, 404));

            const { meta: metaKey } = keysForEntry(entry, "latest");
            // Strong: this object is mutated and written back, so an eventually
            // consistent read would erase whatever landed in between.
            const meta = await readJsonStrong(metaKey, null);

            const principal = await authenticate(request, { env, now });
            const decision = authorizePolicyChange({ principal, existing: entry, meta });
            if (!decision.ok) return withCors(request, json({ error: decision.reason }, decision.status));

            // Read the etag before the value it guards (see lib/shared.js): the
            // other order lets a stale value pass a fresh etag and silently
            // erase a concurrent change.
            const etag = await getBlobEtag(metaKey);
            const next = {
                ...(meta ?? {}),
                accessPolicy: wanted,
                sharedAccountIds: wanted === ACCESS_POLICIES.SHARED ? sharedAccountIds : [],
            };
            const { modified } = await writeJsonConditional(metaKey, next, { onlyIfMatch: etag ?? undefined });
            if (!modified) return withCors(request, json({ error: "conflict" }, 412));

            return withCors(request, json({
                slug: parsed.slug,
                namespace: ns.namespace === "anon" ? null : ns.namespace,
                accessPolicy: wanted,
                sharedAccountIds: next.sharedAccountIds,
            }));
        } catch (err) {
            console.error("[drills-policy]", err);
            return withCors(request, json({ error: "internal" }, 500));
        }
    };
}

export default createHandler();
