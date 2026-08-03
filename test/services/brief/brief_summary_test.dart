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

  // The summary carried the pre-ADR-0062 rotation line long after the brief's
  // Organisering block was fixed: the exercise's own three phase fields, and an
  // unconditional `×`. That matters more than the line's size suggests, because the
  // skill recommends the summary for iterating and it is what an agent reaches for
  // when the full brief is too large to read — so the cheap loop showed the pre-fix
  // picture while only the expensive one told the truth. A fast check may be less
  // detailed than the slow one; it must not be less correct.
  group('the rotation line', () {
    String summaryWith(Exercise Function(Exercise) edit) {
      final plan = _plan();
      return renderBriefSummary(
        plan: plan.copyWith(exercises: [edit(plan.exercises.single)]),
        audience: BriefAudience.director,
      );
    }

    test('ring with no station override renders byte-identically', () {
      // Uniform by construction, so the product is a true statement and the line
      // reads exactly as it always has — the guard on the whole change.
      expect(
        summaryWith((e) => e),
        contains('3 round(s) × (15 | 10 | 5) min, 3 team(s), 3 station(s)'),
      );
    });

    test('ring reads the phases through the rounds, not the exercise', () {
      // The half a `together`-only fix would have missed: in a ring route every
      // station is live every round, so the longest sets all of them. The line used
      // to claim 15 while the clock ran 40.
      final summary = summaryWith(
        (e) => e.copyWith(
          stations: [
            e.stations.first.copyWith(executionTime: 40),
            ...e.stations.skip(1),
          ],
        ),
      );
      expect(summary, contains('3 round(s) × (40 | 10 | 5) min'));
      expect(summary, isNot(contains('(15 | 10 | 5)')));
    });

    test('together spans the phases and stops multiplying', () {
      // Rounds of differing length: `×` would invent a cycle, and a product of a
      // span is not even arithmetic.
      final summary = summaryWith(
        (e) => e.copyWith(
          mode: ExerciseMode.together,
          stations: [
            e.stations.first.copyWith(executionTime: 70),
            e.stations[1].copyWith(executionTime: 100),
            e.stations[2].copyWith(executionTime: 70),
          ],
        ),
      );
      expect(summary, contains('3 round(s) (70–100 | 10 | 5) min'));
      expect(
        summary,
        isNot(contains('× (70–100')),
        reason: 'a span has no cycle to multiply',
      );
    });

    test('a non-ring exercise says which mode it is', () {
      // Without it, differing rounds have no explanation on the line that shows
      // them. `ring` stays silent because it is the default.
      expect(
        summaryWith((e) => e.copyWith(mode: ExerciseMode.together)),
        contains(', mode: together'),
      );
      expect(
        summaryWith((e) => e.copyWith(mode: ExerciseMode.split)),
        contains(', mode: split'),
      );
      expect(summaryWith((e) => e), isNot(contains('mode:')));
    });
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
