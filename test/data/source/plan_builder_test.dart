// `build`: what the compiler derives, what it refuses, and what it warns about.
//
// The reference example (docs/design/source-format-worked-example.md § 1, kept
// as test/fixtures/source/eidene-exercise-2.yaml) is built first, because a
// format whose own documented example does not compile is broken regardless of
// what the unit tests say.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/data/source/source_compiler.dart';
import 'package:ringdrill/data/source/source_diagnostic.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/numbering.dart';
import 'package:ringdrill/models/plan.dart';

/// A minimal buildable document, extended per test.
String _doc({
  String plan = 'name: "Test"\n  language: nb',
  String exercises = '''
  - name: "Ex"
    startTime: "09:00"
    numberOfTeams: 1
    numberOfRounds: 1
    executionTime: 15
    evaluationTime: 5
    rotationTime: 2
    stations:
      - name: "Post"
''',
  String extra = '',
}) => 'plan:\n  $plan\nexercises:\n$exercises$extra';

/// Builds [yaml], returning the plan and every diagnostic.
({Plan plan, List<SourceDiagnostic> diagnostics}) _build(String yaml) =>
    SourceCompiler.toPlan(
      yaml,
      now: DateTime.utc(2026, 1, 1),
      // Deterministic ids so a test can assert on identity without matching
      // random strings. Production mints nanoid(8).
      mintUuid: _counter(),
    );

String Function() _counter() {
  var next = 0;
  return () => 'id${next++}';
}

List<SourceDiagnostic> _errors(String yaml) {
  try {
    return _build(yaml).diagnostics.where((d) => d.isError).toList();
  } on SourceFormatException catch (e) {
    return e.errors.toList();
  }
}

void main() {
  group('the reference example', () {
    late Plan plan;
    late List<SourceDiagnostic> diagnostics;

    setUpAll(() {
      final yaml = File(
        'test/fixtures/source/eidene-exercise-2.yaml',
      ).readAsStringSync();
      final result = _build(yaml);
      plan = result.plan;
      diagnostics = result.diagnostics;
    });

    test('builds without a single diagnostic', () {
      expect(diagnostics, isEmpty, reason: diagnostics.join('\n'));
    });

    test('derives the end time the design document states', () {
      // 09:45 + 6 rounds × (15 + 10 + 5) = 12:45. Quoted in the worked example,
      // so it is the one number a reader will check by hand.
      expect(
        plan.exercises.single.endTime,
        const SimpleTimeOfDay(hour: 12, minute: 45),
      );
    });

    test('derives the full rotation schedule', () {
      final schedule = plan.exercises.single.schedule;
      expect(schedule, hasLength(6));
      expect(schedule.first, [
        const SimpleTimeOfDay(hour: 9, minute: 45),
        const SimpleTimeOfDay(hour: 10, minute: 0),
        const SimpleTimeOfDay(hour: 10, minute: 10),
      ]);
      expect(schedule[1].first, const SimpleTimeOfDay(hour: 10, minute: 15));
    });

    test('derives the team roster from the largest numberOfTeams', () {
      expect(plan.teams.map((t) => t.name), [
        'Lag 1',
        'Lag 2',
        'Lag 3',
        'Lag 4',
      ]);
      expect(plan.teams.map((t) => t.index), [0, 1, 2, 3]);
    });

    test('flips coordinates from {lat, lng} to the stored order', () {
      final position = plan.exercises.single.stations.first.position!;
      expect(position.latitude, closeTo(59.09789, 1e-9));
      expect(position.longitude, closeTo(10.402513, 1e-9));
    });

    test('keeps tokens raw — resolution happens at render', () {
      // build never touches the resolver (DESIGN-014): a station's prose still
      // carries {{station.person.magnus}} verbatim in the archive.
      final station = plan.exercises.single.stations[4];
      expect(station.situationMd, contains('{{station.person.magnus}}'));
      expect(station.situationMd, contains('{{var.talegruppe}}'));
    });

    test('nests role plays onto the plan with derived back-references', () {
      final rolePlay = plan.rolePlays.single;
      expect(rolePlay.exerciseUuid, plan.exercises.single.uuid);
      expect(rolePlay.stationIndex, 4);
      expect(rolePlay.index, 0);
      expect(rolePlay.personRef, 'magnus');
    });

    test('denormalizes the effective identity from the person', () {
      final rolePlay = plan.rolePlays.single;
      expect(rolePlay.name, 'Magnus Damslet');
      expect(rolePlay.age, 6);
      expect(rolePlay.gender, 'male');
      expect(rolePlay.description, 'Rød jakke, blå lue.');
      // Position follows the person's location (lkp) since none was written.
      expect(rolePlay.position!.latitude, closeTo(59.09672, 1e-9));
    });

    test('stamps a content hash that matches the plan it describes', () {
      expect(plan.contentHash, plan.computeContentHash());
    });
  });

  group('identity', () {
    test('preserves an authored uuid and mints one when absent', () {
      final result = _build(
        _doc(
          plan: 'name: "Test"\n  uuid: plan-uuid',
          exercises: '''
  - name: "Given"
    uuid: ex-uuid
    startTime: "09:00"
    numberOfTeams: 1
    numberOfRounds: 1
    executionTime: 15
    evaluationTime: 5
    rotationTime: 2
    stations: [{name: "Post"}]
  - name: "Minted"
    startTime: "10:00"
    numberOfTeams: 1
    numberOfRounds: 1
    executionTime: 15
    evaluationTime: 5
    rotationTime: 2
    stations: [{name: "Post"}]
''',
        ),
      );
      expect(result.plan.uuid, 'plan-uuid');
      expect(result.plan.exercises.first.uuid, 'ex-uuid');
      expect(result.plan.exercises.last.uuid, startsWith('id'));
    });

    test('a role play keeps its authored uuid', () {
      final result = _build(
        _doc(
          exercises: '''
  - name: "Ex"
    startTime: "09:00"
    numberOfTeams: 1
    numberOfRounds: 1
    executionTime: 15
    evaluationTime: 5
    rotationTime: 2
    stations:
      - name: "Post"
        persons: [{slug: pat, name: "Pat"}]
        roleplays:
          - uuid: rp-uuid
            personRef: pat
''',
        ),
      );
      expect(result.plan.rolePlays.single.uuid, 'rp-uuid');
    });
  });

  group('teams', () {
    test('authored names win and generated ones fill the gap', () {
      final result = _build(
        _doc(
          exercises: '''
  - name: "Ex"
    startTime: "09:00"
    numberOfTeams: 3
    numberOfRounds: 1
    executionTime: 15
    evaluationTime: 5
    rotationTime: 2
    stations: [{name: "A"}, {name: "B"}, {name: "C"}]
''',
          extra: '''
teams:
  - name: "Larvik 21"
  - name: "Tønsberg 21"
''',
        ),
      );
      expect(result.plan.teams.map((t) => t.name), [
        'Larvik 21',
        'Tønsberg 21',
        'Lag 3',
      ]);
    });

    test('generated names follow the plan language', () {
      final result = _build(_doc(plan: 'name: "Test"\n  language: en'));
      expect(result.plan.teams.single.name, 'Team 1');
    });

    test('an unnamed language falls back rather than guessing the host', () {
      // A plan with no language must not render differently depending on which
      // machine built it.
      final result = _build(_doc(plan: 'name: "Test"'));
      expect(result.plan.teams.single.name, 'Team 1');
      expect(result.plan.metadata.languageCode, isNull);
    });

    test('a surplus roster warns but still builds', () {
      // Legitimate: several teams grouped into one temporary team for a
      // full-scale exercise. So it must not be an error.
      final result = _build(
        _doc(
          extra: '''
teams:
  - name: "Lag 1"
  - name: "Lag 2"
  - name: "Lag 3"
''',
        ),
      );
      expect(result.plan.teams, hasLength(3));
      final warning = result.diagnostics.singleWhere((d) => !d.isError);
      expect(warning.message, contains('no slot'));
      expect(warning.hint, contains('grouped'));
    });

    test('carries authored size and position', () {
      final result = _build(
        _doc(
          extra: '''
teams:
  - name: "Lag 1"
    numberOfMembers: 4
    position: { lat: 59.1, lng: 10.4 }
''',
        ),
      );
      final team = result.plan.teams.single;
      expect(team.numberOfMembers, 4);
      expect(team.position!.longitude, closeTo(10.4, 1e-9));
    });
  });

  group('role play identity inheritance', () {
    test('an omitted field inherits, a written one overrides', () {
      final result = _build(
        _doc(
          exercises: '''
  - name: "Ex"
    startTime: "09:00"
    numberOfTeams: 1
    numberOfRounds: 1
    executionTime: 15
    evaluationTime: 5
    rotationTime: 2
    stations:
      - name: "Post"
        persons:
          - slug: magnus
            name: "Magnus"
            age: 6
            gender: male
            description: "Rød jakke."
        roleplays:
          - personRef: magnus
            age: 7
''',
        ),
      );
      final rolePlay = result.plan.rolePlays.single;
      expect(rolePlay.age, 7, reason: 'written, so it overrides');
      expect(rolePlay.name, 'Magnus', reason: 'omitted, so it inherits');
      expect(rolePlay.gender, 'male');
      expect(rolePlay.description, 'Rød jakke.');
    });

    test(
      'a role play with no person is allowed and carries its own identity',
      () {
        // personRef is an editor-level invariant, not a wire constraint — a legacy
        // role play loads from its own fields (see RolePlay.personRef's doc).
        final result = _build(
          _doc(
            exercises: '''
  - name: "Ex"
    startTime: "09:00"
    numberOfTeams: 1
    numberOfRounds: 1
    executionTime: 15
    evaluationTime: 5
    rotationTime: 2
    stations:
      - name: "Post"
        roleplays:
          - name: "Ukjent markør"
            behavior: "Passiv."
''',
          ),
        );
        final rolePlay = result.plan.rolePlays.single;
        expect(rolePlay.name, 'Ukjent markør');
        expect(rolePlay.personRef, isNull);
        expect(rolePlay.behavior, 'Passiv.');
      },
    );

    test('a personRef naming no person is an error that lists the options', () {
      final errors = _errors(
        _doc(
          exercises: '''
  - name: "Ex"
    startTime: "09:00"
    numberOfTeams: 1
    numberOfRounds: 1
    executionTime: 15
    evaluationTime: 5
    rotationTime: 2
    stations:
      - name: "Post"
        persons: [{slug: magnus, name: "Magnus"}]
        roleplays: [{personRef: mangus}]
''',
        ),
      );
      expect(errors.single.message, contains('no person "mangus"'));
      expect(errors.single.hint, contains('magnus'));
    });
  });

  group('refusals', () {
    test('more teams than stations cannot rotate', () {
      // The app only asserts this, so it is a debug-mode crash there and nothing
      // in release; the compiler makes it a hard error.
      final errors = _errors(
        _doc(
          exercises: '''
  - name: "Ex"
    startTime: "09:00"
    numberOfTeams: 4
    numberOfRounds: 1
    executionTime: 15
    evaluationTime: 5
    rotationTime: 2
    stations: [{name: "A"}, {name: "B"}]
''',
        ),
      );
      expect(errors.single.message, contains('numberOfTeams is 4'));
      expect(errors.single.path, endsWith('numberOfTeams'));
    });

    test('a swapped coordinate is caught rather than silently relocated', () {
      // {lat: 10.4, lng: 59.1} parses as two valid doubles and would put the
      // station in the Indian Ocean.
      final errors = _errors(
        _doc(
          exercises: '''
  - name: "Ex"
    startTime: "09:00"
    numberOfTeams: 1
    numberOfRounds: 1
    executionTime: 15
    evaluationTime: 5
    rotationTime: 2
    stations:
      - name: "Post"
        position: { lat: 100.5, lng: 10.4 }
''',
        ),
      );
      expect(errors.single.message, contains('latitude'));
      expect(errors.single.hint, contains('swapped'));
    });

    test('a malformed time names the expected shape', () {
      final errors = _errors(
        _doc(
          exercises: '''
  - name: "Ex"
    startTime: "quarter to ten"
    numberOfTeams: 1
    numberOfRounds: 1
    executionTime: 15
    evaluationTime: 5
    rotationTime: 2
    stations: [{name: "Post"}]
''',
        ),
      );
      expect(errors.first.message, contains('"HH:MM"'));
    });

    test('a duplicate slug is an error, not a last-one-wins', () {
      final errors = _errors(
        _doc(
          exercises: '''
  - name: "Ex"
    startTime: "09:00"
    numberOfTeams: 1
    numberOfRounds: 1
    executionTime: 15
    evaluationTime: 5
    rotationTime: 2
    stations:
      - name: "Post"
        locations:
          - {slug: lkp, label: "First"}
          - {slug: lkp, label: "Second"}
''',
        ),
      );
      expect(errors.single.message, contains('duplicate location slug'));
    });

    test('a slug that cannot be referenced is rejected', () {
      final errors = _errors(
        _doc(
          exercises: '''
  - name: "Ex"
    startTime: "09:00"
    numberOfTeams: 1
    numberOfRounds: 1
    executionTime: 15
    evaluationTime: 5
    rotationTime: 2
    stations:
      - name: "Post"
        persons: [{slug: "Magnus Damslet", name: "Magnus"}]
''',
        ),
      );
      expect(errors.single.message, contains('not a valid slug'));
    });

    test('an unsupported source format version is refused', () {
      final errors = _errors('sourceFormat: "9.9"\n${_doc()}');
      expect(errors.single.message, contains('unsupported source format'));
    });

    test('a document with no plan cannot be built', () {
      final errors = _errors('exercises: []\n');
      expect(errors.single.message, contains('no "plan:" mapping'));
    });

    test('an invalid enum value lists the alternatives', () {
      final errors = _errors(
        _doc(plan: 'name: "Test"\n  stationNumberFormat: roman'),
      );
      expect(errors.single.hint, contains('dotted'));
    });
  });

  group('warnings', () {
    test('a derived field in the source is ignored, not fatal', () {
      // An author pasting from an archive, or from a decompiled document written
      // by a future build, should be told what happened — not blocked.
      final result = _build(
        _doc(
          exercises: '''
  - name: "Ex"
    startTime: "09:00"
    endTime: "23:59"
    numberOfTeams: 1
    numberOfRounds: 1
    executionTime: 15
    evaluationTime: 5
    rotationTime: 2
    stations: [{name: "Post"}]
''',
        ),
      );
      final warning = result.diagnostics.singleWhere((d) => !d.isError);
      expect(warning.message, contains('derived'));
      expect(
        result.plan.exercises.single.endTime,
        const SimpleTimeOfDay(hour: 9, minute: 22),
        reason: 'the derived value wins over the authored one',
      );
    });

    test('an unknown key is named alongside what was expected', () {
      final result = _build(_doc(plan: 'name: "Test"\n  colour: blue'));
      final warning = result.diagnostics.singleWhere((d) => !d.isError);
      expect(warning.message, contains('unknown key "colour"'));
      expect(warning.hint, contains('description'));
    });

    test('a bare hour is read as HH:00 and says so', () {
      final result = _build(
        _doc(
          exercises: '''
  - name: "Ex"
    startTime: 9
    numberOfTeams: 1
    numberOfRounds: 1
    executionTime: 15
    evaluationTime: 5
    rotationTime: 2
    stations: [{name: "Post"}]
''',
        ),
      );
      expect(
        result.plan.exercises.single.startTime,
        const SimpleTimeOfDay(hour: 9, minute: 0),
      );
      expect(
        result.diagnostics.singleWhere((d) => !d.isError).message,
        contains('09:00'),
      );
    });
  });

  group('normalization', () {
    test('variable order does not reach the content hash', () {
      String withVariables(String body) =>
          'plan:\n'
          '  name: "Test"\n'
          '  variables:\n$body'
          'exercises:\n'
          '  - name: "Ex"\n'
          '    startTime: "09:00"\n'
          '    numberOfTeams: 1\n'
          '    numberOfRounds: 1\n'
          '    executionTime: 15\n'
          '    evaluationTime: 5\n'
          '    rotationTime: 2\n'
          '    stations: [{name: "Post"}]\n';
      final a = _build(
        withVariables('    alpha: {value: "1"}\n    beta: {value: "2"}\n'),
      ).plan;
      final b = _build(
        withVariables('    beta: {value: "2"}\n    alpha: {value: "1"}\n'),
      ).plan;
      expect(a.contentHash, b.contentHash);
      expect(a.variables.map((v) => v.name), ['alpha', 'beta']);
    });

    test('station index and exercise index come from document order', () {
      final result = _build(
        _doc(
          exercises: '''
  - name: "First"
    startTime: "09:00"
    numberOfTeams: 1
    numberOfRounds: 1
    executionTime: 15
    evaluationTime: 5
    rotationTime: 2
    stations: [{name: "A"}, {name: "B"}]
  - name: "Second"
    startTime: "10:00"
    numberOfTeams: 1
    numberOfRounds: 1
    executionTime: 15
    evaluationTime: 5
    rotationTime: 2
    stations: [{name: "C"}]
''',
        ),
      );
      expect(result.plan.exercises.map((e) => e.index), [0, 1]);
      expect(result.plan.exercises.first.stations.map((s) => s.index), [0, 1]);
    });

    test('a name that already contains a number keeps it verbatim', () {
      // Numbering comes from order; names are opaque (ADR-0059). A pre-numbering
      // plan carrying "#6 " in the name is content, not a label to strip.
      final result = _build(
        _doc(
          exercises: '''
  - name: "#6 Førsteinnsats søk (fullskala)"
    startTime: "17:00"
    numberOfTeams: 1
    numberOfRounds: 1
    executionTime: 90
    evaluationTime: 0
    rotationTime: 0
    stations: [{name: "2a) Fisker"}]
''',
        ),
      );
      expect(
        result.plan.exercises.single.name,
        '#6 Førsteinnsats søk (fullskala)',
      );
      expect(result.plan.exercises.single.stations.single.name, '2a) Fisker');
      // The derived label disagrees with the baked-in one, and that is fine —
      // both are shown, neither is rewritten.
      expect(Numbering.exercise(result.plan.exerciseNumberFormat, 1), '#1');
    });
  });
}
