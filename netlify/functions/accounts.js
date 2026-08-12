import { getStore } from "@netlify/blobs";
import {
    corsPreflight, withCors, metaToFeedItem,
    getDrillsStore as _getDrillsStore, getSlugIndexStore as _getSlugIndexStore,
    readJson as _readJson, writeJsonConditional as _writeJsonConditional,
} from "./lib/shared.js";
import { authenticate } from "./lib/auth/index.js";
import {
    acceptedOwners, claimHandle, defaultStores, deleteAccount, getAccount, getUser, membersOf,
    membershipsOf, newId, normalizeEmail, putMember, removeMember, resolveHandle,
    expiryIndexKey, soleOwnerships, sweepExpired, upgradeToOrganisation, validateHandle,
} from "./lib/identity.js";
import { dropAccountOwnership, keysForEntry } from "./lib/catalog.js";
import { createMailer, sendTemplate } from "./lib/mail/index.js";

/**
 * Organisations and their members (ADR-0024, DESIGN-015 §6).
 *
 * The rules that are easy to get wrong, and are therefore enforced here rather
 * than assumed by callers:
 *
 * * **Only an owner administers.** Publishing follows from membership — every
 *   member publishes, including a guest — so `owner` is not "can do more with
 *   plans", it is "can decide who else is here" (ADR-0024, amended 2026-08-05).
 * * **An organisation always keeps one accepted owner.** Demoting or removing
 *   the last one is refused, not offered and then failed.
 * * **Invited is a state, not a role.** The role is chosen at invite time and
 *   confers nothing until `acceptedAt` is set (DESIGN-015 §6.2).
 */

const ROLES = new Set(["owner", "member", "guest"]);
const INVITE_TTL_DAYS = 14;
const strong = { consistency: "strong" };

const json = (body, status = 200) =>
    new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });

export function createHandler({
    env = process.env,
    now = Date.now,
    stores = defaultStores,
    inviteStore = () => getStore("invitations", strong),
    // The `<expiresAt>/<token>` expiry index. Without it the sweep below reads
    // every invitation in the store to find the handful that have lapsed —
    // fourteen days' worth, on the path an organisation walks once per member
    // it invites.
    inviteExpiryStore = () => getStore("invitations-expiry", strong),
    getDrillsStore = _getDrillsStore,
    getSlugIndexStore = _getSlugIndexStore,
    readJson = _readJson,
    writeJson = _writeJsonConditional,
    mailer = null,
} = {}) {
    return async function (request) {
        const preflight = corsPreflight(request);
        if (preflight) return preflight;

        try {
            const { pathname } = new URL(request.url);
            const tail = pathname.replace(/^.*\/(?:\.netlify\/functions\/accounts|api\/accounts)\/?/, "");
            // Decoded, because a pending member is keyed by email address and
            // arrives percent-encoded (`pending%3Aola%40example.com`). Account
            // ids and section names are unaffected — there is nothing in them
            // to decode.
            const parts = tail.split("/").filter(Boolean).map(safeDecode);

            const principal = await authenticate(request, { env, now });
            if (!principal.ok) return withCors(request, json({ error: principal.reason }, principal.status));
            if (principal.anonymous) return withCors(request, json({ error: "authentication_required" }, 401));

            // POST /api/accounts
            if (parts.length === 0 && request.method === "POST") {
                return withCors(request, await createOrganisation(request, principal));
            }

            // GET /api/accounts/lookup?handle=… — resolve a handle to the id
            // that gets stored. Matched before the `:id` routes below, since
            // `lookup` is not an account id.
            if (parts.length === 1 && parts[0] === "lookup" && request.method === "GET") {
                return withCors(request, await lookup(request));
            }

            const [accountId, section, memberUserId] = parts;
            if (!accountId) return withCors(request, json({ error: "not_found" }, 404));

            if (section === "members") {
                if (request.method === "GET" && !memberUserId) return withCors(request, await listMembers(accountId, principal));
                if (request.method === "POST" && !memberUserId) return withCors(request, await invite(request, accountId, principal));
                if (request.method === "PATCH" && memberUserId) return withCors(request, await changeRole(request, accountId, memberUserId, principal));
                if (request.method === "DELETE" && memberUserId) return withCors(request, await remove(accountId, memberUserId, principal));
            }

            // GET /api/accounts/:id/plans — the Library's fourth tab
            // (DESIGN-015 §5.7).
            if (section === "plans" && !memberUserId && request.method === "GET") {
                return withCors(request, await listPlans(request, accountId, principal));
            }

            // DELETE /api/accounts/:id — delete an organisation, or the
            // caller's own account (DESIGN-015 §5.1).
            if (!section && request.method === "DELETE") {
                return withCors(request, await destroy(request, accountId, principal));
            }

            return withCors(request, json({ error: "not_found" }, 404));
        } catch (err) {
            console.error("[accounts]", err);
            return withCors(request, json({ error: "internal" }, 500));
        }
    };

    function isMember(principal, accountId) {
        return Array.isArray(principal.accounts) && principal.accounts.includes(accountId);
    }
    function isOwner(principal, accountId) {
        return isMember(principal, accountId) && principal.roles?.[accountId] === "owner";
    }

    /**
     * Resolve a handle to the account id behind it.
     *
     * Exists because sharing a plan with another account has to name that
     * account, and **ids are what gets stored** — handles are (semi-)
     * changeable, ids are not (ADR-0074). Asking a person for an opaque id is
     * asking them to fetch something they have never seen; asking for a handle
     * is asking for the name already in their plan URLs.
     *
     * **Exact match only, and no search.** That is the whole of the
     * enumeration answer: a handle is already public — it appears in
     * `/d/<handle>/<slug>` on every shared link — so resolving one reveals
     * nothing that trying the URL would not. A prefix or fuzzy *search*
     * endpoint would be a different thing entirely: a tool for listing which
     * organisations exist. This is deliberately not that, and authentication
     * on top keeps it away from drive-by scanning.
     *
     * Only the id and the display name come back. Membership, size and
     * addresses are none of a prospective grantee's business.
     */
    async function lookup(request) {
        const handle = new URL(request.url).searchParams.get("handle") ?? "";
        const resolved = await resolveHandle(handle, stores);
        if (!resolved) return json({ error: "not_found" }, 404);

        const account = await getAccount(resolved.accountId, stores);
        // A handle whose account is gone is a tombstone from a deletion. It
        // still resolves for existing links, but there is nothing left to
        // share *with*.
        if (!account) return json({ error: "not_found" }, 404);

        return json({
            accountId: account.id,
            displayName: account.displayName,
            handle: account.handle ?? null,
            // True when the caller used a retired name. The current one is in
            // `handle`, so the UI can say which it actually resolved to rather
            // than silently accepting a name that no longer exists.
            renamed: resolved.tombstone === true,
        });
    }

    async function createOrganisation(request, principal) {
        const body = await request.json().catch(() => ({}));
        const displayName = String(body.displayName ?? "").trim();
        if (!displayName) return json({ error: "missing_display_name" }, 400);

        if (body.handle) {
            const v = validateHandle(body.handle);
            if (!v.ok) return json({ error: `handle_${v.reason}` }, 400);
        }

        // "Upgrade my personal account" and "create a fresh organisation" are
        // both offered on the same sheet (DESIGN-015 §5.3) because they suit
        // different intents — one colleague versus a whole hjelpekorps.
        if (body.upgradeAccountId) {
            if (!isOwner(principal, body.upgradeAccountId)) return json({ error: "owner_role_required" }, 403);
            const account = await getAccount(body.upgradeAccountId, stores);
            if (!account) return json({ error: "no_such_account" }, 404);
            if (account.type !== "personal") return json({ error: "not_a_personal_account" }, 409);
            const res = await upgradeToOrganisation(body.upgradeAccountId, { displayName, handle: body.handle }, stores);
            if (!res.ok) return json({ error: res.reason }, res.reason === "taken" ? 409 : 400);
            return json({ account: res.account, upgraded: true });
        }

        const accountId = newId("a");
        if (body.handle) {
            const claimed = await claimHandle(body.handle, accountId, stores);
            if (!claimed.ok) return json({ error: `handle_${claimed.reason}` }, 409);
        }
        const account = {
            id: accountId, displayName, type: "organization",
            handle: body.handle ? validateHandle(body.handle).handle : null,
            createdAt: new Date(now()).toISOString(),
        };
        await stores.accounts().set(accountId, JSON.stringify(account));
        await putMember(accountId, principal.userId, "owner", { acceptedAt: new Date(now()).toISOString() }, stores);
        return json({ account, upgraded: false }, 201);
    }

    async function listMembers(accountId, principal) {
        if (!isMember(principal, accountId)) return json({ error: "not_a_member" }, 403);
        const members = await membersOf(accountId, stores);
        const out = [];
        for (const m of members) {
            const user = m.userId ? await getUser(m.userId, stores) : null;
            out.push({
                userId: m.userId ?? null,
                email: m.email ?? user?.primaryEmail ?? null,
                displayName: user?.displayName ?? null,
                role: m.role,
                // Invited and Failed are states on the row, not roles
                // (DESIGN-015 §6.2).
                state: m.acceptedAt ? "accepted" : (m.bouncedAt ? "failed" : "invited"),
                invitedAt: m.invitedAt ?? null,
                acceptedAt: m.acceptedAt ?? null,
            });
        }
        return json({ members: out, singleOwner: acceptedOwners(members).length === 1 });
    }

    /**
     * The account's plans — every member sees them, guests included.
     *
     * Guest is a *personal-data* tier, not a smaller view of the catalog: a
     * guest publishes like anyone else, so hiding the account's plans from
     * them would hide the thing they were invited to work on. What a guest
     * does not get is the roster inside a plan, and that is enforced on the
     * download path where the roster actually is (ADR-0072), not here.
     *
     * Unlike the public feed this lists **unpublished** plans too. An account
     * library that showed only what had been published would omit precisely
     * the drafts the tab exists for.
     *
     * The scan is by index prefix. `slugIndexKey` is `<namespace>/<slug>` and
     * the stored namespace is the account **id**, so `"<accountId>/"` selects
     * exactly this account — the trailing slash is what stops `a_bergen/`
     * matching `a_bergen2/x`. No dedupe against flat legacy keys is needed
     * here the way the feed needs one: accounts did not exist before the
     * migration, so nothing account-namespaced can have a pre-migration twin.
     */
    async function listPlans(request, accountId, principal) {
        if (!isMember(principal, accountId)) return json({ error: "not_a_member" }, 403);

        const url = new URL(request.url);
        const limit = clampInt(url.searchParams.get("limit"), 1, 100, 50);
        const origin = url.origin;

        const idx = getSlugIndexStore();
        const drills = getDrillsStore();
        const prefix = `${accountId}/`;

        const items = [];
        let cursor = url.searchParams.get("cursor") || undefined;
        let nextCursor;

        while (items.length < limit) {
            const page = await idx.list({ prefix, cursor, limit: 100 });
            cursor = page.cursor;

            for (const b of page.blobs || []) {
                const key = String(b.key);
                const rec = await idx.get(key, { type: "json" });
                if (!rec) continue;

                const meta = await drills.get(keysForEntry(rec).meta, { type: "json" });
                if (!meta) continue;

                items.push({
                    ...metaToFeedItem(meta, { origin, namespace: accountId }),
                    // The feed can assume `published`; this list cannot, so it
                    // says so per item rather than leaving the client to guess
                    // from a missing field.
                    published: meta.published === true,
                });
                if (items.length >= limit) break;
            }

            if (!cursor || items.length >= limit) {
                nextCursor = cursor;
                break;
            }
        }

        items.sort((a, b) => String(b.updatedAt).localeCompare(String(a.updatedAt)));
        return json(nextCursor ? { items, nextCursor } : { items });
    }

    /**
     * Delete an account.
     *
     * Owner-only, and it refuses one case outright: a personal account whose
     * user is the **sole owner of an organisation**. Allowing it would strand
     * an organisation nobody can administer — the exact unrecoverable state
     * DESIGN-015 §4.4 exists to prevent, arrived at through a button rather
     * than through somebody becoming unavailable. The refusal names the
     * organisations so the user knows what to hand over first.
     *
     * What survives is as important as what goes, and is spelled out in
     * `deleteAccount` and `dropAccountOwnership`: published plans stay,
     * losing only their owner; the handle is retired rather than released.
     */
    async function destroy(request, accountId, principal) {
        if (!isOwner(principal, accountId)) return json({ error: "owner_role_required" }, 403);

        const account = await getAccount(accountId, stores);
        if (!account) return json({ error: "no_such_account" }, 404);

        const personal = account.type !== "organization";
        if (personal) {
            const stranded = await soleOwnerships(principal.userId, stores);
            if (stranded.length > 0) {
                return json({
                    error: "sole_owner_of_organisation",
                    organisations: stranded.map((o) => o.displayName),
                }, 409);
            }
        }

        // What happens to plans nobody else relies on. Deleting them is the
        // default because retaining somebody's data after they asked for it to
        // be gone needs a reason, and "they might have wanted it public" is
        // not one — publishing is an act with consequences they will not be
        // around to reverse.
        const body = await request.json().catch(() => ({}));
        const releaseDrafts = body.unpublishedPlans === "publish";

        // Ownership is dropped *before* the account goes. The other order
        // leaves a window where the entries name an account that no longer
        // exists, and a crash in that window strands them there permanently.
        const plans = await dropAccountOwnership(accountId, {
            indexStore: getSlugIndexStore(),
            drillsStore: getDrillsStore(),
            readJson,
            writeJson,
            releaseDrafts,
        });

        const res = await deleteAccount(
            accountId,
            {
                deleteUser: personal ? principal.userId : null,
                // Invitations live in their own store, unreachable from the
                // account — both the ones this user sent and the ones sent to
                // their address outlived deletion until this was passed.
                inviteStore: inviteStore(),
                // The handle is only worth retiring if a link still resolves
                // through it.
                retainedEntries: plans.retained + plans.released,
            },
            stores,
        );
        if (!res.ok) return json({ error: res.reason }, 400);

        return json({
            deleted: true,
            plansKept: plans.retained,
            plansDeleted: plans.deleted,
            plansPublished: plans.released,
        });
    }

    async function invite(request, accountId, principal) {
        if (!isOwner(principal, accountId)) return json({ error: "owner_role_required" }, 403);
        const body = await request.json().catch(() => ({}));
        const email = normalizeEmail(body.email);
        const role = String(body.role ?? "member");
        if (!email || !email.includes("@")) return json({ error: "invalid_email" }, 400);
        if (!ROLES.has(role)) return json({ error: "invalid_role" }, 400);
        if (role === "owner" && !isOwner(principal, accountId)) return json({ error: "owner_role_required" }, 403);

        const account = await getAccount(accountId, stores);
        if (!account) return json({ error: "no_such_account" }, 404);

        // Expired invitations hold an address with nothing left to justify
        // keeping it. Swept here rather than on a schedule: a sweep that runs
        // whenever invitations are used cannot silently stop running.
        await sweepExpired(inviteStore(), { now, index: inviteExpiryStore() });

        // The invitation is addressed to the *email*, because inviting someone
        // with no account is the normal case (DESIGN-015 §6.4). The Member
        // binds when they sign in with a verified identity for that address.
        const token = newId("inv", 24);
        const expiresAt = now() + INVITE_TTL_DAYS * 24 * 60 * 60 * 1000;
        await inviteStore().set(token, JSON.stringify({
            token, accountId, email, role, invitedBy: principal.userId,
            invitedAt: new Date(now()).toISOString(), expiresAt,
        }));
        // Index second: an invitation the sweep cannot see is caught by the
        // next sweep's catch-up pass, where an index entry for an invitation
        // that was never written would delete a key belonging to nobody.
        await inviteExpiryStore().set(expiryIndexKey(expiresAt, token), JSON.stringify({ indexed: true }));
        // A pending row keyed by address, so the members list can show it
        // before there is a userId to key on.
        await stores.members().set(`${accountId}/pending:${email}`, JSON.stringify({
            accountId, userId: null, email, role, invitedAt: new Date(now()).toISOString(), acceptedAt: null,
        }));

        const inviter = await getUser(principal.userId, stores);
        // DESIGN-015 §3.6: an invitation uses the *inviting* user's locale —
        // the only signal available for somebody with no account yet.
        const locale = body.locale === "nb" ? "nb" : "en";
        const url = `${env.PUBLIC_APP_ORIGIN || "https://ringdrill.app"}/invite/${encodeURIComponent(token)}`;
        const send = mailer ?? createMailer({ env });
        await sendTemplate(send, {
            to: email, template: "invitation", locale, idempotencyKey: token,
            params: {
                inviterName: inviter?.displayName ?? "A RingDrill user",
                organisation: account.displayName, role, url, days: INVITE_TTL_DAYS,
            },
        });

        return json({ invited: { email, role, expiresAt } }, 201);
    }

    async function changeRole(request, accountId, memberUserId, principal) {
        if (!isOwner(principal, accountId)) return json({ error: "owner_role_required" }, 403);
        const body = await request.json().catch(() => ({}));
        const role = String(body.role ?? "");
        if (!ROLES.has(role)) return json({ error: "invalid_role" }, 400);

        const members = await membersOf(accountId, stores);
        const target = members.find((m) => m.userId === memberUserId);
        if (!target) return json({ error: "no_such_member" }, 404);

        // The last accepted owner cannot be demoted. Offering the option and
        // then failing would be worse than not offering it — DESIGN-015 §6.3
        // has the picker lock "Owner" with a reason for exactly this.
        const owners = acceptedOwners(members);
        if (target.role === "owner" && role !== "owner" && owners.length === 1 && owners[0].userId === memberUserId) {
            return json({ error: "last_owner" }, 409);
        }

        await putMember(accountId, memberUserId, role, {
            invitedAt: target.invitedAt ?? null, acceptedAt: target.acceptedAt ?? null,
        }, stores);
        return json({ userId: memberUserId, role });
    }

    async function remove(accountId, memberUserId, principal) {
        const leaving = memberUserId === principal.userId;
        // A member may always remove themselves; removing anyone else is
        // administration.
        if (!leaving && !isOwner(principal, accountId)) return json({ error: "owner_role_required" }, 403);

        // Withdrawing an invitation that has not been answered. A pending row
        // is keyed by address and has no userId, so the lookup below could
        // never find it — leaving the owner with a roster entry they could see
        // and not remove, and the invitee with a link that still works.
        // "Withdrawn" is one of the states the invite page renders
        // (DESIGN-015 §6.4), which requires this to be possible.
        if (memberUserId.startsWith("pending:")) {
            if (!isOwner(principal, accountId)) return json({ error: "owner_role_required" }, 403);
            const key = `${accountId}/${memberUserId}`;
            if (!(await stores.members().get(key, { type: "json" }))) return json({ error: "no_such_member" }, 404);
            await stores.members().delete(key);
            return new Response(null, { status: 204 });
        }

        const members = await membersOf(accountId, stores);
        const target = members.find((m) => m.userId === memberUserId);
        if (!target) return json({ error: "no_such_member" }, 404);

        const owners = acceptedOwners(members);
        if (target.role === "owner" && owners.length === 1 && owners[0].userId === memberUserId) {
            // Covers both "remove the last owner" and "leave as the last
            // owner" — the second is the one that would strand an
            // organisation nobody can administer (DESIGN-015 §4.4).
            return json({ error: "last_owner" }, 409);
        }

        await removeMember(accountId, memberUserId, stores);
        return new Response(null, { status: 204 });
    }
}

/** A malformed escape (`%ZZ`) is a bad URL, not a server fault. */
function safeDecode(s) {
    try { return decodeURIComponent(s); } catch { return null; }
}

function clampInt(v, min, max, dflt) {
    const n = Number.parseInt(v ?? "", 10);
    if (Number.isNaN(n)) return dflt;
    return Math.min(max, Math.max(min, n));
}

export default createHandler();
