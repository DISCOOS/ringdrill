import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/staff.dart';
import 'package:ringdrill/views/widgets/app_user_role_selector.dart';
import 'package:ringdrill/views/widgets/staff_role_filter.dart';

/// The filter must stay one row at any width, with every label readable.
///
/// Three attempts got here. `SegmentedButton` equalises every segment to the widest,
/// so four Norwegian role names wrapped mid-word on a phone ("Veilede / r"); dropping
/// icons and shrinking the text then clipped the leading "Ø" against the rounded end.
/// Sizing each segment to *its own* text removes the problem instead of mitigating
/// it, which needs [ToggleButtons] — the Material control that sizes children to
/// their content.
///
/// The widths here are deliberately far from the crossovers. Widget tests render in
/// a placeholder font whose glyphs are much wider than the real one, so the exact
/// thresholds differ between test and app; pinning them would assert the test font
/// rather than the behaviour.
/// Sizes the test *view* as well as the box: the default surface is 800px wide, so a
/// wider SizedBox is silently clamped to it — which made an earlier version of these
/// tests measure a width the widget never actually received.
Future<void> _pump(
  WidgetTester tester, {
  required double width,
  Set<StaffRole> selected = const {},
  ValueChanged<Set<StaffRole>>? onChanged,
}) async {
  tester.view.physicalSize = Size(width + 200, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    _harness(width: width, selected: selected, onChanged: onChanged),
  );
  await tester.pumpAndSettle();
}

Widget _harness({
  required double width,
  Set<StaffRole> selected = const {},
  ValueChanged<Set<StaffRole>>? onChanged,
}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('nb'),
  home: Scaffold(
    body: Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: width,
        child: StaffRoleFilter(
          selected: selected,
          onChanged: onChanged ?? (_) {},
        ),
      ),
    ),
  ),
);

/// Read off the built segments rather than the rendered tree: this asserts the
/// *decision* the widget made, which is what the tiering is, and does not depend on
/// how SegmentedButton happens to nest its icon internally.
bool _hasIcons(WidgetTester tester) =>
    find
        .descendant(of: find.byType(ToggleButtons), matching: find.byType(Icon))
        .evaluate()
        .length ==
    StaffRole.values.length;

void main() {
  // The invariant that matters: one segmented row, never a wrap and never an
  // overflow, whatever width it is handed.
  testWidgets('stays a single segmented row at every width', (tester) async {
    for (final width in [1200.0, 900.0, 700.0, 430.0, 390.0, 300.0, 200.0]) {
      await _pump(tester, width: width);

      expect(
        find.byType(ToggleButtons),
        findsOneWidget,
        reason: 'width $width',
      );
      expect(
        tester.takeException(),
        isNull,
        reason: 'overflow at width $width',
      );
    }
  });

  testWidgets(
    'shows icons when there is room and drops them when there is not',
    (tester) async {
      // Comfortably past the icon threshold even in the wide placeholder font.
      await _pump(tester, width: 1200);
      expect(_hasIcons(tester), isTrue);

      await _pump(tester, width: 500);
      expect(
        _hasIcons(tester),
        isFalse,
        reason: 'the icon is the first thing given up for the label',
      );
    },
  );

  // Every role stays reachable: the adaptation may shrink or clip a name, but it
  // must never drop a segment.
  testWidgets('keeps all four segments at a narrow width', (tester) async {
    await _pump(tester, width: 300);

    final l10n = await AppLocalizations.delegate.load(const Locale('nb'));
    for (final role in StaffRole.values) {
      expect(
        find.text(staffRoleLabel(role, l10n)),
        findsOneWidget,
        reason: 'no role may lose its name to the narrow layout',
      );
    }
  });

  testWidgets('deselecting the last role reports the empty set (no filter)', (
    tester,
  ) async {
    Set<StaffRole>? changed;
    await _pump(
      tester,
      width: 1200,
      selected: const {StaffRole.actor},
      onChanged: (roles) => changed = roles,
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('nb'));

    await tester.tap(find.text(staffRoleLabel(StaffRole.actor, l10n)));
    await tester.pumpAndSettle();

    expect(changed, isEmpty);
  });
}
