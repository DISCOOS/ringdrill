import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/services/geocoding_service.dart';
import 'package:ringdrill/utils/station_scenario_tokens.dart';
import 'package:ringdrill/views/widgets/variable_value_field.dart';

/// DESIGN-008 follow-up 11 — the type-aware value input. The location cases
/// prove the "typed or pasted" coordinate contract: a decimal lat,lng and
/// the equivalent UTM string parse to the same position, address geocoding
/// fills place + position, and unreadable input surfaces inline instead of
/// being silently dropped. No test touches the network: geocoding injects a
/// fake ([_FakeGeocodingService], same shape as the Location form's tests).

class _FakeGeocodingService implements GeocodingService {
  _FakeGeocodingService({this.searchResults = const []});

  final List<GeocodingHit> searchResults;

  @override
  Future<List<GeocodingHit>> search(String query, {LatLng? near}) async =>
      searchResults;

  @override
  Future<String> reverse(LatLng point) async => 'Reversed Place';
}

class _Captured {
  String value = '';
  VariableLocation? location;
}

Future<void> _pump(
  WidgetTester tester, {
  required VariableType type,
  String value = '',
  VariableLocation? location,
  GeocodingService? geocoder,
  bool accent = false,
  required _Captured captured,
}) {
  return tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: VariableValueField(
            type: type,
            value: value,
            location: location,
            accent: accent,
            geocodingService: geocoder ?? _FakeGeocodingService(),
            onChanged: (v, loc) {
              captured.value = v;
              captured.location = loc;
            },
          ),
        ),
      ),
    ),
  );
}

/// The coordinate text field: the location composite renders place first,
/// then the coordinate field, then the map position card.
Finder _coordinateField(AppLocalizations l) =>
    find.widgetWithText(TextFormField, l.variableLocationCoordinateLabel);

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets(
    'accent tints the field border with the app\'s primary color '
    '(DESIGN-008 follow-up 12)',
    (tester) async {
      final captured = _Captured();
      await _pump(
        tester,
        type: VariableType.string,
        accent: true,
        captured: captured,
      );

      final fieldFinder = find.byType(TextField);
      final field = tester.widget<TextField>(fieldFinder);
      final border = field.decoration?.enabledBorder as UnderlineInputBorder?;
      expect(border, isNotNull);

      final theme = Theme.of(tester.element(fieldFinder));
      expect(border!.borderSide.color, theme.colorScheme.primary);
    },
  );

  testWidgets(
    'no accent leaves the field\'s default border untouched',
    (tester) async {
      final captured = _Captured();
      await _pump(tester, type: VariableType.string, captured: captured);

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.decoration?.enabledBorder, isNull);
    },
  );

  testWidgets('a non-numeric number surfaces an inline error', (tester) async {
    final captured = _Captured();
    await _pump(tester, type: VariableType.number, captured: captured);

    await tester.enterText(find.byType(TextFormField), 'abc');
    await tester.pump();

    expect(captured.value, 'abc');
    expect(find.text(l.variableValueInvalidNumber), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '42');
    await tester.pump();
    expect(captured.value, '42');
    expect(find.text(l.variableValueInvalidNumber), findsNothing);
  });

  testWidgets('a time value displays HH:MM and the clear action empties it', (
    tester,
  ) async {
    final captured = _Captured()..value = '09:30';
    await _pump(
      tester,
      type: VariableType.time,
      value: '09:30',
      captured: captured,
    );

    expect(find.text('09:30'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.clear));
    await tester.pump();
    expect(captured.value, '');
  });

  testWidgets(
    'a decimal lat,lng and the equivalent UTM string parse to the same '
    'position (typed or pasted)',
    (tester) async {
      const original = LatLng(59.7445, 10.2045);

      final fromDecimal = _Captured();
      await _pump(
        tester,
        type: VariableType.location,
        captured: fromDecimal,
      );
      await tester.enterText(_coordinateField(l), '59.7445,10.2045');
      await tester.pump();
      expect(fromDecimal.location?.position, isNotNull);
      expect(
        fromDecimal.location!.position!.latitude,
        closeTo(original.latitude, 1e-6),
      );

      // Fresh field, the same point pasted as the app's own UTM display
      // string ("32V 0580414E 6552008N").
      final fromUtm = _Captured();
      await _pump(tester, type: VariableType.location, captured: fromUtm);
      await tester.enterText(_coordinateField(l), formatUtm(original));
      await tester.pump();
      expect(fromUtm.location?.position, isNotNull);
      expect(
        fromUtm.location!.position!.latitude,
        closeTo(fromDecimal.location!.position!.latitude, 1e-4),
      );
      expect(
        fromUtm.location!.position!.longitude,
        closeTo(fromDecimal.location!.position!.longitude, 1e-4),
      );
    },
  );

  testWidgets('unreadable coordinate input surfaces an inline error and '
      'blocks rather than dropping', (tester) async {
    final captured = _Captured();
    await _pump(tester, type: VariableType.location, captured: captured);

    await tester.enterText(_coordinateField(l), 'not a coordinate');
    await tester.pump();

    expect(find.text(l.variableValueInvalidCoordinate), findsOneWidget);
    expect(captured.location?.position, isNull);
  });

  testWidgets('an address geocode suggestion fills place and position', (
    tester,
  ) async {
    const hit = LatLng(59.7445, 10.2045);
    final captured = _Captured();
    await _pump(
      tester,
      type: VariableType.location,
      geocoder: _FakeGeocodingService(
        searchResults: const [GeocodingHit('Meiselen 14, Drammen', hit)],
      ),
      captured: captured,
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, l.locationsSectionPlaceLabel),
      'Meiselen',
    );
    // Past the search debounce (350 ms).
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    await tester.tap(find.text('Meiselen 14, Drammen'));
    await tester.pump();

    expect(captured.location?.place, 'Meiselen 14, Drammen');
    expect(captured.location?.position?.latitude, closeTo(59.7445, 1e-9));
    // The coordinate field reflects the picked position as UTM.
    expect(find.textContaining('32V'), findsWidgets);
  });
}
