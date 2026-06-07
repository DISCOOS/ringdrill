import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/widgets/ring_rotation_figure.dart';

Widget _wrap(RingRotationFigure figure, {ThemeData? theme}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: theme,
  home: Scaffold(body: Center(child: figure)),
);

void main() {
  testWidgets('RingRotationFigure renders in light theme without exception', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const RingRotationFigure(size: 240), theme: ThemeData.light()),
    );
    await tester.pump();

    expect(find.byType(CustomPaint), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('RingRotationFigure renders in dark theme without exception', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const RingRotationFigure(size: 240), theme: ThemeData.dark()),
    );
    await tester.pump();

    expect(find.byType(CustomPaint), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('RingRotationFigure respects the size parameter', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const RingRotationFigure(size: 120), theme: ThemeData.light()),
    );
    await tester.pump();

    // The CustomPaint inside RingRotationFigure (not any ancestor paints).
    final figurePaint = find.descendant(
      of: find.byType(RingRotationFigure),
      matching: find.byType(CustomPaint),
    );
    final renderObject = tester.renderObject<RenderBox>(figurePaint);
    // Width is exactly as requested; height follows 212/240 aspect ratio.
    expect(renderObject.size.width, closeTo(120, 1));
    expect(renderObject.size.height, closeTo(120 * 212 / 240, 1));
  });
}
