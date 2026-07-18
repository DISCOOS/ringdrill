import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/person_form_screen.dart';
import 'package:ringdrill/views/widgets/persons_section.dart';
import 'package:ringdrill/views/widgets/plan_scope.dart';
import 'package:ringdrill/views/widgets/station_scope.dart';

/// DESIGN-010 commit-to-parent label — [PersonsSection] is the station
/// editor's own Personer section (`StationFormScreen`'s deferred call
/// site): its own `openFormSurface<PersonFormResult>` call sets
/// `commitsToParent: true` (the result only folds into the station
/// editor's own working copy via `onSave`, persisted later by the
/// station's own save), so the pushed [PersonFormScreen] must read
/// "Ferdig"/"Done" — never "Lagre"/"Save" — and keep its `×` close
/// affordance. Compare with `station_screen_test.dart`'s "Add role"
/// coverage of a real-save call site.

Future<AppLocalizations> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: PlanScope(
          variables: const [],
          child: StationScope(
            locations: const [],
            persons: const [],
            child: PersonsSection(
              persons: const [],
              locations: const [],
              onSave: (_, _) {},
              onDelete: (_) {},
              usagesFor: (_) => const [],
              rolePlayFor: (_) => null,
              onOpenRolePlay: (_) {},
              onAddRolePlay: (_) {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return AppLocalizations.delegate.load(const Locale('en'));
}

void main() {
  testWidgets('"+ Ny person" opens PersonFormScreen reading Ferdig/Done, not '
      'Lagre/Save — the station editor\'s own save persists it later', (
    tester,
  ) async {
    final l = await _pump(tester);

    await tester.tap(find.text(l.personsSectionAddAction));
    await tester.pumpAndSettle();

    expect(find.byType(PersonFormScreen), findsOneWidget);
    expect(find.text(l.formDoneAction), findsOneWidget);
    expect(find.text(l.save), findsNothing);
    // The × close affordance is unaffected by the label.
    expect(find.byIcon(Icons.close), findsOneWidget);
  });
}
