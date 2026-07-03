import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/catalog_conflict_dialog.dart';

/// Coverage for the responsive presentation (bottom sheet on mobile, larger
/// dialog on wide form factors) and the field-level "what changed" detail
/// added to the catalog conflict diff, so a modified exercise/rolePlay shows
/// which fields changed and their before/after values, not just its name.
void main() {
  final diff = ProgramDiff(
    modifiedExercises: [
      ItemDiff(
        name: 'Ladder',
        changes: [
          FieldChange(
            field: 'methodMd',
            local: 'Old method',
            remote: 'New method',
          ),
          const FieldChange(field: 'stations'),
        ],
      ),
    ],
    addedTeams: const ['Green'],
    modifiedRolePlays: [
      ItemDiff(
        name: 'Anna',
        changes: [FieldChange(field: 'age', local: '30', remote: '31')],
      ),
    ],
  );

  CatalogConflictChoice? result;

  Future<void> openDialog(WidgetTester tester) async {
    result = null;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showCatalogConflictDialog(
                context,
                diff: diff,
                ownedSlug: true,
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

  testWidgets(
    'shows a Dialog with field-level diff detail on wide surfaces',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await openDialog(tester);

      expect(find.byType(Dialog), findsOneWidget);
      // Modified exercise shows its name plus which fields changed and
      // their before/after values — not just "Ladder" in a bare list.
      expect(find.textContaining('Old method'), findsOneWidget);
      expect(find.textContaining('New method'), findsOneWidget);
      // A structural (non-scalar) change renders the field label alone.
      expect(find.textContaining('Stations'), findsOneWidget);
      // RolePlays now get their own diff group (previously missing).
      expect(find.textContaining('Anna'), findsOneWidget);
      expect(find.textContaining('30'), findsOneWidget);
      expect(find.textContaining('31'), findsOneWidget);

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.tap(find.text(l10n.catalogConflictOverwrite));
      await tester.pumpAndSettle();
      expect(result, CatalogConflictChoice.overwriteLocal);
    },
  );

  testWidgets('shows a bottom sheet (no Dialog) on narrow surfaces', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await openDialog(tester);

    expect(find.byType(Dialog), findsNothing);
    expect(find.textContaining('Old method'), findsOneWidget);

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.tap(find.text(l10n.catalogConflictCancel));
    await tester.pumpAndSettle();
    expect(result, CatalogConflictChoice.cancel);
  });
}
