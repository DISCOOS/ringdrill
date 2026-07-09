import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/person.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/views/roleplay_form_screen.dart';

/// DESIGN-009 prompt 5, commit 3 — re-pointing the linked station (and so,
/// necessarily, `personRef`) leaves an already-typed `station.loc.<slug>`
/// unresolved when the new station has no such location. The inline
/// warning under the Post selector surfaces this immediately, without
/// waiting for a Save attempt, and Save stays blocked by commit 1's check
/// until it is fixed — either by editing the text or by re-linking back.

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
  stations: [
    Station(
      index: 0,
      name: 'Post A',
      locations: const [Location(slug: 'lkp', label: 'Sist kjent')],
      persons: const [Person(slug: 'anne', name: 'Anne Glemsk')],
    ),
    Station(
      index: 1,
      name: 'Post B',
      persons: const [Person(slug: 'kari', name: 'Kari Hansen')],
    ),
  ],
  schedule: const [],
);

RolePlay _rolePlay() => const RolePlay(
  uuid: 'role-1',
  index: 0,
  exerciseUuid: 'ex-1',
  name: 'Anne Glemsk',
  stationIndex: 0,
  personRef: 'anne',
  behavior: 'Sier hei ved {{station.loc.lkp}}.',
);

class _Captured {
  RolePlayFormResult? value;
}

Future<void> _open(WidgetTester tester, _Captured captured) async {
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
                    RolePlayFormScreen(rolePlay: _rolePlay(), exercise: _exercise()),
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
    're-pointing to another station leaves the token unresolved: warning '
    'shows and save stays blocked; re-pointing back clears both',
    (tester) async {
      final captured = _Captured();
      await _open(tester, captured);

      // Starts resolved: no warning shown.
      expect(find.byIcon(Icons.error_outline), findsNothing);

      // Re-link to Post B.
      await tester.tap(find.byKey(const Key('station-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Post B').last);
      await tester.pumpAndSettle();

      // The inline warning now names the Behaviour field.
      expect(
        find.textContaining(l.rolePlayBrokenReferenceWarning(l.roleBehavior)),
        findsOneWidget,
      );

      // Pick the new station's person to satisfy the required-personRef
      // validator, then attempt to save.
      await tester.tap(find.byKey(const Key('person-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kari Hansen').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();

      expect(captured.value, isNull);
      expect(
        find.text(
          l.saveBlockedUnresolvedReference(l.roleBehavior, 'station.loc.lkp'),
        ),
        findsOneWidget,
      );

      // Re-link back to Post A: the token resolves again, warning clears.
      await tester.tap(find.byKey(const Key('station-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Post A').last);
      await tester.pumpAndSettle();

      expect(
        find.textContaining(l.rolePlayBrokenReferenceWarning(l.roleBehavior)),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('person-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Anne Glemsk').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();

      expect(captured.value, isNotNull);
      expect(
        captured.value!.rolePlay.behavior,
        'Sier hei ved {{station.loc.lkp}}.',
      );
    },
  );
}
