import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/views/roleplay_screen.dart';
import 'package:ringdrill/views/widgets/plan_scope.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// DESIGN-010 stage 3 — the Spill sheet (roleplay_screen.dart) now wraps
/// itself in a RoleplayScope (its own facets) and a StationScope (the linked
/// station's facets), so a scenario field can reference both `{{roleplay.*}}`
/// and the linked station's `{{station.*}}` instead of leaving them literal.
const _planUuid = 'prog-role-ref';
const _exerciseUuid = 'ex-role-ref';
const _roleUuid = 'role-ref';

Exercise _exercise() => Exercise(
  uuid: _exerciseUuid,
  name: 'Test Exercise',
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
);

RolePlay _rolePlay() => const RolePlay(
  uuid: _roleUuid,
  index: 0,
  exerciseUuid: _exerciseUuid,
  stationIndex: 0,
  name: 'Turgåer',
  age: 34,
  // Mixes three scopes in one field on purpose: roleplay (own facet),
  // exercise (parent) and station (linked). The viewer must provide all
  // three, or the all-or-nothing mustache render throws on the first missing
  // one and drags the rest back to literal.
  description:
      'Alder {{roleplay.age}}, {{exercise.numberOfTeams}} lag, '
      'sett ved {{station.name}}.',
);

Map<String, Object> _prefs() {
  final ex = _exercise();
  return {
    'app:activePlan:v1': _planUuid,
    'app:librarySchema:v1': '1',
    'p:$_planUuid': jsonEncode({
      'uuid': _planUuid,
      'name': 'Test Plan',
      'description': '',
      'metadata': {
        'created': '2024-01-01T00:00:00.000Z',
        'updated': '2024-01-01T00:00:00.000Z',
        'version': '1.1',
      },
      'exercises': [],
      'teams': [],
      'sessions': [],
      'rolePlays': [],
      'actors': [],
      'variables': [],
    }),
    'pe:$_planUuid:$_exerciseUuid': jsonEncode(ex.toJson()),
    'pr:$_planUuid:$_roleUuid': jsonEncode(_rolePlay().toJson()),
  };
}

Widget _buildScreen() {
  // Mirrors the real app: `PlanScope` is always ambient around a viewer
  // screen (main_screen.dart for the wide/inline case, ringdrill_sheet.dart's
  // `_withDefaultPlanScope` for a modal one) — RingDrillText treats its
  // *absence* as "no resolution at all", so a bare-harness test without one
  // would test nothing.
  return const MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: PlanScope(
      variables: [],
      child: RolePlayScreen(uuid: _roleUuid),
    ),
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(_prefs());
    await PlanService().init();
  });

  testWidgets(
    'description resolves {{roleplay.*}}, {{exercise.*}} and {{station.*}} '
    'together instead of leaving them literal',
    (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      // _exercise() declares numberOfTeams: 1.
      expect(find.text('Alder 34, 1 lag, sett ved Post 1.'), findsOneWidget);
      expect(find.textContaining('{{'), findsNothing);
    },
  );
}
