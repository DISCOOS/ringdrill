import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/views/active_plan_actions.dart';

Program _program() {
  final now = DateTime.utc(2026, 1, 1);
  return Program(
    uuid: 'pgm-1',
    name: 'Vinterøvelse',
    description: '',
    metadata: ProgramMetadata(created: now, updated: now, version: '1.0'),
    teams: const [],
    sessions: const [],
    exercises: const [],
  );
}

void main() {
  // Regression test for the "A TextEditingController was used after being
  // disposed" crash seen when creating a new plan. The name-prompt dialog used
  // to dispose its controller inline right after showAdaptiveDialog returned,
  // which tore it down while the still-animating TextField was rebuilding
  // during the pop transition. The controller is now owned by the dialog's
  // State and disposed only when the route leaves the tree.
  testWidgets(
    'new-plan name dialog cancels without using a disposed controller',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => createNewPlan(ctx),
                  child: const Text('New'),
                ),
              ),
            ),
          ),
        ),
      );

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      // Open the dialog.
      await tester.tap(find.text('New'));
      await tester.pumpAndSettle();
      expect(find.text(l10n.newPlanNamePrompt), findsOneWidget);

      // Cancel and let the exit transition fully run — this is the window in
      // which the old code touched the disposed controller.
      await tester.tap(find.text(l10n.cancel));
      await tester.pumpAndSettle();

      expect(find.text(l10n.newPlanNamePrompt), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'new-plan name dialog closes via Create without a disposed controller',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => createNewPlan(ctx),
                  child: const Text('New'),
                ),
              ),
            ),
          ),
        ),
      );

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      await tester.tap(find.text('New'));
      await tester.pumpAndSettle();

      // Tap Create with an empty field: that pops the dialog (exercising the
      // Create button's pop + the same controller-dispose path) but trims to
      // an empty name, so createNewPlan early-returns before touching
      // ProgramService — keeping the test free of storage side effects.
      await tester.tap(find.text(l10n.create));
      await tester.pumpAndSettle();

      expect(find.text(l10n.newPlanNamePrompt), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'rename-plan dialog cancels without using a disposed controller',
    (tester) async {
      final program = _program();
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => renamePlan(ctx, program),
                  child: const Text('Rename'),
                ),
              ),
            ),
          ),
        ),
      );

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      expect(find.text(l10n.libraryRename), findsOneWidget);
      // Seeded with the current plan name.
      expect(find.text('Vinterøvelse'), findsOneWidget);

      await tester.tap(find.text(l10n.cancel));
      await tester.pumpAndSettle();

      expect(find.text(l10n.libraryRename), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
