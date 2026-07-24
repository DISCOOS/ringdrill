import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/team.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/views/shell/open_form_surface.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';

import '../support/save_roundtrip_harness.dart';

/// Regression test for the editor save-loss bug: when `openFormSurface` is
/// invoked from inside a *modal* ContextSheet (the compact-layout path), it
/// dismisses the sheet, pushes the form, and re-opens the sheet after the
/// form pops. `ContextSheetController.show()` only resolves when the
/// re-opened sheet is *dismissed*, so awaiting it parked `openFormSurface`
/// before `return result` — the caller's `await openFormSurface(...)` never
/// resolved and its `PlanService.save*` call never ran. Every editor
/// (exercise, station, roleplay, team, actor) persists through this seam,
/// so all of them silently dropped edits made from a sheet.
void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  setUp(() async {
    // The re-opened sheet renders the real default body (TeamScreen for the
    // target below — a custom bodyBuilder does not survive the close/re-open
    // cycle), so the service must hold a matching team.
    await initActivePlan('Seam test plan');
    await PlanService().saveTeam(
      l10n,
      const Team(uuid: 'team-seam-1', index: 0, name: 'Seam Team'),
    );
  });

  tearDown(() => PlanService().clearAllForTest());

  testWidgets(
    'result reaches the caller as soon as the form pops, while the '
    're-opened sheet is still up',
    (tester) async {
      // Compact window (< 600 logical px wide) so openFormSurface takes the
      // modal-sheet path under test; wider layouts use a dialog and never
      // hit the sheet close/re-open logic.
      useCompactWindow(tester);

      String? received;
      var completed = false;

      final controller = ContextSheetController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ContextSheet(
            controller: controller,
            // The sheet body carries the edit affordance, exactly like the
            // production sheet bodies (TeamScreen, CoordinatorScreen, …).
            bodyBuilder: (context, target) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    final result = await openFormSurface<String>(
                      context,
                      builder: (_) => const _FakeForm(),
                    );
                    received = result;
                    completed = true;
                  },
                  child: const Text('edit'),
                ),
              ),
            ),
            child: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => controller.show(
                      context,
                      const TeamOverviewSheetTarget(teamIndex: 0),
                    ),
                    child: const Text('open sheet'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // Open the modal sheet, then start an edit from inside it.
      await tester.tap(find.text('open sheet'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('edit'));
      await tester.pumpAndSettle();

      // The sheet was dismissed and the form route is up.
      expect(find.text('save'), findsOneWidget);

      // Save: the form pops with a result and openFormSurface re-opens the
      // sheet to the saved target (asserted via the sheet chrome — the
      // re-opened body is the default TeamScreen, not the harness builder).
      await tester.tap(find.text('save'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('ringdrill-sheet-drag-handle')),
        findsOneWidget,
        reason: 'sheet re-opened',
      );

      // The caller must have its result NOW — not when the re-opened sheet
      // is eventually dismissed (by which time the calling context is long
      // disposed and the save would be skipped).
      expect(
        completed,
        isTrue,
        reason: 'openFormSurface must return once the form pops; awaiting '
            'the sheet re-open blocks the caller\'s save',
      );
      expect(received, 'edited-value');
    },
  );
}

class _FakeForm extends StatelessWidget {
  const _FakeForm();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => Navigator.of(context).pop('edited-value'),
          child: const Text('save'),
        ),
      ),
    );
  }
}
