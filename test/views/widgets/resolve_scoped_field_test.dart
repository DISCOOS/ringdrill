import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/l10n/app_localizations_nb.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/person.dart';
import 'package:ringdrill/services/brief/field_resolver.dart' show formatUtm;
import 'package:ringdrill/views/widgets/exercise_scope.dart';
import 'package:ringdrill/views/widgets/plan_scope.dart';
import 'package:ringdrill/views/widgets/resolve_scoped_field.dart';
import 'package:ringdrill/views/widgets/station_scope.dart';

/// DESIGN-010 stage 2 — context assembly: resolveScopedField reads
/// PlanScope/ExerciseScope/StationScope and hands the field resolver
/// (ADR-0048) the same shape BriefRenderer builds server-side, so a field
/// resolves in preview the same way it would in the generated brief.
final _l10n = AppLocalizationsNb();

const _lkp = Location(
  slug: 'lkp',
  place: 'Fjellheisen',
  position: LatLng(58.99, 10.43),
);
const _kari = Person(slug: 'kari', name: 'Kari');
final _stationPosition = const LatLng(59.91, 10.75);

Exercise _exercise() => Exercise(
  uuid: 'ex-1',
  name: 'Exercise 1',
  startTime: SimpleTimeOfDay(hour: 8, minute: 0),
  endTime: SimpleTimeOfDay(hour: 9, minute: 0),
  numberOfTeams: 2,
  numberOfRounds: 2,
  executionTime: 10,
  evaluationTime: 5,
  rotationTime: 5,
  stations: const [],
  schedule: const [],
);

Future<BuildContext> _pumpScoped(WidgetTester tester) async {
  late BuildContext captured;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('nb'),
      home: PlanScope(
        variables: const [DrillVariable(name: 'year', value: '2026')],
        // Contains a nested {{var.year}} — only resolves through the
        // fixpoint loop's second pass, exactly like the brief.
        programName: 'Program {{var.year}}',
        child: ExerciseScope(
          exercise: _exercise(),
          variableOverrides: const {},
          child: StationScope(
            locations: const [_lkp],
            persons: const [_kari],
            name: 'Station A',
            positionUtm: formatUtm(_stationPosition),
            child: Builder(
              builder: (context) {
                captured = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    ),
  );
  return captured;
}

void main() {
  testWidgets(
    'resolves {{var.*}}, {{program.*}}, {{exercise.*}}, {{station.*}} and '
    '{{station.loc/person.*}} the same way the brief would, and leaves an '
    'undeclared variable as the brief\'s unknown-variable placeholder',
    (tester) async {
      final context = await _pumpScoped(tester);

      const content =
          'P={{program.name}} E={{exercise.name}} S={{station.name}} '
          'UTM={{station.position.utm}} LOC={{station.loc.lkp.place}} '
          'PERSON={{station.person.kari.name}} VAR={{var.year}} '
          'UNK={{var.unknown}}';

      final resolved = resolveScopedField(context, content);

      // {{program.name}} itself contains {{var.year}} — only resolves after
      // a second fixpoint pass, exactly like BriefRenderer's own resolver.
      expect(resolved, contains('P=Program 2026'));
      expect(resolved, contains('E=Exercise 1'));
      expect(resolved, contains('S=Station A'));
      expect(resolved, contains('UTM=${formatUtm(_stationPosition)}'));
      expect(resolved, contains('LOC=Fjellheisen'));
      expect(resolved, contains('PERSON=Kari'));
      expect(resolved, contains('VAR=2026'));
      expect(
        resolved,
        contains('UNK=${_l10n.briefUnknownVariable('unknown')}'),
      );
    },
  );

  testWidgets(
    'a field referencing station.* with no StationScope in context leaves '
    'the whole field literal, the same bounded limitation an entirely '
    'unresolvable cross-reference is server-side (ADR-0048)',
    (tester) async {
      late BuildContext captured;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PlanScope(
            variables: const [],
            programName: 'Program One',
            child: Builder(
              builder: (context) {
                captured = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      const content = 'P={{program.name}} S={{station.name}}';
      final resolved = resolveScopedField(captured, content);

      // No StationScope ancestor — the 'station' key is absent entirely
      // from the context, so the mustache pass throws "missing" and the
      // resolver's catch-all leaves the *whole* field's mustache pass
      // unrendered (not just the one absent token) — the field resolver's
      // documented bounded limitation for a partial context, unchanged by
      // this helper.
      expect(resolved, content);
    },
  );

  testWidgets(
    'a field with only a program-scope cross-reference resolves fine with '
    'no ExerciseScope/StationScope in context',
    (tester) async {
      late BuildContext captured;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PlanScope(
            variables: const [],
            programName: 'Program One',
            child: Builder(
              builder: (context) {
                captured = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      final resolved = resolveScopedField(captured, 'P={{program.name}}');

      expect(resolved, 'P=Program One');
    },
  );
}
