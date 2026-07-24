import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations_en.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/person.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/brief/brief_audience.dart';
import 'package:ringdrill/services/brief/brief_renderer.dart';
import 'package:ringdrill/views/widgets/token_insertion_menu.dart';

/// DESIGN-009 follow-up 4d's "the picker never offers an unresolvable
/// token" invariant, enforced mechanically for `station.loc.*`/
/// `station.person.*` facet completion: every entry in
/// [locationFacetNames]/[personFacetNames] — including a person's `loc`
/// facet chained one level to its location's own facets — is inserted as a
/// raw `{{station.loc/person.<slug>[.loc].<facet>}}` and rendered through
/// the real [BriefRenderer]. A future rename that drops a case from
/// `_resolveLocationFacet`/`_resolvePersonFacet` in `brief_renderer.dart`
/// fails here instead of only surfacing as a silently empty mustache miss
/// in a shipped brief.

final _l10n = AppLocalizationsEn();

/// Wraps [name] in unique markers so its resolved value can be located in
/// the full rendered brief regardless of surrounding template chrome.
String _wrap(String name) => '>>>$name>>>{{$name}}<<<$name<<<';

const _locationSlug = 'lkp';
const _personSlug = 'anne';

Location _location() => const Location(
  slug: _locationSlug,
  label: 'Siste kjente posisjon',
  place: 'Sentrum',
  position: LatLng(58.99, 10.43),
);

Person _person() => const Person(
  slug: _personSlug,
  name: 'Anne Glemsk',
  age: 39,
  gender: 'female',
  description: '160 cm, grått hår, blå anorakk',
  locSlug: _locationSlug,
);

Station _station({required String situationMd}) => Station(
  index: 0,
  name: 'Test Station',
  locations: [_location()],
  persons: [_person()],
  situationMd: situationMd,
);

Exercise _exercise(Station station) => Exercise(
  uuid: 'ex-1',
  name: 'Test Exercise',
  startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
  endTime: const SimpleTimeOfDay(hour: 10, minute: 0),
  numberOfTeams: 4,
  numberOfRounds: 3,
  executionTime: 20,
  evaluationTime: 10,
  rotationTime: 5,
  stations: [station],
  schedule: const [],
);

Plan _plan(Exercise exercise) => Plan(
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
);

/// Renders [tokenNames] (each wrapped via [_wrap] into the station's
/// situationMd) and asserts every one resolved to a non-empty value with no
/// unknown-reference placeholder anywhere in the brief.
Future<void> _expectAllResolve(List<String> tokenNames) async {
  final situationMd = tokenNames.map(_wrap).join('\n');
  final station = _station(situationMd: situationMd);
  final exercise = _exercise(station);
  final plan = _plan(exercise);

  final rendered = await BriefRenderer().render(
    plan: plan,
    exercise: exercise,
    audience: BriefAudience.participant,
    l10n: _l10n,
  );

  expect(rendered, isNot(contains('missing reference')));
  for (final name in tokenNames) {
    final pattern = RegExp(
      '>>>${RegExp.escape(name)}>>>(.*?)<<<${RegExp.escape(name)}<<<',
      dotAll: true,
    );
    final match = pattern.firstMatch(rendered);
    expect(match, isNotNull, reason: '$name marker missing from the brief');
    expect(
      match!.group(1)!.trim(),
      isNotEmpty,
      reason: '$name resolved to an empty value',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every locationFacetNames entry resolves via BriefRenderer', () async {
    await _expectAllResolve([
      for (final f in locationFacetNames) 'station.loc.$_locationSlug.$f',
    ]);
  });

  test('every personFacetNames entry resolves via BriefRenderer, including '
      'the bare "loc" facet', () async {
    await _expectAllResolve([
      for (final f in personFacetNames) 'station.person.$_personSlug.$f',
    ]);
  });

  test('every locationFacetNames entry resolves chained through a person\'s '
      'loc (station.person.<slug>.loc.<facet>)', () async {
    await _expectAllResolve([
      for (final f in locationFacetNames) 'station.person.$_personSlug.loc.$f',
    ]);
  });
}
