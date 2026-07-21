import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/position_widget.dart';

void main() {
  Future<void> pump(WidgetTester tester, PositionWidget widget) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: widget),
      ),
    );
    await tester.pump();
  }

  const position = LatLng(59.09978, 10.403795);

  group('PositionFormat.utm', () {
    testWidgets('renders easting (E) before northing (N) as a CodeChip', (
      tester,
    ) async {
      await pump(
        tester,
        const PositionWidget(position: position, format: PositionFormat.utm),
      );

      expect(find.byType(SelectableText), findsNothing);
      expect(find.text('32V 0580414E 6552008N'), findsOneWidget);
    });
  });

  group('PositionFormat.dd', () {
    testWidgets('renders decimal-degree lat/lng as a CodeChip', (
      tester,
    ) async {
      await pump(
        tester,
        const PositionWidget(position: position, format: PositionFormat.dd),
      );

      expect(find.text('59.0998N 10.4038E'), findsOneWidget);
    });
  });

  group('useETRS89', () {
    // useETRS89 only picks which datum the coordinate is projected against;
    // it must never change the visible text's shape (no "(ETRS89)" suffix
    // or similar) — both render identically.
    testWidgets('renders the same "<zone><band> <easting>E <northing>N" '
        'shape whether true or false', (tester) async {
      await pump(
        tester,
        const PositionWidget(
          position: position,
          format: PositionFormat.utm,
          useETRS89: true,
        ),
      );
      final etrs89Text = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>()
          .firstWhere((t) => RegExp(r'^\d+\w \d+E \d+N$').hasMatch(t));

      await pump(
        tester,
        const PositionWidget(
          position: position,
          format: PositionFormat.utm,
          useETRS89: false,
        ),
      );
      final wgs84Text = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>()
          .firstWhere((t) => RegExp(r'^\d+\w \d+E \d+N$').hasMatch(t));

      expect(etrs89Text, wgs84Text);
      expect(etrs89Text, isNot(contains('ETRS89')));
    });
  });

  group('position: null', () {
    testWidgets('renders plain Text with the noLocation string, not a chip', (
      tester,
    ) async {
      await pump(tester, const PositionWidget(position: null));

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.noLocation), findsOneWidget);
      // No chip chrome (copy icon) for the null case.
      expect(find.byIcon(Icons.content_copy), findsNothing);
    });
  });
}
