import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/views/widgets/location_kind_style.dart';
import 'package:ringdrill/views/widgets/role_mini_map.dart';
import 'package:ringdrill/views/widgets/station_mini_map.dart';

/// Every station-position marker in the app shares one label/shortLabel
/// source ([stationNumbering]), every scenario-location marker shares one
/// shape ([locationMarker]), and every role/roleplay marker shares one
/// builder ([roleMarker]) — the consolidation this session's audit found
/// missing (4+ independent reimplementations, some carrying the plan
/// number in their label, some not).
void main() {
  Exercise exercise({List<Station> stations = const []}) => Exercise(
    uuid: 'ex-1',
    name: 'Exercise',
    startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
    endTime: const SimpleTimeOfDay(hour: 9, minute: 0),
    numberOfTeams: 1,
    numberOfRounds: 1,
    executionTime: 10,
    evaluationTime: 5,
    rotationTime: 5,
    stations: stations,
    schedule: const [],
  );

  const station = Station(
    index: 0,
    name: 'Turgåer',
    position: LatLng(59.0, 10.0),
  );

  test(
    'stationNumbering always joins the plan number with the (unresolved) '
    'name for the full label, and the number alone for the short one',
    () {
      final numbering = stationNumbering(exercise(stations: [station]), station);
      expect(numbering.rawLabel, '1.1 Turgåer');
      expect(numbering.shortLabel, '1.1');
    },
  );

  test(
    'locationMarker never sets a shortLabel — locations don\'t need a '
    'zoom-tiered short form the way a station\'s own number does',
    () {
      const location = Location(
        slug: 'lkp',
        label: 'Sist kjent posisjon',
        kind: LocationKind.lkp,
        position: LatLng(59.1, 10.1),
      );
      final marker = locationMarker(location, id: 7);
      expect(marker.id, 7);
      expect(marker.label, 'Sist kjent posisjon');
      expect(marker.shortLabel, isNull);
      expect(marker.point, location.position);
      final icon = marker.child as Icon;
      expect(icon.icon, LocationKind.lkp.icon);
      expect(icon.color, LocationKind.lkp.color);
    },
  );

  test('locationMarker falls back to the slug when label is empty', () {
    const location = Location(
      slug: 'lkp',
      kind: LocationKind.lkp,
      position: LatLng(59.1, 10.1),
    );
    final marker = locationMarker(location, id: 1);
    expect(marker.label, 'lkp');
  });

  testWidgets(
    'roleMarker resolves plan-variable/cross-reference tokens in the '
    'role\'s name when an exercise is supplied, and reuses across marker '
    'id types (int for the single-role view, a compound key for the '
    'all-exercises map)',
    (tester) async {
      const rolePlay = RolePlay(
        uuid: 'rp-1',
        index: 0,
        exerciseUuid: 'ex-1',
        name: 'Hilde',
        position: LatLng(58.99, 10.43),
      );

      late BuildContext capturedContext;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final intMarker = roleMarker<int>(
        capturedContext,
        rolePlay,
        null,
        id: 0,
        exercise: exercise(),
      );
      expect(intMarker, isNotNull);
      expect(intMarker!.id, 0);
      expect(intMarker.label, 'Hilde');
      expect(intMarker.point, rolePlay.position);

      final compoundKeyMarker = roleMarker<(String, int)>(
        capturedContext,
        rolePlay,
        null,
        id: (rolePlay.exerciseUuid, rolePlay.index),
        exercise: exercise(),
      );
      expect(compoundKeyMarker, isNotNull);
      expect(compoundKeyMarker!.id, ('ex-1', 0));
      expect(compoundKeyMarker.label, 'Hilde');
    },
  );

  testWidgets(
    'roleMarker falls back to the raw name when no exercise is given '
    '(a stale roleplay whose parent exercise could not be resolved)',
    (tester) async {
      const rolePlay = RolePlay(
        uuid: 'rp-1',
        index: 0,
        exerciseUuid: 'ex-1',
        name: 'Hilde',
        position: LatLng(58.99, 10.43),
      );

      late BuildContext capturedContext;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final marker = roleMarker<int>(capturedContext, rolePlay, null, id: 0);
      expect(marker, isNotNull);
      expect(marker!.label, 'Hilde');
    },
  );

  test('roleMarker returns null when the role has no central position', () {
    const rolePlay = RolePlay(
      uuid: 'rp-1',
      index: 0,
      exerciseUuid: 'ex-1',
      name: 'Hilde',
    );
    // No BuildContext needed: roleCentralPosition returns null before the
    // label is ever resolved, so roleMarker short-circuits first.
    expect(roleCentralPosition(rolePlay, null), isNull);
  });
}
