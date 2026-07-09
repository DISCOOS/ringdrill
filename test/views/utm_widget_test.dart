import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/utm_widget.dart';

/// `UtmWidget` rendered northing before easting ("6551796N\n0580345E"),
/// the reverse of every other UTM formatter in the app
/// (`station_scenario_tokens.dart`, `locations_section.dart`,
/// `brief_renderer.dart` all render "…E…N") and of what the map search
/// field's parser (`parseCoordinateInput`) accepts. Regression test for
/// the easting-before-northing fix.
void main() {
  Future<String> renderedText(WidgetTester tester, {bool wrapped = true}) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: UtmWidget(
            position: const LatLng(59.09978, 10.403795),
            wrapped: wrapped,
          ),
        ),
      ),
    );
    await tester.pump();
    return tester.widget<SelectableText>(find.byType(SelectableText)).data!;
  }

  testWidgets('renders easting (E) before northing (N), wrapped', (
    tester,
  ) async {
    final text = await renderedText(tester);
    expect(text, '32V 0580414E\n6552008N');
  });

  testWidgets('renders easting (E) before northing (N), unwrapped', (
    tester,
  ) async {
    final text = await renderedText(tester, wrapped: false);
    expect(text, '32V 0580414E 6552008N');
  });
}
