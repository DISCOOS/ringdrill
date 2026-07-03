import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';

import 'support/save_roundtrip_harness.dart';

/// Exercise editor → save → persist round-trip through the compact modal
/// ContextSheet path (ExerciseSheetTarget → CoordinatorScreen → overflow
/// menu "Edit" → ExerciseFormScreen). See save_roundtrip_harness.dart for
/// why this seam needs end-to-end coverage.
void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  setUp(() async {
    await initActivePlan('Exercise roundtrip plan');
    await ProgramService().saveExercise(
      l10n,
      makeExercise(uuid: 'ex-rt-1', name: 'Exercise A'),
    );
  });

  tearDown(() => ProgramService().clearAllForTest());

  Future<void> renameViaSheet(
    WidgetTester tester, {
    required String from,
    required String to,
  }) async {
    await tester.tap(find.byTooltip(l10n.moreActions));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.editExercise));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, from), to);
    await tester.tap(find.text(l10n.save));
    await tester.pumpAndSettle();
  }

  testWidgets('editing an exercise from its sheet persists on save — twice '
      'in a row', (tester) async {
    useCompactWindow(tester);
    final controller = ContextSheetController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      sheetHost(
        controller: controller,
        target: const ExerciseSheetTarget(exerciseUuid: 'ex-rt-1'),
      ),
    );
    await openSheet(tester);

    // Round 1: sheet body (CoordinatorScreen) → edit → rename → save.
    await renameViaSheet(tester, from: 'Exercise A', to: 'Exercise B');
    expect(
      ProgramService().getExercise('ex-rt-1')?.name,
      'Exercise B',
      reason: 'first save from the sheet must persist',
    );
    expect(find.text('Exercise B'), findsWidgets);

    // Round 2: edit again from the re-opened sheet — the scenario that
    // regressed (the stale first re-open future swallowed the result).
    await renameViaSheet(tester, from: 'Exercise B', to: 'Exercise C');
    expect(
      ProgramService().getExercise('ex-rt-1')?.name,
      'Exercise C',
      reason: 'second consecutive save must persist too',
    );
    expect(find.text('Exercise C'), findsWidgets);
  });
}
