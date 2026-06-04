import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';

void main() {
  // Four stations, but only 0, 1 and 3 have a position. numberOfTeams is 2,
  // so at most two stations are "live" in any round (teamIndex < 2).
  final exercise = Exercise(
    uuid: 'ex-1',
    name: 'Ring',
    startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
    numberOfTeams: 2,
    numberOfRounds: 4,
    executionTime: 10,
    evaluationTime: 5,
    rotationTime: 2,
    stations: const [
      Station(index: 0, name: 'S0', position: LatLng(59.9, 10.7)),
      Station(index: 1, name: 'S1', position: LatLng(59.9, 10.8)),
      Station(index: 2, name: 'S2'), // no position → never a marker
      Station(index: 3, name: 'S3', position: LatLng(59.9, 10.9)),
    ],
    schedule: const [],
    endTime: const SimpleTimeOfDay(hour: 9, minute: 0),
  );

  group('activeLocationIds', () {
    test('ids align with getLocations marker ids', () {
      final markerIds = exercise.getLocations(false).map((m) => m.$1).toList();
      // Positioned counter skips the unpositioned station 2.
      expect(markerIds, const [('ex-1', 0), ('ex-1', 1), ('ex-1', 2)]);
    });

    test('round 0 lights the first two positioned stations', () {
      expect(
        exercise.activeLocationIds(0),
        {const ('ex-1', 0), const ('ex-1', 1)},
      );
    });

    test('round 1 lights only station 1 (station 2 has no position)', () {
      // teamIndex puts a team on station 2 in round 1, but it has no position
      // so it is not a marker and must not appear.
      expect(exercise.activeLocationIds(1), {const ('ex-1', 1)});
    });

    test('round 3 lights stations 0 and 3', () {
      expect(
        exercise.activeLocationIds(3),
        {const ('ex-1', 0), const ('ex-1', 2)},
      );
    });

    test('returns an empty set when no station is live', () {
      final empty = Exercise(
        uuid: 'ex-2',
        name: 'No teams',
        startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
        numberOfTeams: 0,
        numberOfRounds: 1,
        executionTime: 10,
        evaluationTime: 5,
        rotationTime: 2,
        stations: const [
          Station(index: 0, name: 'S0', position: LatLng(59.9, 10.7)),
        ],
        schedule: const [],
        endTime: const SimpleTimeOfDay(hour: 9, minute: 0),
      );
      expect(empty.activeLocationIds(0), isEmpty);
    });
  });
}
