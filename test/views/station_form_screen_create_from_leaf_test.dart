import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/views/station_form_screen.dart';

/// DESIGN-010 follow-up "inline create from leaf fields" — the
/// `Location`/`Person` forms' `place`/`note`/`name`/`signalement`/`notes`
/// fields now offer the picker's "Create «x»" entries (ADR-0047, DESIGN-009
/// "Inline creation and write-back"), not just existing-entity references
/// (DESIGN-010 stage 4). This exercises the full round trip through
/// `StationFormScreen`'s own Locations/Persons sections: a leaf field
/// creates a `var.*`/sibling `station.loc.*` inline, and that write-back
/// rides all the way up to `StationFormResult` — a new variable lands in
/// `additions.variables` (ready for the plan-owning caller to apply, see
/// `station_screen.dart`'s `_addLocation`/`_addPerson`), and a new sibling
/// location lands directly on the station itself (`StationFormScreen`
/// merges it into its own working copy via `_mergeAdditions`, mirroring
/// `_openRolePlayEditor`'s existing merge).

Station _station() => const Station(index: 0, name: 'Post 1');

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

  testWidgets(
    'creating a var.* from a new location\'s place field carries it up as '
    'a write-back addition on the station form\'s own result',
    (tester) async {
      final captured = _Captured();
      await _openForm(tester, _station(), captured);

      await tester.tap(find.text(l.locationsSectionTitle));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l.locationsSectionAddAction));
      await tester.pumpAndSettle();

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

      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();

      expect(captured.value, isNotNull);
      expect(
        captured.value!.additions.variables.map((v) => v.name),
        contains('frekvens'),
      );
      expect(captured.value!.station.locations, hasLength(1));
      expect(captured.value!.station.locations.single.place, '{{var.frekvens}}');
    },
  );

  testWidgets(
    'creating a sibling station.loc.* from a new person\'s notes field '
    'lands the location on the same station, via the station form\'s own '
    'merge',
    (tester) async {
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

      final notesField = find.widgetWithText(
        TextFormField,
        l.personsSectionNotesLabel,
      );
      await tester.ensureVisible(notesField);
      await tester.enterText(notesField, '{{station.loc.sentrum');
      await tester.pump();
      await tester.pump();

      expect(find.text(l.tokenMenuCreateLocation('sentrum')), findsOneWidget);
      await tester.tap(find.text(l.tokenMenuCreateLocation('sentrum')));
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, l.save));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();

      expect(captured.value, isNotNull);
      expect(captured.value!.station.persons, hasLength(1));
      expect(
        captured.value!.station.locations.map((loc) => loc.label),
        contains('sentrum'),
      );
    },
  );
}
