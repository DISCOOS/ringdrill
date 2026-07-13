import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/views/widgets/card_section_header.dart';
import 'package:ringdrill/views/widgets/collapse_chevron.dart';
import 'package:ringdrill/views/widgets/collapsible_section_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// DESIGN-010 follow-up: collapsible-section-cards — the shared
// CollapsibleSectionCard wrapper (ScheduleCard, NarrativeRollupCard, the Post
// viewer's Personer/Lokasjoner cards all build on this). Tests it directly
// rather than through any one call site so they cover the shared mechanism
// once instead of per migrated card.
// ---------------------------------------------------------------------------

Widget _harness(String sectionId, {String title = 'Test Section'}) =>
    MaterialApp(
      home: Scaffold(
        body: CollapsibleSectionCard(
          sectionId: sectionId,
          icon: Icons.info,
          title: title,
          body: const Text('Section body content'),
        ),
      ),
    );

/// The header's own bottom-border decoration, or null if it draws none.
BoxDecoration? headerDecoration(WidgetTester tester) {
  final container = tester.widget<Container>(
    find
        .descendant(
          of: find.byType(CardSectionHeader),
          matching: find.byType(Container),
        )
        .first,
  );
  return container.decoration as BoxDecoration?;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'tapping the header collapses the body and hides it; the header '
    '(title/chevron) stays; tapping again expands',
    (tester) async {
      await tester.pumpWidget(_harness('test-section'));
      await tester.pumpAndSettle();

      expect(find.text('TEST SECTION'), findsOneWidget);
      expect(find.text('Section body content'), findsOneWidget);
      expect(find.byType(CollapseChevron), findsOneWidget);

      await tester.tap(find.text('TEST SECTION'));
      await tester.pumpAndSettle();

      expect(find.text('TEST SECTION'), findsOneWidget);
      expect(find.byType(CollapseChevron), findsOneWidget);
      expect(find.text('Section body content'), findsNothing);

      await tester.tap(find.text('TEST SECTION'));
      await tester.pumpAndSettle();

      expect(find.text('Section body content'), findsOneWidget);
    },
  );

  testWidgets(
    'collapsed state persists through SharedPreferences across a rebuild',
    (tester) async {
      await tester.pumpWidget(_harness('persist-section'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('TEST SECTION'));
      await tester.pumpAndSettle();
      expect(find.text('Section body content'), findsNothing);

      // Simulate a fresh mount (e.g. app restart) reading the same store.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_harness('persist-section'));
      await tester.pumpAndSettle();

      expect(find.text('Section body content'), findsNothing);
    },
  );

  testWidgets(
    'collapse state is keyed per sectionId — collapsing one section does '
    'not collapse another',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                CollapsibleSectionCard(
                  sectionId: 'schedule',
                  icon: Icons.access_time,
                  title: 'Tidsplan',
                  body: const Text('Schedule body'),
                ),
                CollapsibleSectionCard(
                  sectionId: 'persons',
                  icon: Icons.people,
                  title: 'Personer',
                  body: const Text('Persons body'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('TIDSPLAN'));
      await tester.pumpAndSettle();

      expect(find.text('Schedule body'), findsNothing);
      expect(find.text('Persons body'), findsOneWidget);
    },
  );

  testWidgets(
    'a trailing action stays its own tap target and does not also toggle '
    'the collapse state',
    (tester) async {
      var trailingTaps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CollapsibleSectionCard(
              sectionId: 'with-trailing',
              icon: Icons.people,
              title: 'Personer',
              trailing: TextButton(
                onPressed: () => trailingTaps++,
                child: const Text('Legg til'),
              ),
              body: const Text('Section body content'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Legg til'));
      await tester.pumpAndSettle();

      expect(trailingTaps, 1);
      // The trailing action's own tap must not have also toggled collapse.
      expect(find.text('Section body content'), findsOneWidget);
    },
  );

  testWidgets(
    'the header draws its own bottom border while expanded, but none once '
    'collapsed — no dangling divider with nothing left below it',
    (tester) async {
      await tester.pumpWidget(_harness('border-section'));
      await tester.pumpAndSettle();

      expect(headerDecoration(tester)?.border, isNotNull);

      await tester.tap(find.text('TEST SECTION'));
      await tester.pumpAndSettle();

      expect(headerDecoration(tester)?.border, isNull);
    },
  );

  testWidgets(
    'dividedBody suppresses the header\'s own border even while expanded — '
    'the body\'s first row supplies that divider instead, so the two never '
    'double up',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CollapsibleSectionCard(
              sectionId: 'divided-section',
              icon: Icons.people,
              title: 'Test Section',
              dividedBody: true,
              body: const Text('Section body content'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(headerDecoration(tester)?.border, isNull);
    },
  );
}
