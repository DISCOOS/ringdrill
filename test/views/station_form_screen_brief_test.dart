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

  testWidgets('seeded equipment section survives a save round-trip', (
    tester,
  ) async {
    await useWideSurface(tester);
    StationFormResult? captured;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (ctx) => TextButton(
            onPressed: () async {
              captured = await Navigator.push<StationFormResult>(
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

    // The Equipment section is seeded as active; switch to it via the rail.
    await tester.tap(find.text(l10n.briefSectionStationEquipment));
    await tester.pumpAndSettle();
    expect(find.text('Stort hus'), findsOneWidget);

    // Save without further edits — the value should round-trip.
    await tester.tap(find.text(l10n.save));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.station.equipmentMd, 'Stort hus');
    expect(captured!.station.situationMd, isNull);
  });

  testWidgets('removing a seeded section clears its value on save', (
    tester,
  ) async {
    await useWideSurface(tester);
    StationFormResult? captured;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (ctx) => TextButton(
            onPressed: () async {
              captured = await Navigator.push<StationFormResult>(
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

    // Switch to the seeded Equipment section, then remove it via its
    // overflow menu's "Remove section" action.
    await tester.tap(find.text(l10n.briefSectionStationEquipment));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.formSectionRemoveAction));
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.save));
    await tester.pumpAndSettle();

    expect(captured!.station.equipmentMd, isNull);
  });

  testWidgets(
    'hides the divider below the optional fields once all are added',
    (tester) async {
      await useWideSurface(tester);
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
                    station: Station(
                      index: 0,
                      name: 'Demens',
                      position: LatLng(58.99, 10.43),
                      equipmentMd: 'Stort hus',
                      situationMd: 'situasjon',
                      missionMd: 'oppdrag',
                      logisticsMd: 'logistikk',
                      criticalQuestionsMd: 'spørsmål',
                      leaderAnswersMd: 'svar',
                      directorNotesMd: 'notater',
                    ),
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

      // No add-buttons left, so the divider above the (now absent)
      // add-buttons row is hidden.
      expect(find.byType(Divider), findsNothing);
    },
  );
}
