import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/shell/detail_empty_pane.dart';

Widget _harness(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('exercise empty pane renders icon and localized copy', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(const ExerciseDetailEmpty()));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.byIcon(Icons.update), findsOneWidget);
    expect(find.text(l10n.detailEmptyExercise), findsOneWidget);
  });

  testWidgets('station empty pane renders icon and localized copy', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(const StationDetailEmpty()));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.byIcon(Icons.place), findsOneWidget);
    expect(find.text(l10n.detailEmptyStation), findsOneWidget);
  });

  testWidgets('role-play empty pane renders icon and localized copy', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(const RolePlayDetailEmpty()));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.byIcon(Icons.theater_comedy), findsOneWidget);
    expect(find.text(l10n.detailEmptyRolePlay), findsOneWidget);
  });

  testWidgets('team empty pane renders icon and localized copy', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(const TeamDetailEmpty()));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.byIcon(Icons.group), findsOneWidget);
    expect(find.text(l10n.detailEmptyTeam), findsOneWidget);
  });
}
