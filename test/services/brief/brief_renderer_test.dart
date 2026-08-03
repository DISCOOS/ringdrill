import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/services/brief/brief_template_source.dart';
import 'package:ringdrill/views/widgets/app_brief_labels.dart';
import 'package:ringdrill/l10n/app_localizations_en.dart';
import 'package:ringdrill/l10n/app_localizations_nb.dart';
import 'package:ringdrill/models/staff.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/numbering.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/brief/brief_audience.dart';
import 'package:ringdrill/services/brief/brief_renderer.dart';
import 'package:ringdrill/services/brief/template_registry.dart';

// ---------------------------------------------------------------------------
// Fixtures — from DESIGN-004 lines 314-382
// ---------------------------------------------------------------------------

final _start = SimpleTimeOfDay(hour: 8, minute: 30);
final _end = SimpleTimeOfDay(hour: 10, minute: 30);

Plan _emptyPlan() {
  final now = DateTime(2026);
  return Plan(
    uuid: 'prog-1',
    name: 'Test Plan',
    description: '',
    metadata: PlanMetadata(created: now, updated: now, version: '1.0'),
    teams: const [],
    sessions: const [],
    exercises: const [],
    rolePlays: const [],
    staff: const [],
  );
}

/// DESIGN-004 exercise fixture.
Exercise _designExercise() => Exercise(
  uuid: 'ex-3',
  name: 'Øvelse 3 – Øve PIK + taktisk tankegang',
  startTime: _start,
  endTime: _end,
  numberOfTeams: 4,
  numberOfRounds: 4,
  executionTime: 60,
  evaluationTime: 15,
  rotationTime: 5,
  stations: [_designStation()],
  schedule: const [],
  methodMd: 'Gruppevis øving utendørs',
  learningGoalsMd: '''Etter gjennomført øvelse skal deltakerne
- kunne planlegge oppdraget taktisk ut fra situasjon og oppdrag
- kunne iverksette oppdraget
- kunne lede mannskaper under utførelsen
''',
  commsMd: '**Talegruppe:** RK-VFOLD-ØV2  \n**Telefon til KO:** 93258930',
);

/// DESIGN-004 station fixture.
Station _designStation() => const Station(
  index: 0,
  name: 'Demens',
  position: LatLng(58.99, 10.43),
  equipmentMd:
      'Et stort hus til å gjennomføre hussøk i (bruk huset «Gamlestuen» på Eidene).',
  situationMd:
      '(AL) Anne Glemsk 39 år er meldt savnet fra Gamlehuset i {{station.position}},\n'
      'av pårørende kl 13.00 i dag. Sist sett på vei mot kjellertrappen kl 09.30.\n',
  missionMd:
      '(AL) Politiet ønsker at Røde Kors utfører søk etter savnet kvinne. Det er\n'
      'avklart at før hussøk kan starte må området rundt huset finsøkes.\n'
      '\n'
      '**Utførelse**\n'
      '\n'
      '(AL) Lag 2.X gjennomfører finsøk på R25 først, deretter hussøk av søndre fløy.\n',
  logisticsMd:
      '(AL) Aksjonssekk etter stående ordre. KO sin posisjon er 32V 0580465E 6551894N.',
  criticalQuestionsMd:
      '(AL)\n'
      '- Har gått seg fast? Dersom de går utenfor en vei kommer de sjelden langt før de\n'
      '  setter seg ned.\n'
      '- Hvilke klær har hun på?\n',
  leaderAnswersMd:
      '- Har vert savnet fire ganger før. Funnet i nærheten av barndomshjemmet.\n'
      '- Bruker briller, kan ha gått fra dem.\n',
  directorNotesMd:
      'Markør er utplassert. Det skal gjennomføres hussøk av «Søndre». Rom 105 er låst med vilje.',
);

const _rolePlay = RolePlay(
  uuid: 'rp-anne',
  index: 0,
  exerciseUuid: 'ex-3',
  name: 'Anne Glemsk',
  age: 39,
  description: '160 cm, grått hår, blå anorakk',
  behavior:
      'Du spiller en dement dame i god fysisk form. Noen karakteristiske trekk:\n'
      '- Du svarer på navnet ditt, men er forvirret om hvor du er.\n'
      '- Du går videre hvis du ikke blir snakket til etter 30 sekunder.\n',
  stationIndex: 0,
  position: LatLng(58.99, 10.43),
  staffUuid: 'actor-12',
);

const _actor = Staff(
  uuid: 'actor-12',
  realName: 'Kari Hansen',
  phone: '99887766',
);

Plan _designPlan() => _emptyPlan().copyWith(
  exercises: [_designExercise()],
  rolePlays: [_rolePlay],
  staff: [_actor],
);

final _l10n = AppLocalizationsNb();
final _l10nEn = AppLocalizationsEn();

/// A [BriefTemplateSource] whose [load] always fails, to exercise the renderer's
/// [BriefTemplateException] wrapping.
///
/// Was an AssetBundle double before the templates moved off the asset bundle
/// (DESIGN-014's amendment to ADR-0048). The behaviour under test is unchanged:
/// the renderer must wrap whatever the source throws, naming the template it
/// could not load.
class _ThrowingTemplateSource extends BriefTemplateSource {
  const _ThrowingTemplateSource();

  @override
  Future<String> load(String assetPath) async {
    throw StateError('Unable to load asset: "$assetPath".');
  }
}

/// Trims trailing whitespace from each line so whitespace-only differences
/// at line endings don't cause false failures.
String _normalizeLines(String s) =>
    s.split('\n').map((l) => l.trimRight()).join('\n');

/// The slice of [brief] that belongs to the station whose `### ` heading
/// contains [nameFragment] — for asserting that two stations under one
/// exercise render the *same* cascaded field differently (ADR-0068).
///
/// Splitting on `^### ` is safe against the field headings: those are `####`,
/// whose fourth character is not the space the pattern requires.
String _stationSection(String brief, String nameFragment) {
  final sections = brief.split(RegExp(r'^### ', multiLine: true));
  return sections.firstWhere(
    (s) => s.split('\n').first.contains(nameFragment),
    orElse: () => throw StateError('No station section for "$nameFragment"'),
  );
}

/// The slice of [brief] that belongs to the exercise whose `## ` heading
/// contains [nameFragment], up to its first station. Where the Organisering
/// block — and so `before_round` — lives.
String _exerciseHead(String brief, String nameFragment) {
  final sections = brief.split(RegExp(r'^## ', multiLine: true));
  final section = sections.firstWhere(
    (s) => s.split('\n').first.contains(nameFragment),
    orElse: () => throw StateError('No exercise section for "$nameFragment"'),
  );
  return section.split(RegExp(r'^### ', multiLine: true)).first;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BriefRenderer renderer;

  setUp(() {
    renderer = BriefRenderer();
  });

  group('BriefRenderer — director audience', () {
    test('renders DESIGN-004 station section for director audience', () async {
      final plan = _designPlan();
      final result = await renderer.render(
        plan: plan,
        audience: BriefAudience.director,
        l10n: _l10n.brief,
      );
      final normalized = _normalizeLines(result);

      // Station heading — default stationNumberFormat is dotted ("1.1")
      expect(normalized, contains('### 1.1 – Demens'));

      // UTM placement — use actual computed value rather than DESIGN-004 example.
      // UTM renders as inline code (backticks) so it stands out from prose.
      final expectedUtm = BriefRenderer.formatUtm(const LatLng(58.99, 10.43));
      expect(normalized, contains('**Post 1.1 plassering:** `$expectedUtm`'));

      // Station Varighet heading (new template: #### Varighet, not **Tid:** inline)
      expect(normalized, contains('#### Varighet'));
      expect(normalized, isNot(contains('**Tid:**')));

      // Exercise-level Tid heading (clock-time span)
      expect(normalized, contains('#### Tid'));
      expect(normalized, contains('08:30–10:30'));

      // Station duration (phase breakdown)
      expect(normalized, contains('80 min (60 | 15 | 5)'));

      // Equipment
      expect(
        normalized,
        contains(
          'Et stort hus til å gjennomføre hussøk i (bruk huset «Gamlestuen» på Eidene).',
        ),
      );

      // Roleplay name
      expect(normalized, contains('#### Markørspill (Anne Glemsk)'));

      // Staff PII (director only)
      expect(normalized, contains('**Markør:** Kari Hansen `(99887766)`'));

      // Situation with resolved UTM cross-reference — {{station.position}} is substituted
      expect(
        normalized,
        contains(
          '(AL) Anne Glemsk 39 år er meldt savnet fra Gamlehuset i `$expectedUtm`,',
        ),
      );

      // Mission
      expect(normalized, contains('#### Oppdrag'));
      expect(
        normalized,
        contains(
          '(AL) Politiet ønsker at Røde Kors utfører søk etter savnet kvinne.',
        ),
      );

      // Director notes
      expect(normalized, contains('**Notater til instruktør/øvingsledelse**'));
      expect(
        normalized,
        contains(
          'Markør er utplassert. Det skal gjennomføres hussøk av «Søndre». Rom 105 er låst med vilje.',
        ),
      );
    });
  });

  group('BriefRenderer — participant audience', () {
    test('drops actor PII and director notes', () async {
      final plan = _designPlan();
      final result = await renderer.render(
        plan: plan,
        audience: BriefAudience.participant,
        l10n: _l10n.brief,
      );

      // Staff PII must be absent
      expect(result, isNot(contains('Kari Hansen')));
      expect(result, isNot(contains('99887766')));
      expect(result, isNot(contains('**Markør:**')));

      // Director notes must be absent
      expect(result, isNot(contains('Notater til instruktør/øvingsledelse')));
      expect(result, isNot(contains('Markør er utplassert.')));

      // Roleplay name (publishable) must still appear
      expect(result, contains('Anne Glemsk'));
    });

    test('withholds every staff-facing field, not just director notes', () async {
      // The printed handout. Before ADR-0063 only director notes and actor PII
      // were gated, so a participant sheet carried the marker's script and the
      // answers a team leader is supposed to have to ask for.
      final result = await renderer.render(
        plan: _designPlan(),
        audience: BriefAudience.participant,
        l10n: _l10n.brief,
      );

      expect(result, isNot(contains('Har vert savnet fire ganger')));
      expect(result, isNot(contains('Har gått seg fast?')));
      expect(result, isNot(contains('dement dame i god fysisk form')));

      // What a participant does need is untouched.
      expect(result, contains('meldt savnet fra Gamlehuset'));
      expect(result, contains('Gruppevis øving utendørs'));
    });
  });

  group('BriefRenderer — actor audience', () {
    test(
      'gets the role play and the cast, not the instructor material',
      () async {
        // A markör needs their own scenario and the markörer they work beside — a
        // station can post two — but not the withheld answers they would be
        // holding next to a participant (ADR-0063).
        final result = await renderer.render(
          plan: _designPlan(),
          audience: BriefAudience.actor,
          l10n: _l10n.brief,
        );

        expect(result, contains('dement dame i god fysisk form'));
        expect(result, contains('Kari Hansen'));

        expect(result, isNot(contains('Har vert savnet fire ganger')));
        expect(result, isNot(contains('Har gått seg fast?')));
        expect(result, isNot(contains('Notater til instruktør/øvingsledelse')));
      },
    );
  });

  group('BriefRenderer — other audience', () {
    test('gets the participant set, on default-deny', () async {
      // A staffing role the enum does not name is granted nothing in particular,
      // the same logic ADR-0057 applies to edit rights. It used to borrow the
      // instructor view.
      final result = await renderer.render(
        plan: _designPlan(),
        audience: BriefAudience.other,
        l10n: _l10n.brief,
      );

      expect(result, contains('meldt savnet fra Gamlehuset'));
      expect(result, isNot(contains('Har vert savnet fire ganger')));
      expect(result, isNot(contains('dement dame i god fysisk form')));
      expect(result, isNot(contains('Kari Hansen')));
    });
  });

  group('BriefRenderer — instructor audience', () {
    test('shows director notes and the cast the veileder has to reach', () async {
      final plan = _designPlan();
      final result = await renderer.render(
        plan: plan,
        audience: BriefAudience.instructor,
        l10n: _l10n.brief,
      );

      expect(result, contains('Notater til instruktør/øvingsledelse'));

      // A veileder supervises a team through a station and is responsible for the
      // markör standing at it, so they get the contact details (ADR-0063). This
      // used to be director-only.
      expect(result, contains('Kari Hansen'));
      expect(result, contains('99887766'));
    });
  });

  group('BriefRenderer — cross-reference resolution', () {
    test('resolves {{station.position}} inside markdown fields', () async {
      const position = LatLng(58.99, 10.43);
      final expectedUtm = BriefRenderer.formatUtm(position);
      final exercise = Exercise(
        uuid: 'ex-1',
        name: 'Test',
        startTime: _start,
        endTime: _end,
        numberOfTeams: 1,
        numberOfRounds: 1,
        executionTime: 30,
        evaluationTime: 5,
        rotationTime: 5,
        stations: const [
          Station(
            index: 0,
            name: 'Post',
            position: position,
            situationMd: 'IPP er ved {{station.position}}.',
          ),
        ],
        schedule: const [],
      );
      final plan = _emptyPlan().copyWith(exercises: [exercise]);
      final result = await renderer.render(
        plan: plan,
        audience: BriefAudience.participant,
        l10n: _l10n.brief,
      );

      expect(result, contains(expectedUtm));
      expect(result, isNot(contains('{{station.position}}')));
    });

    test('{{plan.name}} and {{plan.description}} resolve inside plan-scope '
        'markdown fields (briefIntroMd, commsMd, beforeRoundMd)', () async {
      final exercise = _designExercise();
      final plan = _emptyPlan().copyWith(
        name: 'Vinterøvelse Nordland',
        description: 'Samvirkeøvelse',
        exercises: [exercise],
        briefIntroMd: 'Velkommen til {{plan.name}}.',
        commsMd: '{{plan.description}} — se innledningen.',
        beforeRoundMd: 'Plan: {{plan.name}}.',
      );

      final result = await renderer.render(
        plan: plan,
        audience: BriefAudience.participant,
        l10n: _l10n.brief,
      );

      expect(result, contains('Velkommen til Vinterøvelse Nordland.'));
      expect(result, contains('Samvirkeøvelse — se innledningen.'));
      expect(result, contains('Plan: Vinterøvelse Nordland.'));
      expect(result, isNot(contains('{{plan.name}}')));
      expect(result, isNot(contains('{{plan.description}}')));
    });

    test('plan.description resolves cross-references, like the markdown '
        'fields do', () async {
      // It was grouped with the *names* — a scalar string rather than a markdown
      // field — where it behaves like the markdown ones: it is the plan-scope field
      // that most invites the counts an author would otherwise type, which is what
      // {{plan.exerciseCount}} exists to replace. The skill's token table already
      // told authors to write the token here; the resolver was the inconsistent half.
      final plan = _emptyPlan().copyWith(
        exercises: [
          _designExercise(),
          _designExercise().copyWith(uuid: 'ex-4'),
        ],
        description:
            '{{plan.exerciseCount}} øvelser, {{plan.stationCount}} poster.',
      );

      final result = await renderer.render(
        plan: plan,
        audience: BriefAudience.participant,
        l10n: _l10n.brief,
      );

      expect(result, contains('2 øvelser, 2 poster.'));
      expect(result, isNot(contains('{{plan.exerciseCount}}')));
    });

    // The names ran the variable-only pass, so the brief resolved *less* in a name
    // than the app did: `resolveModelField` has always built the full
    // cross-reference context for a marker caption or search result and documented
    // itself as matching the brief. The brief was the wrong half.
    group('a name resolves cross-references, like the app already did', () {
      test('every scope resolves in its own name', () async {
        final plan = _emptyPlan().copyWith(
          name: 'Plan med {{plan.exerciseCount}} øvelser',
          exercises: [
            _designExercise().copyWith(
              name: 'Øvelse for {{exercise.numberOfTeams}} lag',
              stations: [
                _designStation().copyWith(
                  name: 'Post {{station.stationCode}} i {{exercise.name}}',
                ),
              ],
            ),
          ],
          rolePlays: [_rolePlay.copyWith(name: 'Markør på {{station.name}}')],
          staff: [_actor],
        );

        final result = await renderer.render(
          plan: plan,
          audience: BriefAudience.director,
          l10n: _l10n.brief,
        );

        expect(result, contains('# Plan med 1 øvelser'));
        expect(result, contains('## Øvelse for 4 lag'));
        // A station name reaching up to its exercise — and the exercise name it
        // reads is the raw one, since a refContext facet is the authored value and
        // the pass loop resolves what it injects.
        expect(result, contains('### 1.1 – Post 1.1 i Øvelse for 4 lag'));
        expect(result, contains('Markørspill (Markør på Post 1.1 i'));
        expect(result, isNot(contains('{{station.stationCode}}')));
        expect(result, isNot(contains('{{exercise.numberOfTeams}}')));
      });

      test('the heading and its contents link agree', () async {
        // The anchor is derived from the resolved name, so resolving more in a name
        // has to keep the in-doc TOC pointing at the heading it names.
        final plan = _emptyPlan().copyWith(
          exercises: [
            _designExercise().copyWith(
              stations: [
                _designStation().copyWith(name: 'Post {{station.stationCode}}'),
              ],
            ),
          ],
        );

        final result = await renderer.render(
          plan: plan,
          audience: BriefAudience.participant,
          l10n: _l10n.brief,
        );

        expect(result, contains('### 1.1 – Post 1.1'));
        final anchor = BriefRenderer.toAnchor('1.1 – Post 1.1');
        expect(result, contains('[1.1 – Post 1.1](#$anchor)'));
      });

      test('a coordinate in a name reads as plain text, not a code chip', () async {
        // A name lands in a heading and in a contents link label — plain surfaces.
        // The copy chip that is right in prose would render as inline code inside
        // the heading, and as literal backticks inside the link's [...].
        final plan = _emptyPlan().copyWith(
          exercises: [
            _designExercise().copyWith(
              stations: [
                _designStation().copyWith(
                  name: 'Post ved {{station.position}}',
                ),
              ],
            ),
          ],
        );

        final result = await renderer.render(
          plan: plan,
          audience: BriefAudience.participant,
          l10n: _l10n.brief,
        );

        final utm = BriefRenderer.formatUtm(const LatLng(58.99, 10.43));
        expect(result, contains('### 1.1 – Post ved $utm'));
        expect(
          result,
          isNot(contains('Post ved `$utm`')),
          reason: 'a heading is a plain surface — no chip markup',
        );
      });

      test('a name referencing itself stays literal instead of expanding', () async {
        // A refContext facet carries the *authored* value, so {{station.name}}
        // inside a station's own name substitutes a copy of that name — token and
        // all — and the pass loop expands it once per pass: without the guard this
        // heading read "Post Post Post Post Post Post Post Post Post Post Post
        // {{station.name}}". Bounded, but garbage that looks deliberate, where an
        // unresolved token at least looks unresolved.
        final plan = _emptyPlan().copyWith(
          exercises: [
            _designExercise().copyWith(
              name: 'Øvelse {{exercise.name}}',
              stations: [
                _designStation().copyWith(name: 'Post {{station.name}}'),
              ],
            ),
          ],
        );

        final result = await renderer.render(
          plan: plan,
          audience: BriefAudience.participant,
          l10n: _l10n.brief,
        );

        expect(result, contains('### 1.1 – Post {{station.name}}'));
        expect(result, contains('## Øvelse {{exercise.name}}'));
        expect(result, isNot(contains('Post Post')));
      });

      test('only the name\'s own scope is withheld, not the ones above it', () async {
        // The guard drops one facet, not the cascade: a station name still reads
        // its exercise, and an exercise name still reads its plan.
        final plan = _emptyPlan().copyWith(
          name: 'Vinterøvelse',
          exercises: [
            _designExercise().copyWith(
              name: '{{plan.name}} – dag 1',
              stations: [
                _designStation().copyWith(name: 'Post i {{exercise.name}}'),
              ],
            ),
          ],
        );

        final result = await renderer.render(
          plan: plan,
          audience: BriefAudience.participant,
          l10n: _l10n.brief,
        );

        expect(result, contains('## Vinterøvelse – dag 1'));
        // Two hops in one field: {{exercise.name}} injects the *authored* exercise
        // name, which still holds {{plan.name}}, and the next pass resolves that —
        // the nested-token behaviour the pass loop exists for.
        expect(result, contains('### 1.1 – Post i Vinterøvelse – dag 1'));
      });

      test('an out-of-scope reference takes the whole name literal', () async {
        // The all-or-nothing rule (ADR-0048), unchanged: a plan name has no
        // exercise in scope, so the resolvable half goes literal with the rest
        // rather than resolving on its own. Honest, and never a crash.
        final plan = _emptyPlan().copyWith(
          name: '{{plan.exerciseCount}} øvelser for {{exercise.name}}',
          exercises: [_designExercise()],
        );

        final result = await renderer.render(
          plan: plan,
          audience: BriefAudience.participant,
          l10n: _l10n.brief,
        );

        expect(
          result,
          contains('# {{plan.exerciseCount}} øvelser for {{exercise.name}}'),
        );
      });
    });

    test(
      'exercise-scope cross-references resolve inside exercise-scope markdown fields',
      () async {
        final exercise = Exercise(
          uuid: 'ex-1',
          name: 'Skogsøvelse',
          startTime: _start,
          endTime: _end,
          numberOfTeams: 3,
          numberOfRounds: 2,
          executionTime: 15,
          evaluationTime: 10,
          rotationTime: 5,
          stations: const [Station(index: 0, name: 'Post')],
          schedule: const [],
          methodMd:
              'Øvelse {{exercise.name}} har {{exercise.numberOfTeams}} lag '
              'og går {{exercise.numberOfRounds}} runder, {{exercise.timeLabel}}.',
        );
        final plan = _emptyPlan().copyWith(exercises: [exercise]);

        final result = await renderer.render(
          plan: plan,
          audience: BriefAudience.participant,
          l10n: _l10n.brief,
        );

        expect(
          result,
          contains(
            'Øvelse Skogsøvelse har 3 lag og går 2 runder, 08:30–10:30.',
          ),
        );
        expect(result, isNot(contains('{{exercise.')));
      },
    );

    test('station-scope cross-references resolve station, exercise AND plan data '
        '(cascade)', () async {
      final exercise = Exercise(
        uuid: 'ex-1',
        name: 'Skogsøvelse',
        startTime: _start,
        endTime: _end,
        numberOfTeams: 1,
        numberOfRounds: 1,
        executionTime: 10,
        evaluationTime: 5,
        rotationTime: 5,
        stations: const [
          Station(
            index: 0,
            name: 'Post',
            variantSuffix: 'Vinter',
            description: 'Skogsholt ved myra',
            situationMd:
                '{{plan.name}} / {{exercise.name}} — post {{station.stationCode}} '
                '({{station.variantSuffix}}): {{station.description}}.',
          ),
        ],
        schedule: const [],
      );
      final plan = _emptyPlan().copyWith(
        name: 'Vinterøvelse',
        exercises: [exercise],
      );

      final result = await renderer.render(
        plan: plan,
        audience: BriefAudience.participant,
        l10n: _l10n.brief,
      );

      expect(
        result,
        contains(
          'Vinterøvelse / Skogsøvelse — post 1.1 (Vinter): Skogsholt ved myra.',
        ),
      );
      expect(result, isNot(contains('{{station.')));
      expect(result, isNot(contains('{{exercise.')));
      expect(result, isNot(contains('{{plan.')));
    });

    test(
      'roleplay-scope cross-references resolve roleplay, station, exercise AND '
      'plan data (cascade)',
      () async {
        const rolePosition = LatLng(59.1, 10.5);
        final expectedUtm = BriefRenderer.formatUtm(rolePosition);
        final rolePlay = RolePlay(
          uuid: 'rp-1',
          index: 0,
          exerciseUuid: 'ex-1',
          name: 'Turgåer',
          stationIndex: 0,
          position: rolePosition,
          behavior:
              '{{roleplay.name}} venter ved {{roleplay.position}}, '
              'post {{station.name}}, øvelse {{exercise.name}}.',
        );
        final exercise = Exercise(
          uuid: 'ex-1',
          name: 'Skogsøvelse',
          startTime: _start,
          endTime: _end,
          numberOfTeams: 1,
          numberOfRounds: 1,
          executionTime: 10,
          evaluationTime: 5,
          rotationTime: 5,
          stations: const [Station(index: 0, name: 'Post')],
          schedule: const [],
        );
        final plan = _emptyPlan().copyWith(
          exercises: [exercise],
          rolePlays: [rolePlay],
        );

        final result = await renderer.render(
          plan: plan,
          audience: BriefAudience.director,
          l10n: _l10n.brief,
        );

        expect(
          result,
          contains(
            'Turgåer venter ved `$expectedUtm`, post Post, øvelse Skogsøvelse.',
          ),
        );
        expect(result, isNot(contains('{{roleplay.')));
      },
    );
  });

  group('BriefRenderer — null field omission', () {
    test('omits sections when markdown fields are null', () async {
      final exercise = Exercise(
        uuid: 'ex-1',
        name: 'Test',
        startTime: _start,
        endTime: _end,
        numberOfTeams: 1,
        numberOfRounds: 1,
        executionTime: 30,
        evaluationTime: 5,
        rotationTime: 5,
        stations: const [
          Station(
            index: 0,
            name: 'Post',
            situationMd: 'Situasjonstekst',
            // equipmentMd, missionMd, criticalQuestionsMd are all null
          ),
        ],
        schedule: const [],
      );
      final plan = _emptyPlan().copyWith(exercises: [exercise]);
      final result = await renderer.render(
        plan: plan,
        audience: BriefAudience.participant,
        l10n: _l10n.brief,
      );

      expect(result, contains('#### Situasjon'));
      expect(result, isNot(contains('#### Utstyrsbehov')));
      expect(result, isNot(contains('#### Oppdrag')));
      expect(result, isNot(contains('#### Kritiske spørsmål')));
    });
  });

  group('BriefRenderer — description lead (DESIGN-009)', () {
    Plan planWithDescription(String? description, {LatLng? position}) {
      final exercise = Exercise(
        uuid: 'ex-1',
        name: 'Test',
        startTime: _start,
        endTime: _end,
        numberOfTeams: 1,
        numberOfRounds: 1,
        executionTime: 30,
        evaluationTime: 5,
        rotationTime: 5,
        stations: [
          Station(
            index: 0,
            name: 'Post',
            position: position,
            description: description,
          ),
        ],
        schedule: const [],
      );
      return _emptyPlan().copyWith(exercises: [exercise]);
    }

    test(
      'renders as an unheaded lead paragraph before the plassering line (nb)',
      () async {
        final result = await BriefRenderer().render(
          plan: planWithDescription('Åpent jorde ved elva.'),
          audience: BriefAudience.participant,
          l10n: _l10n.brief,
        );
        final normalized = _normalizeLines(result);

        expect(normalized, contains('Åpent jorde ved elva.'));
        expect(
          normalized.indexOf('Åpent jorde ved elva.'),
          lessThan(normalized.indexOf('**Post 1.1 plassering:**')),
        );
        // No section heading of its own.
        expect(normalized, isNot(contains('#### Postbeskrivelse')));
      },
    );

    test(
      'renders as an unheaded lead paragraph before the location line (en)',
      () async {
        final result = await BriefRenderer().render(
          plan: planWithDescription('Open field by the river.'),
          audience: BriefAudience.participant,
          l10n: _l10nEn.brief,
        );
        final normalized = _normalizeLines(result);

        expect(normalized, contains('Open field by the river.'));
        expect(
          normalized.indexOf('Open field by the river.'),
          lessThan(normalized.indexOf('**Station 1.1 location:**')),
        );
      },
    );

    test('resolves a {{...}} token inside the description', () async {
      const position = LatLng(58.99, 10.43);
      final expectedUtm = BriefRenderer.formatUtm(position);
      final result = await BriefRenderer().render(
        plan: planWithDescription(
          'IPP er ved {{station.position}}.',
          position: position,
        ),
        audience: BriefAudience.participant,
        l10n: _l10n.brief,
      );
      expect(result, isNot(contains('{{station.position}}')));
      expect(result, contains('IPP er ved `$expectedUtm`.'));
    });

    test('an absent description renders no lead paragraph or stray blank '
        'line', () async {
      final result = await BriefRenderer().render(
        plan: planWithDescription(null),
        audience: BriefAudience.participant,
        l10n: _l10n.brief,
      );
      final normalized = _normalizeLines(result);
      final headingIndex = normalized.indexOf('### 1.1 – Post');
      final placementIndex = normalized.indexOf('**Post 1.1 plassering:**');
      expect(headingIndex, greaterThanOrEqualTo(0));
      expect(placementIndex, greaterThan(headingIndex));
      // Exactly one blank line between the heading and the plassering line —
      // no extra blank line left behind by the absent lead block.
      final between = normalized
          .substring(headingIndex, placementIndex)
          .split('\n')
          .where((l) => l.isNotEmpty)
          .toList();
      expect(between, hasLength(1)); // just the heading line itself
    });

    test('an empty-string description renders no lead paragraph', () async {
      final result = await BriefRenderer().render(
        plan: planWithDescription(''),
        audience: BriefAudience.participant,
        l10n: _l10n.brief,
      );
      expect(result, isNot(contains('#### Postbeskrivelse')));
    });
  });

  group('BriefRenderer — comms fallback', () {
    test('exercise.commsMd overrides plan.commsMd in station Samband', () async {
      // Use distinct tokens so we can check the station section independently
      // of the plan-level "Talegrupper" section (which always shows plan.commsMd).
      final exerciseWithComms = Exercise(
        uuid: 'ex-1',
        name: 'Test',
        startTime: _start,
        endTime: _end,
        numberOfTeams: 1,
        numberOfRounds: 1,
        executionTime: 30,
        evaluationTime: 5,
        rotationTime: 5,
        stations: const [Station(index: 0, name: 'Post')],
        schedule: const [],
        commsMd: 'EXERCISE_COMMS_TOKEN',
      );
      final planWithComms = _emptyPlan().copyWith(
        exercises: [exerciseWithComms],
        commsMd: 'PROGRAM_COMMS_TOKEN',
      );

      final result = await renderer.render(
        plan: planWithComms,
        audience: BriefAudience.participant,
        l10n: _l10n.brief,
      );

      // Exercise token must appear (in station Samband)
      expect(result, contains('EXERCISE_COMMS_TOKEN'));

      // The station Samband section shows the exercise comms, not the plan comms.
      // plan.commsMd does appear in the top-level "Talegrupper" section — that is
      // correct behaviour. We verify that directly below the station "#### Samband"
      // heading the exercise comms token appears, not the plan comms token.
      final stationSambandIndex = result.indexOf(
        '#### Samband\nEXERCISE_COMMS_TOKEN',
      );
      expect(
        stationSambandIndex,
        isNot(-1),
        reason: 'Station Samband must contain EXERCISE_COMMS_TOKEN',
      );
    });

    test('falls back to plan.commsMd when exercise has none', () async {
      final exerciseNoComms = Exercise(
        uuid: 'ex-1',
        name: 'Test',
        startTime: _start,
        endTime: _end,
        numberOfTeams: 1,
        numberOfRounds: 1,
        executionTime: 30,
        evaluationTime: 5,
        rotationTime: 5,
        stations: const [Station(index: 0, name: 'Post')],
        schedule: const [],
      );
      final planWithComms = _emptyPlan().copyWith(
        exercises: [exerciseNoComms],
        commsMd: 'PROG COMMS',
      );

      final result = await renderer.render(
        plan: planWithComms,
        audience: BriefAudience.participant,
        l10n: _l10n.brief,
      );
      expect(result, contains('PROG COMMS'));
    });
  });

  group('BriefRenderer — cascaded fields resolve in the rendering scope '
      '(ADR-0068)', () {
    // The reported case: station 7b runs on a different talegruppe from the
    // rest of its exercise, and its Samband block comes from the exercise's
    // `comms`. A `variableOverrides` on the station has to mean the same thing
    // in a field the station borrows as in one it owns.
    Plan planWithCascadedComms({
      required String commsMd,
      Map<String, String> exerciseOverrides = const {},
      Map<String, String> stationOverrides = const {},
      bool commsOnPlan = false,
    }) {
      final exercise = Exercise(
        uuid: 'ex-1',
        name: 'Øvelse 1',
        startTime: _start,
        endTime: _end,
        numberOfTeams: 2,
        numberOfRounds: 2,
        executionTime: 30,
        evaluationTime: 5,
        rotationTime: 5,
        stations: [
          const Station(index: 0, name: 'Hussøk'),
          Station(
            index: 1,
            name: 'Elvesøk',
            variableOverrides: stationOverrides,
          ),
        ],
        schedule: const [],
        variableOverrides: exerciseOverrides,
        commsMd: commsOnPlan ? null : commsMd,
      );
      return _emptyPlan().copyWith(
        exercises: [exercise],
        commsMd: commsOnPlan ? commsMd : null,
        variables: const [
          DrillVariable(name: 'talegruppe', value: 'RK-FELLES'),
        ],
      );
    }

    test(
      'a station override applies to the exercise comms it inherits',
      () async {
        final plan = planWithCascadedComms(
          commsMd: '**Talegruppe:** {{var.talegruppe}}',
          exerciseOverrides: const {'talegruppe': 'RK-ØV2'},
          stationOverrides: const {'talegruppe': 'RK-7B'},
        );

        final result = await renderer.render(
          plan: plan,
          audience: BriefAudience.participant,
          l10n: _l10n.brief,
        );

        // The overriding station's Samband shows its own value...
        expect(
          _stationSection(result, 'Elvesøk'),
          contains('**Talegruppe:** RK-7B'),
        );
        // ...and every other rendering of the same authored text is unchanged:
        // the exercise's own Comms block and the station that overrode nothing.
        expect(
          _stationSection(result, 'Hussøk'),
          contains('**Talegruppe:** RK-ØV2'),
        );
        expect(
          _exerciseHead(result, 'Øvelse 1'),
          contains('**Talegruppe:** RK-ØV2'),
        );
        expect(result, isNot(contains('RK-FELLES')));
      },
    );

    test('a station override applies to the plan comms it inherits', () async {
      final plan = planWithCascadedComms(
        commsMd: '**Talegruppe:** {{var.talegruppe}}',
        stationOverrides: const {'talegruppe': 'RK-7B'},
        commsOnPlan: true,
      );

      final result = await renderer.render(
        plan: plan,
        audience: BriefAudience.participant,
        l10n: _l10n.brief,
      );

      expect(
        _stationSection(result, 'Elvesøk'),
        contains('**Talegruppe:** RK-7B'),
      );
      expect(
        _stationSection(result, 'Hussøk'),
        contains('**Talegruppe:** RK-FELLES'),
      );
    });

    test(
      'an exercise override applies to the plan before_round it renders',
      () async {
        final exercise = Exercise(
          uuid: 'ex-1',
          name: 'Øvelse 1',
          startTime: _start,
          endTime: _end,
          numberOfTeams: 1,
          numberOfRounds: 1,
          executionTime: 30,
          evaluationTime: 5,
          rotationTime: 5,
          stations: const [Station(index: 0, name: 'Post')],
          schedule: const [],
          variableOverrides: const {'talegruppe': 'RK-ØV1'},
        );
        final other = exercise.copyWith(
          uuid: 'ex-2',
          name: 'Øvelse 2',
          variableOverrides: const {},
        );
        final plan = _emptyPlan().copyWith(
          exercises: [exercise, other],
          beforeRoundMd: 'Meld deg på {{var.talegruppe}} før hver post.',
          variables: const [
            DrillVariable(name: 'talegruppe', value: 'RK-FELLES'),
          ],
        );

        final result = await renderer.render(
          plan: plan,
          audience: BriefAudience.participant,
          l10n: _l10n.brief,
        );

        expect(
          _exerciseHead(result, 'Øvelse 1'),
          contains('Meld deg på RK-ØV1 før hver post.'),
        );
        expect(
          _exerciseHead(result, 'Øvelse 2'),
          contains('Meld deg på RK-FELLES før hver post.'),
        );
      },
    );

    test('plan before_round resolves {{exercise.*}} in the exercise that '
        'renders it', () async {
      final exercise = Exercise(
        uuid: 'ex-1',
        name: 'Skogsøvelse',
        startTime: _start,
        endTime: _end,
        numberOfTeams: 3,
        numberOfRounds: 1,
        executionTime: 30,
        evaluationTime: 5,
        rotationTime: 5,
        stations: const [Station(index: 0, name: 'Post')],
        schedule: const [],
      );
      final plan = _emptyPlan().copyWith(
        exercises: [exercise],
        beforeRoundMd: 'Still opp lagvis — {{exercise.numberOfTeams}} lag.',
      );

      final result = await renderer.render(
        plan: plan,
        audience: BriefAudience.participant,
        l10n: _l10n.brief,
      );

      expect(result, contains('Still opp lagvis — 3 lag.'));
      expect(result, isNot(contains('{{exercise.numberOfTeams}}')));
    });

    test('a cascaded comms resolves {{station.*}} in the station that renders '
        'it', () async {
      final plan = planWithCascadedComms(
        commsMd: 'Kall opp KO som «Post {{station.stationCode}}».',
      );

      final result = await renderer.render(
        plan: plan,
        audience: BriefAudience.participant,
        l10n: _l10n.brief,
      );

      expect(
        _stationSection(result, 'Hussøk'),
        contains('Kall opp KO som «Post 1.1».'),
      );
      expect(
        _stationSection(result, 'Elvesøk'),
        contains('Kall opp KO som «Post 1.2».'),
      );
      // The exercise's own Comms block has no station in scope, so the token
      // stays literal there — the resolver's documented all-or-nothing rule
      // (ADR-0048), unchanged by this ADR.
      expect(
        _exerciseHead(result, 'Øvelse 1'),
        contains('{{station.stationCode}}'),
      );
    });

    test(
      'no override on the borrowing station leaves the output identical',
      () async {
        // The ADR's bound on the cost: divergence needs the cascaded text to
        // reference {{var.x}}, the station to override that same x, and the
        // value to differ. Absent any one, resolution is byte-identical — which
        // is every station in every plan authored before this change.
        final withOverride = planWithCascadedComms(
          commsMd: '**Talegruppe:** {{var.talegruppe}}',
          exerciseOverrides: const {'talegruppe': 'RK-ØV2'},
          stationOverrides: const {'talegruppe': 'RK-ØV2'},
        );
        final withoutOverride = planWithCascadedComms(
          commsMd: '**Talegruppe:** {{var.talegruppe}}',
          exerciseOverrides: const {'talegruppe': 'RK-ØV2'},
        );

        final a = await renderer.render(
          plan: withOverride,
          audience: BriefAudience.participant,
          l10n: _l10n.brief,
        );
        final b = await renderer.render(
          plan: withoutOverride,
          audience: BriefAudience.participant,
          l10n: _l10n.brief,
        );

        expect(a, b);
      },
    );
  });

  group('BriefRenderer — template fallback', () {
    test('unknown templateId falls back to system default', () async {
      final exerciseWithTemplate = Exercise(
        uuid: 'ex-1',
        name: 'Test',
        startTime: _start,
        endTime: _end,
        numberOfTeams: 1,
        numberOfRounds: 1,
        executionTime: 30,
        evaluationTime: 5,
        rotationTime: 5,
        stations: const [Station(index: 0, name: 'Post')],
        schedule: const [],
        templateId: 'does-not-exist',
      );
      final exerciseNoTemplate = exerciseWithTemplate.copyWith(
        templateId: null,
      );

      final planA = _emptyPlan().copyWith(exercises: [exerciseWithTemplate]);
      final planB = _emptyPlan().copyWith(exercises: [exerciseNoTemplate]);

      final resultA = await renderer.render(
        plan: planA,
        exercise: exerciseWithTemplate,
        audience: BriefAudience.participant,
        l10n: _l10n.brief,
      );
      final resultB = await renderer.render(
        plan: planB,
        exercise: exerciseNoTemplate,
        audience: BriefAudience.participant,
        l10n: _l10n.brief,
      );

      // Same template used — structural output is equivalent after stripping uuid-derived anchors
      expect(
        _normalizeLines(resultA).contains('## Test'),
        _normalizeLines(resultB).contains('## Test'),
      );
    });
  });

  group('BriefRenderer — wideTocSidebar flag', () {
    test('in-doc TOC present when wideTocSidebar is false (default)', () async {
      final plan = _designPlan();
      final result = await renderer.render(
        plan: plan,
        audience: BriefAudience.participant,
        l10n: _l10n.brief,
        wideTocSidebar: false,
      );
      expect(result, contains('## Innholdsfortegnelse'));
      expect(result, contains('Øvelse 3'));
    });

    test('in-doc TOC absent when wideTocSidebar is true', () async {
      final plan = _designPlan();
      final result = await renderer.render(
        plan: plan,
        audience: BriefAudience.participant,
        l10n: _l10n.brief,
        wideTocSidebar: true,
      );
      expect(result, isNot(contains('## Innholdsfortegnelse')));
      // Exercise content still present
      expect(result, contains('Øvelse 3'));
    });
  });

  group('BriefRenderer — single-exercise mode', () {
    // Plan with all three plan-level intro fields populated so the
    // assertions below distinguish "hidden by isSingleExercise" from "hidden
    // because the field was null".
    Plan planWithIntro() => _designPlan().copyWith(
      briefIntroMd: 'INTRO_BODY',
      commsMd: 'PROGRAM_COMMS_TOKEN',
    );

    test(
      'plan intro (H1, description, TOC, briefIntroMd, commsMd, divider) is omitted',
      () async {
        final plan = planWithIntro();
        final exercise = plan.exercises.first;

        final result = await renderer.render(
          plan: plan,
          exercise: exercise,
          audience: BriefAudience.participant,
          l10n: _l10n.brief,
          wideTocSidebar: false,
        );

        // The plan-level H1 (`# {{plan.name}}`) is dropped. We assert
        // against the leading `# ` form so we do not accidentally match `## `
        // headings that share the plan name in a sub-section.
        expect(
          result,
          isNot(contains('# ${plan.name}\n')),
          reason: 'Plan H1 should be hidden in single-exercise mode',
        );
        expect(
          result,
          isNot(contains('## Innholdsfortegnelse')),
          reason: 'In-doc TOC should be hidden in single-exercise mode',
        );
        expect(
          result,
          isNot(contains('## Generelt om spill og øvingsledelse')),
          reason: 'briefIntroMd block should be hidden in single-exercise mode',
        );
        expect(
          result,
          isNot(contains('## Talegrupper')),
          reason:
              'Plan-level Talegrupper should be hidden in single-exercise '
              'mode (exercise-level Samband still renders inside the exercise)',
        );

        // The exercise heading itself must still be present.
        expect(
          result,
          contains('## ${exercise.name}'),
          reason:
              'Exercise heading should still render in single-exercise mode',
        );
      },
    );

    test('plan intro IS present when no exercise is passed', () async {
      final plan = planWithIntro();

      final result = await renderer.render(
        plan: plan,
        audience: BriefAudience.participant,
        l10n: _l10n.brief,
        wideTocSidebar: false,
      );

      expect(result, contains('# ${plan.name}'));
      expect(result, contains('## Innholdsfortegnelse'));
      expect(result, contains('## Generelt om spill og øvingsledelse'));
      expect(result, contains('## Talegrupper'));
    });
  });

  group('BriefRenderer helpers', () {
    test('exerciseTimeLabel returns clock-time span', () {
      final ex = Exercise(
        uuid: 'e',
        name: 'E',
        startTime: SimpleTimeOfDay(hour: 17, minute: 0),
        endTime: SimpleTimeOfDay(hour: 19, minute: 0),
        numberOfTeams: 1,
        numberOfRounds: 1,
        executionTime: 60,
        evaluationTime: 15,
        rotationTime: 5,
        stations: const [],
        schedule: const [],
      );
      expect(BriefRenderer.exerciseTimeLabel(ex), '17:00–19:00');
    });

    test('exerciseDurationLabel — single round, exact hours', () {
      // 1 × 120 min = "2 timer" (no per-round suffix for single round)
      final single = Exercise(
        uuid: 'e',
        name: 'E',
        startTime: _start,
        endTime: _end,
        numberOfTeams: 1,
        numberOfRounds: 1,
        executionTime: 100,
        evaluationTime: 15,
        rotationTime: 5,
        stations: const [],
        schedule: const [],
      );
      expect(
        BriefRenderer.exerciseDurationLabel(single, _l10n.brief),
        '2 timer',
      );
    });

    test('exerciseDurationLabel — multi-round, exact hours', () {
      // 2 × 60 min = "2 timer (60 min pr oppdrag)"
      final ex = Exercise(
        uuid: 'e',
        name: 'E',
        startTime: _start,
        endTime: _end,
        numberOfTeams: 2,
        numberOfRounds: 2,
        executionTime: 45,
        evaluationTime: 10,
        rotationTime: 5,
        stations: const [],
        schedule: const [],
      );
      expect(
        BriefRenderer.exerciseDurationLabel(ex, _l10n.brief),
        '2 timer (60 min pr oppdrag)',
      );
    });

    test('exerciseDurationLabel — multi-round, non-hour total', () {
      // 3 × 30 min = "90 min (30 min pr oppdrag)". endTime is 10:00 rather than the
      // shared _end, because it has to *agree* with those scalars: the label now
      // reads the total off startTime/endTime, which is the only field that can
      // express an exercise whose rounds differ in length (ADR-0062). This fixture
      // said 3 × 30 and also said two hours, and the old implementation ignored the
      // contradiction because it never looked at endTime at all.
      final ex = Exercise(
        uuid: 'e',
        name: 'E',
        startTime: _start,
        endTime: const SimpleTimeOfDay(hour: 10, minute: 0),
        numberOfTeams: 3,
        numberOfRounds: 3,
        executionTime: 15,
        evaluationTime: 10,
        rotationTime: 5,
        stations: const [],
        schedule: const [],
      );
      expect(
        BriefRenderer.exerciseDurationLabel(ex, _l10n.brief),
        '90 min (30 min pr oppdrag)',
      );
    });

    test('stationDurationLabel formats round duration with phase breakdown', () {
      // 15 + 10 + 5 = 30 min (15 | 10 | 5)
      final ex = Exercise(
        uuid: 'e',
        name: 'E',
        startTime: _start,
        endTime: _end,
        numberOfTeams: 4,
        numberOfRounds: 4,
        executionTime: 15,
        evaluationTime: 10,
        rotationTime: 5,
        stations: const [],
        schedule: const [],
      );
      expect(BriefRenderer.stationDurationLabel(ex), '30 min (15 | 10 | 5)');

      // Each phase the station owns wins, in the total and in the breakdown
      // (ADR-0062). This label prints under every post in a booklet, so reading the
      // exercise's value for a phase the station overrode is a number the reader
      // then plans around: 165 min, not 30, and 25 minutes of debrief they would
      // otherwise cut short.
      expect(
        BriefRenderer.stationDurationLabel(
          ex,
          executionTime: 100,
          evaluationTime: 25,
          rotationTime: 40,
        ),
        '165 min (100 | 25 | 40)',
      );
      // And one override leaves the other two inherited.
      expect(
        BriefRenderer.stationDurationLabel(ex, rotationTime: 40),
        '65 min (15 | 10 | 40)',
      );
    });

    test('formatUtm returns empty string for null', () {
      expect(BriefRenderer.formatUtm(null), '');
    });

    test('formatUtm formats LatLng(58.99, 10.43) as 32V easting/northing', () {
      // Norway 32V extension applies (lat 56-64, lon 3-12).
      final utm = BriefRenderer.formatUtm(const LatLng(58.99, 10.43));
      expect(utm, startsWith('32V '));
      expect(utm, contains('E '));
      expect(utm, contains('N'));
    });
  });

  group('BriefRenderer — station number formats', () {
    Exercise twoStationExercise() => Exercise(
      uuid: 'ex-fmt',
      name: 'Format test',
      startTime: _start,
      endTime: _end,
      numberOfTeams: 2,
      numberOfRounds: 2,
      executionTime: 30,
      evaluationTime: 5,
      rotationTime: 5,
      stations: const [
        Station(index: 0, name: 'Alpha'),
        Station(index: 1, name: 'Beta'),
      ],
      schedule: const [],
    );

    test('dotted format produces "1.1" and "1.2" headings', () async {
      final plan = _emptyPlan().copyWith(
        exercises: [twoStationExercise()],
        stationNumberFormat: StationNumberFormat.dotted,
      );
      final result = await BriefRenderer().render(
        plan: plan,
        audience: BriefAudience.participant,
        l10n: _l10n.brief,
      );
      expect(result, contains('### 1.1 – Alpha'));
      expect(result, contains('### 1.2 – Beta'));
      expect(result, contains('**Post 1.1 plassering:**'));
      expect(result, contains('**Post 1.2 plassering:**'));
    });

    test('dotted format TOC links use dotted labels', () async {
      final plan = _emptyPlan().copyWith(
        exercises: [twoStationExercise()],
        stationNumberFormat: StationNumberFormat.dotted,
      );
      final result = await BriefRenderer().render(
        plan: plan,
        audience: BriefAudience.participant,
        l10n: _l10n.brief,
      );
      expect(result, contains('[1.1 – Alpha]'));
      expect(result, contains('[1.2 – Beta]'));
    });

    test('alpha format produces "1a" and "1b" headings', () async {
      final plan = _emptyPlan().copyWith(
        exercises: [twoStationExercise()],
        stationNumberFormat: StationNumberFormat.alpha,
      );
      final result = await BriefRenderer().render(
        plan: plan,
        audience: BriefAudience.participant,
        l10n: _l10n.brief,
      );
      expect(result, contains('### 1a – Alpha'));
      expect(result, contains('### 1b – Beta'));
      expect(result, contains('**Post 1a plassering:**'));
      expect(result, contains('**Post 1b plassering:**'));
    });

    test('alpha format TOC links use alpha labels', () async {
      final plan = _emptyPlan().copyWith(
        exercises: [twoStationExercise()],
        stationNumberFormat: StationNumberFormat.alpha,
      );
      final result = await BriefRenderer().render(
        plan: plan,
        audience: BriefAudience.participant,
        l10n: _l10n.brief,
      );
      expect(result, contains('[1a – Alpha]'));
      expect(result, contains('[1b – Beta]'));
    });

    test(
      'dotted anchor is derived from stationCode (dot dropped by slug)',
      () async {
        final plan = _emptyPlan().copyWith(
          exercises: [twoStationExercise()],
          stationNumberFormat: StationNumberFormat.dotted,
        );
        final result = await BriefRenderer().render(
          plan: plan,
          audience: BriefAudience.participant,
          l10n: _l10n.brief,
          wideTocSidebar: false,
        );
        // The dot in "1.1" is stripped by _toAnchor, so the expected anchor is
        // "11-alpha". Both the TOC link and the heading use the same anchor,
        // so internal links remain consistent.
        expect(result, contains('[1.1 – Alpha](#11-alpha)'));
        expect(result, contains('### 1.1 – Alpha'));
      },
    );
  });

  group('BriefRenderer — missing template source', () {
    test('wraps a bundle load failure in BriefTemplateException', () async {
      final renderer = BriefRenderer(
        templates: const _ThrowingTemplateSource(),
      );

      await expectLater(
        renderer.render(
          plan: _emptyPlan(),
          audience: BriefAudience.participant,
          l10n: _l10n.brief,
        ),
        throwsA(
          isA<BriefTemplateException>()
              .having(
                (e) => e.templateId,
                'templateId',
                'ringdrill-standard-v1',
              )
              .having(
                (e) => e.assetPath,
                'assetPath',
                'assets/templates/ringdrill-standard-v1.nb.md.mustache',
              )
              .having((e) => e.cause, 'cause', isNotNull),
        ),
      );
    });

    test('locale picks the en asset path in the wrapped exception', () async {
      final renderer = BriefRenderer(
        templates: const _ThrowingTemplateSource(),
      );

      await expectLater(
        renderer.render(
          plan: _emptyPlan(),
          audience: BriefAudience.participant,
          l10n: _l10nEn.brief,
        ),
        throwsA(
          isA<BriefTemplateException>().having(
            (e) => e.assetPath,
            'assetPath',
            'assets/templates/ringdrill-standard-v1.en.md.mustache',
          ),
        ),
      );
    });
  });

  group('BriefRenderer — locale-aware template selection', () {
    test('en locale renders English chrome, no Norwegian headings', () async {
      final plan = _designPlan();
      final result = await BriefRenderer().render(
        plan: plan,
        audience: BriefAudience.director,
        l10n: _l10nEn.brief,
      );
      expect(result, contains('## Table of contents'));
      expect(result, contains('#### Time'));
      expect(result, contains('#### Duration'));
      expect(result, contains('#### Method'));
      expect(result, contains('#### Situation'));
      expect(result, contains('#### Mission'));
      expect(result, contains('**Station '));
      // No leftover Norwegian template chrome or hardcoded "timer".
      expect(result, isNot(contains('## Innholdsfortegnelse')));
      expect(result, isNot(contains('#### Metode')));
      expect(result, isNot(contains('plassering')));
      expect(result, isNot(contains('timer')));
    });

    test('nb locale still renders Norwegian chrome', () async {
      final result = await BriefRenderer().render(
        plan: _designPlan(),
        audience: BriefAudience.participant,
        l10n: _l10n.brief,
      );
      expect(result, contains('## Innholdsfortegnelse'));
      expect(result, contains('#### Metode'));
    });
  });

  group('TemplateRegistry — locale resolution', () {
    final registry = TemplateRegistry.instance;

    test('resolves the nb variant by default and for null/unknown locale', () {
      expect(registry.resolve(null).locale, 'nb');
      expect(registry.resolve('ringdrill-standard-v1').locale, 'nb');
      expect(registry.resolve('ringdrill-standard-v1', 'de').locale, 'nb');
    });

    test('resolves the en variant for en and region-qualified en', () {
      expect(registry.resolve('ringdrill-standard-v1', 'en').locale, 'en');
      expect(registry.resolve('ringdrill-standard-v1', 'en_US').locale, 'en');
      expect(registry.resolve('ringdrill-standard-v1', 'en-GB').locale, 'en');
    });

    test(
      'unknown templateId falls back to default family, honouring locale',
      () {
        expect(registry.resolve('does-not-exist', 'en').locale, 'en');
        expect(registry.resolve('does-not-exist', 'nb').locale, 'nb');
      },
    );
  });
}
