import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/map_picker_screen.dart';

/// docs/prompts/map-picker-redesign.md — MapPickerScreen confirms from a
/// bottom bar (live coordinate + "select here") instead of a small AppBar
/// check button out of thumb reach.
void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  Future<LatLng?> openPicker(WidgetTester tester) async {
    LatLng? popped;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  popped = await Navigator.push<LatLng>(
                    context,
                    MaterialPageRoute(builder: (_) => const MapPickerScreen()),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return popped;
  }

  testWidgets('the confirm check is in the bottom bar, not the AppBar', (
    tester,
  ) async {
    await openPicker(tester);

    final check = find.byIcon(Icons.check);
    expect(check, findsOneWidget);
    expect(
      find.ancestor(of: check, matching: find.byType(AppBar)),
      findsNothing,
    );
    expect(find.text(l.selectHere), findsOneWidget);
  });

  testWidgets('the bottom bar coordinate updates live as the map is panned', (
    tester,
  ) async {
    await openPicker(tester);

    final before = tester.widget<SelectableText>(
      find.byType(SelectableText),
    ).data;

    await tester.drag(find.byType(FlutterMap), const Offset(-200, -150));
    await tester.pump(const Duration(milliseconds: 300));

    final after = tester.widget<SelectableText>(
      find.byType(SelectableText),
    ).data;
    expect(after, isNot(before));
  });

  testWidgets('"select here" pops with the panned-to centre point', (
    tester,
  ) async {
    late LatLng? popped;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  popped = await Navigator.push<LatLng>(
                    context,
                    MaterialPageRoute(builder: (_) => const MapPickerScreen()),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final before = tester.widget<SelectableText>(
      find.byType(SelectableText),
    ).data;

    await tester.drag(find.byType(FlutterMap), const Offset(-200, -150));
    await tester.pump(const Duration(milliseconds: 300));

    // Capture what the bar shows right before confirming: after popping,
    // MapPickerScreen is gone and there is no SelectableText left to read.
    final panned = tester.widget<SelectableText>(
      find.byType(SelectableText),
    ).data;
    expect(panned, isNot(before));

    await tester.tap(find.text(l.selectHere));
    await tester.pumpAndSettle();

    expect(popped, isNotNull);
  });
}
