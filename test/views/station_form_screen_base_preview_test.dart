import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/views/station_form_screen.dart';
import 'package:ringdrill/views/widgets/brief_markdown.dart';

/// DESIGN-010 (revised 2026-07-10) — the base section's preview eye swaps
/// the WHOLE section between its editable fields and the rollup preview
/// (which renders the description as lead plus every section), rather than
/// previewing just the description field inline. This replaced the old
/// bottom "Vis detaljer" toggle + side-by-side pane, which squeezed the
/// fields on medium-wide and hid the toggle below the fold on narrow.
Exercise _exercise() => Exercise(
  uuid: 'ex-1',
  name: 'Exercise',
  startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
  endTime: const SimpleTimeOfDay(hour: 9, minute: 0),
  numberOfTeams: 3,
  numberOfRounds: 1,
  executionTime: 10,
  evaluationTime: 5,
  rotationTime: 2,
  stations: const [Station(index: 0, name: 'Post 1')],
  schedule: const [],
);

void main() {
  Future<void> useWideSurface(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  Future<AppLocalizations> openStation(
    WidgetTester tester,
    Station station, {
    Exercise? parentExercise,
  }) async {
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
                  parentExercise: parentExercise,
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
    'the base section eye swaps the whole section to the rollup preview and '
    'back',
    (tester) async {
      await useWideSurface(tester);
      final station = Station(
        index: 0,
        name: 'Post 1',
        position: const LatLng(59.91, 10.75),
        description: 'Bruk {{var.radio}}',
      );
      final l = await openStation(tester, station);

      // Enabled on the base section — its eye toggles the rollup preview.
      final toggle = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.visibility_outlined),
          matching: find.byType(IconButton),
        ),
      );
      expect(toggle.onPressed, isNotNull);
      expect(toggle.tooltip, l.formSectionPreviewAction);

      // Edit mode: the structural name field is shown, nothing rendered.
      expect(find.widgetWithText(TextFormField, 'Post 1'), findsOneWidget);
      expect(find.byType(BriefMarkdownBlock), findsNothing);

      await tester.tap(find.byTooltip(l.formSectionPreviewAction));
      await tester.pumpAndSettle();

      // The whole section is now the rollup: the description resolves and
      // renders (as lead), and the structural name field is swapped out.
      expect(find.byType(BriefMarkdownBlock), findsWidgets);
      expect(find.textContaining('Bruk Kanal 8'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Post 1'), findsNothing);
      expect(find.byTooltip(l.formSectionEditAction), findsOneWidget);

      // Back to edit restores the fields.
      await tester.tap(find.byTooltip(l.formSectionEditAction));
      await tester.pumpAndSettle();

      expect(find.byType(BriefMarkdownBlock), findsNothing);
      expect(find.widgetWithText(TextFormField, 'Post 1'), findsOneWidget);
    },
  );

  testWidgets(
    'the base-section rollup resolves {{station.*}} and {{exercise.*}} '
    'together — a missing ExerciseScope must not drag the field to literal',
    (tester) async {
      await useWideSurface(tester);
      final station = Station(
        index: 0,
        name: 'Post 1',
        // Mixes the station's own facet with the parent exercise's: the
        // editor offers {{exercise.*}} tokens, so it must provide the scope,
        // or the all-or-nothing mustache render throws and takes {{station.*}}
        // down with it (the same gap the roleplay editor had).
        description:
            'Her på {{station.name}} er det {{exercise.numberOfTeams}} lag.',
      );
      final l = await openStation(tester, station, parentExercise: _exercise());

      await tester.tap(find.byTooltip(l.formSectionPreviewAction));
      await tester.pumpAndSettle();

      // _exercise() declares numberOfTeams: 3.
      expect(
        find.textContaining('Her på Post 1 er det 3 lag.'),
        findsOneWidget,
      );
      expect(find.textContaining('{{'), findsNothing);
    },
  );
}
