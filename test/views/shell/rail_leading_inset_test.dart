import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/views/shell/shell_chrome.dart';

/// Regression guard for the landscape-iPhone rail overflow: `WideShell`
/// reserves `72 + railLeadingInset(context)` for the rail, so that value
/// MUST equal the width `wrapInRailPadding` actually lays a 72px rail out
/// at. On iOS landscape `wrapInRailPadding` adds a 12px left inset (it
/// strips the safe-area padding and re-adds a fixed gap); if the reservation
/// didn't include it, the rail+master Row overflowed its parent SizedBox by
/// exactly 12px — the "squiggly lines" the user saw on a landscape iPhone.
void main() {
  /// Pumps a bare 72×100 box through `wrapInRailPadding` at the given
  /// platform + orientation, and returns (its rendered width, the inset the
  /// reservation adds), so the test can assert they agree.
  Future<({double laidOutWidth, double reservedInset})> measure(
    WidgetTester tester, {
    required TargetPlatform platform,
    required Size size,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const railKey = ValueKey('rail-under-test');
    double? inset;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: platform),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: Builder(
              builder: (context) {
                inset = railLeadingInset(context);
                // KeyedSubtree shrink-wraps wrapInRailPadding's output
                // (ColoredBox + Padding + the 72px child), so its measured
                // width is the rail's real laid-out width = inset + 72.
                return KeyedSubtree(
                  key: railKey,
                  child: wrapInRailPadding(
                    context: context,
                    child: const SizedBox(width: 72, height: 100),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    final width = tester.getSize(find.byKey(railKey)).width;
    return (laidOutWidth: width, reservedInset: inset!);
  }

  testWidgets('iOS landscape: reservation (72 + inset) matches the padded '
      'rail width, and the inset is 12', (tester) async {
    final r = await measure(
      tester,
      platform: TargetPlatform.iOS,
      // Landscape: width > height.
      size: const Size(900, 400),
    );
    expect(r.reservedInset, 12.0);
    expect(72.0 + r.reservedInset, r.laidOutWidth);
  });

  testWidgets('iOS portrait: no inset, rail lays out at the bare 72', (
    tester,
  ) async {
    final r = await measure(
      tester,
      platform: TargetPlatform.iOS,
      size: const Size(400, 900),
    );
    expect(r.reservedInset, 0.0);
    expect(72.0 + r.reservedInset, r.laidOutWidth);
  });

  testWidgets('Android landscape: no inset (iOS-only), rail is 72', (
    tester,
  ) async {
    final r = await measure(
      tester,
      platform: TargetPlatform.android,
      size: const Size(900, 400),
    );
    expect(r.reservedInset, 0.0);
    expect(72.0 + r.reservedInset, r.laidOutWidth);
  });
}
