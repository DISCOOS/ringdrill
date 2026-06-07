import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations_en.dart';
import 'package:ringdrill/l10n/app_localizations_nb.dart';
import 'package:ringdrill/models/actor.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/numbering.dart';
import 'package:ringdrill/models/program.dart';
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

Program _emptyProgram() {
  final now = DateTime(2026);
  return Program(
    uuid: 'prog-1',
    name: 'Test Program',
    description: '',
    metadata: ProgramMetadata(created: now, updated: now, version: '1.0'),
    teams: const [],
    sessions: const [],
    exercises: const [],
    rolePlays: const [],
    actors: const [],
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
      '(AL) Anne Glemsk 39 år er meldt savnet fra Gamlehuset i {{station.position.utm}},\n'
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
  signalement: '160 cm, grått hår, blå anorakk',
  behavior:
      'Du spiller en dement dame i god fysisk form. Noen karakteristiske trekk:\n'
      '- Du svarer på navnet ditt, men er forvirret om hvor du er.\n'
      '- Du går videre hvis du ikke blir snakket til etter 30 sekunder.\n',
  stationIndex: 0,
  position: LatLng(58.99, 10.43),
  actorUuid: 'actor-12',
);

const _actor = Actor(
  uuid: 'actor-12',
  realName: 'Kari Hansen',
  phone: '99887766',
);

Program _designProgram() => _emptyProgram().copyWith(
  exercises: [_designExercise()],
  rolePlays: [_rolePlay],
  actors: [_actor],
);

final _l10n = AppLocalizationsNb();
final _l10nEn = AppLocalizationsEn();

/// An [AssetBundle] whose [load] always fails the way the real bundle does
/// when an asset is absent from the running build's manifest. Used to exercise
/// the renderer's [BriefTemplateException] wrapping.
class _ThrowingAssetBundle extends AssetBundle {
  @override
  Future<ByteData> load(String key) async {
    throw FlutterError('Unable to load asset: "$key".');
  }
}

/// Trims trailing whitespace from each line so whitespace-only differences
/// at line endings don't cause false failures.
String _normalizeLines(String s) =>
    s.split('\n').map((l) => l.trimRight()).join('\n');

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
      final program = _designProgram();
      final result = await renderer.render(
        program: program,
        audience: BriefAudience.director,
        l10n: _l10n,
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

      // Actor PII (director only)
      expect(normalized, contains('**Markør:** Kari Hansen (99887766)'));

      // Situation with resolved UTM cross-reference — {{station.position.utm}} is substituted
      expect(
        normalized,
        contains(
          '(AL) Anne Glemsk 39 år er meldt savnet fra Gamlehuset i $expectedUtm,',
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
      final program = _designProgram();
      final result = await renderer.render(
        program: program,
        audience: BriefAudience.participant,
        l10n: _l10n,
      );

      // Actor PII must be absent
      expect(result, isNot(contains('Kari Hansen')));
      expect(result, isNot(contains('99887766')));
      expect(result, isNot(contains('**Markør:**')));

      // Director notes must be absent
      expect(result, isNot(contains('Notater til instruktør/øvingsledelse')));
      expect(result, isNot(contains('Markør er utplassert.')));

      // Roleplay name (publishable) must still appear
      expect(result, contains('Anne Glemsk'));
    });
  });

  group('BriefRenderer — instructor audience', () {
    test('shows director notes but not actor PII', () async {
      final program = _designProgram();
      final result = await renderer.render(
        program: program,
        audience: BriefAudience.instructor,
        l10n: _l10n,
      );

      // Director notes must be present
      expect(result, contains('Notater til instruktør/øvingsledelse'));

      // Actor PII must be absent
      expect(result, isNot(contains('Kari Hansen')));
      expect(result, isNot(contains('99887766')));
    });
  });

  group('BriefRenderer — cross-reference resolution', () {
    test('resolves {{station.position.utm}} inside markdown fields', () async {
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
            situationMd: 'IPP er ved {{station.position.utm}}.',
          ),
        ],
        schedule: const [],
      );
      final program = _emptyProgram().copyWith(exercises: [exercise]);
      final result = await renderer.render(
        program: program,
        audience: BriefAudience.participant,
        l10n: _l10n,
      );

      expect(result, contains(expectedUtm));
      expect(result, isNot(contains('{{station.position.utm}}')));
    });
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
      final program = _emptyProgram().copyWith(exercises: [exercise]);
      final result = await renderer.render(
        program: program,
        audience: BriefAudience.participant,
        l10n: _l10n,
      );

      expect(result, contains('#### Situasjon'));
      expect(result, isNot(contains('#### Utstyrsbehov')));
      expect(result, isNot(contains('#### Oppdrag')));
      expect(result, isNot(contains('#### Kritiske spørsmål')));
    });
  });

  group('BriefRenderer — comms fallback', () {
    test('exercise.commsMd overrides program.commsMd in station Samband', () async {
      // Use distinct tokens so we can check the station section independently
      // of the program-level "Talegrupper" section (which always shows program.commsMd).
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
      final programWithComms = _emptyProgram().copyWith(
        exercises: [exerciseWithComms],
        commsMd: 'PROGRAM_COMMS_TOKEN',
      );

      final result = await renderer.render(
        program: programWithComms,
        audience: BriefAudience.participant,
        l10n: _l10n,
      );

      // Exercise token must appear (in station Samband)
      expect(result, contains('EXERCISE_COMMS_TOKEN'));

      // The station Samband section shows the exercise comms, not the program comms.
      // program.commsMd does appear in the top-level "Talegrupper" section — that is
      // correct behaviour. We verify that directly below the station "#### Samband"
      // heading the exercise comms token appears, not the program comms token.
      final stationSambandIndex = result.indexOf(
        '#### Samband\nEXERCISE_COMMS_TOKEN',
      );
      expect(
        stationSambandIndex,
        isNot(-1),
        reason: 'Station Samband must contain EXERCISE_COMMS_TOKEN',
      );
    });

    test('falls back to program.commsMd when exercise has none', () async {
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
      final programWithComms = _emptyProgram().copyWith(
        exercises: [exerciseNoComms],
        commsMd: 'PROG COMMS',
      );

      final result = await renderer.render(
        program: programWithComms,
        audience: BriefAudience.participant,
        l10n: _l10n,
      );
      expect(result, contains('PROG COMMS'));
    });
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

      final programA = _emptyProgram().copyWith(
        exercises: [exerciseWithTemplate],
      );
      final programB = _emptyProgram().copyWith(
        exercises: [exerciseNoTemplate],
      );

      final resultA = await renderer.render(
        program: programA,
        exercise: exerciseWithTemplate,
        audience: BriefAudience.participant,
        l10n: _l10n,
      );
      final resultB = await renderer.render(
        program: programB,
        exercise: exerciseNoTemplate,
        audience: BriefAudience.participant,
        l10n: _l10n,
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
      final program = _designProgram();
      final result = await renderer.render(
        program: program,
        audience: BriefAudience.participant,
        l10n: _l10n,
        wideTocSidebar: false,
      );
      expect(result, contains('## Innholdsfortegnelse'));
      expect(result, contains('Øvelse 3'));
    });

    test('in-doc TOC absent when wideTocSidebar is true', () async {
      final program = _designProgram();
      final result = await renderer.render(
        program: program,
        audience: BriefAudience.participant,
        l10n: _l10n,
        wideTocSidebar: true,
      );
      expect(result, isNot(contains('## Innholdsfortegnelse')));
      // Exercise content still present
      expect(result, contains('Øvelse 3'));
    });
  });

  group('BriefRenderer — single-exercise mode', () {
    // Program with all three program-level intro fields populated so the
    // assertions below distinguish "hidden by isSingleExercise" from "hidden
    // because the field was null".
    Program programWithIntro() => _designProgram().copyWith(
      briefIntroMd: 'INTRO_BODY',
      commsMd: 'PROGRAM_COMMS_TOKEN',
    );

    test(
      'program intro (H1, description, TOC, briefIntroMd, commsMd, divider) is omitted',
      () async {
        final program = programWithIntro();
        final exercise = program.exercises.first;

        final result = await renderer.render(
          program: program,
          exercise: exercise,
          audience: BriefAudience.participant,
          l10n: _l10n,
          wideTocSidebar: false,
        );

        // The program-level H1 (`# {{program.name}}`) is dropped. We assert
        // against the leading `# ` form so we do not accidentally match `## `
        // headings that share the program name in a sub-section.
        expect(
          result,
          isNot(contains('# ${program.name}\n')),
          reason: 'Program H1 should be hidden in single-exercise mode',
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
              'Program-level Talegrupper should be hidden in single-exercise '
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

    test('program intro IS present when no exercise is passed', () async {
      final program = programWithIntro();

      final result = await renderer.render(
        program: program,
        audience: BriefAudience.participant,
        l10n: _l10n,
        wideTocSidebar: false,
      );

      expect(result, contains('# ${program.name}'));
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
      expect(BriefRenderer.exerciseDurationLabel(single, _l10n), '2 timer');
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
        BriefRenderer.exerciseDurationLabel(ex, _l10n),
        '2 timer (60 min pr oppdrag)',
      );
    });

    test('exerciseDurationLabel — multi-round, non-hour total', () {
      // 3 × 30 min = "90 min (30 min pr oppdrag)"
      final ex = Exercise(
        uuid: 'e',
        name: 'E',
        startTime: _start,
        endTime: _end,
        numberOfTeams: 3,
        numberOfRounds: 3,
        executionTime: 15,
        evaluationTime: 10,
        rotationTime: 5,
        stations: const [],
        schedule: const [],
      );
      expect(
        BriefRenderer.exerciseDurationLabel(ex, _l10n),
        '90 min (30 min pr oppdrag)',
      );
    });

    test(
      'stationDurationLabel formats round duration with phase breakdown',
      () {
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
      },
    );

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
      final program = _emptyProgram().copyWith(
        exercises: [twoStationExercise()],
        stationNumberFormat: StationNumberFormat.dotted,
      );
      final result = await BriefRenderer().render(
        program: program,
        audience: BriefAudience.participant,
        l10n: _l10n,
      );
      expect(result, contains('### 1.1 – Alpha'));
      expect(result, contains('### 1.2 – Beta'));
      expect(result, contains('**Post 1.1 plassering:**'));
      expect(result, contains('**Post 1.2 plassering:**'));
    });

    test('dotted format TOC links use dotted labels', () async {
      final program = _emptyProgram().copyWith(
        exercises: [twoStationExercise()],
        stationNumberFormat: StationNumberFormat.dotted,
      );
      final result = await BriefRenderer().render(
        program: program,
        audience: BriefAudience.participant,
        l10n: _l10n,
      );
      expect(result, contains('[1.1 – Alpha]'));
      expect(result, contains('[1.2 – Beta]'));
    });

    test('alpha format produces "1a" and "1b" headings', () async {
      final program = _emptyProgram().copyWith(
        exercises: [twoStationExercise()],
        stationNumberFormat: StationNumberFormat.alpha,
      );
      final result = await BriefRenderer().render(
        program: program,
        audience: BriefAudience.participant,
        l10n: _l10n,
      );
      expect(result, contains('### 1a – Alpha'));
      expect(result, contains('### 1b – Beta'));
      expect(result, contains('**Post 1a plassering:**'));
      expect(result, contains('**Post 1b plassering:**'));
    });

    test('alpha format TOC links use alpha labels', () async {
      final program = _emptyProgram().copyWith(
        exercises: [twoStationExercise()],
        stationNumberFormat: StationNumberFormat.alpha,
      );
      final result = await BriefRenderer().render(
        program: program,
        audience: BriefAudience.participant,
        l10n: _l10n,
      );
      expect(result, contains('[1a – Alpha]'));
      expect(result, contains('[1b – Beta]'));
    });

    test(
      'dotted anchor is derived from stationCode (dot dropped by slug)',
      () async {
        final program = _emptyProgram().copyWith(
          exercises: [twoStationExercise()],
          stationNumberFormat: StationNumberFormat.dotted,
        );
        final result = await BriefRenderer().render(
          program: program,
          audience: BriefAudience.participant,
          l10n: _l10n,
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

  group('BriefRenderer — missing template asset', () {
    test('wraps a bundle load failure in BriefTemplateException', () async {
      final renderer = BriefRenderer(bundle: _ThrowingAssetBundle());

      await expectLater(
        renderer.render(
          program: _emptyProgram(),
          audience: BriefAudience.participant,
          l10n: _l10n,
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
      final renderer = BriefRenderer(bundle: _ThrowingAssetBundle());

      await expectLater(
        renderer.render(
          program: _emptyProgram(),
          audience: BriefAudience.participant,
          l10n: _l10nEn,
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
      final program = _designProgram();
      final result = await BriefRenderer().render(
        program: program,
        audience: BriefAudience.director,
        l10n: _l10nEn,
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
        program: _designProgram(),
        audience: BriefAudience.participant,
        l10n: _l10n,
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

    test('unknown templateId falls back to default family, honouring locale', () {
      expect(registry.resolve('does-not-exist', 'en').locale, 'en');
      expect(registry.resolve('does-not-exist', 'nb').locale, 'nb');
    });
  });
}
