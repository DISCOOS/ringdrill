import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/actor.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/brief_screen.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

// ---------------------------------------------------------------------------
// Fixtures (shared with brief_screen_test)
// ---------------------------------------------------------------------------

const _programUuid = 'prog-sheet';
const _exerciseUuid = 'ex-sheet';
const _actorUuid = 'actor-sheet';

final _actor = Actor(uuid: _actorUuid, realName: 'Sheet Actor', phone: null);

const _rolePlay = RolePlay(
  uuid: 'rp-sheet',
  index: 0,
  exerciseUuid: _exerciseUuid,
  name: 'Sheet Role',
  age: 30,
  signalement: 'Tall',
  behavior: 'Calm',
  stationIndex: 0,
  actorUuid: _actorUuid,
);

Exercise _exercise() => Exercise(
  uuid: _exerciseUuid,
  name: 'Sheet Exercise',
  startTime: const SimpleTimeOfDay(hour: 9, minute: 0),
  endTime: const SimpleTimeOfDay(hour: 10, minute: 0),
  numberOfTeams: 2,
  numberOfRounds: 1,
  executionTime: 60,
  evaluationTime: 15,
  rotationTime: 5,
  stations: const [
    Station(
      index: 0,
      name: 'Station A',
      position: LatLng(59.0, 10.0),
      situationMd: 'A situation.',
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
    'version': '1.1',
  };
  return {
    'app:activeProgram:v1': _programUuid,
    'app:librarySchema:v1': '1',
    'p:$_programUuid': jsonEncode({
      'uuid': _programUuid,
      'name': 'Sheet Program',
      'description': '',
      'metadata': meta,
      'exercises': [],
      'teams': [],
      'sessions': [],
      'rolePlays': [],
      'actors': [],
    }),
    'pe:$_programUuid:$_exerciseUuid': jsonEncode(ex.toJson()),
    'pr:$_programUuid:rp-sheet': jsonEncode(_rolePlay.toJson()),
    'pa:$_programUuid:$_actorUuid': jsonEncode(_actor.toJson()),
  };
}

Widget _buildLauncher({String? exerciseUuid, String? programUuid}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: _BriefSheetHarness(
      exerciseUuid: exerciseUuid,
      programUuid: programUuid,
    ),
  );
}

class _BriefSheetHarness extends StatefulWidget {
  const _BriefSheetHarness({this.exerciseUuid, this.programUuid});

  final String? exerciseUuid;
  final String? programUuid;

  @override
  State<_BriefSheetHarness> createState() => _BriefSheetHarnessState();
}

class _BriefSheetHarnessState extends State<_BriefSheetHarness> {
  final _controller = ContextSheetController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.show(
        context,
        BriefSheetTarget(
          exerciseUuid: widget.exerciseUuid,
          programUuid: widget.programUuid,
        ),
      );
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

/// Wait for the sheet to fully open: the post-frame callback schedules the
/// showModalBottomSheet, which runs after the first pump; then we need a
/// runAsync + two pumps to let the async render future complete.
Future<void> _awaitSheetOpen(WidgetTester tester) async {
  await tester.pump(); // post-frame callback fires → showModalBottomSheet
  await tester.pump(); // sheet open animation starts
  await tester.runAsync(() async {
    await Future<void>.delayed(Duration.zero);
  });
  await tester.pump(); // drains _renderFuture microtask chain
  await tester.pump(); // FutureBuilder rebuilds
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    SharedPreferences.setMockInitialValues(_buildPrefs());
    await ProgramService().init();
    // Pre-warm the rootBundle cache so loadString resolves via microtask.
    await rootBundle.loadString(
      'assets/templates/ringdrill-standard-v1.nb.md.mustache',
    );
  });

  group('BriefSheetLauncher', () {
    testWidgets('opens a DraggableScrollableSheet', (tester) async {
      await tester.pumpWidget(_buildLauncher(exerciseUuid: _exerciseUuid));
      await _awaitSheetOpen(tester);

      expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    });

    testWidgets('sheet contains BriefScreen with close button', (tester) async {
      await tester.pumpWidget(_buildLauncher(exerciseUuid: _exerciseUuid));
      await _awaitSheetOpen(tester);

      expect(find.byType(BriefScreen), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('tapping close button calls the onClose callback', (
      tester,
    ) async {
      // Test the isSheet + onClose mechanism directly on BriefScreen rather
      // than through the full sheet stack to avoid timing-sensitive modal
      // animation assertions.
      bool closeCalled = false;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BriefScreen(
            exerciseUuid: _exerciseUuid,
            isSheet: true,
            onClose: () => closeCalled = true,
          ),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pump();
      await tester.pump();

      expect(find.byIcon(Icons.close), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(closeCalled, isTrue, reason: 'onClose should be called on tap');
    });
  });
}
