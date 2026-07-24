import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/person.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/views/plan_additions.dart';

import 'support/save_roundtrip_harness.dart';

/// DESIGN-009 follow-up 4 — pure unit tests for the write-back plumbing
/// (ADR-0047): the `PlanAdditions` record and its apply helpers, exercised
/// directly against `Plan`/`Station` without any editor UI.
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
    final plan = Plan(
      uuid: 'p1',
      name: 'Plan',
      description: '',
      metadata: PlanMetadata(created: now, updated: now, version: '1.2'),
      teams: const [],
      sessions: const [],
      exercises: const [],
      rolePlays: const [],
      actors: const [],
      variables: const [DrillVariable(name: 'existing', value: 'x')],
    );

    test('appends new variables', () {
      final updated = applyVariableAdditions(
        plan,
        variableAdditions(const [DrillVariable(name: 'freq', value: '')]),
      );
      expect(updated.variables.map((v) => v.name), ['existing', 'freq']);
    });

    test('skips a name already declared, to avoid duplicate declarations', () {
      final updated = applyVariableAdditions(
        plan,
        variableAdditions(const [DrillVariable(name: 'existing', value: 'y')]),
      );
      expect(updated.variables, plan.variables);
    });

    test('no-op with empty additions, returns the same instance', () {
      final updated = applyVariableAdditions(plan, noPlanAdditions);
      expect(identical(updated, plan), isTrue);
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
        rolePlays: <RolePlay>[],
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
        rolePlays: <RolePlay>[],
      );
      final updated = applyStationAdditions(station, additions);
      expect(updated.locations, station.locations);
    });

    test('no-op with empty additions, returns the same instance', () {
      final updated = applyStationAdditions(station, noPlanAdditions);
      expect(identical(updated, station), isTrue);
    });
  });

  group('applyPendingRolePlayAdditions', () {
    late AppLocalizations l10n;

    setUpAll(() async {
      l10n = await AppLocalizations.delegate.load(const Locale('en'));
    });

    setUp(() async {
      await initActivePlan('Write-back plan');
      await PlanService().saveExercise(
        l10n,
        makeExercise(uuid: 'ex-1', name: 'Exercise'),
      );
    });

    tearDown(() => PlanService().clearAllForTest());

    test('saves each roleplay through the repo (DESIGN-009 prompt 4j)', () async {
      const rolePlay = RolePlay(
        uuid: 'rp-new',
        index: 0,
        exerciseUuid: 'ex-1',
        name: 'Ukjent',
        stationIndex: 0,
        personRef: 'anne',
      );
      await applyPendingRolePlayAdditions(
        PlanService(),
        l10n,
        variableAdditions(const [], rolePlays: const [rolePlay]),
      );
      expect(PlanService().getRolePlay('rp-new')?.name, 'Ukjent');
    });

    test('no-op with no roleplays', () async {
      await applyPendingRolePlayAdditions(PlanService(), l10n, noPlanAdditions);
      expect(PlanService().loadRolePlays(), isEmpty);
    });
  });
}
