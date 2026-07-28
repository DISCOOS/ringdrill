import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/person.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/views/station_form_screen.dart';

/// DESIGN-009 prompt 5, commit 1 — `StationFormScreen`'s save-block on an
/// unresolved `station.loc.<slug>`/`station.person.<slug>` reference,
/// mirroring the existing `{{var.*}}` undeclared-name save-block. No
/// explicit surface size is set: the default `flutter_test` surface
/// (800x600) lands in the wide/medium window class.

Exercise _exercise() => Exercise(
  uuid: 'ex-1',
  name: 'Exercise',
  startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
  endTime: const SimpleTimeOfDay(hour: 9, minute: 0),
  numberOfTeams: 1,
  numberOfRounds: 1,
  executionTime: 10,
  evaluationTime: 5,
  rotationTime: 5,
  stations: const [],
  schedule: const [],
);

class _Captured {
  StationFormResult? value;
}

Future<void> _openForm(
  WidgetTester tester,
  Station station,
  _Captured captured,
) async {
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
                  parentExercise: _exercise(),
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

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  Station stationWith({
    String? situationMd,
    List<Location> locations = const [],
    List<Person> persons = const [],
  }) => Station(
    index: 0,
    name: 'Post 1',
    position: const LatLng(58.99, 10.43),
    situationMd: situationMd,
    locations: locations,
    persons: persons,
  );

  testWidgets(
    'a field with an unresolved station.loc reference blocks save and '
    'names the field and the broken reference',
    (tester) async {
      final captured = _Captured();
      await _openForm(
        tester,
        stationWith(situationMd: 'Se {{station.loc.ghost}}.'),
        captured,
      );

      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();

      expect(captured.value, isNull);
      expect(
        find.text(
          l.saveBlockedUnresolvedReference(
            l.briefSectionStationSituation,
            'station.loc.ghost',
          ),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('removing the broken token unblocks save', (tester) async {
    final captured = _Captured();
    await _openForm(
      tester,
      stationWith(situationMd: 'Se {{station.loc.ghost}}.'),
      captured,
    );

    await tester.tap(find.text(l.save));
    await tester.pumpAndSettle();
    expect(captured.value, isNull);

    await tester.tap(find.text(l.briefSectionStationSituation));
    await tester.pumpAndSettle();
    // The section field has no floating label (8d7acf9 dropped it as a
    // dup of the switcher/rail name); only one section is mounted at a
    // time, so its field is the sole TextFormField in the tree.
    await tester.enterText(find.byType(TextFormField), 'Ingen referanse her.');
    await tester.tap(find.text(l.save));
    await tester.pumpAndSettle();

    expect(captured.value, isNotNull);
    expect(captured.value!.station.situationMd, 'Ingen referanse her.');
  });

  testWidgets('resolving the reference (adding the location) unblocks save', (
    tester,
  ) async {
    final captured = _Captured();
    await _openForm(
      tester,
      stationWith(situationMd: 'Se {{station.loc.ghost}}.'),
      captured,
    );

    // Add a location whose slug matches the token via the Locations section.
    await tester.tap(find.text(l.locationsSectionTitle));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.locationsSectionAddAction));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, l.locationsSectionLabelLabel),
      'Ghost',
    );
    await tester.tap(find.widgetWithText(FilledButton, l.formDoneAction));
    await tester.pumpAndSettle();

    // The newly created location gets a random slug, not "ghost" — so
    // save is still blocked on the original literal token.
    await tester.tap(find.text(l.save));
    await tester.pumpAndSettle();
    expect(captured.value, isNull);
  });

  testWidgets('a valid station.person reference saves', (tester) async {
    final captured = _Captured();
    await _openForm(
      tester,
      stationWith(
        situationMd: 'Snakk med {{station.person.kari}}.',
        persons: const [Person(slug: 'kari', name: 'Kari')],
      ),
      captured,
    );

    await tester.tap(find.text(l.save));
    await tester.pumpAndSettle();

    expect(captured.value, isNotNull);
    expect(
      captured.value!.station.situationMd,
      'Snakk med {{station.person.kari}}.',
    );
  });

  testWidgets('a faceted token keys on the same slug as the bare token', (
    tester,
  ) async {
    final captured = _Captured();
    await _openForm(
      tester,
      stationWith(situationMd: 'Se {{station.loc.ghost.place}}.'),
      captured,
    );

    await tester.tap(find.text(l.save));
    await tester.pumpAndSettle();

    expect(captured.value, isNull);
    expect(
      find.text(
        l.saveBlockedUnresolvedReference(
          l.briefSectionStationSituation,
          'station.loc.ghost',
        ),
      ),
      findsOneWidget,
    );
  });
}
