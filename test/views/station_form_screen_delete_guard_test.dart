import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/person.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/views/station_form_screen.dart';

/// DESIGN-009 prompt 5, commit 2 — the delete-guard over the
/// station-and-down set: a `Location`/`Person` still referenced by a
/// station field, a person's `homeSlug`, or a linked roleplay is blocked
/// from deletion with a dialog listing the usages; an unreferenced one
/// deletes as before. No explicit surface size is set: the default
/// `flutter_test` surface (800x600) lands in the wide/medium window class.

Exercise _exercise({List<Station> stations = const []}) => Exercise(
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

class _Captured {
  StationFormResult? value;
}

Future<void> _openForm(
  WidgetTester tester,
  Station station,
  _Captured captured, {
  List<RolePlay> roleplays = const [],
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (ctx) => TextButton(
          onPressed: () async {
            captured.value = await Navigator.push<StationFormResult>(
              ctx,
              MaterialPageRoute(
                builder: (_) => StationFormScreen(
                  station: station,
                  parentExercise: _exercise(stations: [station]),
                  roleplays: roleplays,
                ),
              ),
            );
          },
          child: const Text('Open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

/// Swipes the tile showing [text] end-to-start past the dismiss threshold —
/// same drag offset `station_form_screen_locations_persons_test.dart` uses.
Future<void> _swipe(WidgetTester tester, String text) async {
  await tester.drag(find.text(text), const Offset(-500, 0));
  await tester.pumpAndSettle();
}

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets('deleting a location referenced in a section body is blocked, '
      'listing the field', (tester) async {
    final captured = _Captured();
    await _openForm(
      tester,
      Station(
        index: 0,
        name: 'Post 1',
        position: const LatLng(58.99, 10.43),
        locations: const [Location(slug: 'lkp', label: 'Sist kjent')],
        situationMd: 'Se {{station.loc.lkp}}.',
      ),
      captured,
    );

    await tester.tap(find.text(l.locationsSectionTitle));
    await tester.pumpAndSettle();
    await _swipe(tester, 'Sist kjent');

    expect(
      find.text(l.stationReferenceGuardTitle('Sist kjent')),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        l.stationReferenceUsageInField(l.briefSectionStationSituation),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text(l.ok));
    await tester.pumpAndSettle();

    // Still there — the guard blocked the swipe-to-delete.
    expect(find.text('Sist kjent'), findsOneWidget);
  });

  testWidgets("deleting a location that is a person's home is blocked, naming "
      'the person', (tester) async {
    final captured = _Captured();
    await _openForm(
      tester,
      Station(
        index: 0,
        name: 'Post 1',
        position: const LatLng(58.99, 10.43),
        locations: const [Location(slug: 'lkp', label: 'Sist kjent')],
        persons: const [
          Person(slug: 'anne', name: 'Anne Glemsk', homeSlug: 'lkp'),
        ],
      ),
      captured,
    );

    await tester.tap(find.text(l.locationsSectionTitle));
    await tester.pumpAndSettle();
    await _swipe(tester, 'Sist kjent');

    expect(
      find.textContaining(l.stationReferenceUsageIsPersonHome('Anne Glemsk')),
      findsOneWidget,
    );

    await tester.tap(find.text(l.ok));
    await tester.pumpAndSettle();
    expect(find.text('Sist kjent'), findsOneWidget);
  });

  testWidgets("deleting a location referenced in a linked roleplay's field is "
      'blocked, naming the roleplay', (tester) async {
    final station = Station(
      index: 0,
      name: 'Post 1',
      position: const LatLng(58.99, 10.43),
      locations: const [Location(slug: 'lkp', label: 'Sist kjent')],
    );
    final captured = _Captured();
    await _openForm(
      tester,
      station,
      captured,
      roleplays: const [
        RolePlay(
          uuid: 'rp-1',
          index: 0,
          exerciseUuid: 'ex-1',
          name: 'Anne Glemsk',
          stationIndex: 0,
          behavior: 'Sier hei ved {{station.loc.lkp}}.',
        ),
      ],
    );

    await tester.tap(find.text(l.locationsSectionTitle));
    await tester.pumpAndSettle();
    await _swipe(tester, 'Sist kjent');

    expect(
      find.textContaining(
        l.stationReferenceUsageInRoleplayField('Anne Glemsk', l.roleBehavior),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text(l.ok));
    await tester.pumpAndSettle();
    expect(find.text('Sist kjent'), findsOneWidget);
  });

  testWidgets('an unreferenced location deletes as before', (tester) async {
    final captured = _Captured();
    await _openForm(
      tester,
      Station(
        index: 0,
        name: 'Post 1',
        position: const LatLng(58.99, 10.43),
        locations: const [Location(slug: 'lkp', label: 'Sist kjent')],
      ),
      captured,
    );

    await tester.tap(find.text(l.locationsSectionTitle));
    await tester.pumpAndSettle();
    await _swipe(tester, 'Sist kjent');
    await tester.tap(find.text(l.delete));
    await tester.pumpAndSettle();

    expect(find.text('Sist kjent'), findsNothing);

    await tester.tap(find.text(l.save));
    await tester.pumpAndSettle();
    expect(captured.value!.station.locations, isEmpty);
  });

  testWidgets('deleting a person referenced in a section body is blocked', (
    tester,
  ) async {
    final captured = _Captured();
    await _openForm(
      tester,
      Station(
        index: 0,
        name: 'Post 1',
        position: const LatLng(58.99, 10.43),
        persons: const [Person(slug: 'anne', name: 'Anne Glemsk')],
        situationMd: 'Snakk med {{station.person.anne}}.',
      ),
      captured,
    );

    await tester.tap(find.text(l.personsSectionTitle));
    await tester.pumpAndSettle();
    await _swipe(tester, 'Anne Glemsk');

    expect(
      find.text(l.stationReferenceGuardTitle('Anne Glemsk')),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        l.stationReferenceUsageInField(l.briefSectionStationSituation),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text(l.ok));
    await tester.pumpAndSettle();
    expect(find.text('Anne Glemsk'), findsOneWidget);
  });

  testWidgets('deleting a person portrayed by a linked roleplay is blocked, '
      'naming the roleplay', (tester) async {
    final station = Station(
      index: 0,
      name: 'Post 1',
      position: const LatLng(58.99, 10.43),
      persons: const [Person(slug: 'anne', name: 'Anne Glemsk')],
    );
    final captured = _Captured();
    await _openForm(
      tester,
      station,
      captured,
      roleplays: const [
        RolePlay(
          uuid: 'rp-1',
          index: 0,
          exerciseUuid: 'ex-1',
          name: 'Anne Glemsk',
          stationIndex: 0,
          personRef: 'anne',
        ),
      ],
    );

    await tester.tap(find.text(l.personsSectionTitle));
    await tester.pumpAndSettle();
    await _swipe(tester, 'Anne Glemsk');

    expect(
      find.textContaining(l.stationReferenceUsagePortrayedBy('Anne Glemsk')),
      findsOneWidget,
    );

    await tester.tap(find.text(l.ok));
    await tester.pumpAndSettle();
    expect(find.text('Anne Glemsk'), findsOneWidget);
  });

  testWidgets('an unreferenced person deletes as before', (tester) async {
    final captured = _Captured();
    await _openForm(
      tester,
      Station(
        index: 0,
        name: 'Post 1',
        position: const LatLng(58.99, 10.43),
        persons: const [Person(slug: 'anne', name: 'Anne Glemsk')],
      ),
      captured,
    );

    await tester.tap(find.text(l.personsSectionTitle));
    await tester.pumpAndSettle();
    await _swipe(tester, 'Anne Glemsk');
    await tester.tap(find.text(l.delete));
    await tester.pumpAndSettle();

    expect(find.text('Anne Glemsk'), findsNothing);

    await tester.tap(find.text(l.save));
    await tester.pumpAndSettle();
    expect(captured.value!.station.persons, isEmpty);
  });
}
