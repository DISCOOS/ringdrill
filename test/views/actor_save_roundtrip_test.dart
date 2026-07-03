import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/actor.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/roster_view.dart';

import 'support/save_roundtrip_harness.dart';

/// Actor editor → save → persist round-trip through the Roster tab
/// (RosterView row tap → ActorFormScreen via openFormSurface). The actor
/// editor is not reached through a ContextSheet, but it persists through
/// the same openFormSurface → caller-saves seam as the other editors, which
/// had no end-to-end coverage. See save_roundtrip_harness.dart.
void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  setUp(() async {
    await initActivePlan('Actor roundtrip plan');
    await ProgramService().saveActor(
      l10n,
      Actor(uuid: 'actor-rt-1', realName: 'Kari Nordmann'),
    );
  });

  tearDown(() => ProgramService().clearAllForTest());

  Future<void> renameViaRow(
    WidgetTester tester, {
    required String from,
    required String to,
  }) async {
    await tester.tap(find.text(from));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, from), to);
    await tester.tap(find.text(l10n.save));
    await tester.pumpAndSettle();
  }

  testWidgets('editing an actor from the roster persists on save — twice in '
      'a row', (tester) async {
    useCompactWindow(tester);
    final controller = RosterController();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: RosterView(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();

    // Round 1: row tap → ActorFormScreen → rename → save.
    await renameViaRow(tester, from: 'Kari Nordmann', to: 'Kari Hansen');
    expect(
      ProgramService().getActor('actor-rt-1')?.realName,
      'Kari Hansen',
      reason: 'first save must persist',
    );
    expect(find.text('Kari Hansen'), findsWidgets);

    // Round 2: edit the same actor again straight away.
    await renameViaRow(tester, from: 'Kari Hansen', to: 'Kari Berg');
    expect(
      ProgramService().getActor('actor-rt-1')?.realName,
      'Kari Berg',
      reason: 'second consecutive save must persist too',
    );
    expect(find.text('Kari Berg'), findsWidgets);
  });
}
