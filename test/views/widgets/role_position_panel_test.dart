import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/widgets/position_card.dart';
import 'package:ringdrill/views/widgets/role_mini_map.dart';
import 'package:ringdrill/views/widgets/role_position_panel.dart';

/// docs/prompts/position-panel-read-alignment.md — RolePositionPanel on the
/// shared PositionCardShell, mirroring StationPositionPanel's card shape.
void main() {
  testWidgets(
    'renders the shared card shell with the UTM coordinate, and tapping '
    'the thumbnail opens the interactive map sheet titled with the role',
    (tester) async {
      const position = LatLng(58.99, 10.43);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: RolePositionPanel(position: position, label: 'Hilde'),
          ),
        ),
      );

      expect(find.byType(PositionCardShell), findsOneWidget);
      // No default chevron_right (dropped from PositionCardShell's bar);
      // RolePositionPanel has no onTap to forward, so the bar itself is a
      // no-op — only the RoleMiniMap thumbnail's own tap opens the sheet.
      expect(find.byIcon(Icons.chevron_right), findsNothing);

      expect(find.byType(BottomSheet), findsNothing);
      await tester.tap(find.byType(RoleMiniMap));
      await tester.pumpAndSettle();

      // openRoleMapSheet opens the interactive map in a modal sheet.
      expect(find.byType(BottomSheet), findsOneWidget);
    },
  );

  testWidgets(
    'asCard defaults to false (no nested Card when already inside one, e.g. '
    'an ExpandableTile body) and opts into its own Card when set',
    (tester) async {
      const position = LatLng(58.99, 10.43);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: Card(
              child: RolePositionPanel(position: position, label: 'Hilde'),
            ),
          ),
        ),
      );
      expect(find.byType(Card), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: RolePositionPanel(
              position: position,
              label: 'Hilde',
              asCard: true,
            ),
          ),
        ),
      );
      expect(find.byType(Card), findsOneWidget);
    },
  );
}
