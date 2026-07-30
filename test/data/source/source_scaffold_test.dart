// `create`: the scaffold has to survive its own pipeline.
//
// A starting document that does not build, or that builds with warnings, is worse
// than no scaffold at all — it teaches the format wrong and the author cannot tell
// whether the errors are theirs. So the assertions here are end-to-end: scaffold,
// analyze, build, and check the derived values came out right.
//
// This is also why there is no hand-written skeleton fixture in
// test/fixtures/source/. A generated one cannot drift from the format; a
// hand-written one silently does.
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/data/source/source_analyzer.dart';
import 'package:ringdrill/data/source/source_compiler.dart';
import 'package:ringdrill/data/source/source_diagnostic.dart';
import 'package:ringdrill/data/source/source_scaffold.dart';
import 'package:ringdrill/models/exercise.dart';

/// Scaffolds, builds and analyzes in one go — the sequence `create` tells the
/// author to run.
({dynamic plan, List<SourceDiagnostic> diagnostics}) _pipeline(String yaml) {
  final result = SourceCompiler.toPlan(yaml, now: DateTime.utc(2026));
  final sink = DiagnosticSink()..addAll(result.diagnostics);
  SourceAnalyzer.analyze(result.plan, sink);
  return (plan: result.plan, diagnostics: sink.items);
}

void main() {
  group('the scaffold', () {
    test('builds and analyzes with no diagnostics at all', () {
      final yaml = SourceScaffold.generate(name: 'Test Plan');
      final result = _pipeline(yaml);
      expect(
        result.diagnostics,
        isEmpty,
        reason:
            'a scaffolded document must be clean, or an author cannot tell '
            'their own mistakes from ours:\n${result.diagnostics.join('\n')}',
      );
    });

    test('is clean in bare form too', () {
      // --bare drops the variable, so the "declared but never referenced" warning
      // must not fire — which it would if the variable were kept and the prose
      // referencing it removed.
      final result = _pipeline(
        SourceScaffold.generate(name: 'Bare', withExample: false),
      );
      expect(result.diagnostics, isEmpty);
      expect(result.plan.variables, isEmpty);
    });

    test('derives stations from the team count by default', () {
      // Fewer stations than teams leaves a team with nowhere to rotate, which
      // build rejects — so the default has to be at least the team count.
      final result = _pipeline(SourceScaffold.generate(name: 'T', teams: 6));
      final exercise = result.plan.exercises.single as Exercise;
      expect(exercise.numberOfTeams, 6);
      expect(exercise.stations, hasLength(6));
    });

    test('one round per station, so a rotation completes', () {
      final result = _pipeline(SourceScaffold.generate(name: 'T', teams: 3));
      final exercise = result.plan.exercises.single as Exercise;
      expect(exercise.numberOfRounds, 3);
      expect(exercise.schedule, hasLength(3));
    });

    test('exercises do not overlap in time', () {
      // Nothing enforces this — an author may well want concurrent exercises —
      // but a scaffold that starts everything at 09:00 looks broken.
      final result = _pipeline(
        SourceScaffold.generate(name: 'T', exercises: 3, teams: 2),
      );
      final exercises = (result.plan.exercises as List).cast<Exercise>();
      for (var i = 1; i < exercises.length; i++) {
        expect(
          exercises[i].startTime.inMinutes,
          greaterThanOrEqualTo(exercises[i - 1].endTime.inMinutes),
          reason: 'exercise ${i + 1} starts before ${i} ends',
        );
      }
    });

    test('names entities in the plan language, prose in English', () {
      // Names become the author's content, so they read naturally from the start;
      // the placeholders are instructions to delete, so they stay in the CLI's
      // own language.
      final nb = _pipeline(
        SourceScaffold.generate(name: 'T', languageCode: 'nb', teams: 1),
      );
      final exercise = nb.plan.exercises.single as Exercise;
      expect(exercise.name, 'Øvelse 1');
      expect(exercise.stations.single.name, 'Post 1');

      final en = _pipeline(
        SourceScaffold.generate(name: 'T', languageCode: 'en', teams: 1),
      );
      final enExercise = en.plan.exercises.single as Exercise;
      expect(enExercise.name, 'Exercise 1');
      expect(enExercise.stations.single.name, 'Station 1');
    });

    test('mints uuids rather than pre-assigning them', () {
      // A scaffold carrying uuids would make the field look required, when the
      // whole point is that an author never writes one.
      final yaml = SourceScaffold.generate(name: 'T');
      expect(yaml, isNot(contains('uuid:')));
    });

    test('carries no numbering in any name', () {
      // Numbering comes from position (ADR-0059). A scaffold writing "#1 " into a
      // name would teach exactly the habit the format exists to remove — and
      // "Exercise 1" is a name, not a label, which is the distinction that matters.
      final yaml = SourceScaffold.generate(name: 'T', exercises: 2);
      expect(yaml, isNot(contains('#1 ')));
      expect(yaml, isNot(contains('1.1 ')));
    });

    test('shows the scenario layer exactly once', () {
      // Repeated on every station it would bury the structure and look mandatory.
      final result = _pipeline(
        SourceScaffold.generate(name: 'T', exercises: 2, teams: 3),
      );
      final stations = (result.plan.exercises as List).cast<Exercise>().expand(
        (e) => e.stations,
      );
      expect(stations.where((s) => s.persons.isNotEmpty), hasLength(1));
      expect(stations.where((s) => s.locations.isNotEmpty), hasLength(1));
      expect(result.plan.rolePlays, hasLength(1));
    });

    test('the example role play inherits its identity from the person', () {
      // The inherit-by-omission rule (worked example decision 8) is the least
      // obvious part of the format, so the scaffold demonstrates it: the role play
      // writes only personRef and behavior, and the builder fills the rest.
      final result = _pipeline(SourceScaffold.generate(name: 'T'));
      final rolePlay = result.plan.rolePlays.single;
      expect(rolePlay.personRef, 'subject');
      expect(rolePlay.name, 'CHANGE-ME');
      expect(rolePlay.age, 6);
      expect(
        rolePlay.position,
        isNotNull,
        reason: "should follow the person's location",
      );
    });

    test('every placeholder is findable', () {
      // An author needs one thing to grep for. CHANGE-ME is it, and the header
      // says so — a scaffold whose placeholders are invisible ships to a real
      // exercise with "Appearance and identifying detail" still in it.
      final yaml = SourceScaffold.generate(name: 'T');
      expect(yaml, contains('CHANGE-ME'));
      expect(yaml, contains('Every CHANGE-ME is a placeholder'));
    });

    test('scaffolding is deterministic', () {
      // Same answers, same bytes — so it can be committed as a fixture and diffed.
      expect(
        SourceScaffold.generate(name: 'T', exercises: 2, teams: 3),
        SourceScaffold.generate(name: 'T', exercises: 2, teams: 3),
      );
    });
  });
}
