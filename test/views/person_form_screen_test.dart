import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/person.dart';
import 'package:ringdrill/views/person_form_screen.dart';
import 'package:ringdrill/views/widgets/gender_segmented_control.dart';

/// DESIGN-009 follow-up 3b — `PersonFormScreen` in isolation: the
/// segmented gender control and the home picker's inline "Ny lokasjon"
/// creation. Hosted directly (no `StationFormScreen`/`PersonsSection`
/// around it), mirroring `location_form_screen_test.dart`.

class _Captured {
  PersonFormResult? value;
}

Future<void> _open(
  WidgetTester tester,
  _Captured captured, {
  Person? initial,
  List<Location> locations = const [],
  Set<String> existingSlugs = const {},
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (ctx) => TextButton(
          onPressed: () async {
            captured.value = await Navigator.push<PersonFormResult>(
              ctx,
              MaterialPageRoute(
                builder: (_) => PersonFormScreen(
                  existingSlugs: existingSlugs,
                  locations: locations,
                  initial: initial,
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

  testWidgets('the gender segmented control writes the woman code', (
    tester,
  ) async {
    final captured = _Captured();
    await _open(tester, captured);

    await tester.enterText(
      find.widgetWithText(TextFormField, l.roleName),
      'Anne',
    );
    await tester.tap(find.text(l.genderWomanLabel));
    await tester.tap(find.widgetWithText(FilledButton, l.save));
    await tester.pumpAndSettle();

    expect(captured.value, isNotNull);
    expect(captured.value!.person.gender, 'woman');
  });

  testWidgets('the gender segmented control writes the man code', (
    tester,
  ) async {
    final captured = _Captured();
    await _open(tester, captured);

    await tester.enterText(
      find.widgetWithText(TextFormField, l.roleName),
      'Ola',
    );
    await tester.tap(find.text(l.genderManLabel));
    await tester.tap(find.widgetWithText(FilledButton, l.save));
    await tester.pumpAndSettle();

    expect(captured.value!.person.gender, 'man');
  });

  testWidgets('a new person starts with no gender selected', (tester) async {
    final captured = _Captured();
    await _open(tester, captured);

    await tester.enterText(
      find.widgetWithText(TextFormField, l.roleName),
      'Anne',
    );
    await tester.tap(find.widgetWithText(FilledButton, l.save));
    await tester.pumpAndSettle();

    expect(captured.value!.person.gender, isNull);
  });

  testWidgets(
    'the home picker\'s "Ny lokasjon" creates a location and selects it '
    'as homeSlug',
    (tester) async {
      final captured = _Captured();
      await _open(tester, captured);

      await tester.enterText(
        find.widgetWithText(TextFormField, l.roleName),
        'Anne',
      );

      await tester.tap(find.byKey(const Key('home-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.locationsSectionAddAction).last);
      await tester.pumpAndSettle();

      // Now inside the inline-pushed LocationFormScreen, opened as a
      // Dialog on top of the still-mounted Person form (default test
      // surface is wide). Scope to the Dialog: both forms' "Name" field
      // share the exact English label text ("Name" == roleName ==
      // locationsSectionLabelLabel), so an unscoped finder is ambiguous.
      final locationDialog = find.byType(Dialog);
      await tester.enterText(
        find.descendant(
          of: locationDialog,
          matching: find.widgetWithText(
            TextFormField,
            l.locationsSectionLabelLabel,
          ),
        ),
        'Nytt hjem',
      );
      await tester.tap(
        find.descendant(
          of: locationDialog,
          matching: find.widgetWithText(FilledButton, l.save),
        ),
      );
      await tester.pumpAndSettle();

      // Back on the Person form: the new location shows as the selected home.
      expect(find.text('Nytt hjem'), findsWidgets);

      await tester.tap(find.widgetWithText(FilledButton, l.save));
      await tester.pumpAndSettle();

      expect(captured.value, isNotNull);
      final result = captured.value!;
      expect(result.newLocation, isNotNull);
      expect(result.newLocation!.label, 'Nytt hjem');
      expect(result.person.homeSlug, result.newLocation!.slug);
    },
  );

  testWidgets(
    'name and age share a row, with the gender control on its own row '
    'beneath (DESIGN-009 prompt 4g)',
    (tester) async {
      final captured = _Captured();
      await _open(tester, captured);

      final nameField = find.widgetWithText(TextFormField, l.roleName);
      final ageField = find.widgetWithText(TextFormField, l.roleAge);
      final genderControl = find.byType(GenderSegmentedControl);

      final nameTop = tester.getTopLeft(nameField).dy;
      final ageTop = tester.getTopLeft(ageField).dy;
      final genderTop = tester.getTopLeft(genderControl).dy;

      // Same row: name and age align vertically.
      expect(nameTop, ageTop);
      // Own row: the gender control sits strictly below that row.
      expect(genderTop, greaterThan(nameTop));
    },
  );

  testWidgets('the home picker label reads "Lokasjon" (nb)', (tester) async {
    final lNb = await AppLocalizations.delegate.load(const Locale('nb'));
    final captured = _Captured();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('nb'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (ctx) => TextButton(
            onPressed: () async {
              captured.value = await Navigator.push<PersonFormResult>(
                ctx,
                MaterialPageRoute(
                  builder: (_) => const PersonFormScreen(
                    existingSlugs: {},
                    locations: [],
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

    expect(find.text(lNb.personsSectionHomeLabel), findsOneWidget);
    expect(find.text('Bopel'), findsNothing);
  });

  testWidgets('editing leaves the reference unchanged', (tester) async {
    final captured = _Captured();
    await _open(
      tester,
      captured,
      initial: const Person(slug: 'anne', name: 'Anne Glemsk'),
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, l.roleName),
      'Anne Nordmann',
    );
    await tester.tap(find.widgetWithText(FilledButton, l.save));
    await tester.pumpAndSettle();

    expect(captured.value!.person.slug, 'anne');
    expect(captured.value!.person.name, 'Anne Nordmann');
  });
}
