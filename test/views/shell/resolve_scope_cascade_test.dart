import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/person.dart';
import 'package:ringdrill/views/shell/open_form_surface.dart';
import 'package:ringdrill/views/widgets/exercise_scope.dart';
import 'package:ringdrill/views/widgets/plan_scope.dart';
import 'package:ringdrill/views/widgets/station_scope.dart';

/// DESIGN-010 stage 1 — the resolve-context scope cascade: `PlanScope`'s
/// program facets, the new `ExerciseScope`, and `openFormSurface`
/// re-providing all three (whichever are present) across the Navigator push
/// that otherwise strands a pushed form/dialog outside the ancestor
/// `InheritedWidget` tree. No widget reads these scopes for resolution yet
/// (that starts at DESIGN-010 stage 2) — this only proves the scopes are
/// present, carry the right data, and degrade gracefully when absent.
Widget _harness({required Size size, required Widget child}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: Scaffold(body: child),
    ),
  );
}

final _start = SimpleTimeOfDay(hour: 8, minute: 0);
final _end = SimpleTimeOfDay(hour: 9, minute: 0);

Exercise _exercise() => Exercise(
  uuid: 'ex-1',
  name: 'Exercise 1',
  startTime: _start,
  endTime: _end,
  numberOfTeams: 2,
  numberOfRounds: 2,
  executionTime: 10,
  evaluationTime: 5,
  rotationTime: 5,
  stations: const [],
  schedule: const [],
);

void main() {
  group('resolve-context scope cascade (DESIGN-010)', () {
    testWidgets(
      'a probe under the exercise editor sees a non-null ExerciseScope and '
      'PlanScope carrying the program facets',
      (tester) async {
        late BuildContext probeContext;
        await tester.pumpWidget(
          _harness(
            size: const Size(400, 800),
            child: PlanScope(
              variables: const [],
              programName: 'Program One',
              programDescription: 'Program description',
              child: ExerciseScope(
                exercise: _exercise(),
                variableOverrides: const {},
                child: Builder(
                  builder: (context) {
                    probeContext = context;
                    return const Text('probe');
                  },
                ),
              ),
            ),
          ),
        );

        final exerciseScope = ExerciseScope.maybeOf(probeContext);
        final planScope = PlanScope.maybeOf(probeContext);
        expect(exerciseScope, isNotNull);
        expect(exerciseScope!.exercise.name, 'Exercise 1');
        expect(planScope, isNotNull);
        expect(planScope!.programName, 'Program One');
        expect(planScope.programDescription, 'Program description');
      },
    );

    testWidgets(
      'openFormSurface re-provides PlanScope/ExerciseScope/StationScope into '
      'the pushed surface',
      (tester) async {
        const location = Location(slug: 'lkp', place: 'Fjellheisen');
        const person = Person(slug: 'p1', name: 'Kari');

        await tester.pumpWidget(
          _harness(
            size: const Size(400, 800),
            child: PlanScope(
              variables: const [DrillVariable(name: 'v', value: 'val')],
              programName: 'Program One',
              programDescription: 'Program description',
              child: ExerciseScope(
                exercise: _exercise(),
                variableOverrides: const {'v': 'override'},
                child: StationScope(
                  locations: const [location],
                  persons: const [person],
                  child: Builder(
                    builder: (context) {
                      return TextButton(
                        onPressed: () => openFormSurface<void>(
                          context,
                          builder: (_) => const Scaffold(body: Text('Form')),
                        ),
                        child: const Text('Open'),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        final formContext = tester.element(find.text('Form'));
        final planScope = PlanScope.maybeOf(formContext);
        final exerciseScope = ExerciseScope.maybeOf(formContext);
        final stationScope = StationScope.maybeOf(formContext);

        expect(planScope, isNotNull);
        expect(planScope!.programName, 'Program One');
        expect(planScope.variables.single.name, 'v');
        expect(exerciseScope, isNotNull);
        expect(exerciseScope!.variableOverrides, {'v': 'override'});
        expect(stationScope, isNotNull);
        expect(stationScope!.locations.single.slug, 'lkp');
      },
    );

    testWidgets(
      'a form opened with no ancestor scopes sees ExerciseScope/StationScope '
      'as null, gracefully',
      (tester) async {
        await tester.pumpWidget(
          _harness(
            size: const Size(400, 800),
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () => openFormSurface<void>(
                  context,
                  builder: (_) => const Scaffold(body: Text('Form')),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        final formContext = tester.element(find.text('Form'));
        expect(ExerciseScope.maybeOf(formContext), isNull);
        expect(StationScope.maybeOf(formContext), isNull);
        // PlanScope itself is never absent (openFormSurface's pre-DESIGN-010
        // fallback to the active program's variables), but carries no
        // program facets when nothing ambient set them.
        final planScope = PlanScope.maybeOf(formContext);
        expect(planScope, isNotNull);
        expect(planScope!.programName, isNull);
      },
    );
  });
}
