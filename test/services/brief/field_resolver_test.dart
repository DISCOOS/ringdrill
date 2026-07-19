import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations_nb.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/brief/field_resolver.dart';

/// DESIGN-010 stage 1 (ADR-0048) — a direct unit test of the field resolver
/// extracted from `BriefRenderer._resolveField`/`_resolveFieldOnce`, over the
/// resolution context a caller assembles by hand rather than through a full
/// `BriefRenderer.render()`. The parity guarantee itself — the renderer's
/// output is unchanged — is covered by the (unmodified) `brief_renderer_*`
/// suite; this file is about the extracted unit in isolation.
final _l10n = AppLocalizationsNb();

void main() {
  group('resolveField', () {
    test(
      'resolves a {{var.*}} token nested inside a cross-reference value',
      () {
        // {{exercise.name}} resolves (mustache pass) to a raw string that
        // itself contains {{var.year}} — only visible, and only
        // substitutable, after that pass runs; the fixpoint loop is what
        // catches it on the next iteration instead of leaving it literal.
        final vars = {'year': const DrillVariable(name: 'year', value: '2026')};
        final refContext = {
          'exercise': {'name': 'Exercise {{var.year}}'},
        };

        final result = resolveField(
          'Title: {{exercise.name}}',
          vars: vars,
          l10n: _l10n,
          refContext: refContext,
        );

        expect(result, 'Title: Exercise 2026');
      },
    );

    test('resolves a station.loc/person.* facet (ADR-0047)', () {
      const location = Location(
        slug: 'lkp',
        place: 'Fjellheisen',
        position: LatLng(58.99, 10.43),
      );
      final station = Station(
        index: 0,
        name: 'Post 1',
        locations: const [location],
      );
      final expectedUtm = formatUtm(const LatLng(58.99, 10.43));

      final result = resolveField(
        'Sted: {{station.loc.lkp.place}}, UTM: {{station.loc.lkp.position}}',
        vars: const {},
        l10n: _l10n,
        scenarioStation: station,
      );

      expect(result, 'Sted: `Fjellheisen`, UTM: `$expectedUtm`');
    });

    test('the fixpoint loop terminates at maxResolvePasses instead of looping '
        'forever on an unresolvable chain, leaving the remainder literal', () {
      // A 12-deep reference chain v0 -> v1 -> ... -> v11 -> 'END'. Fully
      // unwinding it takes more passes than maxResolvePasses allows, so
      // the loop must stop partway rather than hang or throw — the exact
      // stopping point pins down the cap's off-by-one behaviour.
      expect(maxResolvePasses, 10);
      final chain = <String, DrillVariable>{
        for (var i = 0; i < 11; i++)
          'v$i': DrillVariable(name: 'v$i', value: '{{var.v${i + 1}}}'),
        'v11': const DrillVariable(name: 'v11', value: 'END'),
      };

      final result = resolveField('{{var.v0}}', vars: chain, l10n: _l10n);

      // Bounded by the cap before reaching 'END' — the unresolved token
      // stays visible rather than the render hanging or throwing.
      expect(result, '{{var.v10}}');
    });

    test('returns null for null content', () {
      expect(resolveField(null, vars: const {}, l10n: _l10n), isNull);
    });
  });

  group('ChipFormatter', () {
    const latLng = LatLng(58.99, 10.43);

    group('CopyChipFormatter', () {
      const formatter = CopyChipFormatter();

      test('position renders a plain copy chip regardless of latLng', () {
        expect(
          formatter.position('32V 601234 6643210', latLng),
          '`32V 601234 6643210`',
        );
        expect(
          formatter.position('32V 601234 6643210', null),
          '`32V 601234 6643210`',
        );
      });

      test('phone renders a plain copy chip regardless of the number', () {
        expect(formatter.phone('99887766', '99887766'), '`99887766`');
        expect(formatter.phone('99887766', ''), '`99887766`');
      });

      test('address renders a plain copy chip', () {
        expect(formatter.address('Meiselen 14'), '`Meiselen 14`');
      });

      test('empty values render empty (briefCopyChip parity)', () {
        expect(formatter.position('', null), '');
        expect(formatter.phone('', ''), '');
        expect(formatter.address(''), '');
      });
    });

    group('ActionChipFormatter', () {
      const formatter = ActionChipFormatter();

      test('position with a coordinate encodes a ringdrill://chip map link', () {
        expect(
          formatter.position('32V 601234 6643210', latLng),
          '[32V 601234 6643210]'
          '(ringdrill://chip?action=map&lat=58.99&lng=10.43)',
        );
      });

      test('position without a coordinate degrades to a copy chip', () {
        expect(
          formatter.position('32V 601234 6643210', null),
          '`32V 601234 6643210`',
        );
      });

      test('phone with a number encodes a ringdrill://chip call link', () {
        expect(
          formatter.phone('99887766', '99887766'),
          '[99887766](ringdrill://chip?action=call&tel=99887766)',
        );
      });

      test('phone with an empty number degrades to a copy chip', () {
        expect(formatter.phone('99887766', ''), '`99887766`');
      });

      test('address always renders a plain copy chip', () {
        expect(formatter.address('Meiselen 14'), '`Meiselen 14`');
      });
    });

    test('resolveField with the default formatter renders station.loc facets '
        'byte-identical to the pre-ChipFormatter output', () {
      const location = Location(
        slug: 'lkp',
        place: 'Fjellheisen',
        position: latLng,
      );
      final station = Station(
        index: 0,
        name: 'Post 1',
        locations: const [location],
      );
      final expectedUtm = formatUtm(latLng);

      final result = resolveField(
        'Sted: {{station.loc.lkp}}',
        vars: const {},
        l10n: _l10n,
        scenarioStation: station,
      );

      expect(result, 'Sted: `Fjellheisen` `($expectedUtm)`');
    });

    test('resolveField with ActionChipFormatter renders station.loc facets as '
        'ringdrill://chip map links', () {
      const location = Location(
        slug: 'lkp',
        place: 'Fjellheisen',
        position: latLng,
      );
      final station = Station(
        index: 0,
        name: 'Post 1',
        locations: const [location],
      );
      final expectedUtm = formatUtm(latLng);

      final result = resolveField(
        'Sted: {{station.loc.lkp.position}}',
        vars: const {},
        l10n: _l10n,
        scenarioStation: station,
        chips: const ActionChipFormatter(),
      );

      expect(
        result,
        'Sted: [$expectedUtm]'
        '(ringdrill://chip?action=map&lat=${latLng.latitude}'
        '&lng=${latLng.longitude})',
      );
    });
  });
}
