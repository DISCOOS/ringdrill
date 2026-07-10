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
        'Sted: {{station.loc.lkp.place}}, UTM: {{station.loc.lkp.utm}}',
        vars: const {},
        l10n: _l10n,
        scenarioStation: station,
      );

      expect(result, 'Sted: Fjellheisen, UTM: `$expectedUtm`');
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
}
