import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/person.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/views/roleplay_form_screen.dart';

/// DESIGN-009 follow-up 4, commit 3 — `RolePlayFormScreen`'s Person binding:
/// the `personRef` selector, inherit-or-override identity fields, the
/// effective-identity preview, and the mandatory-personRef-once-a-station-
/// is-selected invariant (ADR-0047). No default surface size is set: the
/// default `flutter_test` surface (800x600) lands in the wide/medium window
/// class, matching `roleplay_form_screen_variables_test.dart`.

RolePlay _rolePlay({
  String name = 'Anna Hansen',
  int? stationIndex,
  String? personRef,
}) => RolePlay(
  uuid: 'role-1',
  index: 0,
  exerciseUuid: 'ex-1',
  name: name,
  stationIndex: stationIndex,
  personRef: personRef,
);

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
  RolePlay? value;
}

Future<void> _openForm(
  WidgetTester tester,
  RolePlay rolePlay,
  Exercise? exercise,
  _Captured captured,
) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (ctx) => TextButton(
          onPressed: () async {
            captured.value = await Navigator.push<RolePlay>(
              ctx,
              MaterialPageRoute(
                builder: (_) =>
                    RolePlayFormScreen(rolePlay: rolePlay, exercise: exercise),
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
    'a brand-new roleplay on a station with no persons auto-creates one '
    'from the typed identity — no extra authoring step',
    (tester) async {
      final station = Station(index: 0, name: 'Post 1');
      final captured = _Captured();
      await _openForm(
        tester,
        _rolePlay(name: 'Esel', stationIndex: 0),
        _exercise(stations: [station]),
        captured,
      );

      // The dropdown already has a selection (no validation error) even
      // though the station started with zero persons.
      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();

      expect(captured.value, isNotNull);
      expect(captured.value!.personRef, isNotNull);
    },
  );

  testWidgets(
    'selecting an existing person fills inherited identity fields',
    (tester) async {
      final station = Station(
        index: 0,
        name: 'Post 1',
        persons: const [
          Person(
            slug: 'anne',
            name: 'Anne Glemsk',
            age: 47,
            gender: 'woman',
            signalement: 'Rød jakke',
          ),
        ],
      );
      await _openForm(
        tester,
        _rolePlay(name: '', stationIndex: 0),
        _exercise(stations: [station]),
        _Captured(),
      );

      await tester.tap(find.byKey(const Key('person-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Anne Glemsk').last);
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(TextFormField, 'Anne Glemsk'),
        findsOneWidget,
      );
      expect(find.text('47'), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, 'Rød jakke'),
        findsOneWidget,
      );
      // Every field still matches the person's own value: inherited, not
      // overridden.
      expect(find.text(l.rolePlayIdentityOverride), findsNothing);
    },
  );

  testWidgets(
    'typing a different name after selecting a person marks it overridden, '
    'and the effective preview reflects the typed value',
    (tester) async {
      final station = Station(
        index: 0,
        name: 'Post 1',
        persons: const [Person(slug: 'anne', name: 'Anne Glemsk', age: 47)],
      );
      await _openForm(
        tester,
        _rolePlay(name: '', stationIndex: 0),
        _exercise(stations: [station]),
        _Captured(),
      );

      await tester.tap(find.byKey(const Key('person-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Anne Glemsk').last);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Anne Glemsk'),
        'Anne (spilt av Kari)',
      );
      await tester.pump();

      expect(find.text(l.rolePlayIdentityOverride), findsOneWidget);
      expect(
        find.textContaining('Anne (spilt av Kari)'),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'save writes the effective identity and personRef',
    (tester) async {
      final station = Station(
        index: 0,
        name: 'Post 1',
        persons: const [Person(slug: 'anne', name: 'Anne Glemsk', age: 47)],
      );
      final captured = _Captured();
      await _openForm(
        tester,
        _rolePlay(name: '', stationIndex: 0),
        _exercise(stations: [station]),
        captured,
      );

      await tester.tap(find.byKey(const Key('person-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Anne Glemsk').last);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Anne Glemsk'),
        'Anne (spilt av Kari)',
      );

      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();

      expect(captured.value, isNotNull);
      expect(captured.value!.personRef, 'anne');
      expect(captured.value!.name, 'Anne (spilt av Kari)');
      expect(captured.value!.age, 47);
    },
  );

  testWidgets(
    'personRef is not required when no station is selected',
    (tester) async {
      final captured = _Captured();
      await _openForm(tester, _rolePlay(), null, captured);

      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();

      expect(captured.value, isNotNull);
      expect(captured.value!.personRef, isNull);
    },
  );

  testWidgets(
    'switching stations re-derives the person list and clears the old selection',
    (tester) async {
      final stationA = Station(
        index: 0,
        name: 'Post 1',
        persons: const [Person(slug: 'anne', name: 'Anne Glemsk')],
      );
      final stationB = Station(
        index: 1,
        name: 'Post 2',
        persons: const [Person(slug: 'ola', name: 'Ola Nordmann')],
      );
      await _openForm(
        tester,
        _rolePlay(name: 'Anne Glemsk', stationIndex: 0, personRef: 'anne'),
        _exercise(stations: [stationA, stationB]),
        _Captured(),
      );

      await tester.tap(find.byType(DropdownButtonFormField<int?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Post 2').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('person-field')));
      await tester.pumpAndSettle();

      // Station B's own person is offered; the old selection ("anne", a
      // Post 1 person) is not among the dropdown's items.
      expect(find.text('Ola Nordmann'), findsWidgets);
      expect(
        find.descendant(
          of: find.byType(DropdownMenuItem<String>),
          matching: find.text('Anne Glemsk'),
        ),
        findsNothing,
      );

      // Close the dropdown without picking anything: the old personRef was
      // cleared by the station switch, so save is now blocked again.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();
      expect(find.text(l.pleaseSelectPerson), findsOneWidget);
    },
  );

  testWidgets('the gender field renders and is saved', (tester) async {
    final station = Station(index: 0, name: 'Post 1');
    final captured = _Captured();
    await _openForm(
      tester,
      _rolePlay(name: 'Esel', stationIndex: 0),
      _exercise(stations: [station]),
      captured,
    );

    expect(find.text(l.roleGender), findsOneWidget);

    await tester.tap(find.text(l.genderWomanLabel));
    await tester.pump();

    await tester.tap(find.text(l.save));
    await tester.pumpAndSettle();

    expect(captured.value?.gender, 'woman');
  });
}
