import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/person.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/views/station_form_screen.dart';

/// DESIGN-009 prompt 3 / follow-up 3b — the Locations and Persons sections
/// in `StationFormScreen`: add/edit (through `openFormSurface` forms) and
/// swipe-to-dismiss delete for both lists, and the Persons form's home
/// picker setting `homeSlug`. No explicit surface size is set: the default
/// `flutter_test` surface (800x600) lands in the wide/medium window class,
/// so tapping a section label needs no switcher-sheet step first (see
/// `station_form_screen_variables_test.dart`), and `openFormSurface` opens
/// each entity form as a `Dialog`, not a full-screen route.

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

/// Swipes the tile showing [text] end-to-start past the dismiss threshold
/// and confirms the resulting `confirmDestructive` dialog (ADR-0031) — the
/// same drag offset and confirm-tap `roster_view_test.dart` uses for its
/// own swipe-to-delete row.
Future<void> _swipeToDeleteAndConfirm(
  WidgetTester tester,
  AppLocalizations l,
  String text,
) async {
  await tester.drag(find.text(text), const Offset(-500, 0));
  await tester.pumpAndSettle();
  await tester.tap(find.text(l.delete));
  await tester.pumpAndSettle();
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
        find.widgetWithText(TextFormField, l.locationsSectionLabelLabel),
        'Sist kjente posisjon',
      );
      await tester.tap(find.widgetWithText(FilledButton, l.save));
      await tester.pumpAndSettle();

      expect(find.text('Sist kjente posisjon'), findsOneWidget);

      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();

      expect(captured.value, isNotNull);
      expect(captured.value!.locations, hasLength(1));
      // Auto-generated (DESIGN-009 follow-up 3b) -- no manual reference field.
      expect(captured.value!.locations.single.slug, 'sist_kjente_posisjon');
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

      await tester.tap(find.text('Old label'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, l.locationsSectionLabelLabel),
        'New label',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, l.locationsSectionPlaceLabel),
        'New place',
      );
      await tester.tap(find.widgetWithText(FilledButton, l.save));
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

      await _swipeToDeleteAndConfirm(tester, l, 'Sist kjent');

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
        find.widgetWithText(TextFormField, l.roleName),
        'Anne Glemsk',
      );
      await tester.tap(find.widgetWithText(FilledButton, l.save));
      await tester.pumpAndSettle();

      expect(find.text('Anne Glemsk'), findsOneWidget);

      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();

      expect(captured.value, isNotNull);
      expect(captured.value!.persons, hasLength(1));
      // Auto-generated (DESIGN-009 follow-up 3b) -- no manual reference field.
      expect(captured.value!.persons.single.slug, 'anne_glemsk');
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

        await tester.tap(find.text('Anne Glemsk'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('home-field')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Sist kjent').last);
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(FilledButton, l.save));
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

      await tester.tap(find.text('Anne Glemsk'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, l.roleAge),
        '74',
      );
      await tester.tap(find.text(l.genderWomanLabel));
      await tester.tap(find.widgetWithText(FilledButton, l.save));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();

      expect(captured.value, isNotNull);
      final saved = captured.value!.persons.single;
      expect(saved.slug, 'anne');
      expect(saved.age, 74);
      expect(saved.gender, 'woman');
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

      await _swipeToDeleteAndConfirm(tester, l, 'Anne Glemsk');

      expect(find.text('Anne Glemsk'), findsNothing);

      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();

      expect(captured.value, isNotNull);
      expect(captured.value!.persons, isEmpty);
    });
  });

  group('auto-generated reference', () {
    testWidgets(
      'two same-named locations get distinct references',
      (tester) async {
        final captured = _Captured();
        await _openForm(tester, _station(), captured);

        await tester.tap(find.text(l.locationsSectionTitle));
        await tester.pumpAndSettle();

        for (var i = 0; i < 2; i++) {
          await tester.tap(find.text(l.locationsSectionAddAction));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.widgetWithText(TextFormField, l.locationsSectionLabelLabel),
            'Sperrepost',
          );
          await tester.tap(find.widgetWithText(FilledButton, l.save));
          await tester.pumpAndSettle();
        }

        await tester.tap(find.text(l.save));
        await tester.pumpAndSettle();

        expect(captured.value, isNotNull);
        final slugs = captured.value!.locations.map((e) => e.slug).toSet();
        expect(slugs, hasLength(2));
      },
    );

    testWidgets(
      'two same-named persons get distinct references',
      (tester) async {
        final captured = _Captured();
        await _openForm(tester, _station(), captured);

        await tester.tap(find.text(l.personsSectionTitle));
        await tester.pumpAndSettle();

        for (var i = 0; i < 2; i++) {
          await tester.tap(find.text(l.personsSectionAddAction));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.widgetWithText(TextFormField, l.roleName),
            'Ukjent',
          );
          await tester.tap(find.widgetWithText(FilledButton, l.save));
          await tester.pumpAndSettle();
        }

        await tester.tap(find.text(l.save));
        await tester.pumpAndSettle();

        expect(captured.value, isNotNull);
        final slugs = captured.value!.persons.map((e) => e.slug).toSet();
        expect(slugs, hasLength(2));
      },
    );
  });

  group('search and sort', () {
    testWidgets('the Locations list filters by search text', (tester) async {
      await _openForm(
        tester,
        _station(
          locations: const [
            Location(slug: 'lkp', label: 'Sist kjent'),
            Location(slug: 'ko', label: 'Kommandoplass'),
          ],
        ),
        _Captured(),
      );

      await tester.tap(find.text(l.locationsSectionTitle));
      await tester.pumpAndSettle();

      expect(find.text('Sist kjent'), findsOneWidget);
      expect(find.text('Kommandoplass'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, l.locationsSectionSearchHint),
        'kommando',
      );
      await tester.pumpAndSettle();

      expect(find.text('Sist kjent'), findsNothing);
      expect(find.text('Kommandoplass'), findsOneWidget);
    });

    testWidgets('the Locations section has no sort control', (tester) async {
      await _openForm(
        tester,
        _station(
          locations: const [
            Location(slug: 'z', label: 'Å', kind: LocationKind.lkp),
            Location(slug: 'a', label: 'Å', kind: LocationKind.other),
          ],
        ),
        _Captured(),
      );

      await tester.tap(find.text(l.locationsSectionTitle));
      await tester.pumpAndSettle();

      expect(find.text(l.locationsSectionSortByKind), findsNothing);
      expect(find.text(l.locationsSectionSortByLabel), findsNothing);
    });

    testWidgets('the Persons list filters by search text', (tester) async {
      await _openForm(
        tester,
        _station(
          persons: const [
            Person(slug: 'anne', name: 'Anne Glemsk'),
            Person(slug: 'ola', name: 'Ola Nordmann'),
          ],
        ),
        _Captured(),
      );

      await tester.tap(find.text(l.personsSectionTitle));
      await tester.pumpAndSettle();

      expect(find.text('Anne Glemsk'), findsOneWidget);
      expect(find.text('Ola Nordmann'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, l.personsSectionSearchHint),
        'ola',
      );
      await tester.pumpAndSettle();

      expect(find.text('Anne Glemsk'), findsNothing);
      expect(find.text('Ola Nordmann'), findsOneWidget);
    });
  });

  group('openFormSurface surface', () {
    testWidgets('the Location form opens as a dialog on wide', (
      tester,
    ) async {
      await _openForm(tester, _station(), _Captured());

      await tester.tap(find.text(l.locationsSectionTitle));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.locationsSectionAddAction));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);
    });

    testWidgets('the Location form opens full-screen (no Dialog) on narrow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _openForm(tester, _station(), _Captured());

      // Narrow layout: the section switcher is a bottom sheet, not a rail.
      await tester.tap(find.text(l.station(1)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.locationsSectionTitle));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.locationsSectionAddAction));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
      expect(find.text(l.locationsSectionAddAction), findsWidgets);
    });
  });

  testWidgets(
    'no user-facing "slug" wording appears in either section or form',
    (tester) async {
      await _openForm(
        tester,
        _station(
          locations: const [Location(slug: 'lkp', label: 'Sist kjent')],
          persons: const [Person(slug: 'anne', name: 'Anne Glemsk')],
        ),
        _Captured(),
      );

      await tester.tap(find.text(l.locationsSectionTitle));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.locationsSectionAddAction));
      await tester.pumpAndSettle();
      expect(find.textContaining('slug'), findsNothing);
      expect(find.textContaining('Slug'), findsNothing);
      await tester.tap(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(l.personsSectionTitle));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.personsSectionAddAction));
      await tester.pumpAndSettle();
      expect(find.textContaining('slug'), findsNothing);
      expect(find.textContaining('Slug'), findsNothing);
    },
  );
}
