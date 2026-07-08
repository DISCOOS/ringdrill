import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations_en.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/services/brief/brief_audience.dart';
import 'package:ringdrill/services/brief/brief_renderer.dart';
import 'package:ringdrill/views/widgets/editor_token.dart';
import 'package:ringdrill/views/widgets/plan_field_tokens.dart';

/// DESIGN-009 follow-up 4b's "the picker never offers an unresolvable
/// token" invariant, enforced mechanically: every [PlanFieldTokens.program]
/// and [PlanFieldTokens.exercise] entry is inserted as a raw `{{<name>}}`
/// into a markdown field and rendered through the real [BriefRenderer]. A
/// future rename that drops a facet from `_programRefContext`/
/// `_exerciseRefContext` fails here instead of only surfacing as a silently
/// empty mustache miss in a shipped brief.

final _l10n = AppLocalizationsEn();

/// Wraps [name] in unique markers so its resolved value can be located in
/// the full rendered brief regardless of surrounding template chrome.
String _wrap(String name) => '>>>$name>>>{{$name}}<<<$name<<<';

Program _program({required String briefIntroMd, required Exercise exercise}) =>
    Program(
      uuid: 'pgm-1',
      name: 'Test Program',
      description: 'A test program',
      metadata: ProgramMetadata(
        created: DateTime(2026),
        updated: DateTime(2026),
        version: '1.0',
      ),
      teams: const [],
      sessions: const [],
      exercises: [exercise],
      briefIntroMd: briefIntroMd,
    );

Exercise _exercise({String? methodMd}) => Exercise(
  uuid: 'ex-1',
  name: 'Test Exercise',
  startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
  endTime: const SimpleTimeOfDay(hour: 10, minute: 0),
  numberOfTeams: 4,
  numberOfRounds: 3,
  executionTime: 20,
  evaluationTime: 10,
  rotationTime: 5,
  stations: const [],
  schedule: const [],
  methodMd: methodMd,
);

/// Asserts every [tokens] entry resolved to a non-empty value somewhere in
/// [rendered], and that the brief contains no unknown-reference placeholder
/// at all.
void _expectAllResolved(String rendered, List<PlanFieldToken> tokens) {
  expect(rendered, isNot(contains('missing reference')));
  for (final token in tokens) {
    final pattern = RegExp(
      '>>>${RegExp.escape(token.name)}>>>(.*?)<<<${RegExp.escape(token.name)}<<<',
      dotAll: true,
    );
    final match = pattern.firstMatch(rendered);
    expect(
      match,
      isNotNull,
      reason: '${token.name} marker missing from the rendered brief',
    );
    expect(
      match!.group(1)!.trim(),
      isNotEmpty,
      reason: '${token.name} resolved to an empty value',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'every PlanFieldTokens.program(l) entry resolves via BriefRenderer',
    () async {
      final tokens = PlanFieldTokens.program(_l10n);
      final briefIntroMd = tokens.map((t) => _wrap(t.name)).join('\n');
      final program = _program(
        briefIntroMd: briefIntroMd,
        exercise: _exercise(),
      );

      final rendered = await BriefRenderer().render(
        program: program,
        audience: BriefAudience.participant,
        l10n: _l10n,
      );

      _expectAllResolved(rendered, tokens);
    },
  );

  test(
    'every PlanFieldTokens.exercise(l) entry resolves via BriefRenderer',
    () async {
      final tokens = PlanFieldTokens.exercise(_l10n);
      final methodMd = tokens.map((t) => _wrap(t.name)).join('\n');
      final exercise = _exercise(methodMd: methodMd);
      final program = _program(briefIntroMd: '', exercise: exercise);

      final rendered = await BriefRenderer().render(
        program: program,
        exercise: exercise,
        audience: BriefAudience.participant,
        l10n: _l10n,
      );

      _expectAllResolved(rendered, tokens);
    },
  );
}
