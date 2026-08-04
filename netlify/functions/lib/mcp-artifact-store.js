// Where a built archive is held between `build_plan` and its download (ADR-0070).
//
// Two functions share this and nothing else: `lib/mcp-backend.js` writes an entry when
// it compiles a plan, and `mcp-artifact.js` reads one when the author follows the link.
// Its own module because that is the whole shared surface — a namespace, a key shape, a
// TTL and a filename — and because the alternative was the download route importing the
// compiler backend to get three constants, which drags `lib/mcp-compiler.js` and its
// 737 KB bundle dependency into a function that only moves bytes. That import is lazy
// today; a seam is cheaper than depending on it staying lazy.
import { sanitizeSlug } from "./shared.js";

/// How long a built archive is held so its download URL works.
///
/// Its own constant rather than a reuse of the document cache's TTL, because the two
/// are measured against different things: a document's window is an iteration loop, an
/// archive's is however long it takes the author to click the link. They agree today.
export const ARTIFACT_TTL_MS = 30 * 60 * 1000;

/// Namespace for built archives, separate from the document cache so the two retention
/// windows can diverge and neither can serve the other's keys.
export const ARTIFACT_CACHE_NS = "mcp-artifact-cache";

/// The key an archive is held under. Content-addressed on the compiler's own
/// `contentHash`, so the URL is unguessable and a read cannot return anything other
/// than what was built from that content.
export function artifactKey(contentHash) {
    return `artifact/${contentHash}`;
}

/// What the download saves as. Stored with the archive rather than derived at read
/// time, because the download route holds bytes and a hash and has no plan to ask.
///
/// The plan's own name, slugged the way the catalog slugs one — lossy for non-ASCII,
/// hence a fallback rather than a guarantee.
export function archiveFileName(planName) {
    return `${sanitizeSlug(planName) || "plan"}.drill`;
}

/// True when an entry is still inside its window. `storedAt` missing is treated as
/// infinitely old, so a malformed entry expires rather than living forever.
export function isFresh(entry, now = Date.now()) {
    if (!entry) return false;
    return now - (entry.storedAt ?? 0) <= ARTIFACT_TTL_MS;
}
