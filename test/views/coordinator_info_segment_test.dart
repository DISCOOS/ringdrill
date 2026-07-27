import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/data/plan_repository.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/views/coordinator_screen.dart';
import 'package:ringdrill/views/widgets/exercise_description_card.dart';
import 'package:ringdrill/views/widgets/schedule_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The coordinator's Info segment: the rotation timetable used to be pinned
/// above the segment selector on *every* segment, and the exercise's own
/// markdown sections were reachable only from the brief or the editor. Both now
/// live together in an Info segment, mirroring StationScreen's.
const _planUuid = 'prog-coordinator-info';
const _exerciseUuid = 'ex-coordinator-info';

Exercise _exercise() => Exercise(
  uuid: _exerciseUuid,
  name: 'Info Segment Test Exercise',
  startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
  numberOfTeams: 1,
  numberOfRounds: 1,
  executionTime: 10,
  evaluationTime: 5,
  rotationTime: 2,
  stations: const [Station(index: 0, name: 'Post 1')],
  schedule: const [
    [
      SimpleTimeOfDay(hour: 8, minute: 0),
      SimpleTimeOfDay(hour: 8, minute: 10),
      SimpleTimeOfDay(hour: 8, minute: 15),
    ],
  ],
  endTime: const SimpleTimeOfDay(hour: 9, minute: 0),
  // Sidecar-stored (ADR-0022), so this fixture seeds through PlanRepository
  // rather than raw prefs JSON.
  methodMd: 'Metode: gå i linje.',
  commsMd: 'Samband: kanal 5.',
);

/// An exercise whose markdown exercises the full resolve cascade an
/// exercise-scope field is allowed to reach (docs/variables.md): the exercise's
/// own facets, the plan's, and a declared plan variable.
Exercise _tokenExercise() => _exercise().copyWith(
  methodMd:
      'Runder: {{exercise.numberOfRounds}}. '
      'Plan: {{plan.name}}. '
      'Frekvens: {{var.frekvens}}.',
  commsMd: null,
);

Plan _shell() {
  final now = DateTime.utc(2026, 1, 1);
  return Plan(
    uuid: _planUuid,
    name: 'Test Plan',
    description: '',
    metadata: PlanMetadata(created: now, updated: now, version: '1.1'),
    variables: const [DrillVariable(name: 'frekvens', value: 'Kanal 6')],
    teams: const [],
    sessions: const [],
    exercises: const [],
    rolePlays: const [],
    actors: const [],
  );
}

Future<void> _seedAndInit([Exercise? exercise]) async {
  SharedPreferences.setMockInitialValues({});
  PlanService().reset();
  final prefs = await SharedPreferences.getInstance();
  final repo = PlanRepository(prefs);
  await repo.savePlanShell(_shell());
  await repo.setActivePlanUuid(_planUuid);
  await repo.saveExercise(exercise ?? _exercise());
  await PlanService().init();
}

Widget _harness(Widget widget) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: widget,
);

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  setUp(_seedAndInit);

  testWidgets('opens on the station list, with no timetable pinned above it', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(const CoordinatorScreen(uuid: _exerciseUuid)),
    );
    await tester.pumpAndSettle();

    // Still lands in the working view rather than on Info.
    expect(find.text('Post 1'), findsOneWidget);
    // The timetable is no longer pinned here — that is what freed the space.
    expect(find.byType(ScheduleCard), findsNothing);
    expect(find.byType(ExerciseDescriptionCard), findsNothing);
  });

  testWidgets('the Info segment holds the description card and the timetable', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(const CoordinatorScreen(uuid: _exerciseUuid)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.infoTab));
    await tester.pumpAndSettle();

    expect(find.byType(ExerciseDescriptionCard), findsOneWidget);
    expect(find.byType(ScheduleCard), findsOneWidget);
  });

  testWidgets('the description card surfaces the exercise markdown sections', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(const CoordinatorScreen(uuid: _exerciseUuid)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.infoTab));
    await tester.pumpAndSettle();

    // Section labels come from the same brief keys the ExerciseCard rollup uses.
    expect(
      find.text(l10n.exerciseDescriptionCardTitle.toUpperCase()),
      findsOneWidget,
    );
    expect(find.textContaining('Metode: gå i linje.'), findsOneWidget);
    expect(find.textContaining('Samband: kanal 5.'), findsOneWidget);
    // An empty field contributes no block at all.
    expect(find.text(l10n.briefSectionExerciseTrainingFocus), findsNothing);
  });

  // The card renders through Rollup, which resolves via the DESIGN-010 scope
  // cascade (ADR-0048) rather than from the passed overrides alone — so the
  // coordinator has to *provide* those scopes or the tokens render literally.
  // `{{var.*}}` in particular needs PlanScope for the declared-variable
  // registry: an overrides map can only override a declared variable's value,
  // never declare one.
  testWidgets('resolves exercise, plan and variable tokens in the card', (
    tester,
  ) async {
    await _seedAndInit(_tokenExercise());
    await tester.pumpWidget(
      _harness(const CoordinatorScreen(uuid: _exerciseUuid)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.infoTab));
    await tester.pumpAndSettle();

    expect(find.textContaining('Runder: 1.'), findsOneWidget);
    expect(find.textContaining('Plan: Test Plan.'), findsOneWidget);
    expect(find.textContaining('Frekvens: Kanal 6.'), findsOneWidget);
    // And nothing is left as a literal token.
    expect(find.textContaining('{{'), findsNothing);
  });
}
