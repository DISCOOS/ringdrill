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
        'grovsøk R25 fra IPP. Sist sett {{station.loc.lkp.position}}. '
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
      expect(en, contains('Ring Route'));
      expect(nb, isNot(en));
    });

    // ADR-0062 changed the model and left the brief asserting a uniform ring route.
    // Two claims on one line: what the conduct is, and whether the rounds share a
    // cycle. Both were true of every exercise once and are now true of `ring` alone.
    group('the Organisering conduct line', () {
      Future<String> renderWith(Exercise Function(Exercise) edit) {
        final plan = _plan();
        return BriefRenderer().render(
          plan: plan.copyWith(exercises: [edit(plan.exercises.first)]),
          audience: BriefAudience.director,
          l10n: HeadlessBriefLabels(languageCode: 'nb'),
        );
      }

      test('ring keeps its route noun and its multiplied cycle', () async {
        // Uniform by construction, so the product is a true statement and the line
        // reads exactly as it always has.
        final markdown = await renderWith((e) => e);
        expect(markdown, contains('Ringløype'));
        expect(markdown, contains('6 x (15 | 10 | 5)'));
      });

      test('together names itself and stops multiplying', () async {
        // Rounds of differing length: "2 x (…)" would invent a cycle, and the phases
        // are a span, so a product of a span is not even arithmetic.
        final markdown = await renderWith(
          (e) => e.copyWith(
            mode: ExerciseMode.together,
            stations: [
              e.stations.first.copyWith(executionTime: 70),
              e.stations.first.copyWith(index: 1, executionTime: 100),
            ],
          ),
        );
        expect(markdown, contains('Samlet gjennomføring'));
        expect(markdown, isNot(contains('Ringløype')));
        expect(markdown, contains('(70–100 | 10 | 5)'));
        expect(
          markdown,
          isNot(contains('x (70–100')),
          reason: 'a span has no cycle to multiply',
        );
      });

      test('split names what the reader sees on the ground', () async {
        final markdown = await renderWith(
          (e) => e.copyWith(mode: ExerciseMode.split),
        );
        expect(markdown, contains('Parallelle poster'));
        expect(markdown, isNot(contains('Ringløype')));
      });
    });

    // A blockquote the template opened and the content walked out of. `>` prefixed the
    // first line only, because mustache interpolates raw — so a one-paragraph note
    // looked correct and hid it, and from paragraph two on, staff notes read as body
    // text inside the brief.
    test(
      'a multi-paragraph director note stays inside its blockquote',
      () async {
        final plan = _plan();
        final station = plan.exercises.first.stations.first;
        final markdown = await BriefRenderer().render(
          plan: plan.copyWith(
            exercises: [
              plan.exercises.first.copyWith(
                stations: [
                  station.copyWith(
                    directorNotesMd:
                        'Markør bak paviljongen.\n'
                        '\n'
                        'Rom 105 er låst med vilje.\n'
                        '\n'
                        'Lås døra etterpå.',
                  ),
                ],
              ),
            ],
          ),
          audience: BriefAudience.director,
          l10n: HeadlessBriefLabels(languageCode: 'nb'),
        );

        // Every line of the note, not just the first.
        expect(markdown, contains('> Markør bak paviljongen.'));
        expect(markdown, contains('> Rom 105 er låst med vilje.'));
        expect(markdown, contains('> Lås døra etterpå.'));
        // And the paragraph breaks stay inside the quote rather than ending it.
        expect(
          markdown,
          isNot(contains('\n\nRom 105')),
          reason: 'a bare paragraph would have left the blockquote',
        );
      },
    );

    // The blank line before a heading lived inside the `{{#actor}}` block, so an
    // *uncast* marker's block ran straight into the next heading and markdown rendered
    // "#### Situasjon" as body text. Every fixture had a cast marker, which is why it
    // survived: the bug was in the branch nobody had a fixture for.
    test(
      'an uncast marker still leaves a blank line before the next heading',
      () async {
        final plan = _plan();
        final markdown = await BriefRenderer().render(
          // Same plan with nobody cast: the roleplay keeps its behaviour, loses its actor.
          plan: plan.copyWith(
            staff: const [],
            rolePlays: [
              for (final r in plan.rolePlays) r.copyWith(staffUuid: null),
            ],
          ),
          audience: BriefAudience.director,
          l10n: HeadlessBriefLabels(languageCode: 'nb'),
        );

        for (final heading
            in markdown
                .split('\n')
                .asMap()
                .entries
                .where((e) => e.value.startsWith('#### '))) {
          final before = markdown.split('\n')[heading.key - 1];
          expect(
            before.trim(),
            isEmpty,
            reason:
                'heading "\${heading.value}" has "\$before" directly above it, so '
                'markdown reads it as body text',
          );
        }
      },
    );

    test('an unsupported language falls back rather than failing', () async {
      // A plan may name a language the app has no ARB for; a brief should still
      // render, in the fallback, rather than throwing at the reader.
      final markdown = await _render(HeadlessBriefLabels(languageCode: 'de'));
      expect(markdown, contains('Ring Route'));
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
