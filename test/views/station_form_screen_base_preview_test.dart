import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/views/station_form_screen.dart';
import 'package:ringdrill/views/widgets/brief_markdown.dart';

/// DESIGN-010 prompt 2b fix 1 — the per-section preview eye must be enabled
/// on the base section too (not just the addable markdown sections), since
/// the station description is a token-aware markdown body living there.
/// The name field and PositionFormField stay editable regardless.
void main() {
  Future<void> useWideSurface(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  Future<AppLocalizations> openStation(
    WidgetTester tester,
    Station station,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (ctx) => TextButton(
            onPressed: () => Navigator.push<StationFormResult>(
              ctx,
              MaterialPageRoute(
                builder: (_) => StationFormScreen(
                  station: station,
                  variables: const [
                    DrillVariable(name: 'radio', value: 'Kanal 8'),
                  ],
                ),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    return AppLocalizations.delegate.load(const Locale('en'));
  }

  testWidgets(
    'the base section eye is enabled and previews the description, while '
    'the name field and position stay editable',
    (tester) async {
      await useWideSurface(tester);
      final station = Station(
        index: 0,
        name: 'Post 1',
        position: const LatLng(59.91, 10.75),
        description: 'Bruk {{var.radio}}',
      );
      final l = await openStation(tester, station);

      // Enabled — not disabled like a base section with no previewable
      // field would be.
      final toggle = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.visibility_outlined),
          matching: find.byType(IconButton),
        ),
      );
      expect(toggle.onPressed, isNotNull);
      expect(toggle.tooltip, l.formSectionPreviewAction);

      expect(find.widgetWithText(TextFormField, 'Post 1'), findsOneWidget);
      expect(find.byType(BriefMarkdown), findsNothing);

      await tester.tap(find.byTooltip(l.formSectionPreviewAction));
      await tester.pumpAndSettle();

      // The description resolves and renders via BriefMarkdown...
      expect(find.byType(BriefMarkdown), findsOneWidget);
      expect(find.textContaining('Bruk Kanal 8'), findsOneWidget);
      // ...while the name field and the position picker are untouched.
      expect(find.widgetWithText(TextFormField, 'Post 1'), findsOneWidget);
      expect(find.byTooltip(l.formSectionEditAction), findsOneWidget);

      await tester.tap(find.byTooltip(l.formSectionEditAction));
      await tester.pumpAndSettle();

      expect(find.byType(BriefMarkdown), findsNothing);
      expect(find.widgetWithText(TextFormField, 'Post 1'), findsOneWidget);
    },
  );
}
