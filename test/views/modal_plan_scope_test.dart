import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/views/brief_screen.dart';
import 'package:ringdrill/views/station_screen.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// DESIGN-008 follow-up 11 — the root-cause fix: `showModalBottomSheet`/
/// `showDialog` push onto the Navigator's `Overlay`, a sibling of
/// `MainScreen` rather than a descendant, so the `PlanScope` wrapping
/// `MainScreen` never reached anything opened this way. These tests push
/// real modals through `ContextSheet.show` — the same call sites the app
/// uses — rather than hand-wrapping a `PlanScope` around the widget under
/// test, so they fail the way the reported bug actually failed if the fix
/// regresses.

const _planUuid = 'prog-modal-scope';
const _exerciseUuid = 'ex-modal-scope';

Exercise _exercise() => Exercise(
  uuid: _exerciseUuid,
  name: 'Exercise {{var.frekvens}}',
  startTime: const SimpleTimeOfDay(hour: 9, minute: 0),
  endTime: const SimpleTimeOfDay(hour: 10, minute: 0),
  numberOfTeams: 1,
  numberOfRounds: 1,
  executionTime: 10,
  evaluationTime: 5,
  rotationTime: 5,
  stations: const [
    Station(
      index: 0,
      name: 'Station {{var.frekvens}}',
      position: LatLng(59.0, 10.0),
    ),
  ],
  schedule: const [],
);

Map<String, Object> _buildPrefs() {
  final ex = _exercise();
  final now = DateTime(2026);
  final meta = {
    'created': now.toIso8601String(),
    'updated': now.toIso8601String(),
    'version': '1.2',
  };
  return {
    'app:activePlan:v1': _planUuid,
    'app:librarySchema:v1': '1',
    'p:$_planUuid': jsonEncode({
      'uuid': _planUuid,
      'name': 'Plan {{var.frekvens}}',
      'description': '',
      'metadata': meta,
      'exercises': [],
      'teams': [],
      'sessions': [],
      'rolePlays': [],
      'actors': [],
      'variables': [
        const DrillVariable(name: 'frekvens', value: 'Kanal 8').toJson(),
      ],
    }),
    'pe:$_planUuid:$_exerciseUuid': jsonEncode(ex.toJson()),
  };
}

Widget _buildHarness({
  String? exerciseUuid,
  String? planUuid,
  int? stationIndex,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: _Harness(
      exerciseUuid: exerciseUuid,
      planUuid: planUuid,
      stationIndex: stationIndex,
    ),
  );
}

class _Harness extends StatefulWidget {
  const _Harness({this.exerciseUuid, this.planUuid, this.stationIndex});

  final String? exerciseUuid;
  final String? planUuid;
  final int? stationIndex;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  final _controller = ContextSheetController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = widget.stationIndex != null
          ? StationSheetTarget(
              exerciseUuid: widget.exerciseUuid!,
              stationIndex: widget.stationIndex!,
            )
          : BriefSheetTarget(
              exerciseUuid: widget.exerciseUuid,
              planUuid: widget.planUuid,
            );
      _controller.show(context, target);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ContextSheet(
      controller: _controller,
      child: const Scaffold(body: SizedBox.shrink()),
    );
  }
}

/// Mirrors `brief_sheet_test.dart`'s `_awaitSheetOpen`: the post-frame
/// callback schedules `showModalBottomSheet`, which needs a pump to open,
/// then a runAsync + pumps to drain the brief's async render future.
Future<void> _awaitSheetOpen(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.runAsync(() async {
    await Future<void>.delayed(Duration.zero);
  });
  await tester.pump();
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    SharedPreferences.setMockInitialValues(_buildPrefs());
    await PlanService().init();
    await rootBundle.loadString(
      'assets/templates/ringdrill-standard-v1.nb.md.mustache',
    );
  });

  testWidgets(
    'the brief modal title resolves the plan name, pushed through the '
    'real ContextSheet.show → showRingdrillViewerSheet path',
    (tester) async {
      await tester.pumpWidget(_buildHarness(exerciseUuid: _exerciseUuid));
      await _awaitSheetOpen(tester);

      expect(find.byType(BriefScreen), findsOneWidget);
      expect(find.text('Exercise Kanal 8'), findsWidgets);
      expect(find.textContaining('{{var.frekvens}}'), findsNothing);
    },
  );

  testWidgets('a detail sheet (StationScreen via ContextSheet.show) '
      'resolves the station name in its SheetTitle', (tester) async {
    await tester.pumpWidget(
      _buildHarness(exerciseUuid: _exerciseUuid, stationIndex: 0),
    );
    await _awaitSheetOpen(tester);

    expect(find.byType(StationScreen), findsOneWidget);
    // The SheetTitle prefixes the resolved name with the formatted post
    // number (Station.numberAndName) — "1.1 Station Kanal 8", not the bare
    // resolved name alone.
    expect(find.text('1.1 Station Kanal 8'), findsWidgets);
    expect(find.textContaining('{{var.frekvens}}'), findsNothing);
  });
}
