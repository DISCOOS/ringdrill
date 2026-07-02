import { afterEach, describe, expect, it, vi } from 'vitest';
import { fetchCatalog, type CatalogItem } from './catalog';

function item(overrides: Partial<CatalogItem> & { slug: string; updatedAt: string }): CatalogItem {
  return {
    programId: `prog-${overrides.slug}`,
    name: overrides.slug,
    description: '',
    exerciseCount: null,
    author: null,
    accessPolicy: null,
    mapCenter: null,
    mapBounds: null,
    place: null,
    languageCode: null,
    tags: [],
    latestUrl: `https://api.ringdrill.app/d/${overrides.slug}`,
    ...overrides,
  };
}

function jsonResponse(body: unknown, ok = true): Response {
  return {
    ok,
    json: async () => body,
  } as Response;
}

afterEach(() => {
  vi.restoreAllMocks();
});

describe('fetchCatalog', () => {
  it('returns items from a single page', async () => {
    const items = [item({ slug: 'a', updatedAt: '2026-01-01T00:00:00.000Z' })];
    const fetchImpl = vi.fn().mockResolvedValue(jsonResponse({ items }));

    const result = await fetchCatalog({ apiBase: 'https://api.ringdrill.app', fetchImpl });

    expect(result.failed).toBe(false);
    expect(result.truncated).toBe(false);
    expect(result.items.map((i) => i.slug)).toEqual(['a']);
    expect(fetchImpl).toHaveBeenCalledTimes(1);
  });

  it('pages through nextCursor and re-sorts the concatenated list by updatedAt descending', async () => {
    const fetchImpl = vi
      .fn()
      .mockResolvedValueOnce(
        jsonResponse({
          items: [item({ slug: 'older', updatedAt: '2026-01-01T00:00:00.000Z' })],
          nextCursor: 'page2',
        }),
      )
      .mockResolvedValueOnce(
        jsonResponse({
          items: [item({ slug: 'newer', updatedAt: '2026-03-01T00:00:00.000Z' })],
        }),
      );

    const result = await fetchCatalog({ apiBase: 'https://api.ringdrill.app', fetchImpl });

    expect(fetchImpl).toHaveBeenCalledTimes(2);
    // Each page is individually "sorted" (one item each) — the meaningful
    // assertion is the cross-page sort: newer (page 2) must sort before
    // older (page 1), which only happens if fetchCatalog re-sorts itself
    // rather than trusting page order.
    expect(result.items.map((i) => i.slug)).toEqual(['newer', 'older']);
    expect(result.truncated).toBe(false);
  });

  it('stops and logs a warning when maxItems is hit with more pages available', async () => {
    const warnSpy = vi.spyOn(console, 'warn').mockImplementation(() => {});
    const fetchImpl = vi
      .fn()
      .mockResolvedValueOnce(
        jsonResponse({
          items: [item({ slug: 'a', updatedAt: '2026-01-01T00:00:00.000Z' })],
          nextCursor: 'page2',
        }),
      );

    const result = await fetchCatalog({
      apiBase: 'https://api.ringdrill.app',
      fetchImpl,
      maxItems: 1,
    });

    expect(result.truncated).toBe(true);
    expect(result.items).toHaveLength(1);
    expect(warnSpy).toHaveBeenCalledTimes(1);
    // A cap must never silently drop data — the caller can see it happened.
    expect(warnSpy.mock.calls[0][0]).toMatch(/stopped early/);
  });

  it('stops and logs a warning when maxPages is hit with more pages available', async () => {
    const warnSpy = vi.spyOn(console, 'warn').mockImplementation(() => {});
    const fetchImpl = vi.fn().mockImplementation((url: string) => {
      const cursor = new URL(url).searchParams.get('cursor') ?? 'start';
      return Promise.resolve(
        jsonResponse({
          items: [item({ slug: cursor, updatedAt: '2026-01-01T00:00:00.000Z' })],
          nextCursor: `${cursor}-next`,
        }),
      );
    });

    const result = await fetchCatalog({
      apiBase: 'https://api.ringdrill.app',
      fetchImpl,
      maxPages: 2,
      maxItems: 1000,
    });

    expect(fetchImpl).toHaveBeenCalledTimes(2);
    expect(result.truncated).toBe(true);
    expect(warnSpy).toHaveBeenCalledTimes(1);
  });

  it('does not report truncated when pagination ends naturally (no nextCursor)', async () => {
    const warnSpy = vi.spyOn(console, 'warn').mockImplementation(() => {});
    const fetchImpl = vi.fn().mockResolvedValue(
      jsonResponse({ items: [item({ slug: 'only', updatedAt: '2026-01-01T00:00:00.000Z' })] }),
    );

    const result = await fetchCatalog({ apiBase: 'https://api.ringdrill.app', fetchImpl });

    expect(result.truncated).toBe(false);
    expect(warnSpy).not.toHaveBeenCalled();
  });

  it('degrades to an empty, failed result on a non-2xx response', async () => {
    const fetchImpl = vi.fn().mockResolvedValue(jsonResponse({}, false));

    const result = await fetchCatalog({ apiBase: 'https://api.ringdrill.app', fetchImpl });

    expect(result).toEqual({ items: [], truncated: false, failed: true });
  });

  it('degrades to an empty, failed result when fetch throws', async () => {
    const fetchImpl = vi.fn().mockRejectedValue(new Error('network down'));

    const result = await fetchCatalog({ apiBase: 'https://api.ringdrill.app', fetchImpl });

    expect(result).toEqual({ items: [], truncated: false, failed: true });
  });
});
