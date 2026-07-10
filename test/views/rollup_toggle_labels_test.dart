import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations_en.dart';
import 'package:ringdrill/l10n/app_localizations_nb.dart';

/// DESIGN-010 prompt 2b fix 3 — the rollup toggle and the per-section eye
/// are two distinct affordances and must not share wording: "forhåndsvisning"
/// is reserved for the eye (a field-level concern), the rollup (a whole
/// post/marker's read-only slice) reads "detaljer" instead.
void main() {
  test(
    'nb: the rollup toggle reads Vis/Skjul detaljer, not forhåndsvisning',
    () {
      final l = AppLocalizationsNb();
      expect(l.rollupShowAction, 'Vis detaljer');
      expect(l.rollupHideAction, 'Skjul detaljer');
      expect(l.rollupShowAction, isNot(contains('forhåndsvisning')));
      expect(l.rollupHideAction, isNot(contains('forhåndsvisning')));
    },
  );

  test('en: the rollup toggle reads Show/Hide details', () {
    final l = AppLocalizationsEn();
    expect(l.rollupShowAction, 'Show details');
    expect(l.rollupHideAction, 'Hide details');
  });

  test('the per-section eye labels are unchanged (Forhåndsvis/Rediger)', () {
    final nb = AppLocalizationsNb();
    expect(nb.formSectionPreviewAction, 'Forhåndsvis');
    expect(nb.formSectionEditAction, 'Rediger');
  });
}
