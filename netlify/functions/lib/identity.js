import crypto from "node:crypto";
import { getStore } from "@netlify/blobs";

/**
 * The Account / User / Identity / Member stores and the operations over them
 * (ADR-0024), plus account handles (ADR-0074).
 *
 * **Every read here decides a write.** Netlify Blobs reads are eventually
 * consistent by default, and a stale read in this module does not merely serve
 * old data — it creates a duplicate User, or hands an account handle to two
 * people. So every accessor asks for strong consistency, and every creation
 * that must be unique goes through a conditional `onlyIfNew` write rather than
 * a read-then-write. See the long warning in lib/shared.js for what the default
 * cost this project once.
 *
 * Store getters are never memoized, for the token-expiry reason recorded there.
 */

const STRONG = { consistency: "strong" };

export const NS = Object.freeze({
    ACCOUNTS: "accounts",
    USERS: "users",
    IDENTITIES: "identities",
    MEMBERS: "members",
    EMAIL_INDEX: "email-index",
    HANDLES: "handles",
    SESSIONS: "sessions",
});

export const defaultStores = Object.freeze({
    accounts: () => getStore(NS.ACCOUNTS, STRONG),
    users: () => getStore(NS.USERS, STRONG),
    identities: () => getStore(NS.IDENTITIES, STRONG),
    members: () => getStore(NS.MEMBERS, STRONG),
    emailIndex: () => getStore(NS.EMAIL_INDEX, STRONG),
    handles: () => getStore(NS.HANDLES, STRONG),
    sessions: () => getStore(NS.SESSIONS, STRONG),
});

/* ---------- ids, handles, emails ---------- */

const ID_ALPHABET = "0123456789abcdefghijklmnopqrstuvwxyz";

/** `u_`/`a_` + 12 chars, per ADR-0024. */
export function newId(prefix, size = 12) {
    const bytes = crypto.randomBytes(size);
    let out = "";
    for (let i = 0; i < size; i++) out += ID_ALPHABET[bytes[i] % ID_ALPHABET.length];
    return `${prefix}_${out}`;
}

export const RESERVED_HANDLES = Object.freeze(new Set([
    // `anon` is the namespace every unauthenticated publish lands in
    // (ADR-0074), so an account holding it could impersonate the wiki corpus.
    "anon",
    // Not route collisions — a handle only ever appears after /d/ or /i/, so it
    // cannot shadow these. They are reserved because a *link* reading
    // "/d/admin/…" or "/d/support/…" implies an authority the account may not
    // have, which is a phishing surface rather than a routing one.
    "admin", "support", "help", "official", "ringdrill", "security", "abuse", "staff",
]));

export const HANDLE_RE = /^[a-z0-9][a-z0-9-]{1,38}$/;

export function normalizeHandle(raw) {
    return String(raw ?? "").trim().toLowerCase();
}

export function validateHandle(raw) {
    const handle = normalizeHandle(raw);
    if (!HANDLE_RE.test(handle)) return { ok: false, reason: "invalid_format" };
    if (RESERVED_HANDLES.has(handle)) return { ok: false, reason: "reserved" };
    if (handle.endsWith("-")) return { ok: false, reason: "invalid_format" };
    return { ok: true, handle };
}

export function normalizeEmail(raw) {
    return String(raw ?? "").trim().toLowerCase();
}

/* ---------- reads ---------- */

export async function getUser(userId, stores = defaultStores) {
    if (!userId) return null;
    return (await stores.users().get(userId, { type: "json" })) ?? null;
}

export async function getAccount(accountId, stores = defaultStores) {
    if (!accountId) return null;
    return (await stores.accounts().get(accountId, { type: "json" })) ?? null;
}

export async function getIdentity(provider, subject, stores = defaultStores) {
    if (!provider || !subject) return null;
    return (await stores.identities().get(`${provider}/${subject}`, { type: "json" })) ?? null;
}

export async function getUserIdByEmail(email, stores = defaultStores) {
    const key = normalizeEmail(email);
    if (!key) return null;
    const rec = await stores.emailIndex().get(key, { type: "json" });
    return rec?.userId ?? null;
}

export async function getMember(accountId, userId, stores = defaultStores) {
    if (!accountId || !userId) return null;
    return (await stores.members().get(`${accountId}/${userId}`, { type: "json" })) ?? null;
}

/**
 * Every account this user belongs to, as the `acts` / `roles` claims want them.
 *
 * Membership is stored under `<accountId>/<userId>`, which answers "who is in
 * this account" cheaply and "which accounts is this user in" only by scanning.
 * A per-user index would invert that, and is worth adding when the scan starts
 * to hurt — at the volumes ADR-0024 sizes for, it does not.
 *
 * **Invited-but-not-accepted members are excluded.** `acceptedAt == null` is a
 * state, not a role (DESIGN-015 §6.2): the role was chosen at invite time, but
 * it does not grant anything until the person accepts.
 */
export async function membershipsOf(userId, stores = defaultStores) {
    if (!userId) return { accounts: [], roles: {} };
    const store = stores.members();
    const accounts = [];
    const roles = {};
    let cursor;
    do {
        const page = await store.list({ cursor });
        cursor = page?.cursor;
        for (const blob of page?.blobs ?? []) {
            const [accountId, memberUserId] = String(blob.key).split("/");
            if (memberUserId !== userId) continue;
            const member = await store.get(blob.key, { type: "json" });
            if (!member || !member.acceptedAt) continue;
            accounts.push(accountId);
            roles[accountId] = member.role;
        }
    } while (cursor);
    return { accounts, roles };
}

/* ---------- writes ---------- */

async function putJson(store, key, value, opts = {}) {
    return store.set(key, JSON.stringify(value), opts);
}

/**
 * Claim a handle for an account, atomically.
 *
 * `onlyIfNew` rather than read-then-write: two people creating an organisation
 * with the same name in the same second must not both succeed, and a strong
 * read followed by a write still leaves the window open.
 */
export async function claimHandle(rawHandle, accountId, stores = defaultStores) {
    const v = validateHandle(rawHandle);
    if (!v.ok) return v;
    const { modified } = await stores.handles().set(
        v.handle, JSON.stringify({ accountId, claimedAt: new Date().toISOString() }), { onlyIfNew: true },
    );
    if (!modified) {
        const existing = await stores.handles().get(v.handle, { type: "json" });
        // Re-claiming your own handle is a no-op rather than an error, so a
        // retried request does not fail the second time.
        if (existing?.accountId === accountId) return { ok: true, handle: v.handle };
        return { ok: false, reason: "taken" };
    }
    return { ok: true, handle: v.handle };
}

/**
 * Rename a handle, leaving the old one as a permanent tombstone (ADR-0074).
 *
 * The tombstone redirects and can never be re-registered. Releasing a handle
 * for reuse would silently point somebody's already-shared link at a stranger's
 * plan, which is worse than the inconvenience of retiring a name.
 */
export async function renameHandle(oldHandle, newHandle, accountId, stores = defaultStores) {
    const claimed = await claimHandle(newHandle, accountId, stores);
    if (!claimed.ok) return claimed;
    const from = normalizeHandle(oldHandle);
    if (from && from !== claimed.handle) {
        await putJson(stores.handles(), from, {
            accountId, tombstone: true, redirectsTo: claimed.handle, retiredAt: new Date().toISOString(),
        });
    }
    return claimed;
}

export async function resolveHandle(rawHandle, stores = defaultStores) {
    const handle = normalizeHandle(rawHandle);
    if (!handle) return null;
    const rec = await stores.handles().get(handle, { type: "json" });
    if (!rec) return null;
    return { accountId: rec.accountId, tombstone: !!rec.tombstone, redirectsTo: rec.redirectsTo ?? null };
}

/**
 * Resolve a provider sign-in to a User, creating or linking as ADR-0024 says:
 *
 *   1. Identity known by (provider, subject) → that User.
 *   2. Otherwise a verified email matching an existing User → link, and tell
 *      the caller so it can say so (DESIGN-015 §3.4). Silence here is worse:
 *      a person who signs in with a different button and lands in the same
 *      account should be told why.
 *   3. Otherwise a new User and a new personal Account.
 *
 * **Linking requires the provider to mark the email verified.** An unverified
 * address creates a separate User instead, because auto-linking on an
 * unverified one is the sign-up squatting attack: claim `victim@example.com`
 * with a provider that does not check, and wait for the real owner to arrive.
 *
 * Apple's "Hide my email" relay is verified but *permanently different* from
 * the user's real address, so it takes branch 3 and creates a second account.
 * That is the duplicate DESIGN-015 §3.5 designs around; it cannot be fixed
 * here, because from this function's side it is indistinguishable from a
 * genuinely new person.
 */
export async function resolveIdentity(
    { provider, subject, email, emailVerified = false, displayName },
    stores = defaultStores,
    { now = () => new Date().toISOString(), makeId = newId } = {},
) {
    if (!provider || !subject) return { ok: false, reason: "missing_provider_or_subject" };

    const addr = normalizeEmail(email);
    const existing = await getIdentity(provider, subject, stores);
    if (existing?.userId) {
        const user = await getUser(existing.userId, stores);
        if (user) return { ok: true, user, created: false, linked: false };
        // An identity pointing at a missing user is corruption, not a sign-up.
        // Falling through to "create a new user" would quietly paper over it.
        return { ok: false, reason: "dangling_identity" };
    }

    if (addr && emailVerified) {
        const userId = await getUserIdByEmail(addr, stores);
        if (userId) {
            const user = await getUser(userId, stores);
            if (user) {
                await putJson(stores.identities(), `${provider}/${subject}`, {
                    userId, provider, subject, email: addr, addedAt: now(),
                });
                return { ok: true, user, created: false, linked: true };
            }
        }
    }

    const userId = makeId("u");
    const accountId = makeId("a");
    const ts = now();

    const user = {
        id: userId,
        displayName: displayName || addr || "RingDrill user",
        primaryEmail: addr || null,
        primaryEmailVerified: !!(addr && emailVerified),
        createdAt: ts,
    };
    const account = {
        id: accountId,
        displayName: user.displayName,
        type: "personal",
        handle: null,
        createdAt: ts,
    };

    await putJson(stores.users(), userId, user);
    await putJson(stores.accounts(), accountId, account);
    await putJson(stores.members(), `${accountId}/${userId}`, {
        accountId, userId, role: "owner", invitedAt: null, acceptedAt: ts,
    });
    await putJson(stores.identities(), `${provider}/${subject}`, {
        userId, provider, subject, email: addr, addedAt: ts,
    });
    if (addr && emailVerified) {
        // onlyIfNew: if two sign-ups race on the same address, the loser must
        // not overwrite the winner's index entry and orphan their account.
        await stores.emailIndex().set(addr, JSON.stringify({ userId }), { onlyIfNew: true });
    }

    return { ok: true, user, account, created: true, linked: false };
}

/** Upgrade a personal account to an organisation (DESIGN-015 §5.3). */
export async function upgradeToOrganisation(accountId, { displayName, handle }, stores = defaultStores) {
    const account = await getAccount(accountId, stores);
    if (!account) return { ok: false, reason: "no_such_account" };
    if (account.type === "organization") return { ok: true, account };

    if (handle) {
        const claimed = await claimHandle(handle, accountId, stores);
        if (!claimed.ok) return claimed;
        account.handle = claimed.handle;
    }
    account.type = "organization";
    if (displayName) account.displayName = displayName;
    await putJson(stores.accounts(), accountId, account);
    return { ok: true, account };
}

/** Add or update a membership. `acceptedAt: null` is the invited state. */
export async function putMember(accountId, userId, role, { invitedAt = null, acceptedAt = null } = {}, stores = defaultStores) {
    await putJson(stores.members(), `${accountId}/${userId}`, {
        accountId, userId, role, invitedAt, acceptedAt,
    });
}

export async function removeMember(accountId, userId, stores = defaultStores) {
    await stores.members().delete(`${accountId}/${userId}`);
}

/**
 * Everyone in an account, accepted or invited.
 *
 * Used by the last-owner invariant (DESIGN-015 §6.3): an organisation must
 * always have at least one accepted owner, so demoting or removing the last one
 * is refused rather than offered and then failed.
 */
export async function membersOf(accountId, stores = defaultStores) {
    const store = stores.members();
    const out = [];
    let cursor;
    do {
        const page = await store.list({ prefix: `${accountId}/`, cursor });
        cursor = page?.cursor;
        for (const blob of page?.blobs ?? []) {
            const member = await store.get(blob.key, { type: "json" });
            if (member) out.push(member);
        }
    } while (cursor);
    return out;
}

/**
 * Every accepted membership this user holds, roles included — including the
 * ones where they are the *only* owner.
 *
 * [membershipsOf] answers "what may this token do" and is therefore about the
 * user. This answers "what would break if this user vanished", which is a
 * different question and the one deletion has to ask.
 */
export async function soleOwnerships(userId, stores = defaultStores) {
    const { accounts } = await membershipsOf(userId, stores);
    const stranded = [];
    for (const accountId of accounts) {
        const account = await getAccount(accountId, stores);
        // A personal account has nobody else to strand — deleting it is the
        // point of the operation, not a side effect of it.
        if (!account || account.type !== "organization") continue;
        const owners = acceptedOwners(await membersOf(accountId, stores));
        if (owners.length === 1 && owners[0].userId === userId) {
            stranded.push({ accountId, displayName: account.displayName });
        }
    }
    return stranded;
}

/**
 * Delete an account, and — for a personal one — the user behind it.
 *
 * Three things deliberately survive, and each would be a mistake to remove:
 *
 * * **Published plans.** Other people have installed them. The catalog entry
 *   stays where it is and loses its owner reference (DESIGN-015 §5.1); the
 *   caller does that part, because it is catalog knowledge, not identity's.
 * * **The handle**, as a tombstone. Releasing it for reuse would point
 *   somebody's already-shared `/d/<handle>/<slug>` link at a stranger's plan.
 *   A deleted account's handle is retired for the same reason a renamed one is
 *   (ADR-0074).
 * * **Nothing keyed by account prefix in the blob store**, because there is
 *   none — that is the whole point of ADR-0074 §4, and a deletion that swept
 *   by prefix is exactly the temptation it was designed out of.
 */
export async function deleteAccount(
    accountId,
    { deleteUser = null, inviteStore = null } = {},
    stores = defaultStores,
) {
    const account = await getAccount(accountId, stores);
    if (!account) return { ok: false, reason: "no_such_account" };

    // Member rows first: a half-deleted account with live memberships would
    // still grant access through a token minted before the rest went.
    const members = await membersOf(accountId, stores);
    for (const member of members) {
        await stores.members().delete(`${accountId}/${member.userId ?? `pending:${member.email}`}`);
    }

    if (account.handle) {
        await putJson(stores.handles(), account.handle, {
            accountId, tombstone: true, redirectsTo: null,
            retiredAt: new Date().toISOString(),
        });
    }
    await stores.accounts().delete(accountId);

    if (deleteUser) {
        await deleteUserRecords(deleteUser, { inviteStore }, stores);
    }
    return { ok: true, account };
}

/**
 * The identity half: the user, every provider identity pointing at them, their
 * verified-address index entries, and their sessions.
 *
 * Identities and email-index entries are found by scanning, because both are
 * keyed by what they resolve *from* rather than by the user. At three users
 * that is free; if it ever is not, the answer is a reverse index rather than a
 * cheaper scan.
 */
async function deleteUserRecords(userId, { inviteStore = null } = {}, stores = defaultStores) {
    // Read the address before the user record goes: it is the only link to
    // the records keyed by email rather than by id.
    const user = await getUser(userId, stores);
    const address = normalizeEmail(user?.primaryEmail);

    const sweeps = [
        [stores.identities(), (rec) => rec?.userId === userId],
        [stores.emailIndex(), (rec) => rec?.userId === userId],
        [stores.sessions(), (rec) => rec?.userId === userId],
        // **Invitations, both directions.** One sent *by* this user names them
        // as `invitedBy`; one sent *to* them holds their address. Neither is
        // reachable from the account being deleted, so both outlived it until
        // this swept them.
        ...(inviteStore
            ? [[inviteStore, (rec) => rec?.invitedBy === userId
                || (address && normalizeEmail(rec?.email) === address)]]
            : []),
        // A pending row in somebody *else's* account, for an invitation this
        // user never accepted. Keyed by address, so deleting their account
        // never touched it.
        ...(address
            ? [[stores.members(), (rec) => !rec?.userId && normalizeEmail(rec?.email) === address]]
            : []),
    ];

    for (const [store, matches] of sweeps) {
        let cursor;
        do {
            const page = await store.list({ cursor });
            cursor = page?.cursor;
            for (const blob of page?.blobs ?? []) {
                const rec = await store.get(blob.key, { type: "json" });
                if (matches(rec)) await store.delete(blob.key);
            }
        } while (cursor);
    }
    await stores.users().delete(userId);
}

/**
 * Drop records whose `expiresAt` has passed.
 *
 * Sign-in challenges and invitations both hold an email address and both were
 * only ever removed when somebody *used* them. An address typed by a person
 * who then closed the tab — including one who never had an account at all —
 * stayed indefinitely, with no basis for keeping it once the record expired.
 *
 * Called opportunistically from the write paths rather than from a scheduler:
 * at this scale a scan per sign-in is free, and a sweep that runs whenever the
 * store is used cannot silently stop running the way a cron can.
 */
export async function sweepExpired(store, { now = Date.now, limit = 200 } = {}) {
    if (!store) return 0;
    let cursor;
    let removed = 0;
    do {
        const page = await store.list({ cursor });
        cursor = page?.cursor;
        for (const blob of page?.blobs ?? []) {
            if (removed >= limit) return removed;
            const rec = await store.get(blob.key, { type: "json" });
            if (typeof rec?.expiresAt === "number" && rec.expiresAt <= now()) {
                await store.delete(blob.key);
                removed += 1;
            }
        }
    } while (cursor);
    return removed;
}

export function acceptedOwners(members) {
    return members.filter((m) => m.role === "owner" && m.acceptedAt);
}
