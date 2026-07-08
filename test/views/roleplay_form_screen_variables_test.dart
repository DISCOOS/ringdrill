import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/person.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/views/roleplay_form_screen.dart';

/// DESIGN-008 follow-up 07 — the section-navigated `RolePlayFormScreen`:
/// token-aware markdown fields resolving at the roleplay's station scope,
/// no Variabler section, and save-time undeclared-token validation. No
/// explicit surface size is set: the default `flutter_test` surface
/// (800x600) already lands in the wide/medium window class, so these tests
/// exercise the master/detail rail directly.

RolePlay _rolePlay({
  String name = 'Anna Hansen',
  int? stationIndex,
  String? behavior,
}) => RolePlay(
  uuid: 'role-1',
  index: 0,
  exerciseUuid: 'ex-1',
  name: name,
  stationIndex: stationIndex,
  behavior: behavior,
);

Exercise _exercise({
  List<Station> stations = const [],
  Map<String, String> variableOverrides = const {},
}) => Exercise(
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
  variableOverrides: variableOverrides,
);

class _Captured {
  RolePlayFormResult? value;
}

Future<void> _openForm(
  WidgetTester tester,
  RolePlay rolePlay,
  Exercise? exercise,
  List<DrillVariable> variables,
  _Captured captured,
) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (ctx) => TextButton(
          onPressed: () async {
            captured.value = await Navigator.push<RolePlayFormResult>(
              ctx,
              MaterialPageRoute(
                builder: (_) => RolePlayFormScreen(
                  rolePlay: rolePlay,
                  exercise: exercise,
                  variables: variables,
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

  testWidgets('there is no Variabler section', (tester) async {
    await _openForm(tester, _rolePlay(), _exercise(), const [
      DrillVariable(name: 'frekvens', value: 'Kanal 6'),
    ], _Captured());

    expect(find.text(l.variablesSectionTitle), findsNothing);
  });

  testWidgets(
    'a token-aware field resolves at the roleplay\'s station scope: station '
    'override shadows exercise override shadows program default',
    (tester) async {
      final station = Station(
        index: 0,
        name: 'Post 1',
        variableOverrides: const {'frekvens': 'Kanal 9'},
      );
      await _openForm(
        tester,
        _rolePlay(stationIndex: 0, behavior: 'x'),
        _exercise(
          stations: [station],
          variableOverrides: const {'frekvens': 'Kanal 8'},
        ),
        const [DrillVariable(name: 'frekvens', value: 'Kanal 6')],
        _Captured(),
      );

      await tester.tap(find.text(l.roleBehavior));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'x /');
      await tester.pump();
      await tester.pump();

      expect(find.text('frekvens'), findsOneWidget);
      expect(find.text('Kanal 9'), findsOneWidget);
      expect(find.text('Kanal 8'), findsNothing);
      expect(find.text('Kanal 6'), findsNothing);
    },
  );

  testWidgets(
    'a token-aware field offers the linked station\'s locations/persons '
    '(DESIGN-009 follow-up 4) and chips a known reference blue',
    (tester) async {
      final station = Station(
        index: 0,
        name: 'Post 1',
        locations: const [Location(slug: 'lkp', place: 'Sentrum')],
        persons: const [Person(slug: 'anne', name: 'Anne Glemsk')],
      );
      await _openForm(
        tester,
        _rolePlay(stationIndex: 0, behavior: 'x'),
        _exercise(stations: [station]),
        const [],
        _Captured(),
      );

      await tester.tap(find.text(l.roleBehavior));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField));
      // Narrowed to each station namespace explicitly (DESIGN-009 follow-up
      // 4b added a dozen program/exercise plan-field entries ahead of these
      // in the unfiltered "/" list, pushing them out of the picker's fixed
      // viewport in this 800x600 test surface).
      await tester.enterText(find.byType(TextField), 'x {{station.loc.');
      await tester.pump();
      await tester.pump();

      expect(find.text('Sentrum'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'x {{station.person.');
      await tester.pump();
      await tester.pump();

      expect(find.text('Anne Glemsk'), findsWidgets);

      await tester.tap(find.text('Anne Glemsk').last);
      await tester.pump();

      expect(find.textContaining('{{station.person.anne}}'), findsOneWidget);
    },
  );

  testWidgets(
    'creating a location/person inline from a markdown field carries them '
    'up as write-back additions for the linked station (ADR-0047, '
    'DESIGN-009 follow-up 4) — the roleplay editor does not own the station',
    (tester) async {
      final station = Station(index: 0, name: 'Post 1');
      final captured = _Captured();
      await _openForm(
        tester,
        _rolePlay(name: 'Esel', stationIndex: 0, behavior: 'x'),
        _exercise(stations: [station]),
        const [],
        captured,
      );

      await tester.tap(find.text(l.roleBehavior));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'x /Sentrum');
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text(l.tokenMenuCreateLocation('Sentrum')));
      await tester.pump();

      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();

      expect(captured.value, isNotNull);
      final additions = captured.value!.additions;
      expect(
        additions.stationLocations.map((l) => l.label),
        contains('Sentrum'),
      );
      // The mandatory-personRef bootstrap (ADR-0047) also creates a Person
      // on this same station this session, so it too rides along in the
      // write-back — this editor owns neither.
      expect(additions.stationPersons, isNotEmpty);
    },
  );

  testWidgets(
    'save is blocked on an undeclared token; removing it unblocks save',
    (tester) async {
      final captured = _Captured();
      await _openForm(
        tester,
        _rolePlay(behavior: 'Bruk {{var.mangler}}'),
        _exercise(),
        const [],
        captured,
      );

      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();
      expect(captured.value, isNull);
      expect(
        find.text(l.programSaveBlockedUndeclaredVariable(l.roleBehavior)),
        findsOneWidget,
      );

      await tester.tap(find.text(l.roleBehavior));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, l.roleBehavior),
        'Bruk radio',
      );

      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();
      expect(captured.value, isNotNull);
      expect(captured.value!.rolePlay.behavior, 'Bruk radio');
    },
  );

  testWidgets(
    'save round-trips a name edit, signalement, a markdown field and props',
    (tester) async {
      final captured = _Captured();
      final station = Station(index: 0, name: 'Post 1');
      await _openForm(
        tester,
        _rolePlay(stationIndex: 0),
        _exercise(stations: [station]),
        const [],
        captured,
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Anna Hansen'),
        'Renamed',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, l.roleSignalement),
        '180 cm, mørkt hår',
      );

      await tester.tap(find.text(l.formSectionAddAction));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.roleBehavior));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, l.roleBehavior),
        'Spiller forvirret',
      );

      // The addable list is already expanded from the earlier tap above —
      // tapping "Legg til seksjon" again would toggle it closed instead.
      await tester.tap(find.text(l.catalogDiffFieldProps));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, l.catalogDiffFieldProps),
        'Rullestol',
      );

      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();

      final saved = captured.value?.rolePlay;
      expect(saved, isNotNull);
      expect(saved!.name, 'Renamed');
      expect(saved.signalement, '180 cm, mørkt hår');
      expect(saved.behavior, 'Spiller forvirret');
      expect(saved.propsMd, 'Rullestol');
      expect(saved.stationIndex, 0);
    },
  );
}
