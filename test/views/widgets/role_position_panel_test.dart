import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/views/widgets/position_card.dart';
import 'package:ringdrill/views/widgets/role_mini_map.dart';
import 'package:ringdrill/views/widgets/position_empty_state.dart';
import 'package:ringdrill/views/widgets/station_position_panel.dart';
import 'package:ringdrill/views/widgets/role_position_panel.dart';

/// docs/prompts/position-panel-read-alignment.md — RolePositionPanel on the
/// shared PositionCardShell, mirroring StationPositionPanel's card shape.
void main() {
  Exercise exercise() => Exercise(
    uuid: 'ex-1',
    name: 'Exercise',
    startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
    endTime: const SimpleTimeOfDay(hour: 9, minute: 0),
    numberOfTeams: 1,
    numberOfRounds: 1,
    executionTime: 10,
    evaluationTime: 5,
    rotationTime: 5,
    stations: const [],
    schedule: const [],
  );

  RolePlay rolePlay() => const RolePlay(
    uuid: 'rp-1',
    index: 0,
    exerciseUuid: 'ex-1',
    name: 'Hilde',
    position: LatLng(58.99, 10.43),
  );

  Widget harness() => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: RolePositionPanel(exercise: exercise(), rolePlay: rolePlay()),
    ),
  );

  testWidgets(
    'renders the shared card shell with the UTM coordinate, and tapping '
    'the thumbnail opens the interactive map sheet titled with the role',
    (tester) async {
      await tester.pumpWidget(harness());

      expect(find.byType(PositionCardShell), findsOneWidget);
      // No default chevron_right (dropped from PositionCardShell's bar);
      // RolePositionPanel has no onTap to forward, so the bar itself is a
      // no-op — only the RoleMiniMap thumbnail's own tap opens the sheet.
      expect(find.byIcon(Icons.chevron_right), findsNothing);

      expect(find.byType(BottomSheet), findsNothing);
      await tester.tap(find.byType(RoleMiniMap));
      await tester.pumpAndSettle();

      // The default (non-fillHeight) 200px map height is below
      // MapConfig.minInteractiveHeight, so RoleMiniMap stays a static
      // tap-to-expand preview even at this (medium) test width —
      // flutter_test's default ~800x600 MediaQuery reads as
      // WindowSizeClass.medium (hasMasterDetail), but there isn't room
      // here for the interactive command stack. openRoleMapSheet is
      // reachable only from that static preview now, so it always opens a
      // bottom sheet (see the "fillHeight + wide window" test below for
      // the genuinely interactive, wide-and-tall case).
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Hilde'), findsWidgets);

      // The header mirrors RolePlayScreen's own AppBar exactly:
      // MasterDetailLeading always renders a close-X in `leading` (there is
      // no MasterDetailScope reachable from a sheet's Overlay, so it never
      // shows the sidebar-toggle branch instead).
      expect(find.byIcon(Icons.close), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
    },
  );

  testWidgets(
    'interactive: true renders a directly interactive map with its own FAB '
    'stack (no tap needed), whose built-in expand command opens a genuine '
    'full-screen route — not a dialog, not a bottom sheet',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            // interactive is decoupled from fillHeight now — pass it
            // explicitly; fillHeight here just gives the map room to fill.
            body: RolePositionPanel(
              exercise: exercise(),
              rolePlay: rolePlay(),
              fillHeight: true,
              interactive: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Directly interactive — the GestureDetector+IgnorePointer wrapper
      // from the static path is gone; the FAB stack is already on screen,
      // no tap needed to reach it.
      expect(find.byIcon(Icons.center_focus_strong_rounded), findsOneWidget);
      expect(find.byIcon(Icons.open_in_full), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);

      await tester.tap(find.byIcon(Icons.open_in_full));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.text('Hilde'), findsWidgets);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.close), findsNothing);
    },
  );

  testWidgets(
    'compact width opens the map as a bottom sheet, header still has the '
    'same close-X as the dialog',
    (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness());

      await tester.tap(find.byType(RoleMiniMap));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
    },
  );

  testWidgets(
    'asCard defaults to false (no nested Card when already inside one, e.g. '
    'an ExpandableTile body) and opts into its own Card when set',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Card(
              child: RolePositionPanel(
                exercise: exercise(),
                rolePlay: rolePlay(),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(Card), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: RolePositionPanel(
              exercise: exercise(),
              rolePlay: rolePlay(),
              asCard: true,
            ),
          ),
        ),
      );
      expect(find.byType(Card), findsOneWidget);
    },
  );

  testWidgets('with no central position, the row is the default', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: RolePositionPanel(
            exercise: exercise(),
            rolePlay: const RolePlay(
              uuid: 'rp-1',
              index: 0,
              exerciseUuid: 'ex-1',
              name: 'Hilde',
            ),
          ),
        ),
      ),
    );

    final l = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l.positionNotSet), findsOneWidget);
    expect(find.byType(PositionEmptyState), findsNothing);
  });

  testWidgets('the card style teaches it, naming both routes out', (
    tester,
  ) async {
    // roleCentralPosition is null only when neither the markør nor its station has
    // a position, so the body must not imply the markør alone is at fault.
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: RolePositionPanel(
            exercise: exercise(),
            rolePlay: const RolePlay(
              uuid: 'rp-1',
              index: 0,
              exerciseUuid: 'ex-1',
              name: 'Hilde',
            ),
            emptyStyle: PositionEmptyStyle.card,
          ),
        ),
      ),
    );

    final l = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.byType(PositionCardShell), findsOneWidget);
    expect(find.text(l.noPositionTitle), findsOneWidget);
    expect(find.text(l.noPositionRolePlayBody), findsOneWidget);
    expect(find.byIcon(Icons.mood), findsOneWidget);
    expect(find.text(l.positionNotSet), findsOneWidget);
  });
}
