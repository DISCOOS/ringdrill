import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/person.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/views/widgets/location_kind_style.dart';
import 'package:ringdrill/views/widgets/station_mini_map.dart';

/// DESIGN-009 prompt 3 — `stationMarkers` builds one marker per positioned
/// scenario `Location` alongside the administrative `Station.position`
/// marker, styled by `LocationKind` and visually distinct from it. A
/// marker-spec unit test rather than pumping a real `flutter_map` widget
/// tree, per the prompt's own alternative — nothing else in this codebase
/// pumps `MapView` yet.
void main() {
  Exercise exercise({required List<Station> stations}) => Exercise(
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

  test(
    'a location with a position and the person home it resolves through '
    'both produce a marker distinct from the position marker',
    () {
      const stationPosition = LatLng(58.99, 10.43);
      const home = Location(
        slug: 'home_anne',
        label: 'Anne sitt hus',
        kind: LocationKind.home,
        position: LatLng(59.0, 10.5),
      );
      const anne = Person(
        slug: 'anne',
        name: 'Anne',
        homeSlug: 'home_anne',
      );
      final station = Station(
        index: 0,
        name: 'Post 1',
        position: stationPosition,
        locations: const [home],
        persons: const [anne],
      );

      final markers = stationMarkers(
        exercise(stations: [station]),
        station,
      );

      expect(markers, hasLength(2));
      final positionMarker = markers.firstWhere((m) => m.id == 0);
      expect(positionMarker.point, stationPosition);

      final locationMarker = markers.firstWhere((m) => m.id != 0);
      expect(locationMarker.point, home.position);
      expect(locationMarker.label, 'Anne sitt hus');

      // Distinct icon/colour from the administrative marker and correctly
      // styled by the location's own LocationKind (ADR-0020/DESIGN-009).
      final positionIcon = positionMarker.child as Icon;
      final locationIcon = locationMarker.child as Icon;
      expect(locationIcon.icon, LocationKind.home.icon);
      expect(locationIcon.color, LocationKind.home.color);
      expect(locationIcon.icon, isNot(positionIcon.icon));
      expect(locationIcon.color, isNot(positionIcon.color));
    },
  );

  test('a location without a position produces no marker', () {
    const noPosition = Location(slug: 'ko', kind: LocationKind.commandPost);
    final station = Station(
      index: 0,
      name: 'Post 1',
      position: const LatLng(58.99, 10.43),
      locations: const [noPosition],
    );

    final markers = stationMarkers(exercise(stations: [station]), station);

    expect(markers, hasLength(1));
    expect(markers.single.id, 0);
  });

  test('a station without a position produces only location markers', () {
    const lkp = Location(
      slug: 'lkp',
      kind: LocationKind.lkp,
      position: LatLng(59.1, 10.6),
    );
    final station = Station(index: 0, name: 'Post 1', locations: const [lkp]);

    final markers = stationMarkers(exercise(stations: [station]), station);

    expect(markers, hasLength(1));
    expect(markers.single.point, lkp.position);
  });
}
