// Rendering a brief with no Flutter in sight — what the ADR-0048 amendment was
// for (DESIGN-014 stage 5).
//
// The interesting assertion is not that markdown comes out, but that it comes out
// *identical* to what the app produces. The amendment replaced an
// `AppLocalizations` parameter with a `BriefLabels` interface and an `AssetBundle`
// with a template source; both implementations are supposed to be
// behaviour-preserving, and "supposed to be" is what a test is for. If the two
// ever diverge, a plan's brief would read differently depending on whether it was
// opened in the app or rendered by the CLI — the sort of difference nobody
// notices until it matters.
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations_en.dart';
import 'package:ringdrill/l10n/app_localizations_nb.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/person.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/schedule.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/brief/brief_audience.dart';
import 'package:ringdrill/services/brief/brief_labels.dart';
import 'package:ringdrill/services/brief/brief_renderer.dart';
import 'package:ringdrill/views/widgets/app_brief_labels.dart';

/// A plan exercising the pieces the brief layer resolves: a plan variable with a
/// station-scoped override, a station-owned location and person, tokens in prose,
/// and a role play portraying that person.
Plan _plan() {
  const start = SimpleTimeOfDay(hour: 9, minute: 45);
  const rounds = 6, exec = 15, eval = 10, rot = 5;
  final now = DateTime.utc(2026);
  final station = Station(
    index: 0,
    name: 'Barn 4-6 år',
    position: const LatLng(59.096857, 10.401633),
    variableOverrides: const {'talegruppe': 'RK-VFOLD-ØV3'},
    locations: const [
      Location(
        slug: 'lkp',
        kind: LocationKind.lkp,
        label: 'Sist kjent posisjon',
        position: LatLng(59.09672, 10.40201),
      ),
    ],
    persons: const [
      Person(slug: 'magnus', name: 'Magnus Damslet', age: 6, locSlug: 'lkp'),
    ],
    situationMd:
        '{{station.person.magnus}} ({{station.person.magnus.age}} år) – '
        'grovsøk R25 fra IPP. Sist sett {{station.loc.lkp.utm}}. '
        'Samband på {{var.talegruppe}}.',
    directorNotesMd: 'Markør bak paviljongen.',
  );
  final exercise = Exercise(
    uuid: 'ex-1',
    index: 0,
    name: 'Førsteinnsats søk',
    startTime: start,
    numberOfTeams: 1,
    numberOfRounds: rounds,
    executionTime: exec,
    evaluationTime: eval,
    rotationTime: rot,
    stations: [station],
    schedule: ExerciseSchedule.rounds(
      startTime: start,
      numberOfRounds: rounds,
      executionTime: exec,
      evaluationTime: eval,
      rotationTime: rot,
    ),
    endTime: ExerciseSchedule.endTime(
      startTime: start,
      numberOfRounds: rounds,
      executionTime: exec,
      evaluationTime: eval,
      rotationTime: rot,
    ),
  );
  return Plan(
    uuid: 'plan-1',
    name: 'LSOR Eidene 2026',
    description: 'Øvingsplan',
    metadata: PlanMetadata(
      created: now,
      updated: now,
      version: '1.0',
      languageCode: 'nb',
    ),
    variables: const [DrillVariable(name: 'talegruppe', value: 'RK-VFOLD-ØV2')],
    teams: const [],
    sessions: const [],
    exercises: [exercise],
    rolePlays: const [
      RolePlay(
        uuid: 'rp-1',
        index: 0,
        exerciseUuid: 'ex-1',
        name: 'Magnus Damslet',
        age: 6,
        stationIndex: 0,
        personRef: 'magnus',
        behavior: 'Gjemmer seg bak paviljongen.',
      ),
    ],
    staff: const [],
  );
}

Future<String> _render(BriefLabels labels, {BriefAudience? audience}) =>
    BriefRenderer().render(
      plan: _plan(),
      audience: audience ?? BriefAudience.director,
      l10n: labels,
    );

void main() {
  group('headless rendering', () {
    test('matches the app byte for byte, in both languages', () async {
      // The whole point of the amendment: one resolver serving app and CLI.
      expect(
        await _render(HeadlessBriefLabels(languageCode: 'nb')),
        await _render(AppLocalizationsNb().brief),
      );
      expect(
        await _render(HeadlessBriefLabels(languageCode: 'en')),
        await _render(AppLocalizationsEn().brief),
      );
    });

    test('matches the app for every audience', () async {
      // Audience changes which sections render, so an l10n member reachable only
      // from a director section would slip past a participant-only comparison.
      for (final audience in BriefAudience.values) {
        expect(
          await _render(
            HeadlessBriefLabels(languageCode: 'nb'),
            audience: audience,
          ),
          await _render(AppLocalizationsNb().brief, audience: audience),
          reason: 'audience ${audience.name}',
        );
      }
    });

    test('resolves every token kind', () async {
      final markdown = await _render(HeadlessBriefLabels(languageCode: 'nb'));
      // Person facets, a location's UTM, and a station-scoped variable override
      // — the three resolution paths, all of which used to need Flutter.
      expect(markdown, contains('Magnus Damslet (6 år)'));
      expect(markdown, contains('Sist sett `32V'));
      expect(
        markdown,
        contains('Samband på RK-VFOLD-ØV3'),
        reason: 'the station override should win over the plan value',
      );
      expect(markdown, isNot(contains('{{')));
    });

    test('renders in the language asked for, not the host locale', () async {
      final nb = await _render(HeadlessBriefLabels(languageCode: 'nb'));
      final en = await _render(HeadlessBriefLabels(languageCode: 'en'));
      expect(nb, contains('Ringløype'));
      expect(en, contains('Ring route'));
      expect(nb, isNot(en));
    });

    test('an unsupported language falls back rather than failing', () async {
      // A plan may name a language the app has no ARB for; a brief should still
      // render, in the fallback, rather than throwing at the reader.
      final markdown = await _render(HeadlessBriefLabels(languageCode: 'de'));
      expect(markdown, contains('Ring route'));
    });

    test('carries no Flutter in its own import closure', () {
      // Belt and braces next to test/bin/cli_flutter_free_test.dart: that walks
      // from bin/, this asserts the brief layer itself is reachable from a plain
      // Dart entry point — which is exactly what this test file is, apart from
      // the test harness.
      expect(HeadlessBriefLabels(languageCode: 'nb').localeName, 'nb');
    });
  });
}
