import { getStore } from "@netlify/blobs";
import { corsPreflight, withCors } from "./lib/shared.js";
import { authenticate } from "./lib/auth/index.js";
import {
    defaultStores, getAccount, getUser, getUserIdByEmail, normalizeEmail, putMember,
} from "./lib/identity.js";

/**
 * Answering an invitation (DESIGN-015 §6.4).
 *
 * Its own function rather than a route on `accounts.js`, for one reason:
 * `accounts.js` refuses anonymous callers outright, and **the describe step
 * here must work signed out.** The landing page has to be able to say "sign in
 * as ola@example.com to accept" before anyone has signed in — which it cannot
 * do if reading the invitation requires already being the right person.
 *
 * The two properties that matter:
 *
 * * **The link is not a credential.** It identifies *which* invitation is being
 *   answered and grants nothing on its own; accepting still requires signing
 *   in. That is what reconciles an emailed link with §2.1's rejection of
 *   unauthenticated bearer URLs for sharing plans: a forwarded plan link hands
 *   over content, a forwarded invite link gets the holder a sign-in prompt they
 *   cannot satisfy.
 * * **The invited address is the one that binds.** Acceptance requires the
 *   signed-in user to hold a *verified* identity for the address the invitation
 *   was sent to. Binding to whoever opens the link would turn a forwarded email
 *   into account access.
 */

const strong = { consistency: "strong" };

const json = (body, status = 200) =>
    new Response(JSON.stringify(body), {
        status,
        headers: {
            "content-type": "application/json",
            // An invitation's state changes underneath the page — accepted,
            // withdrawn, expired. A cached "pending" would be a lie the user
            // acts on.
            "cache-control": "no-store",
        },
    });

export function createHandler({
    env = process.env,
    now = Date.now,
    stores = defaultStores,
    inviteStore = () => getStore("invitations", strong),
} = {}) {
    return async function (request) {
        const preflight = corsPreflight(request);
        if (preflight) return preflight;

        try {
            const { pathname } = new URL(request.url);
            const tail = pathname.replace(/^.*\/(?:\.netlify\/functions\/invitations|api\/invitations)\/?/, "");
            const parts = tail.split("/").filter(Boolean).map(safeDecode);
            const [token, action] = parts;

            if (!token) return withCors(request, json({ error: "not_found" }, 404));

            if (!action && request.method === "GET") {
                return withCors(request, await describe(token));
            }
            if (action === "accept" && request.method === "POST") {
                return withCors(request, await accept(request, token));
            }
            return withCors(request, json({ error: "not_found" }, 404));
        } catch (err) {
            console.error("[invitations]", err);
            return withCors(request, json({ error: "internal" }, 500));
        }
    };

    /**
     * Resolve the invitation to one of the states the landing page renders.
     *
     * DESIGN-015 §6.4 lists them, and none of them is the happy path: already
     * accepted, withdrawn by the owner, expired, the organisation was deleted,
     * signed in as the wrong person. Each is named here so the page can say
     * what happened and what to do, rather than failing generically.
     */
    async function load(token) {
        const inv = await inviteStore().get(token, { type: "json" });
        if (!inv) return { state: "not_found" };

        if (inv.acceptedAt) return { state: "accepted", inv };
        if (typeof inv.expiresAt === "number" && now() > inv.expiresAt) return { state: "expired", inv };

        const account = await getAccount(inv.accountId, stores);
        if (!account) return { state: "organisation_deleted", inv };

        // The owner withdrawing an invitation deletes the pending row; the
        // token blob outlives it. Its absence is therefore the withdrawal,
        // and reporting it as "expired" would tell the invitee to ask for a
        // fresh link that is never coming.
        const pending = await stores.members().get(`${inv.accountId}/pending:${inv.email}`, { type: "json" });
        if (!pending) return { state: "withdrawn", inv, account };

        return { state: "pending", inv, account };
    }

    async function describe(token) {
        const { state, inv, account } = await load(token);
        if (state === "not_found") return json({ error: "not_found" }, 404);

        const inviter = inv.invitedBy ? await getUser(inv.invitedBy, stores) : null;
        return json({
            state,
            // The address is returned to whoever holds the token, deliberately:
            // it is the address the token was emailed to, and "sign in with
            // ola@example.com" is one of the two remedies §6.4 requires. Masking
            // it would leave a wrong-person invitee with no way to act.
            email: inv.email,
            role: inv.role,
            organisation: account?.displayName ?? null,
            inviterName: inviter?.displayName ?? null,
            expiresAt: inv.expiresAt ?? null,
        });
    }

    async function accept(request, token) {
        const principal = await authenticate(request, { env, now });
        if (!principal.ok) return json({ error: principal.reason }, principal.status);
        // Following the link identifies the invitation; answering it is a
        // separate act that needs an identity.
        if (principal.anonymous) return json({ error: "authentication_required" }, 401);

        const { state, inv, account } = await load(token);
        if (state === "not_found") return json({ error: "not_found" }, 404);
        // Every non-pending state is reported by name rather than as a generic
        // 400, because the page renders a different message for each.
        if (state !== "pending") return json({ error: state, state }, state === "accepted" ? 409 : 410);

        if (!(await holdsVerifiedAddress(principal.userId, inv.email))) {
            // Both remedies, because the invitee can act on either and neither
            // is obvious: sign in with the invited address, or ask the owner to
            // re-invite the address they actually use.
            return json({
                error: "wrong_identity",
                state: "wrong_identity",
                invitedEmail: inv.email,
                organisation: account?.displayName ?? null,
            }, 403);
        }

        const ts = new Date(now()).toISOString();
        await putMember(inv.accountId, principal.userId, inv.role, { invitedAt: inv.invitedAt ?? null, acceptedAt: ts }, stores);
        // The pending row is keyed by address and the real one by userId, so
        // leaving it would show the person twice in the roster.
        await stores.members().delete(`${inv.accountId}/pending:${inv.email}`);
        // Single-use. Marking the token rather than deleting it is what lets a
        // second visit say "already accepted" instead of "no such invitation" —
        // the same link is often opened twice on two devices.
        await inviteStore().set(token, JSON.stringify({ ...inv, acceptedAt: ts, acceptedBy: principal.userId }));

        return json({
            accepted: true,
            accountId: inv.accountId,
            organisation: account?.displayName ?? null,
            role: inv.role,
        });
    }

    /**
     * Does this user hold a *verified* identity for the invited address?
     *
     * The email index is the authority: `resolveIdentity` only writes to it
     * when the provider asserted the address is verified, so an entry there
     * means somebody proved ownership. The user record is checked as well
     * because the index is populated at sign-up, and a user whose primary
     * address was verified through a later link would otherwise be turned away
     * from their own invitation.
     */
    async function holdsVerifiedAddress(userId, email) {
        const addr = normalizeEmail(email);
        if (!userId || !addr) return false;

        if ((await getUserIdByEmail(addr, stores)) === userId) return true;

        const user = await getUser(userId, stores);
        return !!user && user.primaryEmailVerified === true && normalizeEmail(user.primaryEmail) === addr;
    }
}

/** A malformed escape (`%ZZ`) is a bad URL, not a server fault. */
function safeDecode(s) {
    try { return decodeURIComponent(s); } catch { return null; }
}

export default createHandler();
