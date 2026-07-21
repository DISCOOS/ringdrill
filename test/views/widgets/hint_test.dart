import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/widgets/hint.dart';

void main() {
  testWidgets('EditSectionHint renders the edit icon and the localized hint '
      'text', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: EditSectionHint()),
      ),
    );

    expect(find.byIcon(Icons.edit), findsOneWidget);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.tapSectionToEditHint), findsOneWidget);
  });
}
