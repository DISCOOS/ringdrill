import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/person.dart';
import 'package:ringdrill/utils/station_scenario_tokens.dart';

/// DESIGN-009 follow-up 4 — pure facet-resolution unit tests for the
/// editor's own `station.loc`/`station.person` token support (see the
/// module doc comment in `station_scenario_tokens.dart` for why this is a
/// deliberate, independent copy of `BriefRenderer`'s server-side logic
/// rather than a shared import).
void main() {
  group('stationScenarioTokenPattern', () {
    test('matches bare and faceted station.loc/person tokens', () {
      final matches = stationScenarioTokenPattern
          .allMatches('{{station.loc.lkp}} {{station.person.anne.age}}')
          .toList();
      expect(matches, hasLength(2));
      expect(matches[0].group(1), 'loc');
      expect(matches[0].group(2), 'lkp');
      expect(stationScenarioTokenFacets(matches[0]), isEmpty);
      expect(matches[1].group(1), 'person');
      expect(matches[1].group(2), 'anne');
      expect(stationScenarioTokenFacets(matches[1]), ['age']);
    });

    test('does not match a plain var.* or unrelated station.* token', () {
      expect(
        stationScenarioTokenPattern.hasMatch('{{var.frekvens}}'),
        isFalse,
      );
      expect(
        stationScenarioTokenPattern.hasMatch('{{station.position.utm}}'),
        isFalse,
      );
    });
  });

  group('resolveLocationFacet', () {
    test('bare token defaults to place, falling back to UTM', () {
      const withPlace = Location(slug: 'a', place: 'Sentrum');
      expect(resolveLocationFacet(withPlace, const []), 'Sentrum');

      const withPositionOnly = Location(
        slug: 'b',
        position: LatLng(59.9139, 10.7522),
      );
      expect(
        resolveLocationFacet(withPositionOnly, const []),
        isNotEmpty,
      );

      const withNeither = Location(slug: 'c');
      expect(resolveLocationFacet(withNeither, const []), isEmpty);
    });

    test('.place/.label/.utm facets resolve their own field', () {
      const location = Location(
        slug: 'a',
        label: 'Siste kjente posisjon',
        place: 'Sentrum',
        position: LatLng(59.9139, 10.7522),
      );
      expect(resolveLocationFacet(location, ['place']), 'Sentrum');
      expect(
        resolveLocationFacet(location, ['label']),
        'Siste kjente posisjon',
      );
      expect(resolveLocationFacet(location, ['utm']), isNotEmpty);
    });
  });

  group('resolvePersonFacet', () {
    const person = Person(
      slug: 'anne',
      name: 'Anne Glemsk',
      age: 47,
      gender: 'woman',
      signalement: 'Rød jakke',
      locSlug: 'loc',
    );
    const loc = Location(slug: 'loc', place: 'Hjemme');

    test('bare token and named facets resolve the person\'s own fields '
        'when there is no portraying override', () {
      expect(resolvePersonFacet(person, null, const [loc], const []), 'Anne Glemsk');
      expect(resolvePersonFacet(person, null, const [loc], ['age']), '47');
      expect(resolvePersonFacet(person, null, const [loc], ['gender']), 'woman');
      expect(
        resolvePersonFacet(person, null, const [loc], ['signalement']),
        'Rød jakke',
      );
      expect(
        resolvePersonFacet(person, null, const [loc], ['loc']),
        'Hjemme',
      );
      expect(
        resolvePersonFacet(person, null, const [loc], ['loc', 'place']),
        'Hjemme',
      );
    });

    test('a non-empty portrayer field overrides the person\'s own value', () {
      const portrayer = EffectivePersonIdentity(name: 'Anne (spilt av Kari)');
      expect(
        resolvePersonFacet(person, portrayer, const [loc], const []),
        'Anne (spilt av Kari)',
      );
      // Age is untouched by the override, so it falls back to the person.
      expect(
        resolvePersonFacet(person, portrayer, const [loc], ['age']),
        '47',
      );
    });

    test('an empty portrayer field falls back to the person\'s own value', () {
      const portrayer = EffectivePersonIdentity(name: '');
      expect(
        resolvePersonFacet(person, portrayer, const [loc], const []),
        'Anne Glemsk',
      );
    });

    test('a dangling locSlug resolves to empty, not a crash', () {
      const orphan = Person(slug: 'p', name: 'P', locSlug: 'missing');
      expect(resolvePersonFacet(orphan, null, const [loc], ['loc']), '');
    });
  });
}
