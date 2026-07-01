import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/shell/legacy_badge.dart';
import 'package:ringdrill/views/shell/migration_banner.dart';

final _ribbon = find.byKey(const Key('legacyRibbon'));

// The badge sits at the top-left of the harness body (0,0), 96x96. This
// point is inside the top-right corner triangle where the ribbon's tap
// target lives.
const _ribbonTapPoint = Offset(82, 8);

Widget _harness(LegacyBadge badge) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Stack(children: [Positioned(top: 0, left: 0, child: badge)]),
  ),
);

void main() {
  // The badge hides while the banner is visible; default to "banner hidden"
  // so the badge is free to show.
  setUp(() => migrationBannerVisible.value = false);
  tearDown(() => migrationBannerVisible.value = false);

  group('LegacyBadge', () {
    testWidgets('hidden when isLegacyHost returns false', (tester) async {
      await tester.pumpWidget(
        _harness(LegacyBadge(isLegacyHostOverride: () => false)),
      );
      await tester.pump();

      expect(_ribbon, findsNothing);
    });

    testWidgets('visible when isLegacyHost returns true', (tester) async {
      await tester.pumpWidget(
        _harness(LegacyBadge(isLegacyHostOverride: () => true)),
      );
      await tester.pump();

      expect(_ribbon, findsOneWidget);
    });

    testWidgets('hidden while the migration banner is visible', (tester) async {
      await tester.pumpWidget(
        _harness(LegacyBadge(isLegacyHostOverride: () => true)),
      );
      await tester.pump();
      expect(_ribbon, findsOneWidget);

      // Banner takes over → ribbon steps aside.
      migrationBannerVisible.value = true;
      await tester.pump();
      expect(_ribbon, findsNothing);
    });

    testWidgets('tap on the ribbon invokes the tap override', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        _harness(
          LegacyBadge(
            isLegacyHostOverride: () => true,
            onTapOverride: () => tapped = true,
          ),
        ),
      );
      await tester.pump();

      await tester.tapAt(_ribbonTapPoint);
      await tester.pump();

      expect(tapped, isTrue);
    });
  });
}
