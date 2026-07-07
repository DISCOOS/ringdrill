import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/person.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/views/station_form_screen.dart';

/// DESIGN-009 prompt 3 — the Locations and Persons sections in
/// `StationFormScreen`: add/edit/delete for both lists, and the Persons
/// row's home picker setting `homeSlug`. No explicit surface size is set:
/// the default `flutter_test` surface (800x600) lands in the wide/medium
/// window class, so tapping a section label needs no switcher-sheet step
/// first (see `station_form_screen_variables_test.dart`).

Station _station({
  List<Location> locations = const [],
  List<Person> persons = const [],
}) => Station(
  index: 0,
  name: 'Post 1',
  position: const LatLng(58.99, 10.43),
  locations: locations,
  persons: persons,
);

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
  Station? value;
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
            captured.value = await Navigator.push<Station>(
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

/// The `⋮` row-action menu for the row whose label text is [text]. Scoped
/// to that row rather than a bare `find.byIcon(Icons.more_vert)`, since
/// `SectionNavigatedForm`'s own overflow control always renders one too
/// (see `program_form_screen_variables_declaration_test.dart`'s
/// `_variableRowMenu`, the same pattern).
Finder _rowMenu(String text) {
  final row = find.ancestor(of: find.text(text), matching: find.byType(Row));
  return find.descendant(of: row, matching: find.byIcon(Icons.more_vert)).first;
}

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  group('Locations section', () {
    testWidgets('adding a location writes it to locations on save', (
      tester,
    ) async {
      final captured = _Captured();
      await _openForm(tester, _station(), captured);

      await tester.tap(find.text(l.locationsSectionTitle));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l.locationsSectionAddAction));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, l.locationsSectionSlugLabel),
        'lkp',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, l.locationsSectionLabelLabel),
        'Sist kjente posisjon',
      );
      await tester.tap(
        find.widgetWithText(FilledButton, l.locationsSectionAddAction),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sist kjente posisjon'), findsOneWidget);

      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();

      expect(captured.value, isNotNull);
      expect(captured.value!.locations, hasLength(1));
      expect(captured.value!.locations.single.slug, 'lkp');
      expect(
        captured.value!.locations.single.label,
        'Sist kjente posisjon',
      );
      expect(captured.value!.locations.single.kind, LocationKind.other);
    });

    testWidgets('editing a location\'s fields persists, slug unchanged', (
      tester,
    ) async {
      final captured = _Captured();
      await _openForm(
        tester,
        _station(
          locations: const [
            Location(slug: 'lkp', label: 'Old label', place: 'Old place'),
          ],
        ),
        captured,
      );

      await tester.tap(find.text(l.locationsSectionTitle));
      await tester.pumpAndSettle();

      await tester.tap(_rowMenu('Old label'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.locationsSectionEditAction));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, l.locationsSectionLabelLabel),
        'New label',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, l.locationsSectionPlaceLabel),
        'New place',
      );
      await tester.tap(
        find.widgetWithText(FilledButton, l.locationsSectionEditAction),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();

      expect(captured.value, isNotNull);
      final saved = captured.value!.locations.single;
      expect(saved.slug, 'lkp');
      expect(saved.label, 'New label');
      expect(saved.place, 'New place');
    });

    testWidgets('deleting a location removes it', (tester) async {
      final captured = _Captured();
      await _openForm(
        tester,
        _station(
          locations: const [Location(slug: 'lkp', label: 'Sist kjent')],
        ),
        captured,
      );

      await tester.tap(find.text(l.locationsSectionTitle));
      await tester.pumpAndSettle();

      await tester.tap(_rowMenu('Sist kjent'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.locationsSectionDeleteAction));
      await tester.pumpAndSettle();

      expect(find.text('Sist kjent'), findsNothing);

      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();

      expect(captured.value, isNotNull);
      expect(captured.value!.locations, isEmpty);
    });
  });

  group('Persons section', () {
    testWidgets('adding a person writes it to persons on save', (
      tester,
    ) async {
      final captured = _Captured();
      await _openForm(tester, _station(), captured);

      await tester.tap(find.text(l.personsSectionTitle));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l.personsSectionAddAction));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, l.personsSectionSlugLabel),
        'anne',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, l.roleName),
        'Anne Glemsk',
      );
      await tester.tap(
        find.widgetWithText(FilledButton, l.personsSectionAddAction),
      );
      await tester.pumpAndSettle();

      expect(find.text('Anne Glemsk'), findsOneWidget);

      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();

      expect(captured.value, isNotNull);
      expect(captured.value!.persons, hasLength(1));
      expect(captured.value!.persons.single.slug, 'anne');
      expect(captured.value!.persons.single.name, 'Anne Glemsk');
    });

    testWidgets(
      'the home picker sets a person\'s homeSlug to a station location',
      (tester) async {
        final captured = _Captured();
        await _openForm(
          tester,
          _station(
            locations: const [Location(slug: 'lkp', label: 'Sist kjent')],
            persons: const [Person(slug: 'anne', name: 'Anne Glemsk')],
          ),
          captured,
        );

        await tester.tap(find.text(l.personsSectionTitle));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('home-field')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Sist kjent').last);
        await tester.pumpAndSettle();

        await tester.tap(find.text(l.save));
        await tester.pumpAndSettle();

        expect(captured.value, isNotNull);
        expect(captured.value!.persons.single.homeSlug, 'lkp');
      },
    );

    testWidgets('editing a person\'s fields persists, slug unchanged', (
      tester,
    ) async {
      final captured = _Captured();
      await _openForm(
        tester,
        _station(
          persons: const [Person(slug: 'anne', name: 'Anne Glemsk')],
        ),
        captured,
      );

      await tester.tap(find.text(l.personsSectionTitle));
      await tester.pumpAndSettle();

      await tester.tap(_rowMenu('Anne Glemsk'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.personsSectionEditAction));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, l.roleAge),
        '74',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, l.roleGender),
        'kvinne',
      );
      await tester.tap(
        find.widgetWithText(FilledButton, l.personsSectionEditAction),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();

      expect(captured.value, isNotNull);
      final saved = captured.value!.persons.single;
      expect(saved.slug, 'anne');
      expect(saved.age, 74);
      expect(saved.gender, 'kvinne');
    });

    testWidgets('deleting a person removes it', (tester) async {
      final captured = _Captured();
      await _openForm(
        tester,
        _station(
          persons: const [Person(slug: 'anne', name: 'Anne Glemsk')],
        ),
        captured,
      );

      await tester.tap(find.text(l.personsSectionTitle));
      await tester.pumpAndSettle();

      await tester.tap(_rowMenu('Anne Glemsk'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.personsSectionDeleteAction));
      await tester.pumpAndSettle();

      expect(find.text('Anne Glemsk'), findsNothing);

      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();

      expect(captured.value, isNotNull);
      expect(captured.value!.persons, isEmpty);
    });
  });
}
