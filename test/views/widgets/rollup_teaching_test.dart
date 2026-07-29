import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/widgets/rollup.dart';
import 'package:ringdrill/views/widgets/teaching_empty_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// The description cards' empty states. Two distinct ones, tested here against
// Rollup/RollupCard directly rather than through any one description card, so
// the shared mechanism is covered once:
//
//   * nothing written at all -> the whole body becomes a TeachingEmptyState
//     carrying the caller's per-entity copy.
//   * something written, but a section the surface marked mandatory is still
//     blank -> a compact nudge naming it, *added* under the content rather
//     than replacing it.
//
// "Mandatory" is a claim by the surface, never by the model: every one of
// these fields is optional in its editor, so the nudge informs and never
// blocks. See RollupSection.mandatoryLabel.
// ---------------------------------------------------------------------------

const _teaching = RollupTeaching(
  title: 'Nothing here yet',
  body: 'Describe the method so instructors know what this trains.',
  actionLabel: 'Add description',
);

Widget _harness({
  required List<RollupSection> sections,
  RollupTeaching? teaching = _teaching,
  ValueChanged<String>? onTapSection,
  bool card = true,
}) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: SingleChildScrollView(
      child: card
          ? RollupCard(
              sectionId: 'description',
              icon: Icons.description,
              title: 'Exercise Description',
              sections: sections,
              teaching: teaching,
              onTapSection: onTapSection,
            )
          : Rollup(
              sections: sections,
              teaching: teaching,
              onTapSection: onTapSection,
            ),
    ),
  ),
);

RollupSection _method({String? text}) => RollupSection(
  id: 'method',
  label: 'Method',
  mandatoryLabel: 'Method',
  text: text,
);

RollupSection _comms({String? text}) =>
    RollupSection(id: 'comms', label: 'Comms', text: text);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('nothing written at all', () {
    testWidgets('the body becomes the teaching empty state', (tester) async {
      await tester.pumpWidget(
        _harness(sections: [_method(), _comms()], onTapSection: (_) {}),
      );

      expect(find.byType(TeachingEmptyState), findsOneWidget);
      expect(find.text('Nothing here yet'), findsOneWidget);
      expect(find.text(_teaching.body), findsOneWidget);
      // The partial-content nudge belongs to the *other* empty state: with
      // nothing written the teaching copy already says so, and both at once
      // would say it twice.
      expect(find.textContaining('Missing:'), findsNothing);
    });

    testWidgets('the action opens the editor at the mandatory section', (
      tester,
    ) async {
      final tapped = <String>[];
      await tester.pumpWidget(
        _harness(
          // `comms` comes first deliberately: the action must follow the
          // mandatory mark, not document order.
          sections: [_comms(), _method()],
          onTapSection: tapped.add,
        ),
      );

      await tester.tap(find.text('Add description'));
      expect(tapped, ['method']);
    });

    testWidgets('a read-only surface keeps the copy but drops the action', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(sections: [_method(), _comms()]));

      expect(find.text('Nothing here yet'), findsOneWidget);
      expect(find.text('Add description'), findsNothing);
    });

    testWidgets('no teaching copy keeps the old bare behaviour', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(sections: [_method(), _comms()], teaching: null),
      );

      expect(find.byType(TeachingEmptyState), findsNothing);
    });

    testWidgets('a bare Rollup takes no space without teaching copy', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(sections: [_method(), _comms()], teaching: null, card: false),
      );

      expect(tester.getSize(find.byType(Rollup)).height, 0);
    });
  });

  group('a mandatory section is blank but others are filled', () {
    testWidgets('the nudge names it and the content stays', (tester) async {
      await tester.pumpWidget(
        _harness(
          sections: [
            _method(),
            _comms(text: 'Channel 5'),
          ],
          onTapSection: (_) {},
        ),
      );

      // Additive, not a swap: the author's own content is still there.
      expect(find.text('Channel 5'), findsOneWidget);
      expect(find.byType(TeachingEmptyState), findsNothing);
      expect(find.text('Missing: Method'), findsOneWidget);
    });

    testWidgets('the nudge action opens the editor at that section', (
      tester,
    ) async {
      final tapped = <String>[];
      await tester.pumpWidget(
        _harness(
          sections: [
            _method(),
            _comms(text: 'Channel 5'),
          ],
          onTapSection: tapped.add,
        ),
      );

      await tester.tap(find.text('Add'));
      expect(tapped, ['method']);
    });

    testWidgets('a read-only surface shows the nudge without its action', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          sections: [
            _method(),
            _comms(text: 'Channel 5'),
          ],
        ),
      );

      expect(find.text('Missing: Method'), findsOneWidget);
      expect(find.text('Add'), findsNothing);
    });

    testWidgets('several missing sections are listed in section order', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          sections: [
            _method(),
            const RollupSection(
              id: 'comms',
              label: 'Comms',
              mandatoryLabel: 'Comms',
              text: null,
            ),
            _comms(text: 'anything, so the card is not empty'),
          ],
          onTapSection: (_) {},
        ),
      );

      expect(find.text('Missing: Method, Comms'), findsOneWidget);
    });

    testWidgets('a filled mandatory section produces no nudge', (tester) async {
      await tester.pumpWidget(
        _harness(
          sections: [
            _method(text: 'Ring drill'),
            _comms(text: 'Channel 5'),
          ],
          onTapSection: (_) {},
        ),
      );

      expect(find.textContaining('Missing:'), findsNothing);
    });

    testWidgets('an unmarked blank section is silently omitted, as before', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          sections: [
            _method(text: 'Ring drill'),
            _comms(),
          ],
          onTapSection: (_) {},
        ),
      );

      expect(find.text('Comms'), findsNothing);
      expect(find.textContaining('Missing:'), findsNothing);
    });
  });
}
