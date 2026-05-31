import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/views/widgets/expandable_tile.dart';
import 'package:ringdrill/views/widgets/role_code_badge.dart';

Widget _buildTile({
  required bool expanded,
  VoidCallback? onOpen,
  VoidCallback? onLongPress,
  VoidCallback? onToggle,
  Widget? trailing,
  Widget? body = const Text('body content'),
}) {
  return MaterialApp(
    home: Scaffold(
      body: ExpandableTile(
        leading: const RoleCodeBadge(code: '1.1'),
        title: const Text('Anna Hansen'),
        subtitle: const Text('Øvelse 1'),
        trailing: trailing,
        body: body,
        expanded: expanded,
        onOpen: onOpen,
        onLongPress: onLongPress,
        onToggle: onToggle,
      ),
    ),
  );
}

void main() {
  testWidgets('collapsed tile does not show body', (tester) async {
    await tester.pumpWidget(
      _buildTile(expanded: false, onOpen: () {}, onToggle: () {}),
    );
    // When collapsed, the body widget is not rendered at all (AnimatedSize
    // switches to an empty SizedBox instead of the Padding+body branch).
    expect(find.text('body content'), findsNothing);
    expect(find.text('Anna Hansen'), findsOneWidget);
  });

  testWidgets('expanded tile shows body content', (tester) async {
    await tester.pumpWidget(
      _buildTile(expanded: true, onOpen: () {}, onToggle: () {}),
    );
    await tester.pump(ExpandableTile.animationDuration);
    // Body is wrapped in Padding when expanded
    expect(find.text('body content'), findsOneWidget);
    expect(find.byType(Padding), findsWidgets);
  });

  testWidgets('tapping body fires onOpen', (tester) async {
    var openCount = 0;
    var toggleCount = 0;
    await tester.pumpWidget(
      _buildTile(
        expanded: false,
        onOpen: () => openCount++,
        onToggle: () => toggleCount++,
      ),
    );
    // Tap the title area. The outer InkWell catches the tap and fires
    // onOpen; onToggle stays untouched because the chevron's
    // IconButton sits in a separate hit region.
    await tester.tap(find.text('Anna Hansen'));
    await tester.pump();
    expect(openCount, 1);
    expect(toggleCount, 0);
  });

  testWidgets('tapping chevron fires onToggle only', (tester) async {
    var openCount = 0;
    var toggleCount = 0;
    await tester.pumpWidget(
      _buildTile(
        expanded: false,
        onOpen: () => openCount++,
        onToggle: () => toggleCount++,
      ),
    );
    // Tap the chevron. IconButton has its own InkResponse that absorbs
    // the gesture, so the outer row-level InkWell does not also fire.
    await tester.tap(find.byType(IconButton));
    await tester.pump();
    expect(toggleCount, 1);
    expect(openCount, 0);
  });

  testWidgets('long-pressing row fires onLongPress only', (tester) async {
    var openCount = 0;
    var longPressCount = 0;
    var toggleCount = 0;
    await tester.pumpWidget(
      _buildTile(
        expanded: false,
        onOpen: () => openCount++,
        onLongPress: () => longPressCount++,
        onToggle: () => toggleCount++,
      ),
    );
    await tester.longPress(find.text('Anna Hansen'));
    await tester.pump();
    expect(longPressCount, 1);
    expect(openCount, 0);
    expect(toggleCount, 0);
  });

  testWidgets('trailing slot renders when provided', (tester) async {
    await tester.pumpWidget(
      _buildTile(
        expanded: false,
        onOpen: () {},
        onToggle: () {},
        trailing: const Icon(Icons.person_add, key: Key('cast-chip')),
      ),
    );
    expect(find.byKey(const Key('cast-chip')), findsOneWidget);
  });

  testWidgets('row tap toggles when onOpen is null', (tester) async {
    var toggleCount = 0;
    await tester.pumpWidget(
      _buildTile(expanded: false, onOpen: null, onToggle: () => toggleCount++),
    );
    // With onOpen null, tapping the row falls through to onToggle.
    await tester.tap(find.text('Anna Hansen'));
    await tester.pump();
    expect(toggleCount, 1);
  });

  testWidgets('chevron is hidden when body is null', (tester) async {
    await tester.pumpWidget(
      _buildTile(expanded: false, onOpen: () {}, onToggle: () {}, body: null),
    );
    // No body means no expand affordance, regardless of onToggle.
    expect(find.byType(IconButton), findsNothing);
  });
}
