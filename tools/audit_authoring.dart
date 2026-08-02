// Audits a source document for the mistakes `analyze` cannot see.
//
//   dart run tools/audit_authoring.dart plan.yaml
//   dart run tools/audit_authoring.dart plan.yaml --baseline=before.yaml
//   dart run tools/audit_authoring.dart plan.yaml --json
//
// `analyze` answers "does this compile and do the references resolve". This answers
// "would a veileder want to run it" — the authoring rules that live in
// `skills/ringdrill-plan-authoring/` as prose and are therefore only as good as the
// agent that read them.
//
// Why it exists: a converted plan came back with every station description empty
// (f8c4e949), and it was found by opening the app and noticing a nudge. That is not a
// repeatable way to tell whether an instruction change worked. This makes the verdict
// mechanical, so two runs can be compared by a script rather than by impression — and
// so the next instruction change has a before and an after.
//
// Deliberately reads the YAML directly rather than going through `PlanBuilder`: a
// candidate document that fails to compile is exactly one worth auditing, and the
// builder throws on it.
//
// Exit code is 1 when any *expected* field is empty, so it can gate a loop. The
// advisory findings never fail the run on their own — they are smells, and a plan is
// allowed to have a reason.
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:yaml/yaml.dart';

/// One thing worth telling the author about.
class Finding {
  Finding(this.kind, this.where, this.detail, {this.expected = false});

  /// Groups findings in the report and in the run-to-run comparison.
  final String kind;

  /// A path a reader can find: `exercises[2].stations[0]`.
  final String where;
  final String detail;

  /// Whether this is one of the fields the app asks for by name. Those fail the run;
  /// the rest are advisory.
  final bool expected;

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'where': where,
    'detail': detail,
    'expected': expected,
  };
}

/// Values the format derives, written out by hand. Each pattern is deliberately
/// narrow: a false positive here costs an author time arguing with a tool, and the
/// point is to catch transcription, not to police prose.
final _derivedSmells = <({RegExp pattern, String token, String why})>[
  (
    // "08:30-10:30", "1700–1830". A clock *range* — a single time is often a real
    // instruction ("meet at 08:00"), a range is almost always the derived window.
    pattern: RegExp(
      r'\b([01]?\d|2[0-3])[:.][0-5]\d\s*[-–—]\s*([01]?\d|2[0-3])[:.][0-5]\d',
    ),
    token: '{{exercise.timeLabel}}',
    why: 'a clock range is the exercise window, which the format derives',
  ),
  (
    // "15 | 10 | 5" — the phase breakdown, pipe-separated.
    pattern: RegExp(r'\b\d{1,3}\s*\|\s*\d{1,3}\s*\|\s*\d{1,3}\b'),
    token: '{{exercise.phaseBreakdown}}',
    why: 'three pipe-separated numbers are the phase breakdown',
  ),
  (
    // A markdown table whose header names round/runde — the rotation table typed out.
    pattern: RegExp(r'\|\s*(runde|round)\b', caseSensitive: false),
    token: '{{exercise.roundTable}}',
    why: 'a table keyed by round is the rotation table',
  ),
  (
    // "20 min pr post", "30 min per oppdrag".
    pattern: RegExp(r'\b\d{1,3}\s*min\.?\s*(pr|per)\b', caseSensitive: false),
    token: '{{station.duration}} or {{exercise.durationLabel}}',
    why: 'a per-unit duration is derived from the phase times',
  ),
];

/// A name carrying the code the app renders itself: "2a) Fisker", "#3 Oppstart",
/// "1.1 Demens".
final _numberedName = RegExp(
  r'^\s*(#\s*\d+|\d+\s*[a-zA-Z]?\s*[).]|\d+\.\d+)\s',
);

/// Markdown-ish fields worth reading for smells, by scope. Not every string field:
/// `name` has its own check and a coordinate is not prose.
const _proseFields = {
  'plan': ['intro', 'comms', 'before_round', 'description'],
  'exercise': [
    'method',
    'learning_goals',
    'training_focus',
    'order_format',
    'execution_tips',
    'comms',
    'description',
  ],
  'station': [
    'description',
    'equipment',
    'situation',
    'mission',
    'logistics',
    'critical_questions',
    'leader_answers',
    'director_notes',
    'comms',
  ],
  'roleplay': ['description', 'behavior', 'background', 'props'],
};

/// The three the app nudges about — `station_description_rollup.dart`,
/// `exercise_description_rollup.dart` and `roleplay_description_rollup.dart` each
/// pass a `mandatoryLabel`, and a post without one shows "Missing: Station
/// description" in its own card until someone fills it.
const _expected = {
  'exercise': 'method',
  'station': 'description',
  'roleplay': 'description',
};

bool _blank(Object? v) => v == null || '$v'.trim().isEmpty;

List<dynamic> _list(Object? node, String key) {
  final v = (node is Map) ? node[key] : null;
  return v is List ? v : const [];
}

String? _str(Object? node, String key) {
  final v = (node is Map) ? node[key] : null;
  return v == null ? null : '$v';
}

class Audit {
  Audit(this.path, this.doc);

  final String path;
  final Object? doc;

  final findings = <Finding>[];
  final _literals = <String, int>{};
  int tokenUses = 0;
  int stations = 0;
  int exercises = 0;
  int roleplays = 0;

  static Audit read(String path) {
    final text = File(path).readAsStringSync();
    return Audit(path, loadYaml(text))..run();
  }

  void run() {
    final plan = (doc is Map) ? (doc as Map)['plan'] : null;
    _scope('plan', plan, 'plan');

    final exerciseList = _list(doc, 'exercises');
    exercises = exerciseList.length;
    for (var e = 0; e < exerciseList.length; e++) {
      final exercise = exerciseList[e];
      final at = 'exercises[$e]';
      _scope('exercise', exercise, at);
      _checkRotationWorkaround(exercise, at);

      final stationList = _list(exercise, 'stations');
      stations += stationList.length;
      for (var s = 0; s < stationList.length; s++) {
        final station = stationList[s];
        final sAt = '$at.stations[$s]';
        _scope('station', station, sAt);

        final rp = _list(station, 'roleplays');
        roleplays += rp.length;
        for (var r = 0; r < rp.length; r++) {
          _scope('roleplay', rp[r], '$sAt.roleplays[$r]');
        }
      }
    }

    _reportRepeatedLiterals();
    if (tokenUses == 0 && stations > 0) {
      findings.add(
        Finding(
          'no-tokens',
          'plan',
          'the document uses no {{tokens}} at all, which usually means derived '
              'values and repeated literals were typed in instead',
        ),
      );
    }
  }

  /// Checks one entity: its expected field, its name, and its prose.
  void _scope(String scope, Object? node, String at) {
    if (node is! Map) return;

    final expected = _expected[scope];
    if (expected != null && _blank(node[expected])) {
      findings.add(
        Finding(
          'missing-expected-field',
          at,
          '`$expected` is empty — the app shows this as a missing section on '
              'every $scope until it is filled',
          expected: true,
        ),
      );
    }

    final name = _str(node, 'name');
    if (name != null && _numberedName.hasMatch(name)) {
      findings.add(
        Finding(
          'number-in-name',
          at,
          'name "$name" carries a code the app renders itself, so it renders twice',
        ),
      );
    }

    for (final field in _proseFields[scope] ?? const <String>[]) {
      final text = _str(node, field);
      if (text == null || text.trim().isEmpty) continue;
      _checkProse(text, '$at.$field');
    }
  }

  void _checkProse(String text, String at) {
    tokenUses += RegExp(r'\{\{[^}]+\}\}').allMatches(text).length;

    for (final smell in _derivedSmells) {
      final match = smell.pattern.firstMatch(text);
      if (match == null) continue;
      findings.add(
        Finding(
          'hand-rolled-derived-value',
          at,
          '"${match.group(0)!.trim()}" — ${smell.why}; write ${smell.token}',
        ),
      );
    }

    // Candidate variables: a distinctive literal repeated across the document. Long
    // enough to be a talk group or a phone number rather than a common word, and
    // counted per field so a single field repeating itself does not trigger it.
    for (final token in RegExp(
      r'\b[A-ZÆØÅ0-9][A-ZÆØÅ0-9\-]{5,}\b',
    ).allMatches(text).map((m) => m.group(0)!).toSet()) {
      _literals.update(token, (n) => n + 1, ifAbsent: () => 1);
    }
    for (final phone in RegExp(
      r'\b(\d{8}|\d{3}\s?\d{2}\s?\d{3})\b',
    ).allMatches(text).map((m) => m.group(0)!).toSet()) {
      _literals.update(phone, (n) => n + 1, ifAbsent: () => 1);
    }
  }

  /// The pre-`mode` workaround: merge every team into one so the derived clock comes
  /// out right, which makes the brief label the merged group "Lag 2.1".
  void _checkRotationWorkaround(Object? exercise, String at) {
    if (exercise is! Map) return;
    final teams = exercise['numberOfTeams'];
    final rounds = exercise['numberOfRounds'];
    if (teams == 1 && rounds is int && rounds > 1) {
      findings.add(
        Finding(
          'teams-one-workaround',
          at,
          'numberOfTeams: 1 with $rounds rounds is the pre-`mode` workaround — '
              'use `mode: together` and keep the real team count',
        ),
      );
    }
  }

  void _reportRepeatedLiterals() {
    final repeated = _literals.entries.where((e) => e.value >= 4).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final entry in repeated.take(10)) {
      findings.add(
        Finding(
          'repeatable-literal',
          'plan',
          '"${entry.key}" appears in ${entry.value} fields — a plan variable is '
              'editable in one place, a literal is not',
        ),
      );
    }
  }

  Map<String, int> get countsByKind {
    final out = <String, int>{};
    for (final f in findings) {
      out.update(f.kind, (n) => n + 1, ifAbsent: () => 1);
    }
    return out;
  }

  int get expectedMissing => findings.where((f) => f.expected).length;

  Map<String, dynamic> toJson() => {
    'path': path,
    'exercises': exercises,
    'stations': stations,
    'roleplays': roleplays,
    'tokenUses': tokenUses,
    'expectedMissing': expectedMissing,
    'countsByKind': countsByKind,
    'findings': findings.map((f) => f.toJson()).toList(),
  };
}

void _printReport(Audit audit, {Audit? baseline}) {
  stdout.writeln(audit.path);
  stdout.writeln(
    '  ${audit.exercises} exercise(s), ${audit.stations} station(s), '
    '${audit.roleplays} roleplay(s), ${audit.tokenUses} token use(s)',
  );
  stdout.writeln('');

  if (audit.findings.isEmpty) {
    stdout.writeln('  nothing to report.');
  }

  // Expected-field misses first: they are the ones that fail the run, and the ones a
  // reader of the app sees as a nudge.
  final ordered = [
    ...audit.findings.where((f) => f.expected),
    ...audit.findings.where((f) => !f.expected),
  ];
  for (final f in ordered) {
    final mark = f.expected ? 'MISSING' : 'note   ';
    stdout.writeln('  $mark ${f.where}');
    stdout.writeln('          ${f.detail}');
  }

  if (baseline != null) {
    stdout.writeln('');
    stdout.writeln('  vs ${baseline.path}:');
    final kinds = <String>{
      ...audit.countsByKind.keys,
      ...baseline.countsByKind.keys,
    }..addAll(const {'__totals__'});
    for (final kind in kinds.toList()..sort()) {
      if (kind == '__totals__') continue;
      final now = audit.countsByKind[kind] ?? 0;
      final was = baseline.countsByKind[kind] ?? 0;
      if (now == was) continue;
      final arrow = now < was ? 'better' : 'worse ';
      stdout.writeln('    $arrow $kind: $was -> $now');
    }
    final now = audit.expectedMissing;
    final was = baseline.expectedMissing;
    stdout.writeln(
      '    expected fields missing: $was -> $now'
      '${now == was ? ' (unchanged)' : ''}',
    );
  }

  stdout.writeln('');
  stdout.writeln(
    '  ${audit.expectedMissing} expected field(s) missing, '
    '${audit.findings.length - audit.expectedMissing} note(s).',
  );
}

void main(List<String> args) {
  final parser = ArgParser()
    ..addOption(
      'baseline',
      help:
          'A previous run to compare against, so a change in the instructions '
          'can be read as better or worse rather than as an impression.',
    )
    ..addFlag('json', negatable: false, help: 'Machine-readable output.')
    ..addFlag('help', abbr: 'h', negatable: false);

  final opts = parser.parse(args);
  if (opts['help'] as bool || opts.rest.isEmpty) {
    stdout.writeln('Audits a source document for what `analyze` cannot see.\n');
    stdout.writeln(
      '  dart run tools/audit_authoring.dart <plan.yaml> '
      '[--baseline=before.yaml] [--json]\n',
    );
    stdout.writeln(parser.usage);
    exit(opts.rest.isEmpty && !(opts['help'] as bool) ? 2 : 0);
  }

  final audit = Audit.read(opts.rest.first);
  final baselinePath = opts['baseline'] as String?;
  final baseline = baselinePath == null ? null : Audit.read(baselinePath);

  if (opts['json'] as bool) {
    stdout.writeln(
      const JsonEncoder.withIndent('  ').convert({
        'audit': audit.toJson(),
        if (baseline != null) 'baseline': baseline.toJson(),
      }),
    );
  } else {
    _printReport(audit, baseline: baseline);
  }

  exit(audit.expectedMissing > 0 ? 1 : 0);
}
