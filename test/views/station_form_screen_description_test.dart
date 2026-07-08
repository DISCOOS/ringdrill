import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/views/station_form_screen.dart';

/// DESIGN-009 — the station description collapses to a "Legg til
/// beskrivelse" affordance in the editor's base section when empty and
/// unfocused, so a section-rich station shows no empty box next to name and
/// position.
void main() {
  Future<void> useWideSurface(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  Future<StationFormResult?> openStation(
    WidgetTester tester,
    Station station,
  ) async {
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
                  builder: (_) => StationFormScreen(station: station),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    return captured;
  }

  testWidgets('an empty description shows the add-description affordance', (
    tester,
  ) async {
    await useWideSurface(tester);
    await openStation(
      tester,
      const Station(
        index: 0,
        name: 'Demens',
        position: LatLng(58.99, 10.43),
      ),
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.text(l10n.stationAddDescriptionAction), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, l10n.stationDescription),
      findsNothing,
    );
  });

  testWidgets('tapping the affordance reveals the focused field', (
    tester,
  ) async {
    await useWideSurface(tester);
    await openStation(
      tester,
      const Station(
        index: 0,
        name: 'Demens',
        position: LatLng(58.99, 10.43),
      ),
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.text(l10n.stationAddDescriptionAction));
    await tester.pumpAndSettle();

    expect(find.text(l10n.stationAddDescriptionAction), findsNothing);
    final field = find.widgetWithText(TextFormField, l10n.stationDescription);
    expect(field, findsOneWidget);
    final editable = tester.widget<EditableText>(
      find.descendant(of: field, matching: find.byType(EditableText)),
    );
    expect(editable.focusNode.hasFocus, isTrue);
  });

  testWidgets('a non-empty description shows the field directly', (
    tester,
  ) async {
    await useWideSurface(tester);
    await openStation(
      tester,
      const Station(
        index: 0,
        name: 'Demens',
        position: LatLng(58.99, 10.43),
        description: 'Åpent jorde ved elva.',
      ),
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.text(l10n.stationAddDescriptionAction), findsNothing);
    expect(find.text('Åpent jorde ved elva.'), findsOneWidget);
  });

  testWidgets('saving round-trips the description text', (tester) async {
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
                    station: const Station(
                      index: 0,
                      name: 'Demens',
                      position: LatLng(58.99, 10.43),
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

    await tester.tap(find.text(l10n.stationAddDescriptionAction));
    await tester.pumpAndSettle();

    final field = find.widgetWithText(TextFormField, l10n.stationDescription);
    await tester.enterText(field, 'Åpent jorde ved elva.');
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.save));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.station.description, 'Åpent jorde ved elva.');
  });
}
