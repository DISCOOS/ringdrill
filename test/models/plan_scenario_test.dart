import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/data/drill_file.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/person.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';

void main() {
  final now = DateTime(2026);

  Plan base() => Plan(
        uuid: 'prog-1',
        name: 'Test',
        description: '',
        metadata: PlanMetadata(created: now, updated: now, version: '1.0'),
        teams: const [],
        sessions: const [],
        exercises: const [],
        rolePlays: const [],
        actors: const [],
      );

  const lkp = Location(
    slug: 'lkp',
    label: 'Last known position',
    kind: LocationKind.lkp,
    place: 'Fjellheisen',
  );
  const home = Location(slug: 'home_anne', kind: LocationKind.home);
  const anne = Person(slug: 'anne', name: 'Anne Glemsk', locSlug: 'home_anne');

  group('backward compatibility', () {
    test('station json without locations/persons deserializes to empty '
        'lists', () {
      final station = Station.fromJson({'index': 0, 'name': 'S1'});
      expect(station.locations, isEmpty);
      expect(station.persons, isEmpty);
    });

    test('roleplay json without personRef/gender deserializes to null', () {
      final rolePlay = RolePlay.fromJson({
        'uuid': 'rp-1',
        'index': 0,
        'exerciseUuid': 'ex-1',
        'name': 'Anna',
      });
      expect(rolePlay.personRef, isNull);
      expect(rolePlay.gender, isNull);
    });

    test('opens a synthetic pre-existing archive with no locations/persons/'
        'personRef keys', () {
      // Simulates a schema 1.2 .drill written before this change.
      final plan = base().copyWith(
        exercises: [
          Exercise(
            uuid: 'ex-1',
            name: 'Ex',
            startTime: SimpleTimeOfDay(hour: 8, minute: 0),
            endTime: SimpleTimeOfDay(hour: 9, minute: 0),
            numberOfTeams: 1,
            numberOfRounds: 1,
            executionTime: 10,
            evaluationTime: 5,
            rotationTime: 5,
            stations: const [Station(index: 0, name: 'S1')],
            schedule: const [],
          ),
        ],
        rolePlays: const [
          RolePlay(uuid: 'rp-1', index: 0, exerciseUuid: 'ex-1', name: 'Anna'),
        ],
      );

      final drillFile = DrillFile.fromPlan(plan, 'legacy');
      final decoded = drillFile.plan();

      expect(decoded.exercises.single.stations.single.locations, isEmpty);
      expect(decoded.exercises.single.stations.single.persons, isEmpty);
      expect(decoded.rolePlays.single.personRef, isNull);
      expect(decoded.rolePlays.single.gender, isNull);
    });
  });

  group('round-trips', () {
    test('station locations and persons round-trip through the real '
        'DrillFile archive, and roleplay personRef/gender survive '
        'unchanged', () {
      final station = Station(
        index: 0,
        name: 'S1',
        locations: const [lkp, home],
        persons: const [anne],
      );
      final exercise = Exercise(
        uuid: 'ex-1',
        name: 'Ex',
        startTime: SimpleTimeOfDay(hour: 8, minute: 0),
        endTime: SimpleTimeOfDay(hour: 9, minute: 0),
        numberOfTeams: 1,
        numberOfRounds: 1,
        executionTime: 10,
        evaluationTime: 5,
        rotationTime: 5,
        stations: [station],
        schedule: const [],
      );
      const rolePlay = RolePlay(
        uuid: 'rp-1',
        index: 0,
        exerciseUuid: 'ex-1',
        name: 'Anne Glemsk',
        gender: 'female',
        personRef: 'anne',
      );
      final plan = base().copyWith(
        exercises: [exercise],
        rolePlays: [rolePlay],
      );

      final decoded = DrillFile.fromPlan(plan, 'test').plan();
      final decodedStation = decoded.exercises.single.stations.single;

      expect(decodedStation.locations, unorderedEquals([lkp, home]));
      expect(decodedStation.persons, [anne]);

      final decodedRolePlay = decoded.rolePlays.single;
      expect(decodedRolePlay.personRef, 'anne');
      expect(decodedRolePlay.gender, 'female');
    });
  });

  group('content hash sensitivity', () {
    Station stationWith({List<Location> locations = const [], List<Person> persons = const []}) =>
        Station(index: 0, name: 'S1', locations: locations, persons: persons);

    Plan planWithStation(Station station) => base().copyWith(
          exercises: [
            Exercise(
              uuid: 'ex-1',
              name: 'Ex',
              startTime: SimpleTimeOfDay(hour: 8, minute: 0),
              endTime: SimpleTimeOfDay(hour: 9, minute: 0),
              numberOfTeams: 1,
              numberOfRounds: 1,
              executionTime: 10,
              evaluationTime: 5,
              rotationTime: 5,
              stations: [station],
              schedule: const [],
            ),
          ],
        );

    test('changes when a station gains a location', () {
      final prog = planWithStation(stationWith());
      final changed = planWithStation(stationWith(locations: const [lkp]));
      expect(prog.computeContentHash(), isNot(changed.computeContentHash()));
    });

    test('changes when a location field changes', () {
      final prog = planWithStation(stationWith(locations: const [lkp]));
      final changed = planWithStation(
        stationWith(locations: [lkp.copyWith(place: 'Elsewhere')]),
      );
      expect(prog.computeContentHash(), isNot(changed.computeContentHash()));
    });

    test('changes when a station gains a person', () {
      final prog = planWithStation(stationWith());
      final changed = planWithStation(stationWith(persons: const [anne]));
      expect(prog.computeContentHash(), isNot(changed.computeContentHash()));
    });

    test('changes when a person field changes', () {
      final prog = planWithStation(stationWith(persons: const [anne]));
      final changed = planWithStation(
        stationWith(persons: [anne.copyWith(age: 74)]),
      );
      expect(prog.computeContentHash(), isNot(changed.computeContentHash()));
    });

    test('is stable when locations/persons differ only in list order', () {
      final a = planWithStation(
        stationWith(locations: const [lkp, home], persons: const [anne]),
      );
      final b = planWithStation(
        stationWith(locations: const [home, lkp], persons: const [anne]),
      );
      expect(a.computeContentHash(), b.computeContentHash());
    });

    test('changes when a roleplay personRef changes', () {
      RolePlay rolePlay(String? ref) => RolePlay(
            uuid: 'rp-1',
            index: 0,
            exerciseUuid: 'ex-1',
            name: 'Anne',
            personRef: ref,
          );

      final prog = base().copyWith(rolePlays: [rolePlay('anne')]);
      final changed = base().copyWith(rolePlays: [rolePlay('other')]);
      expect(prog.computeContentHash(), isNot(changed.computeContentHash()));
    });

    test('changes when a roleplay gender changes', () {
      RolePlay rolePlay(String? gender) => RolePlay(
            uuid: 'rp-1',
            index: 0,
            exerciseUuid: 'ex-1',
            name: 'Anne',
            gender: gender,
          );

      final prog = base().copyWith(rolePlays: [rolePlay('female')]);
      final changed = base().copyWith(rolePlays: [rolePlay('male')]);
      expect(prog.computeContentHash(), isNot(changed.computeContentHash()));
    });
  });
}
