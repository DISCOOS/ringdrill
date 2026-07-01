import { describe, expect, it } from 'vitest';
import { strFromU8, unzipSync } from 'fflate';
import {
  buildExport,
  countPrograms,
  exportFileName,
  hasFlutterData,
  sanitizeSlug,
} from './migrate';

/**
 * Build a fake localStorage snapshot with `count` programs, each holding a
 * single exercise, mirroring how `ProgramRepository` lays keys out.
 */
function fakeStore(
  programs: { uuid: string; name: string; exerciseUuid: string }[],
  { prefix = '' }: { prefix?: string } = {},
): Record<string, string> {
  const store: Record<string, string> = {};
  const now = '2026-06-29T10:00:00.000Z';
  for (const p of programs) {
    store[`${prefix}p:${p.uuid}`] = JSON.stringify({
      uuid: p.uuid,
      name: p.name,
      description: '',
      metadata: { created: now, updated: now, version: '1.0' },
      source: { type: 'local' },
    });
    store[`${prefix}pe:${p.uuid}:${p.exerciseUuid}`] = JSON.stringify({
      uuid: p.exerciseUuid,
      name: `Exercise ${p.exerciseUuid}`,
      index: 0,
    });
  }
  return store;
}

const PROGRAMS = [
  { uuid: 'prog-alpha', name: 'Alpha Drill', exerciseUuid: 'ex-a1' },
  { uuid: 'prog-bravo', name: 'Bravo Exercise', exerciseUuid: 'ex-b1' },
  { uuid: 'prog-charlie', name: 'Charlie Run', exerciseUuid: 'ex-c1' },
];

describe('hasFlutterData', () => {
  it('detects program keys', () => {
    expect(hasFlutterData({ 'p:x': '{}' })).toBe(true);
  });

  it('detects flutter-prefixed keys', () => {
    expect(hasFlutterData({ 'flutter.pe:x:y': '{}' })).toBe(true);
  });

  it('detects the library schema marker', () => {
    expect(hasFlutterData({ 'app:librarySchema:v1': '1' })).toBe(true);
  });

  it('ignores unrelated keys', () => {
    expect(hasFlutterData({ 'theme': 'dark', 'other:thing': '1' })).toBe(false);
  });
});

describe('sanitizeSlug', () => {
  it('lowercases and hyphenates', () => {
    expect(sanitizeSlug('Alpha Drill')).toBe('alpha-drill');
  });

  it('strips punctuation and collapses hyphens', () => {
    expect(sanitizeSlug('  Foo!!  Bar  ')).toBe('foo-bar');
  });
});

describe('exportFileName', () => {
  it('uses the local date', () => {
    expect(exportFileName(new Date(2026, 5, 29))).toBe(
      'ringdrill-eksport-2026-06-29.zip',
    );
  });
});

describe('buildExport', () => {
  it('returns null when there is nothing to migrate', () => {
    expect(buildExport({}, new Date(2026, 5, 29))).toBeNull();
  });

  it('builds one .drill per program with the expected structure', () => {
    const store = fakeStore(PROGRAMS);
    expect(countPrograms(store)).toBe(3);

    const result = buildExport(store, new Date(2026, 5, 29));
    expect(result).not.toBeNull();
    expect(result!.count).toBe(3);
    expect(result!.filename).toBe('ringdrill-eksport-2026-06-29.zip');

    const outer = unzipSync(result!.bytes);
    const drills = Object.keys(outer).filter((n) => n.endsWith('.drill'));
    expect(drills.sort()).toEqual([
      'alpha-drill.drill',
      'bravo-exercise.drill',
      'charlie-run.drill',
    ]);

    for (const program of PROGRAMS) {
      const slug = sanitizeSlug(program.name);
      const inner = unzipSync(outer[`${slug}.drill`]);
      const names = Object.keys(inner).sort();
      expect(names).toEqual([
        'metadata.json',
        'program.json',
        `exercises/${program.exerciseUuid}.json`,
      ].sort());

      // metadata.json is stamped with the current schema.
      const metadata = JSON.parse(strFromU8(inner['metadata.json']));
      expect(metadata.schema).toBe('1.2');

      // program.json carries the program identity with empty collections.
      const shell = JSON.parse(strFromU8(inner['program.json']));
      expect(shell.uuid).toBe(program.uuid);
      expect(shell.exercises).toEqual([]);

      // the exercise manifest is preserved verbatim.
      const exercise = JSON.parse(
        strFromU8(inner[`exercises/${program.exerciseUuid}.json`]),
      );
      expect(exercise.uuid).toBe(program.exerciseUuid);
    }
  });

  it('handles the flutter. localStorage prefix', () => {
    const store = fakeStore([PROGRAMS[0]], { prefix: 'flutter.' });
    const result = buildExport(store, new Date(2026, 5, 29));
    expect(result).not.toBeNull();
    const outer = unzipSync(result!.bytes);
    expect(Object.keys(outer)).toEqual(['alpha-drill.drill']);
  });

  it('de-duplicates identical program-name slugs', () => {
    const store = fakeStore([
      { uuid: 'p1', name: 'Same Name', exerciseUuid: 'e1' },
      { uuid: 'p2', name: 'Same Name', exerciseUuid: 'e2' },
    ]);
    const result = buildExport(store, new Date(2026, 5, 29));
    const outer = unzipSync(result!.bytes);
    expect(Object.keys(outer).sort()).toEqual([
      'same-name-1.drill',
      'same-name.drill',
    ]);
  });
});
