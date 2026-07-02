// Catalog data fetch for the /catalog site route (ADR-0039), reading the
// widened feed item shape from ADR-0040 (+ its map-center addendum). Pure
// and independent of Astro rendering so it's unit-testable without a real
// network call or a rendered page — see catalog.test.ts.

export interface CatalogItem {
  programId: string;
  slug: string;
  name: string;
  description: string;
  exerciseCount: number | null;
  author: string | null;
  accessPolicy: string | null;
  mapCenter: { lat: number; lng: number } | null;
  tags: string[];
  latestUrl: string;
  updatedAt: string | null;
}

interface FeedPage {
  items: CatalogItem[];
  nextCursor?: string;
}

export interface FetchCatalogOptions {
  apiBase: string;
  fetchImpl?: typeof fetch;
  maxPages?: number;
  maxItems?: number;
}

export interface FetchCatalogResult {
  items: CatalogItem[];
  /** True when a page/item cap stopped an otherwise-nonempty pagination. */
  truncated: boolean;
  /** True when the fetch itself failed (network error or non-2xx). */
  failed: boolean;
}

/**
 * Fetch every published catalog item from `GET /api/market-feed`, paging
 * through `nextCursor`, then re-sort the concatenated list by `updatedAt`
 * descending using the same comparator `market-feed.js` uses.
 *
 * The feed only guarantees sort order *within* one call — concatenating
 * multiple pages loses the global order without this final sort.
 *
 * Runs once per HTTP request (this route is on-demand, not build-time), so
 * the page/item caps are intentionally tight: an unbounded pagination loop
 * here is a per-visitor latency and upstream-load problem, not just a
 * one-off build-time cost. A cap that stops an otherwise-nonempty
 * pagination is logged, never truncated silently.
 *
 * Fetch failures (network error, non-2xx) degrade to an empty result with
 * `failed: true` rather than throwing — an API blip must render a
 * "temporarily unavailable" empty state, not a 500 for the whole page.
 */
export async function fetchCatalog({
  apiBase,
  fetchImpl = fetch,
  maxPages = 3,
  maxItems = 300,
}: FetchCatalogOptions): Promise<FetchCatalogResult> {
  const items: CatalogItem[] = [];
  let cursor: string | undefined;
  let truncated = false;

  try {
    for (let page = 0; page < maxPages; page++) {
      // The native /.netlify/functions/<name> path always resolves, in both
      // production (api.ringdrill.app) and local dev (`netlify
      // functions:serve`, which does NOT apply netlify.toml's /api/* alias
      // redirects — see the redirect comment in netlify.toml and ADR-0013).
      // Using it here means `make site-dev` + `make netlify-dev` +
      // `make catalog-seed` works with no extra local-only routing.
      const url = new URL('/.netlify/functions/market-feed', apiBase);
      url.searchParams.set('limit', '100');
      if (cursor) url.searchParams.set('cursor', cursor);

      const res = await fetchImpl(url.toString());
      if (!res.ok) return { items: [], truncated: false, failed: true };

      const body = (await res.json()) as FeedPage;
      items.push(...body.items);
      cursor = body.nextCursor;

      if (items.length >= maxItems) {
        truncated = Boolean(cursor);
        break;
      }
      if (!cursor) break;
      if (page === maxPages - 1 && cursor) truncated = true;
    }
  } catch {
    return { items: [], truncated: false, failed: true };
  }

  if (truncated) {
    console.warn(
      `fetchCatalog: stopped early (maxPages=${maxPages}, maxItems=${maxItems}) with more items available`,
    );
  }

  items.sort((a, b) => String(b.updatedAt).localeCompare(String(a.updatedAt)));

  return { items, truncated, failed: false };
}
