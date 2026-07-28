import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/person.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/views/roleplay_form_screen.dart';
import 'package:ringdrill/views/station_form_screen.dart';

/// DESIGN-009 prompt 4j — authoring a marker from the post editor's Persons
/// section: "Legg til spill" opens the RolePlay editor with the post and
/// person pre-set; saving returns to the post editor, where the person
/// shows the marker inline; the new roleplay rides the post editor's own
/// [PlanAdditions] write-back rather than being saved directly.

Station _station({List<Person> persons = const []}) =>
    Station(index: 0, name: 'Post 1', persons: persons);

Exercise _exercise(Station station) => Exercise(
  uuid: 'ex-1',
  name: 'Exercise',
  startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
  endTime: const SimpleTimeOfDay(hour: 9, minute: 0),
  numberOfTeams: 1,
  numberOfRounds: 1,
  executionTime: 10,
  evaluationTime: 5,
  rotationTime: 5,
  stations: [station],
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
                  parentExercise: _exercise(station),
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

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets(
    '"Legg til spill" opens the RolePlay editor with the post and person '
    'pre-set; saving shows the marker inline and rides the write-back',
    (tester) async {
      final station = _station(
        persons: const [Person(slug: 'anne', name: 'Anne Glemsk', age: 47)],
      );
      final captured = _Captured();
      await _openForm(tester, station, captured);

      await tester.tap(find.text(l.personsSectionTitle));
      await tester.pumpAndSettle();

      expect(find.text(l.personsSectionAddMarkerAction), findsOneWidget);
      await tester.tap(find.text(l.personsSectionAddMarkerAction));
      await tester.pumpAndSettle();

      // Landed on the RolePlay editor, not the person picker — post and
      // person are already resolved.
      expect(find.byType(RolePlayFormScreen), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('station-field')),
          matching: find.text('Post 1'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('person-field')),
          matching: find.text('Anne Glemsk'),
        ),
        findsOneWidget,
      );

      // The previous (station editor) route stays mounted underneath while
      // the roleplay editor is pushed, so scope the tap to the nested
      // editor's own AppBar action.
      await tester.tap(
        find.descendant(
          of: find.byType(RolePlayFormScreen),
          matching: find.text(l.formDoneAction),
        ),
      );
      await tester.pumpAndSettle();

      // Back on the post editor: the person's card now shows the marker
      // inline instead of "Legg til spill". The marker is enacted but not yet
      // cast (actors are assigned close to execution), so the row reads the
      // no-cast line rather than naming anyone.
      expect(find.byType(RolePlayFormScreen), findsNothing);
      expect(find.text(l.personsSectionAddMarkerAction), findsNothing);
      expect(find.text(l.noCastLine), findsOneWidget);

      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();

      expect(captured.value, isNotNull);
      expect(captured.value!.additions.rolePlays, hasLength(1));
      final rolePlay = captured.value!.additions.rolePlays.single;
      expect(rolePlay.personRef, 'anne');
      expect(rolePlay.stationIndex, 0);
      expect(rolePlay.exerciseUuid, 'ex-1');
      expect(rolePlay.name, 'Anne Glemsk');
    },
  );

  testWidgets(
    'tapping an existing marker inline opens it in the RolePlay editor; '
    'editing rides the same write-back',
    (tester) async {
      final station = _station(
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

      // The uncast marker shows the no-cast line inline; tapping it opens the
      // RolePlay editor.
      expect(find.text(l.noCastLine), findsOneWidget);
      await tester.tap(find.text(l.noCastLine));
      await tester.pumpAndSettle();

      expect(find.byType(RolePlayFormScreen), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('identity-disclosure')));
      await tester.tap(find.byKey(const Key('identity-disclosure')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Anne Glemsk'),
        'Kari',
      );
      await tester.tap(
        find.descendant(
          of: find.byType(RolePlayFormScreen),
          matching: find.text(l.formDoneAction),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(RolePlayFormScreen), findsNothing);
      // Still enacted and still uncast, so the row keeps the no-cast line; the
      // renamed identity rides the write-back (asserted below).
      expect(find.text(l.noCastLine), findsOneWidget);

      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();

      expect(captured.value, isNotNull);
      expect(captured.value!.additions.rolePlays, hasLength(1));
      expect(captured.value!.additions.rolePlays.single.uuid, 'rp-1');
      expect(captured.value!.additions.rolePlays.single.name, 'Kari');
    },
  );

  testWidgets('cancelling the post edit discards a marker added this session', (
    tester,
  ) async {
    final station = _station(
      persons: const [Person(slug: 'anne', name: 'Anne Glemsk')],
    );
    final captured = _Captured();
    await _openForm(tester, station, captured);

    await tester.tap(find.text(l.personsSectionTitle));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.personsSectionAddMarkerAction));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(RolePlayFormScreen),
        matching: find.text(l.formDoneAction),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(l.noCastLine), findsOneWidget);

    // Close the post editor without saving.
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(captured.value, isNull);
  });
}
