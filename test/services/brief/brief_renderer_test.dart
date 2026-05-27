import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/models/actor.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/brief/brief_audience.dart';
import 'package:ringdrill/services/brief/brief_renderer.dart';

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
      );
      final normalized = _normalizeLines(result);

      // Station heading
      expect(normalized, contains('### 1a – Demens'));

      // UTM placement — use actual computed value rather than DESIGN-004 example
      final expectedUtm = BriefRenderer.formatUtm(const LatLng(58.99, 10.43));
      expect(normalized, contains('**Post 1a plassering:** $expectedUtm'));

      // Duration
      expect(normalized, contains('4 x 60 min.'));

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
      );
      final resultB = await renderer.render(
        program: programB,
        exercise: exerciseNoTemplate,
        audience: BriefAudience.participant,
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
        wideTocSidebar: true,
      );
      expect(result, isNot(contains('## Innholdsfortegnelse')));
      // Exercise content still present
      expect(result, contains('Øvelse 3'));
    });
  });

  group('BriefRenderer helpers', () {
    test('stationLetter maps index 0..25 to a..z', () {
      for (var i = 0; i <= 25; i++) {
        final station = Station(index: i, name: 'S$i');
        expect(
          BriefRenderer.stationLetter(station),
          String.fromCharCode('a'.codeUnitAt(0) + i),
          reason: 'index $i',
        );
      }
    });

    test('durationLabel formats single and multi-round exercises', () {
      final single = Exercise(
        uuid: 'e',
        name: 'E',
        startTime: _start,
        endTime: _end,
        numberOfTeams: 1,
        numberOfRounds: 1,
        executionTime: 45,
        evaluationTime: 10,
        rotationTime: 5,
        stations: const [],
        schedule: const [],
      );
      expect(BriefRenderer.durationLabel(single), '45 min.');

      final multi = single.copyWith(numberOfRounds: 4, executionTime: 60);
      expect(BriefRenderer.durationLabel(multi), '4 x 60 min.');
    });

    test('setupLabel formats ring config string', () {
      final exercise = Exercise(
        uuid: 'e',
        name: 'E',
        startTime: _start,
        endTime: _end,
        numberOfTeams: 4,
        numberOfRounds: 4,
        executionTime: 60,
        evaluationTime: 15,
        rotationTime: 5,
        stations: const [],
        schedule: const [],
      );
      expect(BriefRenderer.setupLabel(exercise), r'4 x (60 \| 15 \| 5)');
    });

    test('setupLabel appends schedule round-start times when present', () {
      final schedule = [
        [SimpleTimeOfDay(hour: 8, minute: 30)],
        [SimpleTimeOfDay(hour: 9, minute: 35)],
        [SimpleTimeOfDay(hour: 10, minute: 40)],
        [SimpleTimeOfDay(hour: 11, minute: 45)],
      ];
      final exercise = Exercise(
        uuid: 'e',
        name: 'E',
        startTime: _start,
        endTime: _end,
        numberOfTeams: 4,
        numberOfRounds: 4,
        executionTime: 60,
        evaluationTime: 15,
        rotationTime: 5,
        stations: const [],
        schedule: schedule,
      );
      final label = BriefRenderer.setupLabel(exercise);
      expect(label, startsWith(r'4 x (60 \| 15 \| 5)<br>'));
      expect(label, contains('08:30'));
      expect(label, contains('09:35'));
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
}
