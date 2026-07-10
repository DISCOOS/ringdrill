import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/person.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/views/roleplay_form_screen.dart';

/// DESIGN-009 follow-up 4, commit 3 (superseded in shape by prompt 4i's
/// identity card) — `RolePlayFormScreen`'s Person binding: the `personRef`
/// picker (now a tap-to-choose dialog, not a dropdown), inherit-or-override
/// identity facets packed into one card, and the mandatory-personRef-once-
/// a-station-is-selected invariant (ADR-0047). No default surface size is
/// set: the default `flutter_test` surface (800x600) lands in the wide/
/// medium window class, matching `roleplay_form_screen_variables_test.dart`.

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
  RolePlayFormResult? value;
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
            captured.value = await Navigator.push<RolePlayFormResult>(
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

/// Taps the identity card's header (opens the person-picker dialog) and
/// picks the entry with [name].
Future<void> _pickPerson(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(const Key('person-field')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

/// Expands the identity card's "Tilpass" override panel.
Future<void> _expandIdentity(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('identity-disclosure')));
  await tester.pumpAndSettle();
}

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets(
    'a brand-new roleplay does not auto-create a person; save is blocked '
    'until one is selected (ADR-0047, amended 2026-07-10)',
    (tester) async {
      final station = Station(index: 0, name: 'Post 1');
      final captured = _Captured();
      // A brand-new roleplay is constructed with an empty name.
      await _openForm(
        tester,
        _rolePlay(name: '', stationIndex: 0),
        _exercise(stations: [station]),
        captured,
      );

      // No placeholder Person was manufactured, so the identity header
      // reads as a prompt and save is blocked on the mandatory personRef.
      expect(find.text(l.rolePlaySelectPersonPrompt), findsOneWidget);
      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();

      expect(captured.value, isNull);
      expect(find.text(l.pleaseSelectPerson), findsOneWidget);
    },
  );

  testWidgets(
    'identity and position are gated until a Post is selected, and the '
    'person picker offers a "+ Ny person" entry',
    (tester) async {
      final station = Station(
        index: 0,
        name: 'Post 1',
        persons: const [Person(slug: 'anne', name: 'Anne Glemsk')],
      );
      await _openForm(
        tester,
        _rolePlay(name: '', stationIndex: null),
        _exercise(stations: [station]),
        _Captured(),
      );

      // No Post chosen: the base section shows only the hint, not the
      // identity card or position picker.
      expect(find.text(l.rolePlayPostRequiredHint), findsOneWidget);
      expect(find.byKey(const Key('person-field')), findsNothing);

      // Choose the Post — identity card now appears.
      await tester.tap(find.byKey(const Key('station-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Post 1').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('person-field')), findsOneWidget);

      // The picker offers the inline create entry alongside the station's
      // own persons.
      await tester.tap(find.byKey(const Key('person-field')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(SimpleDialog),
          matching: find.text(l.personsSectionAddAction),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'selecting an existing person fills the collapsed identity card with '
    'its inherited summary',
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

      await _pickPerson(tester, 'Anne Glemsk');

      expect(
        find.descendant(
          of: find.byKey(const Key('person-field')),
          matching: find.text('Anne Glemsk'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining(l.rolePlayAgeYears(47)), findsOneWidget);
      expect(find.text('Rød jakke'), findsOneWidget);
      // Every facet still matches the person's own value: inherited, not
      // overridden — the card stays collapsed with just the "Tilpass"
      // disclosure, no per-facet text (DESIGN-009 prompt 4j).
      expect(find.text(l.rolePlayIdentityCustomizeAction), findsOneWidget);
      expect(find.byKey(const Key('identity-panel')), findsNothing);
    },
  );

  testWidgets(
    'typing a different name after selecting a person marks it overridden',
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

      await _pickPerson(tester, 'Anne Glemsk');
      await _expandIdentity(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Anne Glemsk'),
        'Anne (spilt av Kari)',
      );
      await tester.pump();

      expect(find.text(l.rolePlayIdentityResetAction), findsOneWidget);
      expect(find.textContaining('Anne (spilt av Kari)'), findsWidgets);
      // The overridden name reads "Tilpasset fra {navn}" in the collapsed
      // header, naming the underlying person (DESIGN-009 prompt 4j) —
      // superseding 4i's "Portraying {name}".
      expect(find.text(l.rolePlayCustomizedFrom('Anne Glemsk')), findsOneWidget);
    },
  );

  testWidgets('save writes the effective identity and personRef', (
    tester,
  ) async {
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

    await _pickPerson(tester, 'Anne Glemsk');
    await _expandIdentity(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Anne Glemsk'),
      'Anne (spilt av Kari)',
    );

    await tester.tap(find.text(l.save));
    await tester.pumpAndSettle();

    expect(captured.value, isNotNull);
    expect(captured.value!.rolePlay.personRef, 'anne');
    expect(captured.value!.rolePlay.name, 'Anne (spilt av Kari)');
    expect(captured.value!.rolePlay.age, 47);
  });

  testWidgets('personRef is not required when no station is selected', (
    tester,
  ) async {
    final captured = _Captured();
    await _openForm(tester, _rolePlay(), null, captured);

    await tester.tap(find.text(l.save));
    await tester.pumpAndSettle();

    expect(captured.value, isNotNull);
    expect(captured.value!.rolePlay.personRef, isNull);
  });

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

      await tester.tap(find.byKey(const Key('station-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Post 2').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('person-field')));
      await tester.pumpAndSettle();

      // Station B's own person is offered; the old selection ("anne", a
      // Post 1 person) is not among the dialog's options.
      expect(
        find.descendant(
          of: find.byType(SimpleDialog),
          matching: find.text('Ola Nordmann'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(SimpleDialog),
          matching: find.text('Anne Glemsk'),
        ),
        findsNothing,
      );

      // Close the dialog without picking anything: the old personRef was
      // cleared by the station switch, so save is now blocked again.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();
      expect(find.text(l.pleaseSelectPerson), findsOneWidget);
    },
  );

  testWidgets('the gender field renders and is saved', (tester) async {
    final station = Station(
      index: 0,
      name: 'Post 1',
      persons: const [Person(slug: 'anne', name: 'Anne Glemsk')],
    );
    final captured = _Captured();
    await _openForm(
      tester,
      _rolePlay(name: '', stationIndex: 0),
      _exercise(stations: [station]),
      captured,
    );

    // A Person must be selected before the "Tilpass" panel is available.
    await _pickPerson(tester, 'Anne Glemsk');
    await _expandIdentity(tester);
    expect(find.text(l.roleGender), findsOneWidget);

    await tester.tap(find.text(l.genderWomanLabel));
    await tester.pump();

    await tester.tap(find.text(l.save));
    await tester.pumpAndSettle();

    expect(captured.value?.rolePlay.gender, 'woman');
  });

  testWidgets(
    'a roleplay already diverged from its person auto-expands the panel '
    'with a single collective reset action, no per-field labels',
    (tester) async {
      final station = Station(
        index: 0,
        name: 'Post 1',
        persons: const [Person(slug: 'anne', name: 'Anne Glemsk', age: 47)],
      );
      // Name and age both differ from the linked person (as if this
      // roleplay was hand-crafted rather than produced by the normal
      // personRef-selection sync) — two overridden facets on open.
      final rolePlay = RolePlay(
        uuid: 'role-1',
        index: 0,
        exerciseUuid: 'ex-1',
        name: 'Kari',
        age: 30,
        stationIndex: 0,
        personRef: 'anne',
      );
      await _openForm(
        tester,
        rolePlay,
        _exercise(stations: [station]),
        _Captured(),
      );

      // Auto-expanded: the panel's own fields are already mounted, no
      // "Tilpass" tap needed. A single collective "Tilbakestill" covers
      // both overridden facets at once (DESIGN-009 prompt 4j) — not a
      // per-field count or label.
      expect(find.byKey(const Key('identity-panel')), findsOneWidget);
      expect(find.text(l.rolePlayIdentityResetAction), findsOneWidget);

      await tester.ensureVisible(find.text(l.rolePlayIdentityResetAction));
      await tester.tap(find.text(l.rolePlayIdentityResetAction));
      await tester.pumpAndSettle();

      expect(find.text('Kari'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('person-field')),
          matching: find.text('Anne Glemsk'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining(l.rolePlayAgeYears(47)), findsOneWidget);
    },
  );
}
