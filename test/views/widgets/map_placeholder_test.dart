import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/views/widgets/map_placeholder.dart';

/// The shared empty state shown in a map slot with no position to plot:
/// icon + message in a card-shaped tonal box, either a fixed height or
/// filling a height-bounded parent.
void main() {
  Widget harness(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('renders the icon and message', (tester) async {
    await tester.pumpWidget(
      harness(
        const MapPlaceholder(
          height: 200,
          icon: Icons.location_off,
          message: 'No location',
        ),
      ),
    );

    expect(find.byIcon(Icons.location_off), findsOneWidget);
    expect(find.text('No location'), findsOneWidget);
  });

  testWidgets('sizes to the given height', (tester) async {
    await tester.pumpWidget(
      harness(
        const Align(
          alignment: Alignment.topLeft,
          child: MapPlaceholder(height: 240, message: 'x'),
        ),
      ),
    );

    expect(tester.getSize(find.byType(MapPlaceholder)).height, 240);
  });

  testWidgets('fills a height-bounded parent when height is null', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(const SizedBox(height: 500, child: MapPlaceholder(message: 'x'))),
    );

    // No fixed height of its own — takes the parent's tight 500.
    expect(tester.getSize(find.byType(MapPlaceholder)).height, 500);
  });
}
