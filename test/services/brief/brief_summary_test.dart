// The brief's shape without its prose (ADR-0064).
//
// The point of a summary is to answer "does this read" without spending the whole
// brief, so the tests are about what it *names* — codes, sections present, sections
// empty — and about the audience filter, which is what makes it honest rather than
// a table of contents.
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/brief/brief_audience.dart';
import 'package:ringdrill/services/brief/brief_summary.dart';

Plan _plan() {
  final now = DateTime(2026);
  const stations = [
    Station(
      index: 0,
      name: 'Turgåer',
      situationMd: 'Kåre er savnet.',
      leaderAnswersMd: 'Svart Volvo.',
      directorNotesMd: 'Markør bak paviljongen.',
    ),
    Station(index: 1, name: 'Fisker', situationMd: 'Kari er savnet.'),
    Station(index: 2, name: 'Henteoppdrag', missionMd: 'Hent pasienten.'),
  ];
  return Plan(
    uuid: 'p-1',
    name: 'Test Plan',
    description: '',
    metadata: PlanMetadata(created: now, updated: now, version: '1.0'),
    teams: const [],
    sessions: const [],
    rolePlays: const [],
    staff: const [],
    exercises: [
      Exercise(
        uuid: 'ex-1',
        index: 0,
        name: 'Øve oppstart',
        startTime: SimpleTimeOfDay(hour: 9, minute: 0),
        endTime: SimpleTimeOfDay(hour: 11, minute: 0),
        numberOfTeams: 3,
        numberOfRounds: 3,
        executionTime: 15,
        evaluationTime: 10,
        rotationTime: 5,
        schedule: const [],
        stations: stations,
        methodMd: 'Planspill.',
        trainingFocusMd: 'Se etter taktisk tankegang.',
      ),
    ],
  );
}

void main() {
  test('names every exercise and station with the code the brief gives it', () {
    final summary = renderBriefSummary(
      plan: _plan(),
      audience: BriefAudience.director,
    );
    expect(summary, contains('## #1 Øve oppstart'));
    expect(summary, contains('### 1.1 Turgåer'));
    expect(summary, contains('### 1.3 Henteoppdrag'));
  });

  test('separates the sections present from the ones left empty', () {
    // The empty half is the more useful one: it is what an author forgot.
    final summary = renderBriefSummary(
      plan: _plan(),
      audience: BriefAudience.director,
    );
    expect(summary, contains('Station sections: situation, leader_answers'));
    expect(summary, contains('Station empty: equipment, mission, logistics'));
  });

  test('counts only what the audience would see', () {
    // A field this audience may not see is omitted rather than reported empty:
    // calling it missing would read as something to go and write (ADR-0063).
    final participant = renderBriefSummary(
      plan: _plan(),
      audience: BriefAudience.participant,
    );
    expect(participant, isNot(contains('leader_answers')));
    expect(participant, isNot(contains('director_notes')));
    expect(participant, isNot(contains('training_focus')));
    expect(participant, contains('situation'));

    final director = renderBriefSummary(
      plan: _plan(),
      audience: BriefAudience.director,
    );
    expect(director, contains('leader_answers'));
    expect(director, contains('training_focus'));
  });

  test('a scoped exercise keeps its own number', () {
    // A station- or exercise-scoped call passes a filtered copy that is no longer
    // in plan.exercises, so numbering from list position rendered it as 0.
    final plan = _plan();
    final scoped = plan.exercises.single.copyWith(
      stations: [plan.exercises.single.stations[2]],
    );
    final summary = renderBriefSummary(
      plan: plan,
      audience: BriefAudience.director,
      exercise: scoped,
    );
    expect(summary, contains('## #1 Øve oppstart'));
    expect(summary, contains('### 1.3 Henteoppdrag'));
    expect(summary, isNot(contains('Turgåer')));
  });

  test('is a fraction of the brief it summarises', () {
    // Not a golden size, just the property that makes it worth having.
    final summary = renderBriefSummary(
      plan: _plan(),
      audience: BriefAudience.director,
    );
    expect(summary.length, lessThan(2000));
  });
}
