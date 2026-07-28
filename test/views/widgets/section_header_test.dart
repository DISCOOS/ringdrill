import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/widgets/gate_badge.dart';
import 'package:ringdrill/views/widgets/section_header.dart';

Widget _harness(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  group('SectionHeader', () {
    testWidgets('renders the label uppercased', (tester) async {
      await tester.pumpWidget(_harness(const SectionHeader('Description')));

      expect(find.text('DESCRIPTION'), findsOneWidget);
    });

    testWidgets('gated: false renders no badge', (tester) async {
      await tester.pumpWidget(_harness(const SectionHeader('Notes')));

      expect(find.byType(GateBadge), findsNothing);
    });

    testWidgets('gated: true renders the director-only GateBadge', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(const SectionHeader('Notes', gated: true)),
      );

      expect(find.byType(GateBadge), findsOneWidget);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.directorOnlyBadge), findsOneWidget);
    });
  });

  group('GateBadge', () {
    testWidgets('renders the label and the hidden-from-participants icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(const GateBadge(label: 'Director only')),
      );

      expect(find.text('Director only'), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });
  });
}
