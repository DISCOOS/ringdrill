import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/l10n/app_localizations_nb.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/person.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/brief/field_resolver.dart'
    show formatUtm, onResolveFieldError;
import 'package:ringdrill/views/widgets/exercise_scope.dart';
import 'package:ringdrill/views/widgets/plan_scope.dart';
import 'package:ringdrill/views/widgets/resolve_scoped_field.dart';
import 'package:ringdrill/views/widgets/roleplay_scope.dart';
import 'package:ringdrill/utils/plan_field_names.dart';
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
const _rolePlay = RolePlay(
  uuid: 'rp-1',
  index: 0,
  exerciseUuid: 'ex-1',
  name: 'Nordmann',
  age: 42,
  description: 'Skadd turgåer',
  position: LatLng(59.90, 10.74),
);
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
  // Two rounds of 10 + 5 + 5 from 08:00, so `{{exercise.roundTable}}` has
  // something to derive. `const []` is a state the compiler never produces, and
  // a fixture carrying it made the brief-side guard pass on an empty string.
  schedule: const [
    [
      SimpleTimeOfDay(hour: 8, minute: 0),
      SimpleTimeOfDay(hour: 8, minute: 10),
      SimpleTimeOfDay(hour: 8, minute: 15),
    ],
    [
      SimpleTimeOfDay(hour: 8, minute: 20),
      SimpleTimeOfDay(hour: 8, minute: 30),
      SimpleTimeOfDay(hour: 8, minute: 35),
    ],
  ],
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
        planName: 'Plan {{var.year}}',
        planDescription: 'Vinterøvelse',
        planCounts: const (exercises: 7, teams: 4, stations: 25),
        child: ExerciseScope(
          exercise: _exercise(),
          variableOverrides: const {},
          child: StationScope(
            locations: const [_lkp],
            persons: const [_kari],
            name: 'Station A',
            stationCode: '1c',
            variantSuffix: 'A',
            position: _stationPosition,
            child: RoleplayScope.forRoleplay(
              _rolePlay,
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
    ),
  );
  return captured;
}

void main() {
  // The guard that was missing, and the reason `{{exercise.roundTable}}` shipped
  // resolving in the brief and not in the editor. `PlanFieldNames` declares the
  // facet names; `BriefRenderer` and this resolver each build their own value
  // map, and only the brief's was ever checked against the declaration
  // (test/views/plan_field_tokens_resolution_test.dart). So a facet added to one
  // map was offered in the picker, validated by `analyze` and rendered in the
  // brief — and left as a literal `{{exercise.roundTable}}` in the app's own
  // preview, which is where an author looks first.
  //
  // Asserted at roleplay scope because that is the deepest one: its cascade is
  // every facet the resolver can ever be asked for.
  testWidgets('every facet PlanFieldNames declares resolves here too, not only '
      'in the brief', (tester) async {
    final context = await _pumpScoped(tester);

    final errors = <Object>[];
    onResolveFieldError = (error, _) => errors.add(error);
    addTearDown(() => onResolveFieldError = null);

    final unresolved = <String>[];
    final empty = <String>[];
    for (final name in PlanFieldNames.resolvableAt(PlanFieldScope.roleplay)) {
      final resolved = resolveScopedField(context, '>>>{{$name}}<<<');
      if (resolved == null || resolved.contains('{{')) {
        unresolved.add(name);
        continue;
      }
      final value = resolved
          .replaceFirst('>>>', '')
          .replaceFirst('<<<', '')
          .trim();
      if (value.isEmpty) empty.add(name);
    }

    expect(
      unresolved,
      isEmpty,
      reason:
          'these facets are declared but the app-side resolver has no value '
          'for them, so they render as a literal token in preview',
    );
    expect(
      empty,
      isEmpty,
      reason:
          'these resolved to nothing at all — a value map entry that is '
          'present but always empty is the same bug one step later',
    );
    expect(errors, isEmpty);
  });

  testWidgets('the facets added for the LSOR conversion resolve to real values', (
    tester,
  ) async {
    final context = await _pumpScoped(tester);

    // Spelled out rather than left to the sweep above, because "non-empty" is a
    // weak assertion for a derived value: a wrong number is also non-empty.
    expect(resolveScopedField(context, '{{plan.exerciseCount}}'), '7');
    expect(resolveScopedField(context, '{{plan.teamCount}}'), '4');
    expect(resolveScopedField(context, '{{plan.stationCount}}'), '25');
    // 10 + 5 + 5 per round, with the phase breakdown the booklet prints.
    expect(
      resolveScopedField(context, '{{station.duration}}'),
      '20 min (10 | 5 | 5)',
    );
    // A GFM table with a column per phase, in hhmm.
    final table = resolveScopedField(context, '{{exercise.roundTable}}')!;
    expect(table, contains('| 1 | 0800 | 0810 | 0815 |'));
    expect(table, contains('| 2 | 0820 | 0830 | 0835 |'));
  });

  testWidgets('resolves {{var.*}}, {{plan.*}}, {{exercise.*}}, {{station.*}}, '
      '{{station.loc/person.*}} and {{roleplay.*}} together the same way the '
      'brief would, and leaves an undeclared variable as the brief\'s '
      'unknown-variable placeholder', (tester) async {
    final context = await _pumpScoped(tester);

    final errors = <Object>[];
    onResolveFieldError = (error, _) => errors.add(error);
    addTearDown(() => onResolveFieldError = null);

    // Deliberately mixes every scope in one field: this is what caught the
    // roleplay-editor gap — the mustache render is all-or-nothing, so a
    // single token whose scope a surface forgot to provide throws and drags
    // every *other* token back to literal too.
    const content =
        'P={{plan.name}} E={{exercise.name}} S={{station.name}} '
        'UTM={{station.position}} LOC={{station.loc.lkp.place}} '
        'PERSON={{station.person.kari.name}} '
        'RP={{roleplay.name}} RPAGE={{roleplay.age}} '
        'VAR={{var.year}} UNK={{var.unknown}}';

    final resolved = resolveScopedField(context, content);

    // {{plan.name}} itself contains {{var.year}} — only resolves after
    // a second fixpoint pass, exactly like BriefRenderer's own resolver.
    expect(resolved, contains('P=Plan 2026'));
    expect(resolved, contains('E=Exercise 1'));
    expect(resolved, contains('S=Station A'));
    // The app resolvers pass ActionChipFormatter (ADR-0050): a position
    // with a coordinate resolves as a ringdrill://chip map link, an address
    // stays a plain copy chip.
    expect(
      resolved,
      contains(
        'UTM=[${formatUtm(_stationPosition)}]'
        '(ringdrill://chip?action=map&lat=${_stationPosition.latitude}'
        '&lng=${_stationPosition.longitude})',
      ),
    );
    expect(resolved, contains('LOC=`Fjellheisen`'));
    expect(resolved, contains('PERSON=Kari'));
    expect(resolved, contains('RP=Nordmann'));
    expect(resolved, contains('RPAGE=42'));
    expect(resolved, contains('VAR=2026'));
    expect(resolved, contains('UNK=${_l10n.briefUnknownVariable('unknown')}'));
    // Every scope the field references was in context, so no cross-reference
    // pass failed and the observability hook must stay silent.
    expect(errors, isEmpty);
  });

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
            planName: 'Plan One',
            child: Builder(
              builder: (context) {
                captured = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      final errors = <Object>[];
      onResolveFieldError = (error, _) => errors.add(error);
      addTearDown(() => onResolveFieldError = null);

      const content = 'P={{plan.name}} S={{station.name}}';
      final resolved = resolveScopedField(captured, content);

      // No StationScope ancestor — the 'station' key is absent entirely
      // from the context, so the mustache pass throws "missing" and the
      // resolver's catch-all leaves the *whole* field's mustache pass
      // unrendered (not just the one absent token) — the field resolver's
      // documented bounded limitation for a partial context, unchanged by
      // this helper.
      expect(resolved, content);
      // But it is no longer *silent*: the swallowed failure is surfaced once
      // through the hook, so a missing scope can be alerted on (Sentry in the
      // app) or asserted on in tests instead of vanishing into the catch.
      expect(errors, hasLength(1));
    },
  );

  testWidgets(
    'a field with only a plan-scope cross-reference resolves fine with '
    'no ExerciseScope/StationScope in context',
    (tester) async {
      late BuildContext captured;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PlanScope(
            variables: const [],
            planName: 'Plan One',
            child: Builder(
              builder: (context) {
                captured = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      final resolved = resolveScopedField(captured, 'P={{plan.name}}');

      expect(resolved, 'P=Plan One');
    },
  );

  testWidgets(
    'resolveModelField resolves exercise/station/roleplay facets from explicit '
    'models (eager labels with no scoped subtree, e.g. map markers) and keeps '
    'the hook silent when they are all supplied',
    (tester) async {
      late BuildContext captured;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('nb'),
          home: PlanScope(
            variables: const [DrillVariable(name: 'year', value: '2026')],
            planName: 'Plan {{var.year}}',
            child: Builder(
              builder: (context) {
                captured = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      final errors = <Object>[];
      onResolveFieldError = (error, _) => errors.add(error);
      addTearDown(() => onResolveFieldError = null);

      const content =
          'P={{plan.name}} E={{exercise.name}} S={{station.name}} '
          'RP={{roleplay.name}} VAR={{var.year}}';

      final resolved = resolveModelField(
        captured,
        content,
        exercise: _exercise(),
        station: const Station(index: 0, name: 'Station A'),
        roleplay: _rolePlay,
        overrides: const {},
      );

      expect(resolved, contains('P=Plan 2026'));
      expect(resolved, contains('E=Exercise 1'));
      expect(resolved, contains('S=Station A'));
      expect(resolved, contains('RP=Nordmann'));
      expect(resolved, contains('VAR=2026'));
      expect(errors, isEmpty);
    },
  );
}
