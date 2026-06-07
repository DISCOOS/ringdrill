import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/data/drill_file.dart';
import 'package:ringdrill/models/numbering.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final (assetPath, expectedTeamPrefix) in [
    ('assets/example/onboarding-example.nb.drill', 'Lag'),
    ('assets/example/onboarding-example.en.drill', 'Team'),
  ]) {
    group(assetPath, () {
      late DrillFile drill;

      setUpAll(() async {
        final data = await rootBundle.load(assetPath);
        drill = DrillFile.fromBytes(
          assetPath.split('/').last,
          data.buffer.asUint8List(),
        );
      });

      test('parses without error', () {
        expect(() => drill.program(), returnsNormally);
      });

      test('has 2 exercises', () {
        expect(drill.program().exercises, hasLength(2));
      });

      test('showcased exercise (#2) has 3 stations and 3 teams, 2 rounds', () {
        // Exercises are ordered by index; index=1 is exercise #2.
        final exercises = [...drill.program().exercises]
          ..sort((a, b) => a.index.compareTo(b.index));
        final ex2 = exercises[1];
        expect(ex2.stations, hasLength(3));
        expect(ex2.numberOfTeams, 3);
        expect(ex2.numberOfRounds, 2);
      });

      test('station labels on exercise #2 are 2a/2b/2c (alpha format)', () {
        final program = drill.program();
        expect(program.stationNumberFormat, StationNumberFormat.alpha);
        final exercises = [...program.exercises]
          ..sort((a, b) => a.index.compareTo(b.index));
        final ex2 = exercises[1]; // index=1 → exerciseNumber=2
        for (var i = 0; i < ex2.stations.length; i++) {
          final label = Numbering.station(
            StationNumberFormat.alpha,
            exerciseNumber: 2,
            stationIndex: i,
          );
          expect(label, '2${'abc'[i]}');
        }
      });

      test('has 3 teams starting with "$expectedTeamPrefix"', () {
        final teams = drill.program().teams;
        expect(teams, hasLength(3));
        expect(teams.every((t) => t.name.startsWith(expectedTeamPrefix)), isTrue);
      });

      test('has at least 1 RolePlay on exercise #2', () {
        final program = drill.program();
        final exercises = [...program.exercises]
          ..sort((a, b) => a.index.compareTo(b.index));
        final ex2Uuid = exercises[1].uuid;
        final rolePlays = program.rolePlays
            .where((rp) => rp.exerciseUuid == ex2Uuid)
            .toList();
        expect(rolePlays, isNotEmpty);
      });

      test('has a non-empty brief intro', () {
        final program = drill.program();
        expect(program.briefIntroMd, isNotNull);
        expect(program.briefIntroMd, isNotEmpty);
      });
    });
  }
}
