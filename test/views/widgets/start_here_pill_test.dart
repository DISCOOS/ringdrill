import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/widgets/start_here_pill.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _harness(ThemeData theme) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: theme,
  home: Scaffold(
    body: StartHerePill(onActivate: () {}),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ProgramService().init();
  });

  testWidgets('renders without exceptions in light theme and shows label', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.pumpWidget(_harness(ThemeData.light()));
    await tester.pump(); // let _loadFlag async settle

    expect(find.text(l10n.startHereCue), findsOneWidget);
  });

  testWidgets('renders without exceptions in dark theme and shows label', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.pumpWidget(_harness(ThemeData.dark()));
    await tester.pump();

    expect(find.text(l10n.startHereCue), findsOneWidget);
  });

  testWidgets('hides when keyStartHereSeen is already set', (tester) async {
    SharedPreferences.setMockInitialValues({'app:startHereSeen:v1': true});
    await ProgramService().init();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.pumpWidget(_harness(ThemeData.light()));
    await tester.pump();

    expect(find.text(l10n.startHereCue), findsNothing);
  });
}
