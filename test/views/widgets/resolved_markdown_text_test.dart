import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/views/widgets/resolved_markdown_text.dart';

/// The sanctioned way to display a raw plan-scope markdown field
/// (`Plan.briefIntroMd`/`commsMd`/`beforeRoundMd`) outside the full
/// brief — see the widget's doc comment and `AGENTS.md`'s Pitfalls entry.

Plan _plan({List<DrillVariable> variables = const []}) {
  final now = DateTime.utc(2026, 1, 1);
  return Plan(
    uuid: 'pgm-1',
    name: 'Vinterøvelse Nordland',
    description: 'Samvirkeøvelse',
    metadata: PlanMetadata(created: now, updated: now, version: '1.1'),
    teams: const [],
    sessions: const [],
    exercises: const [],
    variables: variables,
  );
}

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('resolves a declared variable before rendering', (tester) async {
    await _pump(
      tester,
      ResolvedMarkdownText(
        plan: _plan(
          variables: const [DrillVariable(name: 'frekvens', value: 'Kanal 6')],
        ),
        content: 'Samband på kanal {{var.frekvens}}.',
      ),
    );

    expect(find.text('Samband på kanal Kanal 6.'), findsOneWidget);
  });

  testWidgets('resolves {{plan.name}} and {{plan.description}}', (
    tester,
  ) async {
    await _pump(
      tester,
      ResolvedMarkdownText(
        plan: _plan(),
        content: '{{plan.name}} — {{plan.description}}',
      ),
    );

    expect(find.text('Vinterøvelse Nordland — Samvirkeøvelse'), findsOneWidget);
  });

  testWidgets('an undeclared variable renders the localized placeholder', (
    tester,
  ) async {
    await _pump(
      tester,
      ResolvedMarkdownText(plan: _plan(), content: 'Kanal {{var.mangler}}.'),
    );

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(
      find.text('Kanal ${l10n.briefUnknownVariable('mangler')}.'),
      findsOneWidget,
    );
    expect(find.textContaining('{{var.mangler}}'), findsNothing);
  });

  testWidgets('null content renders nothing', (tester) async {
    await _pump(tester, ResolvedMarkdownText(plan: _plan(), content: null));

    expect(find.byType(Text), findsNothing);
  });

  testWidgets('applies style, maxLines and overflow to the resolved text', (
    tester,
  ) async {
    await _pump(
      tester,
      ResolvedMarkdownText(
        plan: _plan(),
        content: 'Plain text, no tokens.',
        style: const TextStyle(fontSize: 20),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );

    final text = tester.widget<Text>(find.text('Plain text, no tokens.'));
    expect(text.style?.fontSize, 20);
    expect(text.maxLines, 2);
    expect(text.overflow, TextOverflow.ellipsis);
  });
}
