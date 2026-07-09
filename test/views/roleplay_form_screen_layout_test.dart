import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/person.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/views/position_form_field.dart';
import 'package:ringdrill/views/roleplay_form_screen.dart';

/// DESIGN-009 prompt 4g — the reordered default section: Post first, then
/// Navn+Alder, then Person+Kjønn, Signalement, Posisjon, with no explicit
/// "Effektiv identitet:" heading. Default `flutter_test` surface (800x600)
/// is above the Person/Kjønn row breakpoint, so they share a row.

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
  stations: const [
    Station(
      index: 0,
      name: 'Post 1',
      persons: [Person(slug: 'anne', name: 'Anne Glemsk', gender: 'woman')],
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
);

Future<void> _open(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: RolePlayFormScreen(rolePlay: _rolePlay(), exercise: _exercise()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets('Post leads, then Navn+Alder, then Person+Kjønn, then '
      'Signalement, then Posisjon', (tester) async {
    await _open(tester);

    final postTop = tester
        .getTopLeft(find.byKey(const Key('station-field')))
        .dy;
    final nameTop = tester
        .getTopLeft(find.widgetWithText(TextFormField, l.roleName))
        .dy;
    final ageTop = tester.getTopLeft(find.byKey(const Key('age-field'))).dy;
    final personTop = tester
        .getTopLeft(find.byKey(const Key('person-field')))
        .dy;
    // The "Kjønn" label is the gender column's first child, so its top
    // aligns with the person dropdown's top in their shared row — the
    // segmented control itself sits lower, below the label.
    final genderTop = tester.getTopLeft(find.text(l.roleGender)).dy;
    final signalementTop = tester
        .getTopLeft(find.widgetWithText(TextFormField, l.roleSignalement))
        .dy;
    final positionTop = tester
        .getTopLeft(find.byType(PositionFormField))
        .dy;

    // Navn and Alder share a row.
    expect(nameTop, ageTop);
    // Person and Kjønn share a row (default surface is above the
    // narrow-width breakpoint).
    expect(personTop, genderTop);

    // Overall top-to-bottom order.
    expect(postTop, lessThan(nameTop));
    expect(nameTop, lessThan(personTop));
    expect(personTop, lessThan(signalementTop));
    expect(signalementTop, lessThan(positionTop));
  });

  testWidgets('no explicit "Effective identity" heading, but the '
      'inherit/override hints still show', (tester) async {
    await _open(tester);

    expect(find.textContaining('Effective identity'), findsNothing);
    // The per-field inherit hint still shows for a field tracking the
    // selected person (name here, seeded to match Anne Glemsk exactly).
    expect(find.text(l.rolePlayIdentityInherited), findsWidgets);
  });
}
