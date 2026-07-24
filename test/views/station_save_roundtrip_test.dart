import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';

import 'support/save_roundtrip_harness.dart';

/// Station editor → save → persist round-trip through the compact modal
/// ContextSheet path (StationSheetTarget → StationScreen → AppBar
/// edit icon → StationFormScreen; the caller splices the popped station
/// into its owning exercise and saves that). See save_roundtrip_harness.dart
/// for why this seam needs end-to-end coverage.
void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  setUp(() async {
    await initActivePlan('Station roundtrip plan');
    await ProgramService().saveExercise(
      l10n,
      makeExercise(uuid: 'ex-rt-st', name: 'Station Exercise'),
    );
  });

  tearDown(() => ProgramService().clearAllForTest());

  Future<void> renameViaSheet(
    WidgetTester tester, {
    required String from,
    required String to,
  }) async {
    await tester.tap(find.byTooltip(l10n.editExercise));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, from), to);
    await tester.tap(find.text(l10n.save));
    await tester.pumpAndSettle();
  }

  testWidgets('editing a station from its sheet persists on save — twice in '
      'a row', (tester) async {
    useCompactWindow(tester);
    final controller = ContextSheetController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      sheetHost(
        controller: controller,
        target: const StationSheetTarget(
          exerciseUuid: 'ex-rt-st',
          stationIndex: 0,
        ),
      ),
    );
    await openSheet(tester);

    // Round 1: sheet body (StationScreen) → edit → rename → save.
    await renameViaSheet(tester, from: 'Post 1', to: 'Post X');
    expect(
      ProgramService().getExercise('ex-rt-st')?.stations[0].name,
      'Post X',
      reason: 'first save from the sheet must persist',
    );
    // The sheet title now prefixes the formatted post number ("1.1 Post X").
    expect(find.textContaining('Post X'), findsWidgets);

    // Round 2: edit again from the re-opened sheet — the scenario that
    // regressed (the stale first re-open future swallowed the result).
    await renameViaSheet(tester, from: 'Post X', to: 'Post Y');
    expect(
      ProgramService().getExercise('ex-rt-st')?.stations[0].name,
      'Post Y',
      reason: 'second consecutive save must persist too',
    );
    expect(find.textContaining('Post Y'), findsWidgets);
  });
}
