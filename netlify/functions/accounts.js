import { getStore } from "@netlify/blobs";
import {
    corsPreflight, withCors, metaToFeedItem,
    getDrillsStore as _getDrillsStore, getSlugIndexStore as _getSlugIndexStore,
} from "./lib/shared.js";
import { authenticate } from "./lib/auth/index.js";
import {
    acceptedOwners, claimHandle, defaultStores, getAccount, getUser, membersOf, membershipsOf,
    newId, normalizeEmail, putMember, removeMember, upgradeToOrganisation, validateHandle,
} from "./lib/identity.js";
import { keysForEntry } from "./lib/catalog.js";
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
    getDrillsStore = _getDrillsStore,
    getSlugIndexStore = _getSlugIndexStore,
    mailer = null,
} = {}) {
    return async function (request) {
        const preflight = corsPreflight(request);
        if (preflight) return preflight;

        try {
            const { pathname } = new URL(request.url);
            const tail = pathname.replace(/^.*\/(?:\.netlify\/functions\/accounts|api\/accounts)\/?/, "");
            const parts = tail.split("/").filter(Boolean);

            const principal = await authenticate(request, { env, now });
            if (!principal.ok) return withCors(request, json({ error: principal.reason }, principal.status));
            if (principal.anonymous) return withCors(request, json({ error: "authentication_required" }, 401));

            // POST /api/accounts
            if (parts.length === 0 && request.method === "POST") {
                return withCors(request, await createOrganisation(request, principal));
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

        // The invitation is addressed to the *email*, because inviting someone
        // with no account is the normal case (DESIGN-015 §6.4). The Member
        // binds when they sign in with a verified identity for that address.
        const token = newId("inv", 24);
        const expiresAt = now() + INVITE_TTL_DAYS * 24 * 60 * 60 * 1000;
        await inviteStore().set(token, JSON.stringify({
            token, accountId, email, role, invitedBy: principal.userId,
            invitedAt: new Date(now()).toISOString(), expiresAt,
        }));
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

function clampInt(v, min, max, dflt) {
    const n = Number.parseInt(v ?? "", 10);
    if (Number.isNaN(n)) return dflt;
    return Math.min(max, Math.max(min, n));
}

export default createHandler();
