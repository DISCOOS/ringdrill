import { defaultStores, memberIndexKey, sessionIndexKey } from "./identity.js";

/**
 * One-off construction of the two reverse indexes, `member-index` and
 * `session-index`.
 *
 * Both are derived data: every entry here can be recomputed from the canonical
 * store, which is what makes this safe to re-run and safe to run while the site
 * is live. Nothing is deleted and no canonical record is touched — the worst a
 * bad run can do is write an index entry that a later read discards.
 *
 * **This is an optimisation, not a migration.** `membershipsOf` and
 * `sessionsOf` both fall back to the scan they replaced when a user has no
 * index entries, and index what they find on the way out, so the system is
 * correct before this runs, during it, and if it is never run at all. What it
 * buys is not correctness but the moment the cost drops: without it, a user
 * pays one full scan on their next token mint, and a user who never signs in
 * again leaves an entry nobody needs. With it, the scans stop at a time we
 * choose rather than spread across whatever traffic arrives first.
 *
 * Deliberately *not* resumable via cursor state. A re-run rewrites the same
 * keys with the same bytes, so restarting from the beginning costs a duplicate
 * pass and nothing else — cheaper to reason about than a checkpoint that can
 * itself go stale.
 */

/**
 * Members are keyed `<accountId>/<userId>`, and a pending invitation is keyed
 * `<accountId>/pending:<email>` — that second shape has no user to index, and
 * gets counted as skipped rather than silently ignored so a report that shows
 * nothing migrated can be told apart from one that had nothing to migrate.
 */
export async function backfillMemberIndex({ dryRun = true, stores = defaultStores } = {}) {
    const members = stores.members();
    const index = stores.memberIndex();
    const report = { store: "member-index", dryRun, scanned: 0, indexed: 0, skipped: 0, errors: [] };

    let cursor;
    do {
        const page = await members.list({ cursor });
        cursor = page?.cursor;
        for (const blob of page?.blobs ?? []) {
            report.scanned++;
            const key = String(blob.key);
            const [accountId, userId] = key.split("/");
            if (!accountId || !userId || userId.startsWith("pending:")) {
                report.skipped++;
                continue;
            }
            try {
                if (!dryRun) await index.set(memberIndexKey(userId, accountId), JSON.stringify({ indexed: true }));
                report.indexed++;
            } catch (err) {
                report.errors.push({ key, error: String(err?.message ?? err) });
            }
        }
    } while (cursor);
    return report;
}

/**
 * Sessions are keyed by session id alone, so the owning user comes from the
 * record body. A record without one cannot be indexed and cannot be listed by
 * user either — it is unreachable rather than merely unindexed, so it is
 * reported as an error, not a skip.
 *
 * Expired sessions are indexed too. `sessionsOf` filters them on read and this
 * is not the place to decide what to delete: a backfill that also collected
 * garbage would be two operations wearing one name, and the destructive half
 * would run under a flag named `dryRun: false` that the operator read as
 * meaning "write the index".
 */
export async function backfillSessionIndex({ dryRun = true, stores = defaultStores } = {}) {
    const sessions = stores.sessions();
    const index = stores.sessionIndex();
    const report = { store: "session-index", dryRun, scanned: 0, indexed: 0, skipped: 0, errors: [] };

    let cursor;
    do {
        const page = await sessions.list({ cursor });
        cursor = page?.cursor;
        for (const blob of page?.blobs ?? []) {
            report.scanned++;
            const key = String(blob.key);
            try {
                const rec = await sessions.get(key, { type: "json" });
                if (!rec?.userId) {
                    report.errors.push({ key, error: "session_without_user" });
                    continue;
                }
                if (!dryRun) await index.set(sessionIndexKey(rec.userId, key), JSON.stringify({ indexed: true }));
                report.indexed++;
            } catch (err) {
                report.errors.push({ key, error: String(err?.message ?? err) });
            }
        }
    } while (cursor);
    return report;
}

export async function backfillIndexes({ dryRun = true, stores = defaultStores } = {}) {
    return {
        dryRun,
        members: await backfillMemberIndex({ dryRun, stores }),
        sessions: await backfillSessionIndex({ dryRun, stores }),
    };
}
