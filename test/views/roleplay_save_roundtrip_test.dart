import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';

import 'support/save_roundtrip_harness.dart';

/// Roleplay (script) editor → save → persist round-trip through the compact
/// modal ContextSheet path (RoleSheetTarget → RolePlayScreen → AppBar edit
/// icon → RolePlayFormScreen). See save_roundtrip_harness.dart for why this
/// seam needs end-to-end coverage.
void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  setUp(() async {
    await initActivePlan('Roleplay roundtrip plan');
    await ProgramService().saveExercise(
      l10n,
      makeExercise(uuid: 'ex-rt-rp', name: 'Roleplay Exercise'),
    );
    await ProgramService().saveRolePlay(
      l10n,
      const RolePlay(
        uuid: 'role-rt-1',
        index: 0,
        exerciseUuid: 'ex-rt-rp',
        stationIndex: 0,
        name: 'Pasient A',
      ),
    );
  });

  tearDown(() => ProgramService().clearAllForTest());

  Future<void> renameViaSheet(
    WidgetTester tester, {
    required String from,
    required String to,
  }) async {
    await tester.tap(find.byTooltip(l10n.roleSection));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, from), to);
    await tester.tap(find.text(l10n.save));
    await tester.pumpAndSettle();
  }

  testWidgets('editing a roleplay from its sheet persists on save — twice '
      'in a row', (tester) async {
    useCompactWindow(tester);
    final controller = ContextSheetController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      sheetHost(
        controller: controller,
        target: const RoleSheetTarget(rolePlayUuid: 'role-rt-1'),
      ),
    );
    await openSheet(tester);

    // Round 1: sheet body (RolePlayScreen) → edit → rename → save.
    await renameViaSheet(tester, from: 'Pasient A', to: 'Pasient B');
    expect(
      ProgramService().getRolePlay('role-rt-1')?.name,
      'Pasient B',
      reason: 'first save from the sheet must persist',
    );
    expect(find.text('Pasient B'), findsWidgets);

    // Round 2: edit again from the re-opened sheet — the scenario that
    // regressed (the stale first re-open future swallowed the result).
    await renameViaSheet(tester, from: 'Pasient B', to: 'Pasient C');
    expect(
      ProgramService().getRolePlay('role-rt-1')?.name,
      'Pasient C',
      reason: 'second consecutive save must persist too',
    );
    expect(find.text('Pasient C'), findsWidgets);
  });
}
