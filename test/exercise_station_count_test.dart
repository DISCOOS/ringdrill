import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations_en.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/program_service.dart';

void main() {
  final localizations = AppLocalizationsEn();

  group('decoupled station count', () {
    test('one round can still create four stations for four teams', () {
      final exercise = ProgramService.generateSchedule(
        name: 'One-round ring',
        startTime: const TimeOfDay(hour: 8, minute: 0),
        numberOfTeams: 4,
        numberOfStations: 4,
        numberOfRounds: 1,
        executionTime: 10,
        evaluationTime: 5,
        rotationTime: 2,
        localizations: localizations,
      );

      expect(exercise.stations, hasLength(4));
      expect(exercise.schedule, hasLength(1));
      for (var team = 0; team < 4; team++) {
        expect(exercise.stationIndex(team, 0), team);
      }
    });

    test('more rounds than stations is allowed for revisits', () {
      final exercise = ProgramService.generateSchedule(
        name: 'Revisits',
        startTime: const TimeOfDay(hour: 8, minute: 0),
        numberOfTeams: 4,
        numberOfStations: 4,
        numberOfRounds: 6,
        executionTime: 10,
        evaluationTime: 5,
        rotationTime: 2,
        localizations: localizations,
      );

      expect(exercise.stations, hasLength(4));
      expect(exercise.schedule, hasLength(6));
      expect(exercise.stationIndex(0, 4), 0);
    });

    test('more teams than stations asserts', () {
      expect(
        () => ProgramService.generateSchedule(
          name: 'Too many teams',
          startTime: const TimeOfDay(hour: 8, minute: 0),
          numberOfTeams: 5,
          numberOfStations: 4,
          numberOfRounds: 6,
          executionTime: 10,
          evaluationTime: 5,
          rotationTime: 2,
          localizations: localizations,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('stations and rounds can differ across json round-trip', () {
      final exercise = Exercise(
        uuid: 'exercise-1',
        name: 'Loaded drill',
        startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
        numberOfTeams: 4,
        numberOfRounds: 1,
        executionTime: 10,
        evaluationTime: 5,
        rotationTime: 2,
        stations: const [
          Station(index: 0, name: 'Station 1'),
          Station(index: 1, name: 'Station 2'),
          Station(index: 2, name: 'Station 3'),
          Station(index: 3, name: 'Station 4'),
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

      final reloaded = Exercise.fromJson(
        jsonDecode(jsonEncode(exercise.toJson())) as Map<String, dynamic>,
      );

      expect(reloaded.stations, hasLength(4));
      expect(reloaded.schedule, hasLength(1));
      expect(jsonEncode(reloaded.toJson()), jsonEncode(exercise.toJson()));
    });
  });
}
