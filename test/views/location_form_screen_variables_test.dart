import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/person.dart';
import 'package:ringdrill/views/location_form_screen.dart';
import 'package:ringdrill/views/widgets/plan_scope.dart';
import 'package:ringdrill/views/widgets/resolve_scoped_field.dart';
import 'package:ringdrill/views/widgets/station_scope.dart';

/// DESIGN-009 follow-up 4e — `LocationFormScreen`'s `place`/`note` fields:
/// token-aware chip rendering, the insertion menu (plan variables and
/// `station.loc/person.*` cross-references), the self-reference rule (the
/// `place` field withholds its own `station.loc.<self>.place` facet and
/// bare default; `note` has no matching facet to withhold in the first
/// place), and the save-time unresolved-reference block (ADR-0047). No
/// preview toggle exists on this plain (non-section-navigated) form, so
/// resolution is checked via `resolveScopedField` directly — mirroring
/// `roleplay_form_screen_reference_integrity_test.dart`'s own save-block
/// shape for the rest.

class _Captured {
  LocationFormResult? value;
}

Future<void> _open(
  WidgetTester tester,
  _Captured captured, {
  Location? initial,
  Set<String> existingSlugs = const {},
  List<DrillVariable> variables = const [],
  List<Location> stationLocations = const [],
  List<Person> stationPersons = const [],
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (ctx) => TextButton(
          onPressed: () async {
            captured.value = await Navigator.push<LocationFormResult>(
              ctx,
              MaterialPageRoute(
                builder: (_) => PlanScope(
                  variables: variables,
                  child: StationScope(
                    locations: stationLocations,
                    persons: stationPersons,
                    child: LocationFormScreen(
                      existingSlugs: existingSlugs,
                      initial: initial,
                    ),
                  ),
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

  testWidgets(
    'the place field offers a declared plan variable and inserts its '
    'exact token',
    (tester) async {
      final captured = _Captured();
      await _open(
        tester,
        captured,
        variables: const [DrillVariable(name: 'kanal', value: 'Kanal 6')],
      );

      final placeField = find.widgetWithText(
        TextFormField,
        l.locationsSectionPlaceLabel,
      );
      await tester.ensureVisible(placeField);
      await tester.enterText(placeField, '{{var.');
      await tester.pump();
      await tester.pump();

      expect(find.text('kanal'), findsOneWidget);

      await tester.tap(find.text('kanal'));
      await tester.pump();

      expect(find.textContaining('{{var.kanal}}'), findsOneWidget);
    },
  );

  testWidgets(
    'the place field offers other locations but withholds its own place '
    'facet and bare default (self-reference rule, DESIGN-009)',
    (tester) async {
      final captured = _Captured();
      await _open(
        tester,
        captured,
        initial: const Location(slug: 'lkp', label: 'LKP', place: 'Sentrum'),
        stationLocations: const [
          Location(slug: 'lkp', label: 'LKP', place: 'Sentrum'),
          Location(slug: 'obs', label: 'Utkikkspost', place: 'Åsen'),
        ],
      );

      final placeField = find.widgetWithText(
        TextFormField,
        l.locationsSectionPlaceLabel,
      );
      await tester.ensureVisible(placeField);
      await tester.enterText(placeField, '{{station.loc.');
      await tester.pump();
      await tester.pump();

      final menu = find.byType(ListView);
      expect(
        find.descendant(of: menu, matching: find.text('Utkikkspost')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: menu, matching: find.text('LKP')),
        findsNothing,
      );

      await tester.enterText(placeField, '{{station.loc.lkp.');
      await tester.pump();
      await tester.pump();

      expect(
        find.descendant(
          of: menu,
          matching: find.text(l.locationsSectionLabelLabel),
        ),
        findsOneWidget,
      );
      expect(find.descendant(of: menu, matching: find.text(l.utm)), findsOneWidget);
      expect(
        find.descendant(
          of: menu,
          matching: find.text(l.locationsSectionPlaceLabel),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'an unresolved station.loc reference in the note field blocks save; '
    'removing it unblocks',
    (tester) async {
      final captured = _Captured();
      await _open(tester, captured);

      await tester.enterText(
        find.widgetWithText(TextFormField, l.locationsSectionLabelLabel),
        'LKP',
      );
      final noteField = find.widgetWithText(
        TextFormField,
        l.locationsSectionNoteLabel,
      );
      await tester.ensureVisible(noteField);
      await tester.enterText(noteField, 'Se {{station.loc.ghost}}.');

      await tester.tap(find.widgetWithText(FilledButton, l.save));
      await tester.pumpAndSettle();

      expect(captured.value, isNull);
      expect(
        find.text(
          l.saveBlockedUnresolvedReference(
            l.locationsSectionNoteLabel,
            'station.loc.ghost',
          ),
        ),
        findsOneWidget,
      );

      await tester.enterText(noteField, 'Se stedet.');
      await tester.tap(find.widgetWithText(FilledButton, l.save));
      await tester.pumpAndSettle();

      expect(captured.value, isNotNull);
      expect(captured.value!.location.note, 'Se stedet.');
    },
  );

  testWidgets(
    'a var.* token entered in the note field resolves via '
    'resolveScopedField -- no preview toggle on this plain form, so the '
    "brief's own fixpoint pass is what catches it once saved (no renderer "
    'change needed)',
    (tester) async {
      final captured = _Captured();
      await _open(
        tester,
        captured,
        variables: const [DrillVariable(name: 'kanal', value: 'Kanal 6')],
      );

      final noteField = find.widgetWithText(
        TextFormField,
        l.locationsSectionNoteLabel,
      );
      await tester.ensureVisible(noteField);
      await tester.enterText(noteField, 'Bruk {{var.kanal}}.');
      await tester.pump();

      final context = tester.element(find.byType(LocationFormScreen));
      expect(
        resolveScopedField(context, 'Bruk {{var.kanal}}.'),
        'Bruk Kanal 6.',
      );
    },
  );

  testWidgets(
    'the place field offers "Create variable" when nothing matches; '
    'selecting it inserts the token and carries the new variable up as a '
    'write-back addition (ADR-0047, DESIGN-009 "Inline creation and '
    'write-back")',
    (tester) async {
      final captured = _Captured();
      await _open(tester, captured);

      await tester.enterText(
        find.widgetWithText(TextFormField, l.locationsSectionLabelLabel),
        'LKP',
      );

      final placeField = find.widgetWithText(
        TextFormField,
        l.locationsSectionPlaceLabel,
      );
      await tester.ensureVisible(placeField);
      await tester.enterText(placeField, '{{var.frekvens');
      await tester.pump();
      await tester.pump();

      expect(find.text(l.tokenMenuCreateVariable('frekvens')), findsOneWidget);
      await tester.tap(find.text(l.tokenMenuCreateVariable('frekvens')));
      await tester.pump();

      expect(find.textContaining('{{var.frekvens}}'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, l.save));
      await tester.pumpAndSettle();

      expect(captured.value, isNotNull);
      expect(
        captured.value!.additions.variables.map((v) => v.name),
        contains('frekvens'),
      );
    },
  );

  testWidgets(
    'the note field offers "Create location «x»" when nothing matches; '
    'selecting it carries the new sibling location up as a write-back '
    'addition',
    (tester) async {
      final captured = _Captured();
      await _open(tester, captured);

      await tester.enterText(
        find.widgetWithText(TextFormField, l.locationsSectionLabelLabel),
        'LKP',
      );

      final noteField = find.widgetWithText(
        TextFormField,
        l.locationsSectionNoteLabel,
      );
      await tester.ensureVisible(noteField);
      await tester.enterText(noteField, 'Se {{station.loc.sentrum');
      await tester.pump();
      await tester.pump();

      expect(find.text(l.tokenMenuCreateLocation('sentrum')), findsOneWidget);
      await tester.tap(find.text(l.tokenMenuCreateLocation('sentrum')));
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, l.save));
      await tester.pumpAndSettle();

      expect(captured.value, isNotNull);
      expect(
        captured.value!.additions.stationLocations.map((loc) => loc.label),
        contains('sentrum'),
      );
    },
  );
}
