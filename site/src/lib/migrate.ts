// ADR-0039 Phase 3 client-side migration export.
//
// Rebuilds the RingDrill `.drill` archive format (ADR-0007 / ADR-0022)
// directly from the Flutter PWA's `localStorage`, with no Flutter runtime.
// The output is byte-compatible with the new PWA's existing import pipeline
// (`lib/data/drill_file.dart`), so a user who never acted on the in-app
// Phase 1 banner can still export from the retired apex origin.
//
// Storage key layout mirrors `lib/data/program_repository.dart`:
//   p:<U>            program shell (JSON)            -> program.json + metadata.json
//   pe:<U>:<E>       exercise (JSON)                 -> exercises/<E>.json
//   pt:<U>:<T>       team (JSON)                     -> teams/<T>.json
//   ps:<U>:<S>       session (JSON)                  -> sessions/<S>.json
//   pr:<U>:<R>       role-play (JSON)                -> roleplays/<R>.json
//   pa:<U>:<A>       actor (JSON)                    -> actors/<A>.json
//   pan:<U>:<A>      actor notes (raw markdown)      -> actors/<A>/notes.md
//   pgm:<U>          program brief sidecar (JSON)    -> program/*.md
//   pem:<U>:<E>      exercise brief sidecar (JSON)   -> exercises/<E>/*.md (+ stations)
//   prm:<U>:<R>      role-play brief sidecar (JSON)  -> roleplays/<R>/*.md
//
// shared_preferences (web) prefixes every key with `flutter.` in
// localStorage; we strip that prefix so both real installs and
// devtools-seeded test keys are recognised.
import { strToU8, zipSync } from 'fflate';

/** Current `.drill` schema, matching `DrillFile.drillSchemaCurrent`. */
export const DRILL_SCHEMA = '1.2';

const FLUTTER_PREFIX = 'flutter.';

const PROGRAM_BRIEF_FILES: Record<string, string> = {
  briefIntro: 'program/intro.md',
  comms: 'program/comms.md',
  beforeRound: 'program/before-round.md',
};

const EXERCISE_BRIEF_FILES: Record<string, string> = {
  method: 'method.md',
  learningGoals: 'learning-goals.md',
  trainingFocus: 'training-focus.md',
  orderFormat: 'order-format.md',
  executionTips: 'execution-tips.md',
  comms: 'comms.md',
};

const STATION_BRIEF_FILES: Record<string, string> = {
  equipment: 'equipment.md',
  situation: 'situation.md',
  mission: 'mission.md',
  logistics: 'logistics.md',
  criticalQuestions: 'critical-questions.md',
  leaderAnswers: 'leader-answers.md',
  directorNotes: 'director-notes.md',
};

const ROLEPLAY_BRIEF_FILES: Record<string, string> = {
  background: 'background.md',
  behavior: 'behavior.md',
  props: 'props.md',
};

/** A single program's raw storage entries, grouped by kind. */
interface ProgramGroup {
  uuid: string;
  shell?: string;
  programBrief?: string;
  exercises: Map<string, string>;
  exerciseBriefs: Map<string, string>;
  teams: Map<string, string>;
  sessions: Map<string, string>;
  rolePlays: Map<string, string>;
  rolePlayBriefs: Map<string, string>;
  actors: Map<string, string>;
  actorNotes: Map<string, string>;
}

/** Snapshot a `Storage` (e.g. `window.localStorage`) into a plain record. */
export function readStorage(storage: Storage): Record<string, string> {
  const out: Record<string, string> = {};
  for (let i = 0; i < storage.length; i++) {
    const key = storage.key(i);
    if (key === null) continue;
    const value = storage.getItem(key);
    if (value !== null) out[key] = value;
  }
  return out;
}

function stripPrefix(key: string): string {
  return key.startsWith(FLUTTER_PREFIX) ? key.slice(FLUTTER_PREFIX.length) : key;
}

/** `p*:` key prefixes that make up a stored program library (see header). */
const RINGDRILL_KEY_PREFIXES = [
  'p:',
  'pe:',
  'pem:',
  'pt:',
  'ps:',
  'pr:',
  'prm:',
  'pa:',
  'pan:',
  'pgm:',
];

/** Standalone marker keys the Flutter PWA writes alongside the library. */
const RINGDRILL_KEY_MARKERS = new Set(['app:librarySchema:v1']);

/** True if a prefix-stripped key belongs to RingDrill's stored library. */
function isRingdrillKey(strippedKey: string): boolean {
  if (RINGDRILL_KEY_MARKERS.has(strippedKey)) return true;
  return RINGDRILL_KEY_PREFIXES.some((prefix) => strippedKey.startsWith(prefix));
}

/** Normalise entries: strip the `flutter.` prefix from every key. */
function normalise(entries: Record<string, string>): Record<string, string> {
  const out: Record<string, string> = {};
  for (const [key, value] of Object.entries(entries)) {
    out[stripPrefix(key)] = value;
  }
  return out;
}

/** True if the store holds any Flutter library data worth migrating. */
export function hasFlutterData(entries: Record<string, string>): boolean {
  return Object.keys(entries).some((key) => isRingdrillKey(stripPrefix(key)));
}

/**
 * The original (unstripped) keys in `entries` that belong to RingDrill's
 * stored library. Unrelated keys (theme, analytics consent, …) are left out.
 */
export function ringdrillKeys(entries: Record<string, string>): string[] {
  return Object.keys(entries).filter((key) => isRingdrillKey(stripPrefix(key)));
}

/**
 * Remove every RingDrill program-library key from `storage`, leaving
 * unrelated keys untouched. Returns the number of keys removed.
 *
 * Keys are collected before removal so the live index does not shift
 * mid-iteration.
 */
export function clearFlutterData(storage: Storage): number {
  const keys: string[] = [];
  for (let i = 0; i < storage.length; i++) {
    const key = storage.key(i);
    if (key === null) continue;
    if (isRingdrillKey(stripPrefix(key))) keys.push(key);
  }
  for (const key of keys) storage.removeItem(key);
  return keys.length;
}

function groupPrograms(entries: Record<string, string>): ProgramGroup[] {
  const normalised = normalise(entries);
  const groups = new Map<string, ProgramGroup>();

  const groupFor = (uuid: string): ProgramGroup => {
    let group = groups.get(uuid);
    if (!group) {
      group = {
        uuid,
        exercises: new Map(),
        exerciseBriefs: new Map(),
        teams: new Map(),
        sessions: new Map(),
        rolePlays: new Map(),
        rolePlayBriefs: new Map(),
        actors: new Map(),
        actorNotes: new Map(),
      };
      groups.set(uuid, group);
    }
    return group;
  };

  for (const [key, value] of Object.entries(normalised)) {
    const parts = key.split(':');
    const kind = parts[0];
    const programUuid = parts[1];
    const entityUuid = parts[2];

    // Program shell is `p:<U>` (kind === 'p'); everything else is `p*:...`.
    if (kind === 'p' && parts.length === 2) {
      groupFor(programUuid).shell = value;
      continue;
    }
    if (!programUuid) continue;

    switch (kind) {
      case 'pgm':
        groupFor(programUuid).programBrief = value;
        break;
      case 'pe':
        if (entityUuid) groupFor(programUuid).exercises.set(entityUuid, value);
        break;
      case 'pem':
        if (entityUuid) groupFor(programUuid).exerciseBriefs.set(entityUuid, value);
        break;
      case 'pt':
        if (entityUuid) groupFor(programUuid).teams.set(entityUuid, value);
        break;
      case 'ps':
        if (entityUuid) groupFor(programUuid).sessions.set(entityUuid, value);
        break;
      case 'pr':
        if (entityUuid) groupFor(programUuid).rolePlays.set(entityUuid, value);
        break;
      case 'prm':
        if (entityUuid) groupFor(programUuid).rolePlayBriefs.set(entityUuid, value);
        break;
      case 'pa':
        if (entityUuid) groupFor(programUuid).actors.set(entityUuid, value);
        break;
      case 'pan':
        if (entityUuid) groupFor(programUuid).actorNotes.set(entityUuid, value);
        break;
      default:
        break;
    }
  }

  // A program is only exportable if its shell (program.json source) exists.
  return [...groups.values()].filter((g) => g.shell != null);
}

function tryParse(value: string): Record<string, unknown> | null {
  try {
    const decoded = JSON.parse(value);
    return decoded && typeof decoded === 'object' && !Array.isArray(decoded)
      ? (decoded as Record<string, unknown>)
      : null;
  } catch {
    return null;
  }
}

/**
 * Build one `.drill` ZIP (bytes) for a single program group, reproducing
 * the layout `DrillFile.fromProgram` writes.
 */
function buildDrill(group: ProgramGroup): Uint8Array {
  const files: Record<string, Uint8Array> = {};

  const shell = tryParse(group.shell!) ?? {};

  // metadata.json — the program's metadata, stamped with the current schema.
  const metadata = {
    ...((shell.metadata as Record<string, unknown>) ?? {}),
    schema: DRILL_SCHEMA,
  };
  files['metadata.json'] = strToU8(JSON.stringify(metadata));

  // program.json — the shell with nested collections emptied.
  const program = {
    ...shell,
    teams: [],
    sessions: [],
    exercises: [],
    rolePlays: [],
    actors: [],
  };
  files['program.json'] = strToU8(JSON.stringify(program));

  // Entity manifests (raw stored JSON, byte-preserved).
  for (const [uuid, value] of group.exercises) {
    files[`exercises/${uuid}.json`] = strToU8(value);
  }
  for (const [uuid, value] of group.teams) {
    files[`teams/${uuid}.json`] = strToU8(value);
  }
  for (const [uuid, value] of group.sessions) {
    files[`sessions/${uuid}.json`] = strToU8(value);
  }
  for (const [uuid, value] of group.rolePlays) {
    files[`roleplays/${uuid}.json`] = strToU8(value);
  }
  for (const [uuid, value] of group.actors) {
    files[`actors/${uuid}.json`] = strToU8(value);
  }
  // Actor notes are stored raw (ADR-0022), not as JSON.
  for (const [uuid, value] of group.actorNotes) {
    files[`actors/${uuid}/notes.md`] = strToU8(value);
  }

  // Program-level markdown sidecar.
  if (group.programBrief) {
    const blob = tryParse(group.programBrief);
    if (blob) {
      for (const [field, path] of Object.entries(PROGRAM_BRIEF_FILES)) {
        const md = blob[field];
        if (md != null) files[path] = strToU8(String(md));
      }
    }
  }

  // Exercise + station markdown sidecars.
  for (const [uuid, value] of group.exerciseBriefs) {
    const blob = tryParse(value);
    if (!blob) continue;
    const exercise = blob.exercise as Record<string, unknown> | undefined;
    if (exercise) {
      for (const [field, file] of Object.entries(EXERCISE_BRIEF_FILES)) {
        const md = exercise[field];
        if (md != null) files[`exercises/${uuid}/${file}`] = strToU8(String(md));
      }
    }
    const stations = blob.stations as Record<string, unknown> | undefined;
    if (stations) {
      for (const [index, raw] of Object.entries(stations)) {
        const sm = raw as Record<string, unknown>;
        for (const [field, file] of Object.entries(STATION_BRIEF_FILES)) {
          const md = sm[field];
          if (md != null) {
            files[`exercises/${uuid}/stations/${index}/${file}`] = strToU8(
              String(md),
            );
          }
        }
      }
    }
  }

  // Role-play markdown sidecars.
  for (const [uuid, value] of group.rolePlayBriefs) {
    const blob = tryParse(value);
    if (!blob) continue;
    for (const [field, file] of Object.entries(ROLEPLAY_BRIEF_FILES)) {
      const md = blob[field];
      if (md != null) files[`roleplays/${uuid}/${file}`] = strToU8(String(md));
    }
  }

  return zipSync(files);
}

/**
 * Slugify a program name the same way `sanitizeSlug` does in Dart, so
 * exported filenames match what the app produces.
 */
export function sanitizeSlug(input: string): string {
  return input
    .toLowerCase()
    .trim()
    .replace(/\s+/g, '-')
    .replace(/[^a-z0-9-]/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-|-$/g, '');
}

function programName(group: ProgramGroup): string {
  const shell = tryParse(group.shell!);
  const name = shell?.name;
  return typeof name === 'string' ? name : '';
}

/** Format the local date as `YYYY-MM-DD` for the export filename. */
export function formatExportDate(date: Date): string {
  const y = date.getFullYear().toString();
  const m = (date.getMonth() + 1).toString().padStart(2, '0');
  const d = date.getDate().toString().padStart(2, '0');
  return `${y}-${m}-${d}`;
}

/** Suggested outer-ZIP filename, matching the in-app export. */
export function exportFileName(date: Date): string {
  return `ringdrill-eksport-${formatExportDate(date)}.zip`;
}

/** Number of exportable programs found in the store. */
export function countPrograms(entries: Record<string, string>): number {
  return groupPrograms(entries).length;
}

export interface ExportResult {
  filename: string;
  bytes: Uint8Array;
  count: number;
}

/**
 * Build the outer migration ZIP containing one `.drill` per program.
 * Returns `null` when there is nothing to export.
 */
export function buildExport(
  entries: Record<string, string>,
  date: Date,
): ExportResult | null {
  const groups = groupPrograms(entries);
  if (groups.length === 0) return null;

  const files: Record<string, Uint8Array> = {};
  const seen = new Set<string>();

  for (const group of groups) {
    let slug = sanitizeSlug(programName(group));
    if (slug === '') slug = group.uuid;

    let name = slug;
    let counter = 1;
    while (seen.has(name)) {
      name = `${slug}-${counter}`;
      counter += 1;
    }
    seen.add(name);

    files[`${name}.drill`] = buildDrill(group);
  }

  return {
    filename: exportFileName(date),
    bytes: zipSync(files),
    count: groups.length,
  };
}
