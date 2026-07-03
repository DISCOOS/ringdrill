import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/team.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';

import 'support/save_roundtrip_harness.dart';

/// Team editor → save → persist round-trip through the compact modal
/// ContextSheet path (TeamOverviewSheetTarget → TeamScreen → edit icon →
/// TeamFormScreen). See save_roundtrip_harness.dart for why this seam needs
/// end-to-end coverage.
void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  setUp(() async {
    await initActivePlan('Team roundtrip plan');
    await ProgramService().saveTeam(
      l10n,
      const Team(uuid: 'team-rt-1', index: 0, name: 'Team A'),
    );
  });

  tearDown(() => ProgramService().clearAllForTest());

  testWidgets('editing a team from its sheet persists on save — twice in a '
      'row', (tester) async {
    useCompactWindow(tester);
    final controller = ContextSheetController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      sheetHost(
        controller: controller,
        target: const TeamOverviewSheetTarget(teamIndex: 0),
      ),
    );
    await openSheet(tester);

    // Round 1: sheet body (TeamScreen) → edit → rename → save.
    await tester.tap(find.byTooltip(l10n.editTeam));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Team A'),
      'Team B',
    );
    await tester.tap(find.text(l10n.save));
    await tester.pumpAndSettle();

    expect(
      ProgramService().getTeam(0)?.name,
      'Team B',
      reason: 'first save from the sheet must persist',
    );
    // openFormSurface re-opened the sheet to the same target; the fresh
    // TeamScreen body must show the saved name.
    expect(find.text('Team B'), findsWidgets);

    // Round 2: edit again from the re-opened sheet — the scenario that
    // regressed (the stale first re-open future swallowed the result).
    await tester.tap(find.byTooltip(l10n.editTeam));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Team B'),
      'Team C',
    );
    await tester.tap(find.text(l10n.save));
    await tester.pumpAndSettle();

    expect(
      ProgramService().getTeam(0)?.name,
      'Team C',
      reason: 'second consecutive save must persist too',
    );
    expect(find.text('Team C'), findsWidgets);
  });
}
