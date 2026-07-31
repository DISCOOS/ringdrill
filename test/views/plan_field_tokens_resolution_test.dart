import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/views/widgets/app_brief_labels.dart';
import 'package:ringdrill/l10n/app_localizations_en.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/brief/brief_audience.dart';
import 'package:ringdrill/services/brief/brief_renderer.dart';
import 'package:ringdrill/views/widgets/editor_token.dart';
import 'package:ringdrill/views/widgets/plan_field_tokens.dart';

/// DESIGN-009 follow-ups 4b and 4c's "the picker never offers an
/// unresolvable token" invariant, enforced mechanically: every
/// [PlanFieldTokens.plan]/[PlanFieldTokens.exercise]/
/// [PlanFieldTokens.station]/[PlanFieldTokens.roleplay] entry is inserted as
/// a raw `{{<name>}}` into a markdown field and rendered through the real
/// [BriefRenderer]. A future rename that drops a facet from
/// `_planRefContext`/`_exerciseRefContext`/`stationRefContext`/
/// `roleplayRefContext` fails here instead of only surfacing as a silently
/// empty mustache miss in a shipped brief.

final _l10n = AppLocalizationsEn();

/// Wraps [name] in unique markers so its resolved value can be located in
/// the full rendered brief regardless of surrounding template chrome.
String _wrap(String name) => '>>>$name>>>{{$name}}<<<$name<<<';

Plan _plan({
  required String briefIntroMd,
  required Exercise exercise,
  List<RolePlay> rolePlays = const [],
}) => Plan(
  uuid: 'pgm-1',
  name: 'Test Plan',
  description: 'A test plan',
  metadata: PlanMetadata(
    created: DateTime(2026),
    updated: DateTime(2026),
    version: '1.0',
  ),
  teams: const [],
  sessions: const [],
  exercises: [exercise],
  rolePlays: rolePlays,
  briefIntroMd: briefIntroMd,
);

Exercise _exercise({String? methodMd, List<Station> stations = const []}) =>
    Exercise(
      uuid: 'ex-1',
      name: 'Test Exercise',
      startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
      endTime: const SimpleTimeOfDay(hour: 10, minute: 0),
      numberOfTeams: 4,
      numberOfRounds: 3,
      executionTime: 20,
      evaluationTime: 10,
      rotationTime: 5,
      stations: stations,
      // A real schedule, not `const []`: the derived-value tokens
      // (`exercise.roundTable`, `station.duration`) read it, and an exercise
      // without one is a state the compiler never produces. Three rounds of
      // 20 + 10 + 5 from 08:00, which is what these durations derive.
      schedule: const [
        [
          SimpleTimeOfDay(hour: 8, minute: 0),
          SimpleTimeOfDay(hour: 8, minute: 20),
          SimpleTimeOfDay(hour: 8, minute: 30),
        ],
        [
          SimpleTimeOfDay(hour: 8, minute: 35),
          SimpleTimeOfDay(hour: 8, minute: 55),
          SimpleTimeOfDay(hour: 9, minute: 5),
        ],
        [
          SimpleTimeOfDay(hour: 9, minute: 10),
          SimpleTimeOfDay(hour: 9, minute: 30),
          SimpleTimeOfDay(hour: 9, minute: 40),
        ],
      ],
      methodMd: methodMd,
    );

Station _station({String? situationMd}) => Station(
  index: 0,
  name: 'Test Station',
  position: const LatLng(58.99, 10.43),
  variantSuffix: 'A',
  situationMd: situationMd,
);

RolePlay _rolePlay({String? behavior}) => RolePlay(
  uuid: 'rp-1',
  index: 0,
  exerciseUuid: 'ex-1',
  name: 'Test Role',
  age: 30,
  description: 'Test description',
  stationIndex: 0,
  position: const LatLng(58.99, 10.43),
  behavior: behavior,
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
    'every PlanFieldTokens.plan(l) entry resolves via BriefRenderer',
    () async {
      final tokens = PlanFieldTokens.plan(_l10n);
      final briefIntroMd = tokens.map((t) => _wrap(t.name)).join('\n');
      final plan = _plan(briefIntroMd: briefIntroMd, exercise: _exercise());

      final rendered = await BriefRenderer().render(
        plan: plan,
        audience: BriefAudience.participant,
        l10n: _l10n.brief,
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
      final plan = _plan(briefIntroMd: '', exercise: exercise);

      final rendered = await BriefRenderer().render(
        plan: plan,
        exercise: exercise,
        audience: BriefAudience.participant,
        l10n: _l10n.brief,
      );

      _expectAllResolved(rendered, tokens);
    },
  );

  test(
    'every PlanFieldTokens.station(l) entry resolves via BriefRenderer',
    () async {
      final tokens = PlanFieldTokens.station(_l10n);
      final situationMd = tokens.map((t) => _wrap(t.name)).join('\n');
      final station = _station(situationMd: situationMd);
      final exercise = _exercise(stations: [station]);
      final plan = _plan(briefIntroMd: '', exercise: exercise);

      final rendered = await BriefRenderer().render(
        plan: plan,
        exercise: exercise,
        audience: BriefAudience.participant,
        l10n: _l10n.brief,
      );

      _expectAllResolved(rendered, tokens);
    },
  );

  test(
    'every PlanFieldTokens.roleplay(l) entry resolves via BriefRenderer',
    () async {
      final tokens = PlanFieldTokens.roleplay(_l10n);
      final behavior = tokens.map((t) => _wrap(t.name)).join('\n');
      final station = _station();
      final exercise = _exercise(stations: [station]);
      final rolePlay = _rolePlay(behavior: behavior);
      final plan = _plan(
        briefIntroMd: '',
        exercise: exercise,
        rolePlays: [rolePlay],
      );

      final rendered = await BriefRenderer().render(
        plan: plan,
        exercise: exercise,
        // Role-play fields are staff-facing (ADR-0063), so a participant render
        // has no role-play section to resolve tokens in. This test is about token
        // resolution, not visibility.
        audience: BriefAudience.instructor,
        l10n: _l10n.brief,
      );

      _expectAllResolved(rendered, tokens);
    },
  );
}
