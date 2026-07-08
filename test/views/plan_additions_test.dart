import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/person.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/views/plan_additions.dart';

/// DESIGN-009 follow-up 4 — pure unit tests for the write-back plumbing
/// (ADR-0047): the `PlanAdditions` record and its apply helpers, exercised
/// directly against `Program`/`Station` without any editor UI.
void main() {
  group('variableAdditions', () {
    test('carries only variables, empty station lists', () {
      const vars = [DrillVariable(name: 'freq', value: '')];
      final additions = variableAdditions(vars);
      expect(additions.variables, vars);
      expect(additions.stationLocations, isEmpty);
      expect(additions.stationPersons, isEmpty);
    });
  });

  group('applyVariableAdditions', () {
    final now = DateTime(2026);
    final program = Program(
      uuid: 'p1',
      name: 'Plan',
      description: '',
      metadata: ProgramMetadata(created: now, updated: now, version: '1.2'),
      teams: const [],
      sessions: const [],
      exercises: const [],
      rolePlays: const [],
      actors: const [],
      variables: const [DrillVariable(name: 'existing', value: 'x')],
    );

    test('appends new variables', () {
      final updated = applyVariableAdditions(
        program,
        variableAdditions(const [DrillVariable(name: 'freq', value: '')]),
      );
      expect(updated.variables.map((v) => v.name), ['existing', 'freq']);
    });

    test('skips a name already declared, to avoid duplicate declarations', () {
      final updated = applyVariableAdditions(
        program,
        variableAdditions(const [DrillVariable(name: 'existing', value: 'y')]),
      );
      expect(updated.variables, program.variables);
    });

    test('no-op with empty additions, returns the same instance', () {
      final updated = applyVariableAdditions(program, noPlanAdditions);
      expect(identical(updated, program), isTrue);
    });
  });

  group('applyStationAdditions', () {
    final station = Station(
      index: 0,
      name: 'Post 1',
      locations: const [Location(slug: 'lkp', place: 'Sentrum')],
      persons: const [Person(slug: 'anne', name: 'Anne')],
    );

    test('appends new locations and persons', () {
      final additions = (
        variables: <DrillVariable>[],
        stationLocations: [const Location(slug: 'ipp', place: 'Skogen')],
        stationPersons: [const Person(slug: 'ola', name: 'Ola')],
      );
      final updated = applyStationAdditions(station, additions);
      expect(updated.locations.map((l) => l.slug), ['lkp', 'ipp']);
      expect(updated.persons.map((p) => p.slug), ['anne', 'ola']);
    });

    test('skips a slug already present', () {
      final additions = (
        variables: <DrillVariable>[],
        stationLocations: [const Location(slug: 'lkp', place: 'Duplicate')],
        stationPersons: <Person>[],
      );
      final updated = applyStationAdditions(station, additions);
      expect(updated.locations, station.locations);
    });

    test('no-op with empty additions, returns the same instance', () {
      final updated = applyStationAdditions(station, noPlanAdditions);
      expect(identical(updated, station), isTrue);
    });
  });
}
