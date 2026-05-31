import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/team.dart';
import 'package:ringdrill/views/team_form_screen.dart';

Widget _buildForm() {
  return const MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: TeamFormScreen(
      team: Team(uuid: 'team-1', index: 0, name: 'Blue'),
    ),
  );
}

void main() {
  testWidgets('name field is required', (tester) async {
    await tester.pumpWidget(_buildForm());
    final localizations = await AppLocalizations.delegate.load(
      const Locale('en'),
    );

    await tester.enterText(find.widgetWithText(TextFormField, 'Blue'), '');
    await tester.tap(find.text(localizations.save));
    await tester.pump();

    expect(find.text(localizations.pleaseEnterAName), findsOneWidget);
  });
}
