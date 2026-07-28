import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations_nb.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/brief/brief_audience.dart';
import 'package:ringdrill/services/brief/brief_renderer.dart';

/// DESIGN-008 Stage 2 — `{{var.<name>}}` resolution across scopes. See
/// brief_renderer_test.dart for the DESIGN-004 no-variable fixture: that
/// suite renders the same fixture untouched and still passes after this
/// stage, which is the "no-variable plans are unchanged" regression check —
/// no golden file exists for this renderer, so this is a manual/full-suite
/// diff rather than a dedicated byte-for-byte golden test.

final _l10n = AppLocalizationsNb();
final _start = SimpleTimeOfDay(hour: 8, minute: 0);
final _end = SimpleTimeOfDay(hour: 9, minute: 0);

Plan _emptyPlan() {
  final now = DateTime(2026);
  return Plan(
    uuid: 'prog-vars',
    name: 'Variables Plan',
    description: '',
    metadata: PlanMetadata(created: now, updated: now, version: '1.0'),
    teams: const [],
    sessions: const [],
    exercises: const [],
    rolePlays: const [],
    actors: const [],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BriefRenderer renderer;
  setUp(() {
    renderer = BriefRenderer();
  });

  group('BriefRenderer — plan variables', () {
    test(
      'cascades station override, exercise override and plan default',
      () async {
        final stationOverride = Station(
          index: 0,
          name: 'Post A',
          situationMd: 'PostA kanal {{var.frekvens}}',
          variableOverrides: const {'frekvens': 'Kanal 9'},
        );
        final stationInherited = Station(
          index: 1,
          name: 'Post B',
          situationMd: 'PostB kanal {{var.frekvens}}',
        );
        final exercise = Exercise(
          uuid: 'ex-1',
          name: 'Exercise',
          startTime: _start,
          endTime: _end,
          numberOfTeams: 1,
          numberOfRounds: 1,
          executionTime: 10,
          evaluationTime: 5,
          rotationTime: 5,
          stations: [stationOverride, stationInherited],
          schedule: const [],
          methodMd: 'Metode kanal {{var.frekvens}}',
          variableOverrides: const {'frekvens': 'Kanal 8'},
        );
        final plan = _emptyPlan().copyWith(
          exercises: [exercise],
          variables: const [DrillVariable(name: 'frekvens', value: 'Kanal 6')],
          briefIntroMd: 'Plan kanal {{var.frekvens}}',
        );

        final result = await renderer.render(
          plan: plan,
          audience: BriefAudience.participant,
          l10n: _l10n,
        );

        expect(result, contains('Plan kanal Kanal 6'));
        expect(result, contains('Metode kanal Kanal 8'));
        expect(result, contains('PostA kanal Kanal 9'));
        expect(
          result,
          contains('PostB kanal Kanal 8'),
          reason: 'a station with no override inherits the exercise value',
        );
      },
    );

    test('the cascade resolves identically for all three audiences '
        '(DESIGN-008 follow-up 10 — audience gates section visibility, '
        'never variable substitution)', () async {
      final stationOverride = Station(
        index: 0,
        name: 'Post A',
        situationMd: 'PostA kanal {{var.frekvens}}',
        variableOverrides: const {'frekvens': 'Kanal 9'},
      );
      final exercise = Exercise(
        uuid: 'ex-1',
        name: 'Exercise',
        startTime: _start,
        endTime: _end,
        numberOfTeams: 1,
        numberOfRounds: 1,
        executionTime: 10,
        evaluationTime: 5,
        rotationTime: 5,
        stations: [stationOverride],
        schedule: const [],
        methodMd: 'Metode kanal {{var.frekvens}}',
        variableOverrides: const {'frekvens': 'Kanal 8'},
      );
      final plan = _emptyPlan().copyWith(
        exercises: [exercise],
        variables: const [DrillVariable(name: 'frekvens', value: 'Kanal 6')],
        briefIntroMd: 'Plan kanal {{var.frekvens}}',
      );

      for (final audience in BriefAudience.values) {
        final result = await renderer.render(
          plan: plan,
          audience: audience,
          l10n: _l10n,
        );

        expect(
          result,
          contains('Plan kanal Kanal 6'),
          reason: 'plan default, audience: $audience',
        );
        expect(
          result,
          contains('Metode kanal Kanal 8'),
          reason: 'exercise override, audience: $audience',
        );
        expect(
          result,
          contains('PostA kanal Kanal 9'),
          reason: 'station override, audience: $audience',
        );
      }
    });

    test('renders a visible placeholder for an undeclared variable', () async {
      final exercise = Exercise(
        uuid: 'ex-1',
        name: 'Exercise',
        startTime: _start,
        endTime: _end,
        numberOfTeams: 1,
        numberOfRounds: 1,
        executionTime: 10,
        evaluationTime: 5,
        rotationTime: 5,
        stations: const [Station(index: 0, name: 'Post')],
        schedule: const [],
        methodMd: 'Bruk {{var.mangler}}',
      );
      final plan = _emptyPlan().copyWith(exercises: [exercise]);

      final result = await renderer.render(
        plan: plan,
        audience: BriefAudience.participant,
        l10n: _l10n,
      );

      expect(result, contains(_l10n.briefUnknownVariable('mangler')));
      expect(result, isNot(contains('{{var.mangler}}')));
    });

    test(
      'a declared but empty variable renders as empty, not a placeholder',
      () async {
        final exercise = Exercise(
          uuid: 'ex-1',
          name: 'Exercise',
          startTime: _start,
          endTime: _end,
          numberOfTeams: 1,
          numberOfRounds: 1,
          executionTime: 10,
          evaluationTime: 5,
          rotationTime: 5,
          stations: const [Station(index: 0, name: 'Post')],
          schedule: const [],
          methodMd: 'Verdi:[{{var.tom}}] slutt',
        );
        final plan = _emptyPlan().copyWith(
          exercises: [exercise],
          variables: const [DrillVariable(name: 'tom')],
        );

        final result = await renderer.render(
          plan: plan,
          audience: BriefAudience.participant,
          l10n: _l10n,
        );

        expect(result, contains('Verdi:[] slutt'));
        expect(result, isNot(contains(_l10n.briefUnknownVariable('tom'))));
      },
    );

    test(
      'an override keyed on an undeclared variable name is ignored',
      () async {
        final exercise = Exercise(
          uuid: 'ex-1',
          name: 'Exercise',
          startTime: _start,
          endTime: _end,
          numberOfTeams: 1,
          numberOfRounds: 1,
          executionTime: 10,
          evaluationTime: 5,
          rotationTime: 5,
          stations: const [Station(index: 0, name: 'Post')],
          schedule: const [],
          methodMd: 'Kanal {{var.frekvens}}',
          variableOverrides: const {'ukjent': 'Skal ikke vises'},
        );
        final plan = _emptyPlan().copyWith(
          exercises: [exercise],
          variables: const [DrillVariable(name: 'frekvens', value: 'Kanal 6')],
        );

        final result = await renderer.render(
          plan: plan,
          audience: BriefAudience.participant,
          l10n: _l10n,
        );

        expect(result, contains('Kanal Kanal 6'));
        expect(result, isNot(contains('Skal ikke vises')));
      },
    );

    test(
      'a field with both a variable and a cross-reference resolves both',
      () async {
        const position = LatLng(58.99, 10.43);
        final expectedUtm = BriefRenderer.formatUtm(position);
        final exercise = Exercise(
          uuid: 'ex-1',
          name: 'Exercise',
          startTime: _start,
          endTime: _end,
          numberOfTeams: 1,
          numberOfRounds: 1,
          executionTime: 10,
          evaluationTime: 5,
          rotationTime: 5,
          stations: [
            Station(
              index: 0,
              name: 'Post',
              position: position,
              situationMd: 'Kanal {{var.frekvens}} ved {{station.position}}',
            ),
          ],
          schedule: const [],
        );
        final plan = _emptyPlan().copyWith(
          exercises: [exercise],
          variables: const [DrillVariable(name: 'frekvens', value: 'Kanal 6')],
        );

        final result = await renderer.render(
          plan: plan,
          audience: BriefAudience.participant,
          l10n: _l10n,
        );

        expect(result, contains('Kanal Kanal 6 ved `$expectedUtm`'));
      },
    );

    test(
      'resolves a variable in plan, exercise, station and roleplay fields',
      () async {
        final station = Station(
          index: 0,
          name: 'Post',
          situationMd: 'Stasjon {{var.frekvens}}',
        );
        final rolePlay = RolePlay(
          uuid: 'rp-1',
          index: 0,
          exerciseUuid: 'ex-1',
          name: 'Rollespiller',
          stationIndex: 0,
          behavior: 'Sier {{var.frekvens}}',
        );
        final exercise = Exercise(
          uuid: 'ex-1',
          name: 'Exercise',
          startTime: _start,
          endTime: _end,
          numberOfTeams: 1,
          numberOfRounds: 1,
          executionTime: 10,
          evaluationTime: 5,
          rotationTime: 5,
          stations: [station],
          schedule: const [],
          methodMd: 'Metode {{var.frekvens}}',
        );
        final plan = _emptyPlan().copyWith(
          exercises: [exercise],
          rolePlays: [rolePlay],
          variables: const [DrillVariable(name: 'frekvens', value: 'Kanal 6')],
          briefIntroMd: 'Intro {{var.frekvens}}',
        );

        final result = await renderer.render(
          plan: plan,
          audience: BriefAudience.director,
          l10n: _l10n,
        );

        expect(result, contains('Intro Kanal 6'));
        expect(result, contains('Metode Kanal 6'));
        expect(result, contains('Stasjon Kanal 6'));
        expect(result, contains('Sier Kanal 6'));
      },
    );
  });

  /// DESIGN-008 follow-up 05 — `{{var.<name>}}` resolution extends to entity
  /// names and descriptions (reading path only), on top of Stage 2's
  /// markdown-field resolution above.
  group('BriefRenderer — plan variables in names and descriptions', () {
    test('a variable in plan.name resolves in the H1', () async {
      final plan = _emptyPlan().copyWith(
        name: 'Plan {{var.frekvens}}',
        variables: const [DrillVariable(name: 'frekvens', value: 'Kanal 6')],
      );

      final result = await renderer.render(
        plan: plan,
        audience: BriefAudience.participant,
        l10n: _l10n,
      );

      expect(result, contains('# Plan Kanal 6'));
      expect(result, isNot(contains('{{var.frekvens}}')));
    });

    test('a variable in plan.description resolves in the subtitle', () async {
      final plan = _emptyPlan().copyWith(
        description: 'Beskrivelse {{var.frekvens}}',
        variables: const [DrillVariable(name: 'frekvens', value: 'Kanal 6')],
      );

      final result = await renderer.render(
        plan: plan,
        audience: BriefAudience.participant,
        l10n: _l10n,
      );

      expect(result, contains('_Beskrivelse Kanal 6_'));
    });

    test(
      'a variable in exercise.name resolves in the heading, and the TOC anchor '
      'follows the resolved name',
      () async {
        final exercise = Exercise(
          uuid: 'ex-1',
          name: 'Øvelse {{var.frekvens}}',
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
          variables: const [DrillVariable(name: 'frekvens', value: 'Kanal 6')],
        );

        final result = await renderer.render(
          plan: plan,
          audience: BriefAudience.participant,
          l10n: _l10n,
        );

        expect(result, contains('## Øvelse Kanal 6'));
        final anchor = BriefRenderer.toAnchor('Øvelse Kanal 6');
        expect(result, contains('[Øvelse Kanal 6](#$anchor)'));
      },
    );

    test(
      'a variable in station.name and roleplay.name resolves at station '
      'scope, with an exercise/station override shadowing the plan default',
      () async {
        final rolePlay = RolePlay(
          uuid: 'rp-1',
          index: 0,
          exerciseUuid: 'ex-1',
          name: 'Rollespiller {{var.frekvens}}',
          stationIndex: 0,
        );
        final station = Station(
          index: 0,
          name: 'Post {{var.frekvens}}',
          variableOverrides: const {'frekvens': 'Kanal 9'},
        );
        final exercise = Exercise(
          uuid: 'ex-1',
          name: 'Exercise',
          startTime: _start,
          endTime: _end,
          numberOfTeams: 1,
          numberOfRounds: 1,
          executionTime: 10,
          evaluationTime: 5,
          rotationTime: 5,
          stations: [station],
          schedule: const [],
          variableOverrides: const {'frekvens': 'Kanal 8'},
        );
        final plan = _emptyPlan().copyWith(
          exercises: [exercise],
          rolePlays: [rolePlay],
          variables: const [DrillVariable(name: 'frekvens', value: 'Kanal 6')],
        );

        final result = await renderer.render(
          plan: plan,
          audience: BriefAudience.director,
          l10n: _l10n,
        );

        expect(
          result,
          contains('Post Kanal 9'),
          reason:
              "the station's own override shadows the exercise's and "
              "the plan's default",
        );
        expect(result, contains('Markørspill (Rollespiller Kanal 9)'));
      },
    );

    test(
      'an undeclared variable in a name renders the unknown-variable placeholder',
      () async {
        final exercise = Exercise(
          uuid: 'ex-1',
          name: 'Øvelse {{var.mangler}}',
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
        final plan = _emptyPlan().copyWith(exercises: [exercise]);

        final result = await renderer.render(
          plan: plan,
          audience: BriefAudience.participant,
          l10n: _l10n,
        );

        expect(result, contains(_l10n.briefUnknownVariable('mangler')));
        expect(result, isNot(contains('{{var.mangler}}')));
      },
    );

    test(
      'a declared but empty variable in a name renders empty, not a placeholder',
      () async {
        final exercise = Exercise(
          uuid: 'ex-1',
          name: 'Øvelse[{{var.tom}}]',
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
          variables: const [DrillVariable(name: 'tom')],
        );

        final result = await renderer.render(
          plan: plan,
          audience: BriefAudience.participant,
          l10n: _l10n,
        );

        expect(result, contains('## Øvelse[]'));
        expect(result, isNot(contains(_l10n.briefUnknownVariable('tom'))));
      },
    );

    test(
      'a plan with no variables renders names and descriptions unchanged',
      () async {
        final station = Station(
          index: 0,
          name: 'Post A',
          position: const LatLng(58.99, 10.43),
        );
        final exercise = Exercise(
          uuid: 'ex-1',
          name: 'Øvelse 1',
          startTime: _start,
          endTime: _end,
          numberOfTeams: 1,
          numberOfRounds: 1,
          executionTime: 10,
          evaluationTime: 5,
          rotationTime: 5,
          stations: [station],
          schedule: const [],
        );
        final rolePlay = RolePlay(
          uuid: 'rp-1',
          index: 0,
          exerciseUuid: 'ex-1',
          name: 'Anne Glemsk',
          stationIndex: 0,
        );
        final plan = _emptyPlan().copyWith(
          name: 'Test Plan',
          description: 'En beskrivelse',
          exercises: [exercise],
          rolePlays: [rolePlay],
        );

        final result = await renderer.render(
          plan: plan,
          audience: BriefAudience.director,
          l10n: _l10n,
        );

        expect(result, contains('# Test Plan'));
        expect(result, contains('_En beskrivelse_'));
        expect(result, contains('## Øvelse 1'));
        expect(result, contains('Post A'));
        expect(result, contains('Markørspill (Anne Glemsk)'));
        expect(
          result,
          contains('[Øvelse 1](#${BriefRenderer.toAnchor('Øvelse 1')})'),
        );
      },
    );
  });

  /// Nested-token resolution: a token can arrive inside a value injected by
  /// another token. `_resolveField` iterates its pipeline to a fixpoint so
  /// these deeper layers resolve, instead of stopping at the innermost layer
  /// already present in the raw text.
  group('BriefRenderer — nested token resolution', () {
    test('a variable inside plan.name resolves when the name is reached '
        'through {{plan.name}} in a markdown field', () async {
      final plan = _emptyPlan().copyWith(
        name: 'LSOR Eidene {{var.year}}',
        variables: const [DrillVariable(name: 'year', value: '2026')],
        briefIntroMd: 'Velkommen til {{plan.name}}!',
      );

      final result = await renderer.render(
        plan: plan,
        audience: BriefAudience.participant,
        l10n: _l10n,
      );

      expect(result, contains('# LSOR Eidene 2026'));
      expect(result, contains('Velkommen til LSOR Eidene 2026!'));
      expect(result, isNot(contains('{{var.year}}')));
    });

    test('a three-level chain field -> {{plan.description}} -> {{plan.name}} '
        '-> {{var.year}} resolves fully', () async {
      final plan = _emptyPlan().copyWith(
        name: 'LSOR Eidene {{var.year}}',
        description: 'Se planen {{plan.name}}',
        variables: const [DrillVariable(name: 'year', value: '2026')],
        commsMd: 'Detaljer: {{plan.description}}.',
      );

      final result = await renderer.render(
        plan: plan,
        audience: BriefAudience.participant,
        l10n: _l10n,
      );

      expect(result, contains('Detaljer: Se planen LSOR Eidene 2026.'));
      expect(result, isNot(contains('{{var.year}}')));
    });

    test('a circular cross-reference terminates and leaves a literal token '
        'instead of hanging', () async {
      final plan = _emptyPlan().copyWith(
        name: '{{plan.description}}',
        description: '{{plan.name}}',
        commsMd: 'Intro: {{plan.name}}',
      );

      final result = await renderer.render(
        plan: plan,
        audience: BriefAudience.participant,
        l10n: _l10n,
      );

      // Reaching here at all proves the fixpoint loop terminated; the cap's
      // fail-safe leaves the unresolvable cycle as a visible literal token.
      expect(result, contains('{{plan.'));
    });
  });

  group('BriefRenderer — typed variables (DESIGN-008 follow-up 11)', () {
    setUpAll(() async {
      // Localized date rendering needs the nb date symbols; the app gets
      // them from flutter_localizations, a bare test loads them itself.
      await initializeDateFormatting('nb');
    });

    Plan typedPlan() => _emptyPlan().copyWith(
      variables: const [
        DrillVariable(name: 'tid', type: VariableType.time, value: '12:00'),
        DrillVariable(
          name: 'dato',
          type: VariableType.date,
          value: '2026-05-17',
        ),
        DrillVariable(
          name: 'varighet',
          type: VariableType.duration,
          value: '90',
        ),
        DrillVariable(name: 'pi', type: VariableType.number, value: '3.14'),
        DrillVariable(
          name: 'oppmote',
          type: VariableType.location,
          location: VariableLocation(
            place: 'Meiselen 14',
            position: LatLng(59.7445, 10.2045),
          ),
        ),
        // Back-compat: an untyped (string) variable renders exactly its
        // value, as before typed variables existed.
        DrillVariable(name: 'frekvens', value: 'Kanal 6'),
      ],
      briefIntroMd:
          'Oppmøte kl {{var.tid}} den {{var.dato}}, varer {{var.varighet}}. '
          'Pi er {{var.pi}}. Kanal {{var.frekvens}}. '
          'Sted: {{var.oppmote}} — UTM {{var.oppmote.position}}, '
          'adresse {{var.oppmote.place}}.',
    );

    test('formats each type canonically for display in the brief', () async {
      final result = await renderer.render(
        plan: typedPlan(),
        audience: BriefAudience.participant,
        l10n: _l10n,
      );

      expect(result, contains('kl 12:00'));
      expect(result, contains('den 17. mai 2026'));
      expect(result, contains('varer 1 t 30 min'));
      expect(result, contains('Pi er 3,14'));
      expect(result, contains('Kanal Kanal 6'));
    });

    test(
      'resolves location facets, with the brief\'s inline-code UTM styling',
      () async {
        final result = await renderer.render(
          plan: typedPlan(),
          audience: BriefAudience.participant,
          l10n: _l10n,
        );

        // Bare token: place + position, position as an inline-code chip.
        expect(
          result,
          contains(RegExp(r'Sted: `Meiselen 14` `\(32V [^`]+\)`')),
        );
        expect(result, contains(RegExp(r'UTM `32V [^`]+`')));
        expect(result, contains('adresse `Meiselen 14`'));
      },
    );

    test(
      'a station-scope override on a typed variable resolves per type',
      () async {
        final station = Station(
          index: 0,
          name: 'Post A',
          situationMd: 'Post-tid {{var.tid}}',
          variableOverrides: const {'tid': '14:30'},
        );
        final exercise = Exercise(
          uuid: 'ex-1',
          name: 'Exercise',
          startTime: _start,
          endTime: _end,
          numberOfTeams: 1,
          numberOfRounds: 1,
          executionTime: 10,
          evaluationTime: 5,
          rotationTime: 5,
          stations: [station],
          schedule: const [],
        );
        final plan = typedPlan().copyWith(exercises: [exercise]);

        final result = await renderer.render(
          plan: plan,
          audience: BriefAudience.participant,
          l10n: _l10n,
        );

        expect(result, contains('Post-tid 14:30'));
      },
    );
  });
}
