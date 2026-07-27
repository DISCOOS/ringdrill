import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/utils/app_config.dart';
import 'package:ringdrill/utils/ui_prefs.dart';
import 'package:ringdrill/views/widgets/collapsible_section_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A section stored *collapsed* must be collapsed on its very first paint.
///
/// It used to read the preference with an awaited `SharedPreferences
/// .getInstance()` from `initState`, which lands a frame late: the card painted
/// expanded and then snapped shut. Only `getInstance()` is asynchronous — the
/// getters read an in-memory map — so binding the instance once in `main`
/// (`UiPrefs`) makes the read synchronous and the first frame correct.
const _sectionId = 'sync-load-section';

Widget _harness() => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: const Scaffold(
    body: CollapsibleSectionCard(
      sectionId: _sectionId,
      icon: Icons.info,
      title: 'Section',
      body: Text('section body'),
    ),
  ),
);

/// The clipped height of the card's reveal transition. Zero means collapsed;
/// the body stays in the tree so it can slide, so "hidden" is a height of 0,
/// not an absent widget.
double _revealHeight(WidgetTester tester) {
  final body = find.text('section body');
  expect(body, findsOneWidget);
  return tester
      .widgetList<SizeTransition>(
        find.ancestor(of: body, matching: find.byType(SizeTransition)),
      )
      .first
      .sizeFactor
      .value;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      AppConfig.collapsibleSectionKey(_sectionId): true,
    });
    // Each test decides whether an instance is bound; a binding left over from
    // a previous test would serve that test's values.
    UiPrefs.reset();
    addTearDown(UiPrefs.reset);
  });

  testWidgets('bound prefs: collapsed on the first frame, with no flicker', (
    tester,
  ) async {
    UiPrefs.bind(await SharedPreferences.getInstance());

    await tester.pumpWidget(_harness());
    // Exactly one frame — no settle, no timer drain. This is the frame the user
    // sees first, and it must already be collapsed.
    expect(
      _revealHeight(tester),
      0,
      reason: 'the stored collapsed state must not arrive a frame late',
    );

    // And it stays put rather than animating open and shut again.
    await tester.pumpAndSettle();
    expect(_revealHeight(tester), 0);
  });

  testWidgets('unbound prefs: the preference is still restored', (
    tester,
  ) async {
    // A widget test (or any entry point that skips main) binds nothing. The
    // preference must not be lost — it falls back to the awaited read.
    //
    // Deliberately no first-frame assertion here: the mock SharedPreferences
    // resolves inside the same frame, so this path looks instant in a test and
    // only lags against a real platform channel. That is exactly why the
    // flicker was invisible to the suite and obvious in the app — which is what
    // the bound-prefs case above pins down instead.
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(_revealHeight(tester), 0);
  });

  testWidgets('nothing stored: expanded on the first frame', (tester) async {
    SharedPreferences.setMockInitialValues({});
    UiPrefs.bind(await SharedPreferences.getInstance());

    await tester.pumpWidget(_harness());

    expect(_revealHeight(tester), 1);
  });
}
