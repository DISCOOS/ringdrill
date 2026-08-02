// One rule for what a view selector shows, because four screens had four answers.
//
// Reported from a phone: the coordinator's Info · Stations · Teams · Map row was wider
// than the screen. It did not overflow — it sat in a horizontal scroll view — which is
// worse in one way: the last segment is simply off the edge, and nothing says so.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/views/widgets/view_segments.dart';

/// Resolves the rule at a given window width, since it reads the window class from
/// context rather than taking it as an argument.
Future<SegmentDisplay> _displayAt(
  WidgetTester tester, {
  required double width,
  required int segments,
  double? paneWidth,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  late SegmentDisplay resolved;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          resolved = segmentDisplayFor(
            context,
            segments: segments,
            paneWidth: paneWidth,
          );
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return resolved;
}

void main() {
  group('the rule', () {
    testWidgets('compact drops the icons and keeps the labels', (tester) async {
      // The label names the view; the icon beside it is decoration, so it goes first.
      expect(
        await _displayAt(tester, width: 400, segments: 3),
        SegmentDisplay.labelOnly,
      );
    });

    testWidgets('a roomy window shows both', (tester) async {
      expect(
        await _displayAt(tester, width: 1200, segments: 3),
        SegmentDisplay.iconAndLabel,
      );
    });

    testWidgets('four segments never carry icons, at any width', (
      tester,
    ) async {
      // Both screens with four had the same bug, and `PlanView` had already
      // concluded this locally before the rule was shared.
      expect(
        await _displayAt(tester, width: 1600, segments: 4),
        SegmentDisplay.labelOnly,
      );
    });

    testWidgets('a pane too narrow for text falls back to icons', (
      tester,
    ) async {
      // PlanView's master pane on a wide window: the window is expanded but the pane
      // it hands the selector is not, which is why the rule takes a pane width at all.
      expect(
        await _displayAt(tester, width: 1600, segments: 4, paneWidth: 320),
        SegmentDisplay.iconOnly,
      );
    });

    testWidgets('a wide pane on a compact window still drops the icons', (
      tester,
    ) async {
      // Passing a pane width must not re-introduce icons on a phone.
      expect(
        await _displayAt(tester, width: 400, segments: 2, paneWidth: 400),
        SegmentDisplay.labelOnly,
      );
    });
  });

  group('viewSegment', () {
    ButtonSegment<int> build(SegmentDisplay display) =>
        viewSegment(value: 1, icon: Icons.map, label: 'Map', display: display);

    test('labelOnly draws no icon', () {
      final segment = build(SegmentDisplay.labelOnly);
      expect(segment.icon, isNull);
      expect(segment.label, isNotNull);
    });

    test('iconOnly keeps the label reachable as a tooltip', () {
      // Asking the reader to know the glyphs is the cost of this mode, so the label
      // has to survive somewhere.
      final segment = build(SegmentDisplay.iconOnly);
      expect(segment.label, isNull);
      expect(segment.icon, isA<Tooltip>());
      expect((segment.icon as Tooltip).message, 'Map');
    });

    test('iconAndLabel draws both, and the label never wraps', () {
      // A wrapping label makes the button taller than the row it sits in rather than
      // eliding.
      final segment = build(SegmentDisplay.iconAndLabel);
      expect(segment.icon, isA<Icon>());
      final label = segment.label as Text;
      expect(label.maxLines, 1);
      expect(label.overflow, TextOverflow.ellipsis);
    });
  });
}
