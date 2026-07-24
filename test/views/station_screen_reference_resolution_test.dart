import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/brief/field_resolver.dart' show formatUtm;
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/station_screen.dart';
import 'package:ringdrill/views/widgets/plan_scope.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// DESIGN-010 stage 3 — regression test for the reported bug: the Post
/// sheet's description used to render `{{station.position}}` (and
/// `{{station.loc.*}}`) as literal text (only `{{var.*}}` resolved). Now
/// that station_screen.dart wraps itself in ExerciseScope/StationScope and
/// resolves its description through resolveScopedField (ADR-0048), the
/// cross-references resolve the same way they would in the brief.
const _programUuid = 'prog-ref';
const _exerciseUuid = 'ex-ref';
final _stationPosition = const LatLng(59.91, 10.75);

const _lkp = Location(
  slug: 'lkp',
  place: 'Fjellheisen',
  position: LatLng(58.99, 10.43),
);

Exercise _exercise() => Exercise(
  uuid: _exerciseUuid,
  name: 'Test Exercise',
  startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
  numberOfTeams: 1,
  numberOfRounds: 1,
  executionTime: 10,
  evaluationTime: 5,
  rotationTime: 2,
  stations: [
    Station(
      index: 0,
      name: 'Post 1',
      position: _stationPosition,
      locations: const [_lkp],
      description:
          'Posisjon: {{station.position}}. Møtepunkt: '
          '{{station.loc.lkp.place}}.',
    ),
  ],
  schedule: const [
    [
      SimpleTimeOfDay(hour: 8, minute: 0),
      SimpleTimeOfDay(hour: 8, minute: 10),
      SimpleTimeOfDay(hour: 8, minute: 15),
    ],
  ],
  endTime: const SimpleTimeOfDay(hour: 8, minute: 17),
);

Map<String, Object> _prefs() {
  final ex = _exercise();
  return {
    'app:activeProgram:v1': _programUuid,
    'app:librarySchema:v1': '1',
    'p:$_programUuid': jsonEncode({
      'uuid': _programUuid,
      'name': 'Test Program',
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
    'pe:$_programUuid:$_exerciseUuid': jsonEncode(ex.toJson()),
  };
}

Widget _buildScreen() {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const PlanScope(
          variables: [],
          child: StationScreen(
            stationIndex: 0,
            uuid: _exerciseUuid,
          ),
        ),
      ),
    ],
  );
  return MaterialApp.router(
    routerConfig: router,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(_prefs());
    await ProgramService().init();
  });

  testWidgets('the description resolves {{station.position}} and '
      '{{station.loc.*}} instead of leaving them literal', (tester) async {
    await tester.pumpWidget(_buildScreen());
    await tester.pumpAndSettle();

    final expectedUtm = formatUtm(_stationPosition);
    // The detail card renders via markdown. The app resolvers pass
    // ActionChipFormatter (ADR-0050), so the position resolves as a
    // ringdrill://chip link (rendered as plain link text until DESIGN-013
    // Commit 4 wires up the pill renderer) rather than a standalone
    // copy-chip Text — match on rendered text instead of the chip's own
    // Text widget.
    expect(find.textContaining(expectedUtm), findsWidgets);
    expect(
      find.byWidgetPredicate((w) => w is Text && w.data == 'Fjellheisen'),
      findsWidgets,
    );
    expect(find.textContaining('{{station.'), findsNothing);
  });
}
