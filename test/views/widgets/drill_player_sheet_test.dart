import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/widgets/drill_player_sheet.dart';

Widget _harness() => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDrillPlayerSheet<void>(
              context: context,
              builder: (_) => const Center(child: Text('sheet body')),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

void main() {
  testWidgets('opens, renders builder body, closes via chevron', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('sheet body'), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);

    await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
    await tester.pumpAndSettle();

    expect(find.text('sheet body'), findsNothing);
  });

  testWidgets('no drag handle', (tester) async {
    await tester.pumpWidget(_harness());

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ringdrill-sheet-drag-handle')), findsNothing);
  });

  testWidgets('drag gesture does not dismiss sheet', (tester) async {
    await tester.pumpWidget(_harness());

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('sheet body'), findsOneWidget);

    await tester.fling(
      find.text('sheet body'),
      const Offset(0, 400),
      800,
    );
    await tester.pumpAndSettle();

    // Sheet must still be visible — drag is disabled
    expect(find.text('sheet body'), findsOneWidget);
  });
}
