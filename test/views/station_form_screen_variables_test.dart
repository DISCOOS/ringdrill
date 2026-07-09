import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/views/station_form_screen.dart';
import 'package:ringdrill/views/widgets/token_text_editing_controller.dart';

/// DESIGN-008 follow-up 07 — the section-navigated `StationFormScreen`:
/// the override table (`VariableOverridesSection`) at station scope,
/// token-aware markdown fields resolving through the full
/// program→exercise→station cascade, and save-time undeclared-token
/// validation. No explicit surface size is set: the default
/// `flutter_test` surface (800x600) already lands in the wide/medium
/// window class, so these tests exercise the master/detail rail directly
/// (tapping a section label needs no switcher-sheet step first).

Station _station({
  String name = 'Post 1',
  String? situationMd,
  Map<String, String> variableOverrides = const {},
}) => Station(
  index: 0,
  name: name,
  position: const LatLng(58.99, 10.43),
  situationMd: situationMd,
  variableOverrides: variableOverrides,
);

Exercise _exercise({Map<String, String> variableOverrides = const {}}) =>
    Exercise(
      uuid: 'ex-1',
      name: 'Exercise',
      startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
      endTime: const SimpleTimeOfDay(hour: 9, minute: 0),
      numberOfTeams: 1,
      numberOfRounds: 1,
      executionTime: 10,
      evaluationTime: 5,
      rotationTime: 5,
      stations: const [],
      schedule: const [],
      variableOverrides: variableOverrides,
    );

class _Captured {
  StationFormResult? value;
}

Future<void> _openForm(
  WidgetTester tester,
  Station station,
  Exercise parentExercise,
  List<DrillVariable> variables,
  _Captured captured,
) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (ctx) => TextButton(
          onPressed: () async {
            captured.value = await Navigator.push<StationFormResult>(
              ctx,
              MaterialPageRoute(
                builder: (_) => StationFormScreen(
                  station: station,
                  parentExercise: parentExercise,
                  variables: variables,
                ),
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
}

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets('the override table shows the inherited value at station scope '
      '(program overlaid by the enclosing exercise)', (tester) async {
    await _openForm(
      tester,
      _station(),
      _exercise(variableOverrides: const {'frekvens': 'Kanal 8'}),
      const [DrillVariable(name: 'frekvens', value: 'Kanal 6')],
      _Captured(),
    );

    await tester.tap(find.text(l.variablesSectionTitle));
    await tester.pumpAndSettle();

    expect(
      find.text('(Kanal 8)'),
      findsOneWidget,
      reason:
          'inherited at station scope means program overlaid by the '
          'enclosing exercise, not the bare program default',
    );
  });

  testWidgets(
    'a local override value writes to station.variableOverrides on save',
    (tester) async {
      final captured = _Captured();
      await _openForm(tester, _station(), _exercise(), const [
        DrillVariable(name: 'frekvens', value: 'Kanal 6'),
      ], captured);

      await tester.tap(find.text(l.variablesSectionTitle));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(
          TextFormField,
          l.variableOverridesSectionLocalValueLabel,
        ),
        'Kanal 9',
      );
      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();

      expect(captured.value, isNotNull);
      expect(captured.value!.station.variableOverrides, {
        'frekvens': 'Kanal 9',
      });
    },
  );

  testWidgets('a token-aware station field resolves the full cascade: station '
      'override shadows exercise override shadows program default', (
    tester,
  ) async {
    await _openForm(
      tester,
      _station(
        situationMd: 'x',
        variableOverrides: const {'frekvens': 'Kanal 9'},
      ),
      _exercise(variableOverrides: const {'frekvens': 'Kanal 8'}),
      const [DrillVariable(name: 'frekvens', value: 'Kanal 6')],
      _Captured(),
    );

    await tester.tap(find.text(l.briefSectionStationSituation));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'x /');
    await tester.pump();
    await tester.pump();

    expect(find.text('frekvens'), findsOneWidget);
    expect(find.text('Kanal 9'), findsOneWidget);
    expect(find.text('Kanal 8'), findsNothing);
    expect(find.text('Kanal 6'), findsNothing);
  });

  testWidgets(
    'creating a variable inline declares it (no save-block) and returns it '
    'in additions.variables (ADR-0047, DESIGN-009 follow-up 4)',
    (tester) async {
      final captured = _Captured();
      await _openForm(
        tester,
        _station(situationMd: 'x'),
        _exercise(),
        const [],
        captured,
      );

      await tester.tap(find.text(l.briefSectionStationSituation));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'x /frekvens');
      await tester.pump();
      await tester.pump();

      final createVar = l.tokenMenuCreateVariable('frekvens');
      await tester.tap(find.text(createVar));
      await tester.pump();

      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();

      expect(captured.value, isNotNull);
      expect(
        captured.value!.additions.variables.map((v) => v.name),
        ['frekvens'],
      );
    },
  );

  testWidgets(
    'creating a location/person inline adds it straight to the station '
    '(no write-back — the station owns them directly)',
    (tester) async {
      final captured = _Captured();
      await _openForm(
        tester,
        _station(situationMd: 'x'),
        _exercise(),
        const [],
        captured,
      );

      await tester.tap(find.text(l.briefSectionStationSituation));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'x /Sentrum');
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text(l.tokenMenuCreateLocation('Sentrum')));
      await tester.pump();

      // The menu inserted a token for the just-created location; read its
      // slug back from the field text rather than assuming a name-derived
      // value (DESIGN-009 follow-up 4h — slugs are now random).
      final editableFinder = find.byType(EditableText);
      final controller =
          tester.widget<EditableText>(editableFinder).controller
              as TokenTextEditingController;
      final tokenMatch = RegExp(
        r'\{\{station\.loc\.[a-z][a-z0-9_]*\}\}',
      ).firstMatch(controller.text);
      expect(tokenMatch, isNotNull);
      final token = tokenMatch!.group(0)!;

      // The just-created location has no place/position yet, so its bare
      // token chips amber — "declared but empty", the same as a freshly
      // created {{var.x}} (ADR-0046/ADR-0047 share this three-way state).
      final span = controller.buildTextSpan(
        context: tester.element(editableFinder),
        style: const TextStyle(),
        withComposing: false,
      );
      Color? chipColor;
      span.visitChildren((child) {
        if (child is TextSpan && child.text == token) {
          chipColor = child.style?.color;
          return false;
        }
        return true;
      });
      expect(chipColor, Colors.amber.shade900);

      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();

      expect(captured.value, isNotNull);
      expect(captured.value!.station.locations, hasLength(1));
      expect(captured.value!.station.locations.single.label, 'Sentrum');
      // Not part of the write-back: the station owns this directly.
      expect(captured.value!.additions.stationLocations, isEmpty);
    },
  );

  testWidgets(
    'save is blocked on an undeclared token; removing it unblocks save',
    (tester) async {
      final captured = _Captured();
      await _openForm(
        tester,
        _station(situationMd: 'Bruk {{var.mangler}}'),
        _exercise(),
        const [],
        captured,
      );

      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();
      expect(captured.value, isNull);
      expect(
        find.text(
          l.programSaveBlockedUndeclaredVariable(
            l.briefSectionStationSituation,
          ),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text(l.briefSectionStationSituation));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, l.briefSectionStationSituation),
        'Bruk radio',
      );

      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();
      expect(captured.value, isNotNull);
      expect(captured.value!.station.situationMd, 'Bruk radio');
    },
  );
}
