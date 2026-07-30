import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/views/widgets/app_brief_labels.dart';
import 'package:ringdrill/l10n/app_localizations_nb.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/person.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/brief/brief_audience.dart';
import 'package:ringdrill/services/brief/brief_renderer.dart';

/// DESIGN-009 prompt 2 — `{{station.loc.<slug>}}` / `{{station.person.<slug>}}`
/// resolution, with facets and the effective-identity rule (ADR-0047).

final _l10n = AppLocalizationsNb();
final _start = SimpleTimeOfDay(hour: 8, minute: 0);
final _end = SimpleTimeOfDay(hour: 9, minute: 0);

const _lkp = Location(
  slug: 'lkp',
  label: 'Sist kjente posisjon',
  kind: LocationKind.lkp,
  place: 'Fjellheisen',
  position: LatLng(58.99, 10.43),
);
const _noPositionLoc = Location(slug: 'ko', place: 'Rådhuset');

Plan _emptyPlan() {
  final now = DateTime(2026);
  return Plan(
    uuid: 'prog-scenario',
    name: 'Scenario Plan',
    description: '',
    metadata: PlanMetadata(created: now, updated: now, version: '1.0'),
    teams: const [],
    sessions: const [],
    exercises: const [],
    rolePlays: const [],
    staff: const [],
  );
}

Exercise _exerciseWith({
  required Station station,
  List<RolePlay> rolePlays = const [],
  String? methodMd,
}) => Exercise(
  uuid: 'ex-1',
  name: 'Exercise',
  startTime: _start,
  endTime: _end,
  numberOfTeams: 1,
  numberOfRounds: 1,
  executionTime: 10,
  evaluationTime: 5,
  rotationTime: 5,
  stations: [station],
  schedule: const [],
  methodMd: methodMd,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BriefRenderer renderer;
  setUp(() {
    renderer = BriefRenderer();
  });

  group('BriefRenderer — station locations', () {
    test('.place, .position, .label and the bare default resolve', () async {
      final station = Station(
        index: 0,
        name: 'Post',
        locations: const [_lkp],
        situationMd:
            'Sted: {{station.loc.lkp.place}}\n'
            'UTM: {{station.loc.lkp.position}}\n'
            'Navn: {{station.loc.lkp.label}}\n'
            'Standard: {{station.loc.lkp}}',
      );
      final plan = _emptyPlan().copyWith(
        exercises: [_exerciseWith(station: station)],
      );

      final result = await renderer.render(
        plan: plan,
        audience: BriefAudience.participant,
        l10n: _l10n.brief,
      );

      final utm = BriefRenderer.formatUtm(_lkp.position);
      expect(result, contains('Sted: `Fjellheisen`'));
      expect(result, contains('UTM: `$utm`'));
      expect(result, contains('Navn: Sist kjente posisjon'));
      // Parentheses are folded into the code span so the chip renderer can
      // keep "(pill)" on one line; copy still yields the bare coordinate.
      // Place and UTM are each their own copy chip; the UTM chip keeps the
      // folded parentheses.
      expect(result, contains('Standard: `Fjellheisen` `($utm)`'));
    });

    test('.position is empty when the location has no position', () async {
      final station = Station(
        index: 0,
        name: 'Post',
        locations: const [_noPositionLoc],
        situationMd:
            'UTM:[{{station.loc.ko.position}}] Standard:[{{station.loc.ko}}]',
      );
      final plan = _emptyPlan().copyWith(
        exercises: [_exerciseWith(station: station)],
      );

      final result = await renderer.render(
        plan: plan,
        audience: BriefAudience.participant,
        l10n: _l10n.brief,
      );

      expect(result, contains('UTM:[] Standard:[`Rådhuset`]'));
    });
  });

  group('BriefRenderer — station persons', () {
    test('.name/.age/.gender/.description resolve from the Person', () async {
      const anne = Person(
        slug: 'anne',
        name: 'Anne Glemsk',
        age: 74,
        gender: 'kvinne',
        description: 'Blå jakke',
      );
      final station = Station(
        index: 0,
        name: 'Post',
        persons: const [anne],
        situationMd:
            'Navn: {{station.person.anne.name}}\n'
            'Alder: {{station.person.anne.age}}\n'
            'Kjønn: {{station.person.anne.gender}}\n'
            'Description: {{station.person.anne.description}}\n'
            'Standard: {{station.person.anne}}',
      );
      final plan = _emptyPlan().copyWith(
        exercises: [_exerciseWith(station: station)],
      );

      final result = await renderer.render(
        plan: plan,
        audience: BriefAudience.participant,
        l10n: _l10n.brief,
      );

      expect(result, contains('Navn: Anne Glemsk'));
      expect(result, contains('Alder: 74'));
      expect(result, contains('Kjønn: kvinne'));
      expect(result, contains('Description: Blå jakke'));
      expect(result, contains('Standard: Anne Glemsk'));
    });

    test('.loc.position resolves through locSlug to the location', () async {
      const anne = Person(slug: 'anne', name: 'Anne Glemsk', locSlug: 'lkp');
      final station = Station(
        index: 0,
        name: 'Post',
        locations: const [_lkp],
        persons: const [anne],
        situationMd:
            'Hjemme: {{station.person.anne.loc}}\n'
            'HjemmeUTM: {{station.person.anne.loc.position}}',
      );
      final plan = _emptyPlan().copyWith(
        exercises: [_exerciseWith(station: station)],
      );

      final result = await renderer.render(
        plan: plan,
        audience: BriefAudience.participant,
        l10n: _l10n.brief,
      );

      final utm = BriefRenderer.formatUtm(_lkp.position);
      expect(result, contains('Hjemme: `Fjellheisen` `($utm)`'));
      expect(result, contains('HjemmeUTM: `$utm`'));
    });

    test('.loc.place resolves through locSlug to the location\'s place, '
        'with no .home anywhere', () async {
      const anne = Person(slug: 'anne', name: 'Anne Glemsk', locSlug: 'lkp');
      final station = Station(
        index: 0,
        name: 'Post',
        locations: const [_lkp],
        persons: const [anne],
        situationMd: 'Sted: {{station.person.anne.loc.place}}',
      );
      final plan = _emptyPlan().copyWith(
        exercises: [_exerciseWith(station: station)],
      );

      final result = await renderer.render(
        plan: plan,
        audience: BriefAudience.participant,
        l10n: _l10n.brief,
      );

      expect(result, contains('Sted: `Fjellheisen`'));
      expect(result, isNot(contains('.home')));
      expect(result, isNot(contains('{{station.person.anne.loc.place}}')));
    });

    test('a person portrayed by a roleplay whose name differs resolves to the '
        'roleplay\'s value', () async {
      const anne = Person(slug: 'anne', name: 'Anne Glemsk', age: 74);
      final rolePlay = RolePlay(
        uuid: 'rp-1',
        index: 0,
        exerciseUuid: 'ex-1',
        name: 'Anne Nordmann',
        stationIndex: 0,
        personRef: 'anne',
      );
      final station = Station(
        index: 0,
        name: 'Post',
        persons: const [anne],
        situationMd: 'Navn: {{station.person.anne.name}}',
      );
      final plan = _emptyPlan().copyWith(
        exercises: [
          _exerciseWith(station: station, rolePlays: [rolePlay]),
        ],
        rolePlays: [rolePlay],
      );

      final result = await renderer.render(
        plan: plan,
        audience: BriefAudience.participant,
        l10n: _l10n.brief,
      );

      expect(result, contains('Navn: Anne Nordmann'));
      expect(result, isNot(contains('Navn: Anne Glemsk')));
    });

    test('with no portraying roleplay, a person facet falls back to the '
        'Person\'s own value', () async {
      const anne = Person(slug: 'anne', name: 'Anne Glemsk');
      final station = Station(
        index: 0,
        name: 'Post',
        persons: const [anne],
        situationMd: 'Navn: {{station.person.anne.name}}',
      );
      final plan = _emptyPlan().copyWith(
        exercises: [_exerciseWith(station: station)],
      );

      final result = await renderer.render(
        plan: plan,
        audience: BriefAudience.participant,
        l10n: _l10n.brief,
      );

      expect(result, contains('Navn: Anne Glemsk'));
    });

    test(
      'an empty roleplay override field falls back to the Person\'s value',
      () async {
        const anne = Person(
          slug: 'anne',
          name: 'Anne Glemsk',
          gender: 'kvinne',
        );
        final rolePlay = RolePlay(
          uuid: 'rp-1',
          index: 0,
          exerciseUuid: 'ex-1',
          name: 'Anne Glemsk',
          gender: '',
          stationIndex: 0,
          personRef: 'anne',
        );
        final station = Station(
          index: 0,
          name: 'Post',
          persons: const [anne],
          situationMd: 'Kjønn: {{station.person.anne.gender}}',
        );
        final plan = _emptyPlan().copyWith(
          exercises: [
            _exerciseWith(station: station, rolePlays: [rolePlay]),
          ],
          rolePlays: [rolePlay],
        );

        final result = await renderer.render(
          plan: plan,
          audience: BriefAudience.participant,
          l10n: _l10n.brief,
        );

        expect(result, contains('Kjønn: kvinne'));
      },
    );

    test(
      'a roleplay field resolves station.* against its own station',
      () async {
        const anne = Person(slug: 'anne', name: 'Anne Glemsk');
        final rolePlay = RolePlay(
          uuid: 'rp-1',
          index: 0,
          exerciseUuid: 'ex-1',
          name: 'Anne Glemsk',
          stationIndex: 0,
          personRef: 'anne',
          behavior: 'Spiller {{station.person.anne.name}}',
        );
        final station = Station(index: 0, name: 'Post', persons: const [anne]);
        final plan = _emptyPlan().copyWith(
          exercises: [
            _exerciseWith(station: station, rolePlays: [rolePlay]),
          ],
          rolePlays: [rolePlay],
        );

        // Instructor, not participant: a role-play field is staff-facing
        // (ADR-0063) and this test is about token resolution, not visibility.
        final result = await renderer.render(
          plan: plan,
          audience: BriefAudience.instructor,
          l10n: _l10n.brief,
        );

        expect(result, contains('Spiller Anne Glemsk'));
      },
    );
  });

  group('BriefRenderer — scope and unknown references', () {
    test('a plan field does not resolve station.loc/person (no station in '
        'scope)', () async {
      final plan = _emptyPlan().copyWith(
        exercises: [
          _exerciseWith(station: const Station(index: 0, name: 'Post')),
        ],
        briefIntroMd: 'Ingen post her: {{station.loc.lkp}}',
      );

      final result = await renderer.render(
        plan: plan,
        audience: BriefAudience.participant,
        l10n: _l10n.brief,
      );

      expect(
        result,
        isNot(contains(_l10n.briefUnknownReference('station.loc.lkp'))),
      );
      expect(result, contains('{{station.loc.lkp}}'));
    });

    test('an exercise field does not resolve station.loc/person (no station in '
        'scope)', () async {
      final plan = _emptyPlan().copyWith(
        exercises: [
          _exerciseWith(
            station: const Station(index: 0, name: 'Post'),
            methodMd: 'Ingen post her: {{station.loc.lkp}}',
          ),
        ],
      );

      final result = await renderer.render(
        plan: plan,
        audience: BriefAudience.participant,
        l10n: _l10n.brief,
      );

      expect(
        result,
        isNot(contains(_l10n.briefUnknownReference('station.loc.lkp'))),
      );
      expect(result, contains('{{station.loc.lkp}}'));
    });

    test('an unknown location slug renders a visible placeholder', () async {
      final station = Station(
        index: 0,
        name: 'Post',
        situationMd: 'Sted: {{station.loc.mangler}}',
      );
      final plan = _emptyPlan().copyWith(
        exercises: [_exerciseWith(station: station)],
      );

      final result = await renderer.render(
        plan: plan,
        audience: BriefAudience.participant,
        l10n: _l10n.brief,
      );

      expect(
        result,
        contains(_l10n.briefUnknownReference('station.loc.mangler')),
      );
      expect(result, isNot(contains('{{station.loc.mangler}}')));
    });

    test('an unknown person slug renders a visible placeholder', () async {
      final station = Station(
        index: 0,
        name: 'Post',
        situationMd: 'Person: {{station.person.mangler}}',
      );
      final plan = _emptyPlan().copyWith(
        exercises: [_exerciseWith(station: station)],
      );

      final result = await renderer.render(
        plan: plan,
        audience: BriefAudience.participant,
        l10n: _l10n.brief,
      );

      expect(
        result,
        contains(_l10n.briefUnknownReference('station.person.mangler')),
      );
      expect(result, isNot(contains('{{station.person.mangler}}')));
    });

    test(
      'a known slug with an empty facet renders empty, not a placeholder',
      () async {
        const anne = Person(slug: 'anne', name: 'Anne');
        final station = Station(
          index: 0,
          name: 'Post',
          persons: const [anne],
          situationMd: 'Description:[{{station.person.anne.description}}]',
        );
        final plan = _emptyPlan().copyWith(
          exercises: [_exerciseWith(station: station)],
        );

        final result = await renderer.render(
          plan: plan,
          audience: BriefAudience.participant,
          l10n: _l10n.brief,
        );

        expect(result, contains('Description:[]'));
        expect(
          result,
          isNot(contains(_l10n.briefUnknownReference('station.person.anne'))),
        );
      },
    );
  });

  group('BriefRenderer — no-scenario regression', () {
    test('a plan with no locations/persons renders identically to before this '
        'prompt', () async {
      final station = Station(
        index: 0,
        name: 'Post',
        position: const LatLng(58.99, 10.43),
        situationMd: 'IPP er ved {{station.position}}.',
      );
      final plan = _emptyPlan().copyWith(
        exercises: [_exerciseWith(station: station)],
      );

      final result = await renderer.render(
        plan: plan,
        audience: BriefAudience.participant,
        l10n: _l10n.brief,
      );

      final utm = BriefRenderer.formatUtm(station.position);
      expect(result, contains('IPP er ved `$utm`.'));
    });
  });
}
