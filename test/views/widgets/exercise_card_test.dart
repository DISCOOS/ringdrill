import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/views/program_view.dart';

Exercise _exercise() => Exercise(
  uuid: 'exercise-card-test',
  name: 'Search exercise',
  startTime: const SimpleTimeOfDay(hour: 10, minute: 0),
  endTime: const SimpleTimeOfDay(hour: 11, minute: 0),
  numberOfTeams: 1,
  numberOfRounds: 1,
  executionTime: 45,
  evaluationTime: 10,
  rotationTime: 5,
  stations: const [],
  schedule: const [],
);

Widget _harness({VoidCallback? onOpen, VoidCallback? onLongPress}) =>
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => ExerciseCard(
            exercise: _exercise(),
            localizations: AppLocalizations.of(context)!,
            markers: const [],
            onOpen: onOpen,
            onLongPress: onLongPress,
          ),
        ),
      ),
    );

void main() {
  testWidgets('long-pressing card fires onLongPress only', (tester) async {
    var openCount = 0;
    var longPressCount = 0;
    await tester.pumpWidget(
      _harness(onOpen: () => openCount++, onLongPress: () => longPressCount++),
    );

    await tester.longPress(find.text('Search exercise'));
    await tester.pump();

    expect(longPressCount, 1);
    expect(openCount, 0);
  });
}
