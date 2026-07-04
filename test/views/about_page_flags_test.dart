import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/utils/app_flags.dart';
import 'package:ringdrill/views/about_page.dart';

/// AppFlags.all/activeOnly are compile-time dart-define values (ADR-0042),
/// so a single `flutter test` run cannot toggle a flag on and off to prove
/// the "Developer info" section appears when one is active — that needs a
/// real dart-define, same limitation documented in
/// test/web/legacy_host_test.dart. Verify manually instead:
///   flutter run --dart-define=RINGDRILL_FORCE_LEGACY_HOST=true
///     # About page → Developer info → RINGDRILL_FORCE_LEGACY_HOST: true
///
/// What IS automatable, and what this test covers, is the regression an
/// added AppFlagInfo entry could actually cause: it must not make the
/// section appear when every flag is still at its default (the state of
/// every normal build and every other test run).
void main() {
  testWidgets(
    'Developer info section is absent when all flags are at default',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AboutPage(),
        ),
      );
      await tester.pump();

      expect(AppFlags.activeOnly, isEmpty);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.developerInfoSectionTitle), findsNothing);
      expect(find.text('RINGDRILL_FORCE_LEGACY_HOST'), findsNothing);
    },
  );
}
