import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/phase_headers.dart';

Widget _harness(Widget widget) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: Center(child: widget)),
);

void main() {
  testWidgets(
    'uppercases the title, matching the already-uppercase phase labels',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          const PhaseHeaders(
            title: 'Plan',
            titleWidth: 90,
            mainAxisAlignment: MainAxisAlignment.center,
          ),
        ),
      );

      expect(find.text('PLAN'), findsOneWidget);
      expect(find.text('Plan'), findsNothing);
      expect(find.text('DRILL'), findsOneWidget);
      expect(find.text('EVAL'), findsOneWidget);
      expect(find.text('ROLL'), findsOneWidget);
    },
  );
}
