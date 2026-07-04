import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/widgets/ringdrill_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// DESIGN-008 follow-up 11 guard — a modal choke point with no active
/// program must still degrade to an empty [PlanScope] (plain text, no
/// throw), not crash on `ProgramService().activeProgram!.variables`.
/// Kept in its own file so `ProgramService()`'s singleton state starts
/// clean (no active program set anywhere else in this test process),
/// rather than sharing a file with tests that seed an active program.
void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({'app:librarySchema:v1': '1'});
    await ProgramService().init();
  });

  testWidgets('showRingdrillActionSheet renders with no throw when there is no '
      'active program', (tester) async {
    expect(ProgramService().activeProgram, isNull);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showRingdrillActionSheet<void>(
              context: context,
              builder: (_) => const Text('Body'),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Body'), findsOneWidget);
  });
}
