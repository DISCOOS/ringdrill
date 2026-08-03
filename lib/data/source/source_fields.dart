/// The DESIGN-014 source format, as data.
///
/// This table is the single description of the format. `build`, `decompile`,
/// `analyze` and `schema` all read it, which is what keeps them consistent by
/// construction rather than by discipline: a field added here is accepted,
/// emitted, validated and documented in one edit.
///
/// Two conventions, both from the worked example:
///
/// * **Names mirror the frozen `.drill` wire keys** (decision 2), not the Dart
///   class names — the `Program → Plan` rename changed identifiers, not the
///   archive's JSON keys. Only value *shapes* are source-friendly.
/// * **Markdown fields take their archive file's name** (decision 6):
///   `directorNotesMd` is stored as `director-notes.md` and written
///   `director_notes`. For those the archive path is the wire key.
///
/// Free of `package:flutter/*` (AGENTS.md rule 7).
library;

import 'package:ringdrill/data/source/source_field.dart';
import 'package:ringdrill/services/brief/brief_audience.dart';

// Who sees a markdown field (ADR-0063). Named for what the group *is*, so a
// reclassification is one edit here rather than a hunt through the table.

/// Participants and every staff role — the plan as everyone reads it.
const _everyone = <BriefAudience>{
  BriefAudience.participant,
  BriefAudience.actor,
  BriefAudience.instructor,
  BriefAudience.director,
  BriefAudience.other,
};

/// The roles that run and evaluate the exercise. Withheld from participants
/// because it would spoil the station, and from actors because it is not theirs
/// to hold while standing next to a participant.
const _control = <BriefAudience>{
  BriefAudience.instructor,
  BriefAudience.director,
};

/// The marker's own material, plus the roles that brief and supervise them.
const _rolePlay = <BriefAudience>{
  BriefAudience.actor,
  BriefAudience.instructor,
  BriefAudience.director,
};

/// The format version the source document declares, and this build accepts.
///
/// Deliberately decoupled from `DrillFile.drillSchemaCurrent` (settled decision
/// 3): the authored surface and the archive evolve for different reasons, and
/// DESIGN-014 adds no `.drill` schema bump.
const sourceFormatVersion = '1.0';

/// Scope definitions, reachable from [planScope] downwards.
class SourceScopes {
  const SourceScopes._();

  /// A station-owned scenario place (ADR-0047, DESIGN-009).
  static const location = SourceScope(
    name: 'location',
    description:
        'Scenario geography owned by a station, referenced in prose '
        'as {{station.loc.<slug>}}.',
    fields: [
      SourceField(
        'slug',
        shape: SourceShape.string,
        description:
            'Reference key, unique within the station. '
            r'Must match ^[a-z][a-z0-9_]*$.',
      ),
      SourceField('label', shape: SourceShape.string),
      SourceField(
        'kind',
        shape: SourceShape.enumeration,
        enumValues: [
          'lkp',
          'ipp',
          'pp',
          'rendezvous',
          'commandPost',
          'home',
          'trackFound',
          'dogInterest',
          'obstacle',
          'notSearchable',
          'phoneTrace',
          'observation',
          'vantagePoint',
          'containmentPost',
          'personFound',
          'other',
        ],
        description:
            'Marker styling and picker grouping. An unknown value '
            'reads as "other".',
      ),
      SourceField('place', shape: SourceShape.string),
      SourceField(
        'position',
        shape: SourceShape.position,
        description: 'Scenario coordinate as {lat, lng}.',
      ),
      SourceField('note', shape: SourceShape.string),
    ],
  );

  /// A station-owned fictional person — no PII (ADR-0047, DESIGN-009).
  static const person = SourceScope(
    name: 'person',
    description:
        'A fictional scenario person owned by a station, referenced '
        'in prose as {{station.person.<slug>}}. Never a real human — that is '
        'Staff, which is stripped at publish and absent from this format.',
    fields: [
      SourceField(
        'slug',
        shape: SourceShape.string,
        description:
            'Reference key, unique within the station. '
            r'Must match ^[a-z][a-z0-9_]*$.',
      ),
      SourceField('name', shape: SourceShape.string),
      SourceField('age', shape: SourceShape.integer),
      SourceField('gender', shape: SourceShape.string),
      SourceField(
        'description',
        shape: SourceShape.string,
        description:
            'Appearance and identifying detail. Was named '
            '"signalement" before the rename; ADR-0059 migrates that key.',
      ),
      SourceField(
        'locSlug',
        shape: SourceShape.string,
        description: 'Slug of a location on the same station.',
      ),
      SourceField('notes', shape: SourceShape.string),
    ],
  );

  /// A role a marker enacts, nested under the station that owns its person.
  static const roleplay = SourceScope(
    name: 'roleplay',
    description:
        'A role portraying one of the station\'s persons. Identity '
        'fields are inherited from that person unless written here; the '
        'builder denormalizes the effective value (ADR-0047).',
    fields: [
      SourceField(
        'uuid',
        shape: SourceShape.string,
        kind: SourceFieldKind.identity,
      ),
      SourceField(
        'personRef',
        shape: SourceShape.string,
        description:
            'Slug of the person on this station that the role '
            'portrays.',
      ),
      SourceField(
        'name',
        shape: SourceShape.string,
        description: 'Overrides the person\'s name. Omit to inherit.',
      ),
      SourceField(
        'age',
        shape: SourceShape.integer,
        description: 'Overrides the person\'s age. Omit to inherit.',
      ),
      SourceField(
        'gender',
        shape: SourceShape.string,
        description: 'Overrides the person\'s gender. Omit to inherit.',
      ),
      SourceField(
        'description',
        shape: SourceShape.string,
        description: 'Overrides the person\'s description. Omit to inherit.',
      ),
      SourceField(
        'position',
        shape: SourceShape.position,
        description:
            'Overrides the coordinate inherited from the person\'s '
            'location, as {lat, lng}.',
      ),
      SourceField(
        'behavior',
        shape: SourceShape.markdown,
        mdFileName: 'behavior.md',
        audiences: _rolePlay,
      ),
      SourceField(
        'background',
        shape: SourceShape.markdown,
        mdFileName: 'background.md',
        audiences: _rolePlay,
      ),
      SourceField(
        'props',
        shape: SourceShape.markdown,
        wireKey: 'propsMd',
        mdFileName: 'props.md',
        audiences: _rolePlay,
      ),
      // Derived, listed so schema/analyze can name them as such.
      SourceField(
        'index',
        shape: SourceShape.integer,
        kind: SourceFieldKind.derived,
      ),
      SourceField(
        'exerciseUuid',
        shape: SourceShape.string,
        kind: SourceFieldKind.derived,
      ),
      SourceField(
        'stationIndex',
        shape: SourceShape.integer,
        kind: SourceFieldKind.derived,
      ),
      SourceField(
        'staffUuid',
        shape: SourceShape.string,
        kind: SourceFieldKind.derived,
        description:
            'Casting to a real person. Local PII, never published, '
            'never authored here.',
      ),
    ],
  );

  /// A rotation post.
  static const station = SourceScope(
    name: 'station',
    description:
        'A rotation post within an exercise. Stations have no uuid — '
        'identity is (exercise, index).',
    fields: [
      SourceField('name', shape: SourceShape.string),
      SourceField(
        'executionTime',
        shape: SourceShape.integer,
        description:
            "Minutes a team spends drilling here, overriding the exercise's "
            'executionTime (ADR-0062). Absent inherits, which is what almost '
            'every station does. Write it where the source document states it '
            '— "post b takes 100 minutes" is a fact about the post, not about '
            'a round. In `ring` the longest station sets every round, so an '
            'override there lengthens the whole exercise and leaves the other '
            'stations waiting. At least 1 — unlike evaluationTime and '
            'rotationTime, 0 is not meaningful here: a post nobody spends time '
            'at is a void post, not a fast one.',
      ),
      SourceField(
        'evaluationTime',
        shape: SourceShape.integer,
        description:
            "Minutes of debrief at this station, overriding the exercise's "
            'evaluationTime. Absent inherits; 0 means no debrief at this post '
            'at all. A demanding post earns a longer debrief than a simple '
            'one. Maximised per round like executionTime, and independently '
            'of it.',
      ),
      SourceField(
        'rotationTime',
        shape: SourceShape.integer,
        description:
            'Minutes to leave this station and reach the next one, overriding '
            "the exercise's rotationTime. Absent inherits; 0 means no walk, "
            'as when the next post is at the same spot. Terrain is what '
            'makes it vary — the walk off a shoreline post is not the walk off '
            'the one beside the car park. In `ring` every team rotates at '
            'once, so the longest walk sets the round and the rest wait; in '
            '`together` a round is a station, so this is exactly that round\'s '
            'rotation.',
      ),
      SourceField(
        'variantSuffix',
        shape: SourceShape.string,
        description:
            'Display-only qualifier appended after the station name in '
            'the brief ("7a – Assistanse turgåer – variant B"). Nothing is '
            'derived from it and it has no editable UI in the app.',
      ),
      SourceField(
        'position',
        shape: SourceShape.position,
        description:
            'Administrative placement of the post itself, as '
            '{lat, lng}. Scenario geography belongs in locations.',
      ),
      SourceField(
        'description',
        shape: SourceShape.string,
        description:
            "The post's own summary: what this post is, in a sentence or two, "
            'for someone scanning the list. The app treats it as expected and '
            'shows "Missing: Station description" on a post without one, so '
            'omitting it is visible rather than neutral. Not a duplicate of '
            'situation — that is the scenario as the team meets it, this is '
            'the post as staff refer to it. Longer prose belongs in situation.',
      ),
      SourceField(
        'variableOverrides',
        shape: SourceShape.stringMap,
        description:
            'Overrides plan variable values for this station. Never '
            'declares new variables (ADR-0046). It applies to every field '
            'this post renders, including the ones it inherits: overriding '
            'the variable an exercise\'s comms references changes the comms '
            'block under this post and no other (ADR-0068). So a post on its '
            'own talk group needs the override and nothing else — do not '
            'repeat the token in logistics, which prints the talk group in '
            'the administration section where no reader looks for it.',
      ),
      SourceField(
        'equipment',
        shape: SourceShape.markdown,
        wireKey: 'equipmentMd',
        mdFileName: 'equipment.md',
        audiences: _everyone,
      ),
      SourceField(
        'situation',
        shape: SourceShape.markdown,
        wireKey: 'situationMd',
        mdFileName: 'situation.md',
        audiences: _everyone,
      ),
      SourceField(
        'mission',
        shape: SourceShape.markdown,
        wireKey: 'missionMd',
        mdFileName: 'mission.md',
        audiences: _everyone,
      ),
      SourceField(
        'logistics',
        shape: SourceShape.markdown,
        wireKey: 'logisticsMd',
        mdFileName: 'logistics.md',
        audiences: _everyone,
      ),
      SourceField(
        'critical_questions',
        shape: SourceShape.markdown,
        wireKey: 'criticalQuestionsMd',
        mdFileName: 'critical-questions.md',
        audiences: _control,
      ),
      SourceField(
        'leader_answers',
        shape: SourceShape.markdown,
        wireKey: 'leaderAnswersMd',
        mdFileName: 'leader-answers.md',
        audiences: _control,
      ),
      SourceField(
        'director_notes',
        shape: SourceShape.markdown,
        wireKey: 'directorNotesMd',
        mdFileName: 'director-notes.md',
        audiences: _control,
        description: 'Instructor/director only. Never shown to participants.',
      ),
      SourceField(
        'index',
        shape: SourceShape.integer,
        kind: SourceFieldKind.derived,
      ),
    ],
    children: [
      SourceChild('locations', scope: location),
      SourceChild('persons', scope: person),
      SourceChild(
        'roleplays',
        scope: roleplay,
        collection: SourceCollection.relocatedList,
        description:
            'Nested here, stored at plan level with a derived '
            'exerciseUuid and stationIndex.',
      ),
    ],
  );

  /// One exercise: a set of stations and the rotation over them.
  static const exercise = SourceScope(
    name: 'exercise',
    fields: [
      SourceField(
        'uuid',
        shape: SourceShape.string,
        kind: SourceFieldKind.identity,
      ),
      SourceField(
        'name',
        shape: SourceShape.string,
        description:
            'The name alone. The displayed number ("#2") is derived '
            'from position, so it does not belong here — but a name that '
            'already contains one is content and is preserved verbatim.',
      ),
      SourceField(
        'startTime',
        shape: SourceShape.time,
        description:
            'Clock face as "HH:MM". An exercise has no date '
            '(DEBT-0013).',
      ),
      SourceField('numberOfTeams', shape: SourceShape.integer),
      SourceField(
        'numberOfRounds',
        shape: SourceShape.integer,
        description:
            'How many rounds the rotation runs. Authored in `ring`; in '
            '`together` and `split` it is derived (one round per station, or '
            'per parallel group) and an authored value is ignored.',
      ),
      SourceField(
        'mode',
        shape: SourceShape.enumeration,
        enumValues: ['ring', 'together', 'split'],
        description:
            'How teams relate to stations (ADR-0062). `ring` (the default, and '
            'what an absent mode means) rotates one team per station. '
            '`together` puts every team on one station at a time, so a round '
            'is a station. `split` runs several stations at once with the '
            'teams divided between them. All three are the same structure — a '
            'round is a set of groups, a group is a station with some teams on '
            'it — and the first two are generated, which is why they cost '
            'nothing to author.',
      ),
      SourceField(
        'executionTime',
        shape: SourceShape.integer,
        description: 'Minutes of execution per round.',
      ),
      SourceField(
        'evaluationTime',
        shape: SourceShape.integer,
        description: 'Minutes of evaluation per round.',
      ),
      SourceField(
        'rotationTime',
        shape: SourceShape.integer,
        description: 'Minutes to rotate between stations.',
      ),
      SourceField('templateId', shape: SourceShape.string),
      SourceField(
        'variableOverrides',
        shape: SourceShape.stringMap,
        description:
            'Overrides plan variable values for this exercise and its '
            'stations. Never declares new variables (ADR-0046). It applies to '
            'every field this exercise renders, including the plan-level ones '
            'it inherits — before_round, and comms when the exercise has none '
            'of its own (ADR-0068). A station may override the same key again '
            'for itself.',
      ),
      SourceField(
        'method',
        shape: SourceShape.markdown,
        wireKey: 'methodMd',
        mdFileName: 'method.md',
        audiences: _everyone,
      ),
      SourceField(
        'learning_goals',
        shape: SourceShape.markdown,
        wireKey: 'learningGoalsMd',
        mdFileName: 'learning-goals.md',
        audiences: _everyone,
      ),
      SourceField(
        'training_focus',
        shape: SourceShape.markdown,
        wireKey: 'trainingFocusMd',
        mdFileName: 'training-focus.md',
        audiences: _control,
      ),
      SourceField(
        'order_format',
        shape: SourceShape.markdown,
        wireKey: 'orderFormatMd',
        mdFileName: 'order-format.md',
        audiences: _everyone,
      ),
      SourceField(
        'execution_tips',
        shape: SourceShape.markdown,
        wireKey: 'executionTipsMd',
        mdFileName: 'execution-tips.md',
        audiences: _control,
      ),
      SourceField(
        'comms',
        shape: SourceShape.markdown,
        wireKey: 'commsMd',
        mdFileName: 'comms.md',
        audiences: _everyone,
      ),
      // Derived.
      SourceField(
        'index',
        shape: SourceShape.integer,
        kind: SourceFieldKind.derived,
      ),
      SourceField(
        'schedule',
        shape: SourceShape.raw,
        kind: SourceFieldKind.derived,
        description:
            'Phase boundaries per round, from startTime and the '
            'three durations.',
      ),
      SourceField(
        'endTime',
        shape: SourceShape.time,
        kind: SourceFieldKind.derived,
        description:
            'startTime + numberOfRounds × (execution + evaluation + '
            'rotation).',
      ),
    ],
    children: [
      SourceChild('stations', scope: station),
      SourceChild(
        'groups',
        scope: exerciseGroup,
        description:
            'For `mode: split` only, one entry per round. Absent in every '
            'other mode; absent in split too until the author has grouped '
            'anything, which reads as `together` in the meantime rather than '
            'as an error.',
      ),
    ],
  );

  /// One station inside a parallel group, with the teams placed on it.
  static const groupStation = SourceScope(
    name: 'groupStation',
    description:
        'A station in a parallel group, and the teams on it (ADR-0062). '
        'Both refer to list positions — the station by its position in the '
        "exercise's stations, the teams by theirs in the plan's teams — so "
        'nothing here is a name and nothing is parsed (ADR-0059).',
    fields: [
      SourceField(
        'station',
        shape: SourceShape.integer,
        wireKey: 'stationIndex',
        description:
            "Zero-based position in the exercise's stations. The station's "
            'derived code (7c) comes from the same position, which is why a '
            'concurrent phase can stay one exercise instead of being split '
            'into several and renumbered.',
      ),
      SourceField(
        'teams',
        shape: SourceShape.integerList,
        description:
            "Zero-based positions in the plan's teams. A team may appear in "
            'at most one station of a group — the stations run at once, so it '
            'can only be at one of them — and a team in none of them is '
            'held back, which analyze warns about rather than forbids.',
      ),
    ],
  );

  /// One round of a split exercise: the stations running at the same time.
  static const exerciseGroup = SourceScope(
    name: 'exerciseGroup',
    description:
        'One round of a `mode: split` exercise — the stations running at the '
        'same time, and who is on each. Groups are of any size and need not '
        'match each other: four teams across three stations is 2 + 1 + 1. '
        'Ignored in the other modes, where the grouping is generated.',
    fields: [],
    children: [SourceChild('stations', scope: groupStation)],
  );

  /// A rotating group of participants.
  static const team = SourceScope(
    name: 'team',
    description:
        'Optional. When absent, build derives as many teams as the '
        'largest numberOfTeams across the exercises, with generated names — '
        'the same rule the app applies (PlanService.ensureTeams).',
    fields: [
      SourceField(
        'uuid',
        shape: SourceShape.string,
        kind: SourceFieldKind.identity,
      ),
      SourceField(
        'name',
        shape: SourceShape.string,
        description:
            'Free text. Naming conventions are subject-area '
            'specific, so nothing is derived from it (see docs/glossary.md).',
      ),
      SourceField('numberOfMembers', shape: SourceShape.integer),
      SourceField('position', shape: SourceShape.position),
      SourceField(
        'index',
        shape: SourceShape.integer,
        kind: SourceFieldKind.derived,
      ),
    ],
  );

  /// A plan-global variable (ADR-0046, DESIGN-008).
  static const variable = SourceScope(
    name: 'variable',
    description:
        'Declared once on the plan and referenced as '
        '{{var.<name>}}. Exercises and stations may only override the value.',
    fields: [
      SourceField(
        'name',
        shape: SourceShape.string,
        description: r'Reference key. Must match ^[a-z][a-z0-9_]*$.',
      ),
      SourceField(
        'value',
        shape: SourceShape.string,
        description:
            'Canonically encoded per type. Unused when type is '
            '"location" — use the location field.',
      ),
      SourceField('hint', shape: SourceShape.string),
      SourceField(
        'type',
        shape: SourceShape.enumeration,
        enumValues: [
          'string',
          'number',
          'time',
          'date',
          'duration',
          'location',
        ],
      ),
      SourceField(
        'location',
        shape: SourceShape.raw,
        description:
            'Structured value for type "location": {place, position} '
            'with position as {lat, lng}.',
      ),
    ],
  );

  /// The plan itself — the document root's `plan:` mapping.
  static const plan = SourceScope(
    name: 'plan',
    fields: [
      SourceField(
        'uuid',
        shape: SourceShape.string,
        kind: SourceFieldKind.identity,
      ),
      SourceField('name', shape: SourceShape.string),
      SourceField('description', shape: SourceShape.string),
      SourceField(
        'language',
        shape: SourceShape.string,
        wireKey: 'languageCode',
        description:
            'ISO 639-1 code for the plan\'s content language. Also '
            'selects the language of any generated default names.',
      ),
      SourceField('tags', shape: SourceShape.stringList),
      SourceField(
        'exerciseNumberFormat',
        shape: SourceShape.enumeration,
        enumValues: ['hash'],
        description:
            'How a derived exercise number is displayed: '
            '"hash" renders exercise 2 as "#2".',
      ),
      SourceField(
        'stationNumberFormat',
        shape: SourceShape.enumeration,
        enumValues: ['dotted', 'alpha'],
        description:
            'How a derived station code is displayed: "dotted" '
            'renders exercise 2\'s first station as "2.1", "alpha" as "2a". '
            'Pick "alpha" to reproduce a source document that labels its posts '
            '1a/2f/7c — model each of its exercises as one exercise and its '
            'lettered sub-sections as that exercise\'s stations.',
      ),
      SourceField(
        'intro',
        shape: SourceShape.markdown,
        wireKey: 'briefIntroMd',
        mdFileName: 'intro.md',
        audiences: _everyone,
      ),
      SourceField(
        'comms',
        shape: SourceShape.markdown,
        wireKey: 'commsMd',
        mdFileName: 'comms.md',
        audiences: _everyone,
      ),
      SourceField(
        'before_round',
        shape: SourceShape.markdown,
        wireKey: 'beforeRoundMd',
        mdFileName: 'before-round.md',
        audiences: _everyone,
      ),
      // Derived / excluded.
      SourceField(
        'contentHash',
        shape: SourceShape.raw,
        kind: SourceFieldKind.derived,
      ),
      SourceField(
        'source',
        shape: SourceShape.raw,
        kind: SourceFieldKind.derived,
      ),
      SourceField(
        'metadata',
        shape: SourceShape.raw,
        kind: SourceFieldKind.derived,
      ),
      SourceField(
        'sessions',
        shape: SourceShape.raw,
        kind: SourceFieldKind.derived,
        description: 'Run records. Always empty in a published plan.',
      ),
      SourceField(
        'staff',
        shape: SourceShape.raw,
        kind: SourceFieldKind.derived,
        description:
            'Local roster with PII. Stripped at publish; never in '
            'this format.',
      ),
    ],
    children: [
      SourceChild(
        'variables',
        scope: variable,
        collection: SourceCollection.keyedMap,
        keyField: 'name',
      ),
    ],
  );

  /// Every scope, for schema generation and tests.
  static const all = <SourceScope>[
    plan,
    exercise,
    station,
    location,
    person,
    roleplay,
    team,
    variable,
    exerciseGroup,
    groupStation,
  ];

  /// Every markdown field, keyed by wire key (`situationMd`, `directorNotesMd`).
  ///
  /// Wire keys because that is what the renderer builds its mustache context
  /// with. A key is unique across scopes for the fields that matter here —
  /// `comms` is declared on both plan and exercise and resolves to the same
  /// `commsMd` with the same audiences.
  /// A key absent here is not a markdown field and carries no audience of its
  /// own — `description`, the plain-string station lead-in, is the case that
  /// matters. The renderer passes those through rather than treating "no
  /// declaration" as "nobody".
  static final markdownByWireKey = <String, SourceField>{
    for (final scope in all)
      for (final field in scope.fields)
        if (field.shape == SourceShape.markdown) field.wireKey: field,
  };
}

/// Top-level keys of the source document.
///
/// The document is `{sourceFormat?, plan, exercises?, teams?}` — the plan's own
/// scalars live under `plan:` while the collections sit beside it, so a long
/// exercise list does not bury the plan header.
class SourceDocumentKeys {
  const SourceDocumentKeys._();

  static const sourceFormat = 'sourceFormat';
  static const plan = 'plan';
  static const exercises = 'exercises';
  static const teams = 'teams';

  static const all = <String>[sourceFormat, plan, exercises, teams];
}
