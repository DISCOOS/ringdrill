import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/views/widgets/position_empty_state.dart';

/// The teaching empty state for a map slot with no position.
///
/// Three behaviours are worth pinning, because each replaces a way the old empty
/// states got it wrong: the full column in a slot that owns a real map height, a
/// compact caption when the slot is too short to hold it, and an action that is
/// *absent* for a viewer but *disabled with a reason* while an exercise runs. The
/// last distinction is the point — a dead button and no button say different
/// things.
void main() {
  Widget harness(Widget child, {double? height}) => MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 360, height: height, child: child),
      ),
    ),
  );

  testWidgets('renders the full column in a slot with room', (tester) async {
    await tester.pumpWidget(
      harness(
        const PositionEmptyState(
          title: 'Ingen posisjon satt',
          body: 'Posten vises ikke i kartet.',
          actionLabel: 'Sett posisjon',
        ),
        height: 240,
      ),
    );

    expect(find.text('Ingen posisjon satt'), findsOneWidget);
    expect(find.text('Posten vises ikke i kartet.'), findsOneWidget);
    expect(find.text('Sett posisjon'), findsOneWidget);
  });

  testWidgets('long copy keeps its body and action in a fixed slot', (
    tester,
  ) async {
    // The markør body runs three lines where the station's runs two, and the
    // thumbnail slot has a *fixed* height — it does not grow the way the mockup's
    // `min-height` does. A layout tuned to the shorter copy clipped the longer one's
    // button, so the widget measures the copy and drops the icon disc before it
    // drops anything that carries meaning.
    //
    // Asserted as "the text and the action survive", not "the disc is gone at
    // exactly 190 px": which tier a given height selects depends on font metrics,
    // and that is not the behaviour worth pinning.
    await tester.pumpWidget(
      harness(
        const PositionEmptyState(
          title: 'Ingen posisjon satt',
          body:
              'Markøren følger posten, men posten har ingen posisjon. Sett '
              'posisjon på posten, eller gi markøren sin egen.',
          icon: Icons.mood,
          actionLabel: 'Sett egen posisjon',
        ),
        height: 190,
      ),
    );

    expect(find.text('Ingen posisjon satt'), findsOneWidget);
    expect(find.textContaining('Markøren følger posten'), findsOneWidget);
    expect(find.text('Sett egen posisjon'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('falls back to a compact caption in a short slot', (
    tester,
  ) async {
    // The body and the action cannot fit, and overflowing is worse than omitting:
    // the title alone still says what is wrong.
    await tester.pumpWidget(
      harness(
        const PositionEmptyState(
          title: 'Ingen posisjon satt',
          body: 'Posten vises ikke i kartet.',
          actionLabel: 'Sett posisjon',
        ),
        height: 80,
      ),
    );

    expect(find.text('Ingen posisjon satt'), findsOneWidget);
    expect(find.text('Posten vises ikke i kartet.'), findsNothing);
    expect(find.text('Sett posisjon'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a null actionLabel renders no button at all', (tester) async {
    // The viewer variant: the explanation without a dead affordance.
    await tester.pumpWidget(
      harness(
        const PositionEmptyState(
          title: 'Ingen posisjon satt',
          body: 'Posten vises ikke i kartet.',
        ),
        height: 240,
      ),
    );

    expect(find.text('Ingen posisjon satt'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('a null onAction disables the button and explains why', (
    tester,
  ) async {
    // The running-exercise variant: the action exists, just not now.
    await tester.pumpWidget(
      harness(
        const PositionEmptyState(
          title: 'Ingen posisjon satt',
          body: 'Posten vises ikke i kartet.',
          actionLabel: 'Sett posisjon',
          disabledTooltip: 'Stopp øvelsen for å endre posten.',
        ),
        height: 240,
      ),
    );

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull, reason: 'disabled, not hidden');
    expect(find.byTooltip('Stopp øvelsen for å endre posten.'), findsOneWidget);
  });

  testWidgets('an action fires', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      harness(
        PositionEmptyState(
          title: 'Ingen posisjon satt',
          body: 'Posten vises ikke i kartet.',
          actionLabel: 'Sett posisjon',
          onAction: () => tapped++,
        ),
        height: 240,
      ),
    );

    await tester.tap(find.text('Sett posisjon'));
    expect(tapped, 1);
  });
}
