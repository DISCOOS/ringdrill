import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/views/plan_form_screen.dart';

Plan _basePlan({
  String name = 'Vinterøvelse',
  String description = '',
  String? briefIntroMd,
  String? commsMd,
  String? beforeRoundMd,
  String? languageCode,
}) {
  final now = DateTime.utc(2026, 1, 1);
  return Plan(
    uuid: 'pgm-1',
    name: name,
    description: description,
    metadata: PlanMetadata(
      created: now,
      updated: now,
      version: '1.0',
      languageCode: languageCode,
    ),
    teams: const [],
    sessions: const [],
    exercises: const [],
    briefIntroMd: briefIntroMd,
    commsMd: commsMd,
    beforeRoundMd: beforeRoundMd,
  );
}

Future<Plan?> _openForm(WidgetTester tester, Plan plan) async {
  Plan? result;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (ctx) => TextButton(
          onPressed: () async {
            result = await Navigator.push<Plan>(
              ctx,
              MaterialPageRoute(
                builder: (_) => PlanFormScreen(plan: plan),
              ),
            );
          },
          child: const Text('Open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('renders base fields with seeded values', (tester) async {
    await _openForm(
      tester,
      _basePlan(description: 'En kjent rute'),
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.text(l10n.planName), findsOneWidget);
    expect(find.text(l10n.planDescription), findsOneWidget);
    expect(find.text('Vinterøvelse'), findsOneWidget);
    expect(find.text('En kjent rute'), findsOneWidget);
  });

  testWidgets('save edits name, description and a brief field', (tester) async {
    Plan? captured;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (ctx) => TextButton(
            onPressed: () async {
              captured = await Navigator.push<Plan>(
                ctx,
                MaterialPageRoute(
                  builder: (_) => PlanFormScreen(
                    plan: _basePlan(languageCode: 'nb'),
                  ),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Edit name + description in the default "Plan" section.
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Vinterøvelse'),
      'Vårøvelse',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, l10n.planDescription),
      'Ny undertittel',
    );

    // Add the intro brief section and type into it. The default 800x600
    // test surface lands in the wide/medium window class, so the rail
    // lists the addable section directly — no switcher sheet needed.
    await tester.tap(find.text(l10n.formSectionAddAction));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.briefSectionPlanIntro));
    await tester.pumpAndSettle();
    // Only one section is mounted at a time, so its field is the sole
    // TextFormField in the tree (the section now also shows its own
    // floating label, matching the roleplay editor's sections).
    final introField = find.byType(TextFormField);
    expect(introField, findsOneWidget);
    await tester.enterText(introField, 'Generelt om spillet ...');

    await tester.tap(find.text(l10n.save));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.name, 'Vårøvelse');
    expect(captured!.description, 'Ny undertittel');
    expect(captured!.briefIntroMd, 'Generelt om spillet ...');
    expect(captured!.commsMd, isNull);
    expect(captured!.beforeRoundMd, isNull);
  });

  testWidgets('seeded optional sections appear pre-active and are editable', (
    tester,
  ) async {
    Plan? captured;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (ctx) => TextButton(
            onPressed: () async {
              captured = await Navigator.push<Plan>(
                ctx,
                MaterialPageRoute(
                  builder: (_) => PlanFormScreen(
                    plan: _basePlan(
                      briefIntroMd: 'gammel intro',
                      languageCode: 'nb',
                    ),
                  ),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // The intro section is already active — switch to it directly via the
    // rail (default surface is wide/medium; no add-button for it since it
    // is not addable).
    await tester.tap(find.text(l10n.briefSectionPlanIntro));
    await tester.pumpAndSettle();
    expect(find.text('gammel intro'), findsOneWidget);

    // Replace the content and save. Only one section is mounted at a
    // time, so its field is the sole TextFormField in the tree.
    await tester.enterText(find.byType(TextFormField), 'ny intro');
    await tester.tap(find.text(l10n.save));
    await tester.pumpAndSettle();

    expect(captured!.briefIntroMd, 'ny intro');
  });

  testWidgets('removing an active section clears its value on save', (
    tester,
  ) async {
    Plan? captured;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (ctx) => TextButton(
            onPressed: () async {
              captured = await Navigator.push<Plan>(
                ctx,
                MaterialPageRoute(
                  builder: (_) => PlanFormScreen(
                    plan: _basePlan(
                      briefIntroMd: 'noe innhold',
                      languageCode: 'nb',
                    ),
                  ),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.briefSectionPlanIntro));
    await tester.pumpAndSettle();

    // Remove the active intro section via its overflow menu.
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.formSectionRemoveAction));
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.save));
    await tester.pumpAndSettle();

    expect(captured!.briefIntroMd, isNull);
  });

  testWidgets('selecting a plan language saves languageCode', (tester) async {
    Plan? captured;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (ctx) => TextButton(
            onPressed: () async {
              captured = await Navigator.push<Plan>(
                ctx,
                MaterialPageRoute(
                  builder: (_) => PlanFormScreen(plan: _basePlan()),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Norsk').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.save));
    await tester.pumpAndSettle();

    expect(captured!.metadata.languageCode, 'nb');
  });

  testWidgets('blocks save and shows an error when no language is chosen', (
    tester,
  ) async {
    Plan? captured;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (ctx) => TextButton(
            onPressed: () async {
              captured = await Navigator.push<Plan>(
                ctx,
                MaterialPageRoute(
                  builder: (_) => PlanFormScreen(plan: _basePlan()),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.save));
    await tester.pumpAndSettle();

    // The form does not pop — save is blocked until a language is chosen.
    expect(captured, isNull);
    expect(find.text(l10n.pleaseSelectALanguage), findsOneWidget);
  });
}
