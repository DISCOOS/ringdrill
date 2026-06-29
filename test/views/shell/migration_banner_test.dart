import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/utils/app_config.dart';
import 'package:ringdrill/views/shell/migration_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Fixed "now" used across all tests to keep dismiss-window checks stable.
final _now = DateTime(2026, 6, 29, 12, 0, 0);
DateTime _nowFn() => _now;

Widget _harness(MigrationBanner banner) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: Column(children: [banner])),
);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await ProgramService().init();
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await ProgramService().clearAllForTest();
  });

  group('MigrationBanner visibility', () {
    testWidgets('hidden when isLegacyHost returns false', (tester) async {
      await tester.pumpWidget(
        _harness(
          MigrationBanner(
            isLegacyHostOverride: () => false,
            nowOverride: _nowFn,
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('web.ringdrill.app'), findsNothing);
    });

    testWidgets('visible when isLegacyHost returns true', (tester) async {
      await tester.pumpWidget(
        _harness(
          MigrationBanner(
            isLegacyHostOverride: () => true,
            nowOverride: _nowFn,
          ),
        ),
      );
      // Wait for SharedPreferences async load.
      await tester.pumpAndSettle();

      expect(find.textContaining('web.ringdrill.app'), findsOneWidget);
    });

    testWidgets('hidden when dismissed within 24 hours', (tester) async {
      // Pre-set a dismiss timestamp 1 hour ago.
      final oneHourAgo = _now.subtract(const Duration(hours: 1));
      SharedPreferences.setMockInitialValues({
        AppConfig.keyMigrationBannerDismissedAt:
            oneHourAgo.millisecondsSinceEpoch,
      });

      await tester.pumpWidget(
        _harness(
          MigrationBanner(
            isLegacyHostOverride: () => true,
            nowOverride: _nowFn,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('web.ringdrill.app'), findsNothing);
    });

    testWidgets('visible when dismiss timestamp is older than 24 hours',
        (tester) async {
      final twoDaysAgo = _now.subtract(const Duration(hours: 25));
      SharedPreferences.setMockInitialValues({
        AppConfig.keyMigrationBannerDismissedAt:
            twoDaysAgo.millisecondsSinceEpoch,
      });

      await tester.pumpWidget(
        _harness(
          MigrationBanner(
            isLegacyHostOverride: () => true,
            nowOverride: _nowFn,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('web.ringdrill.app'), findsOneWidget);
    });
  });

  group('MigrationBanner dismiss', () {
    testWidgets('tapping close writes dismiss timestamp and hides banner',
        (tester) async {
      await tester.pumpWidget(
        _harness(
          MigrationBanner(
            isLegacyHostOverride: () => true,
            nowOverride: _nowFn,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('web.ringdrill.app'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.textContaining('web.ringdrill.app'), findsNothing);

      final prefs = await SharedPreferences.getInstance();
      final ts = prefs.getInt(AppConfig.keyMigrationBannerDismissedAt);
      expect(ts, _now.millisecondsSinceEpoch);
    });
  });

  group('MigrationBanner actions', () {
    testWidgets('primary action calls export override', (tester) async {
      var exportCalled = false;

      await tester.pumpWidget(
        _harness(
          MigrationBanner(
            isLegacyHostOverride: () => true,
            nowOverride: _nowFn,
            onExportOverride: () async => exportCalled = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Export all my plans'));
      await tester.pumpAndSettle();

      expect(exportCalled, isTrue);
    });

    testWidgets('secondary action calls open-new-app override', (tester) async {
      Uri? launchedUri;

      await tester.pumpWidget(
        _harness(
          MigrationBanner(
            isLegacyHostOverride: () => true,
            nowOverride: _nowFn,
            onOpenNewAppOverride: (uri) async => launchedUri = uri,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open the new app'));
      await tester.pumpAndSettle();

      expect(launchedUri?.host, 'web.ringdrill.app');
    });
  });
}
