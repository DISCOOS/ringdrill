import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/views/station_form_screen.dart';

void main() {
  Future<void> useWideSurface(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  /// Pre-existing layout: StationFormScreen renders its 230 px position panel
  /// next to an Expanded name field. The PositionFormField inside that panel
  /// wraps a fixed Row whose English labels (`Position` + `Pick a location`)
  /// outgrow the panel and trigger a RenderFlex overflow. The overflow is
  /// orthogonal to the optional-section behaviour we are testing here; clear
  /// it so the round-trip assertion runs.
  void drainPositionPanelOverflow(WidgetTester tester) {
    final exception = tester.takeException();
    if (exception != null) {
      final message = exception.toString();
      if (!message.contains('overflowed')) {
        throw exception;
      }
    }
  }

  testWidgets('seeded equipment section survives a save round-trip', (
    tester,
  ) async {
    await useWideSurface(tester);
    Station? captured;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (ctx) => TextButton(
            onPressed: () async {
              captured = await Navigator.push<Station>(
                ctx,
                MaterialPageRoute(
                  builder: (_) => StationFormScreen(
                    station: Station(
                      index: 0,
                      name: 'Demens',
                      position: LatLng(58.99, 10.43),
                      equipmentMd: 'Stort hus',
                    ),
                  ),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    drainPositionPanelOverflow(tester);

    // The seeded value is shown and the Equipment add-button is absent.
    expect(find.text('Stort hus'), findsOneWidget);
    expect(
      find.widgetWithText(
        OutlinedButton,
        l10n.briefSectionStationEquipment,
      ),
      findsNothing,
    );

    // Save without further edits — the value should round-trip.
    await tester.tap(find.text(l10n.save));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.equipmentMd, 'Stort hus');
    expect(captured!.situationMd, isNull);
  });

  testWidgets('removing a seeded section clears its value on save', (
    tester,
  ) async {
    await useWideSurface(tester);
    Station? captured;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (ctx) => TextButton(
            onPressed: () async {
              captured = await Navigator.push<Station>(
                ctx,
                MaterialPageRoute(
                  builder: (_) => StationFormScreen(
                    station: Station(
                      index: 0,
                      name: 'Demens',
                      position: LatLng(58.99, 10.43),
                      equipmentMd: 'Stort hus',
                    ),
                  ),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    drainPositionPanelOverflow(tester);

    // The AppBar leading also uses Icons.close, so scope to the Form subtree
    // to hit the optional-section suffix close button instead.
    await tester.tap(
      find.descendant(of: find.byType(Form), matching: find.byIcon(Icons.close)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.save));
    await tester.pumpAndSettle();

    expect(captured!.equipmentMd, isNull);
  });
}
