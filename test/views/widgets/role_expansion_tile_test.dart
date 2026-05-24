import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/views/widgets/role_expansion_tile.dart';

Widget _buildTile({
  required bool expanded,
  required VoidCallback onOpen,
  required VoidCallback onToggle,
  Widget? trailing,
}) {
  return MaterialApp(
    home: Scaffold(
      body: RoleExpansionTile(
        leading: const RoleCodeBadge(code: '1.1'),
        title: const Text('Anna Hansen'),
        subtitle: const Text('Øvelse 1'),
        trailing: trailing,
        body: const Text('body content'),
        expanded: expanded,
        onOpen: onOpen,
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
    await tester.pump(RoleExpansionTile.animationDuration);
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
    // Tap the title area (InkWell)
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
    // Tap the chevron (IconButton)
    await tester.tap(find.byType(IconButton));
    await tester.pump();
    expect(toggleCount, 1);
    expect(openCount, 0);
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
}
