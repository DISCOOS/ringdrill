import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shared harness for the editor → save → persist round-trip tests
/// (`*_save_roundtrip_test.dart`).
///
/// These tests drive the compact-layout modal [ContextSheet] path end to end:
/// open a sheet to a real default body (CoordinatorScreen, TeamScreen, …),
/// tap its edit affordance so `openFormSurface` dismisses the sheet and
/// pushes the real form, save, and assert the change landed in
/// [ProgramService]. This is the seam none of the form-in-isolation or
/// service-level tests cover — the editors pop a result and rely on the
/// (possibly since-disposed) caller to persist it.

/// Sizes the test window like a phone so `WindowSizeClass.of` reports
/// compact and `openFormSurface` takes the modal-sheet path under test
/// (wide layouts use a dialog and never touch the sheet close/re-open
/// logic).
void useCompactWindow(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Resets the (singleton) [ProgramService] state and activates a fresh
/// empty plan named [planName]. Entities are then seeded through the
/// service's own save methods by each test file. Pair with
/// `tearDown(() => ProgramService().clearAllForTest())`.
Future<void> initActivePlan(String planName) async {
  SharedPreferences.setMockInitialValues({});
  await ProgramService().init();
  await ProgramService().clearAllForTest();
  final program = await ProgramService().createProgram(name: planName);
  await ProgramService().setActive(program.uuid);
}

/// Minimal valid exercise with two stations and one team/round, mirroring
/// the fixture used across the existing view tests.
Exercise makeExercise({required String uuid, required String name}) {
  return Exercise(
    uuid: uuid,
    name: name,
    startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
    numberOfTeams: 1,
    numberOfRounds: 1,
    executionTime: 10,
    evaluationTime: 5,
    rotationTime: 2,
    stations: const [
      Station(index: 0, name: 'Post 1'),
      Station(index: 1, name: 'Post 2'),
    ],
    schedule: const [
      [
        SimpleTimeOfDay(hour: 8, minute: 0),
        SimpleTimeOfDay(hour: 8, minute: 10),
        SimpleTimeOfDay(hour: 8, minute: 15),
      ],
    ],
    endTime: const SimpleTimeOfDay(hour: 8, minute: 17),
  );
}

const String kOpenSheetLabel = 'open sheet';

/// A [MaterialApp] whose home carries a [ContextSheet] (no custom
/// bodyBuilder, so [target] resolves to the real default sheet body) and a
/// button labelled [kOpenSheetLabel] that opens the sheet — mimicking a
/// list-row tap in the production shell, where main_screen wraps everything
/// in a [ContextSheet] the same way.
Widget sheetHost({
  required ContextSheetController controller,
  required ContextSheetTarget target,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: ContextSheet(
      controller: controller,
      child: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => controller.show(context, target),
              child: const Text(kOpenSheetLabel),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Taps the harness button and settles the sheet-open animation.
Future<void> openSheet(WidgetTester tester) async {
  await tester.tap(find.text(kOpenSheetLabel));
  await tester.pumpAndSettle();
}
