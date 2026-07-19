import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/person.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/views/widgets/exercise_scope.dart';
import 'package:ringdrill/views/widgets/station_scope.dart';

/// [StationScope.forStation] is the single source of the per-station /
/// per-exercise scope every station-detail surface reads (Poster/Øvelser/Spill
/// tabs, coordinator). These guard that it exposes the full facet set derived
/// from the models, and that an unassigned roleplay (no station) still gets an
/// ExerciseScope.
Exercise _exercise() => Exercise(
  uuid: 'ex-1',
  name: 'Ex',
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
  endTime: const SimpleTimeOfDay(hour: 8, minute: 17),
  variableOverrides: const {'freq': 'Kanal 8'},
);

const _station = Station(
  index: 0,
  name: 'Post 1',
  position: LatLng(59.91, 10.75),
  variantSuffix: 'A',
  locations: [Location(slug: 'lkp', place: 'Fjellheisen')],
  persons: [Person(slug: 'p1', name: 'Kari')],
);

void main() {
  testWidgets('exposes ExerciseScope + StationScope facets to descendants', (
    tester,
  ) async {
    ExerciseScope? ex;
    StationScope? st;
    await tester.pumpWidget(
      MaterialApp(
        home: StationScope.forStation(
          exercise: _exercise(),
          station: _station,
          child: Builder(
            builder: (context) {
              ex = ExerciseScope.maybeOf(context);
              st = StationScope.maybeOf(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    expect(ex, isNotNull);
    expect(ex!.variableOverrides, {'freq': 'Kanal 8'});
    expect(st, isNotNull);
    expect(st!.name, 'Post 1');
    expect(st!.position, const LatLng(59.91, 10.75));
    expect(st!.variantSuffix, 'A');
    expect(st!.locations.single.slug, 'lkp');
    expect(st!.persons.single.slug, 'p1');
  });

  testWidgets('a null station provides ExerciseScope only', (tester) async {
    ExerciseScope? ex;
    StationScope? st;
    await tester.pumpWidget(
      MaterialApp(
        home: StationScope.forStation(
          exercise: _exercise(),
          station: null,
          child: Builder(
            builder: (context) {
              ex = ExerciseScope.maybeOf(context);
              st = StationScope.maybeOf(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    expect(ex, isNotNull);
    expect(st, isNull);
  });
}
