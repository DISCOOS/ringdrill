import 'package:flutter/material.dart';
import 'package:ringdrill/theme.dart';
import 'package:ringdrill/views/drill_player/docked_drill_mini_player.dart';
import 'package:ringdrill/views/drill_player/drill_player_coordinator.dart';
import 'package:ringdrill/views/page_widget.dart';
import 'package:ringdrill/views/shell/master_detail_scope.dart';
import 'package:ringdrill/views/shell/migration_banner.dart';
import 'package:ringdrill/views/shell/shell_chrome.dart';
import 'package:ringdrill/views/shell/window_size_class.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';

/// Wide/master-detail layout shell. Renders the [NavigationRail], the
/// master pane (AppBar + tabs + FAB anchored to the master bottom-right),
/// the docked [DockedDrillMiniPlayer], and the detail pane via
/// [MasterDetailScope] + [MasterDetailPane].
///
/// The Map tab (`currentTab == 1`) is a special case: it has no
/// master/detail split, just `rail + tabs` so the map fills the width.
class WideShell extends StatelessWidget {
  const WideShell({
    super.key,
    required this.constraints,
    required this.page,
    required this.windowSizeClass,
    required this.currentTab,
    required this.scaffoldKey,
    required this.destinations,
    required this.onDestinationSelected,
    required this.tabs,
    required this.emptyPaneBuilder,
    required this.masterAppBar,
    required this.contextSheetController,
    required this.drillPlayer,
  });

  final BoxConstraints constraints;
  final PageWidget<ScreenController> page;
  final WindowSizeClass windowSizeClass;
  final int currentTab;
  final GlobalKey<ScaffoldState> scaffoldKey;
  final List<Destination> destinations;
  final ValueChanged<int> onDestinationSelected;

  /// Pre-built IndexedStack of the shell's tab pages. Same instance the
  /// narrow layout would use, so per-tab state is preserved across
  /// layout transitions.
  final Widget tabs;

  /// Builds the empty-state widget for the detail pane when no target
  /// is selected. Forwarded to [MasterDetailScope.emptyPaneBuilder].
  final WidgetBuilder emptyPaneBuilder;

  /// Pre-built master AppBar (with `hasRail: true`). Built by the host
  /// so the same AppBar logic backs both the wide and narrow layouts.
  final PreferredSizeWidget masterAppBar;

  final ContextSheetController contextSheetController;
  final DrillPlayerCoordinator drillPlayer;

  @override
  Widget build(BuildContext context) {
    final fab = page.controller.buildFAB(context, constraints);
    final panelColor = shellPanelColor(context);
    final masterAccent = shellMasterAccent(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Explicit rail icon colours so the selected icon stays legible on
    // the `masterAccent` indicator pill (which is a light eggshell in
    // light mode, where M3's auto-derived `onSecondaryContainer` was
    // landing too close to the indicator background). In dark mode the
    // default white still works.
    final selectedIconColor = isDark
        ? Colors.white
        : RingDrillColors.lightOnSurface;
    final unselectedIconColor = isDark
        ? RingDrillColors.darkOnSurfaceVariant
        : RingDrillColors.lightOnSurfaceVariant;
    final rail = wrapInRailPadding(
      context: context,
      child: NavigationRail(
        // Explicit so the rail body paints with the same tone as the
        // surrounding ColoredBox in `wrapInRailPadding`. The selection
        // indicator picks up `masterAccent` so the selected tab visually
        // extends into the master pane on the right.
        backgroundColor: panelColor,
        indicatorColor: masterAccent,
        selectedIconTheme: IconThemeData(color: selectedIconColor),
        unselectedIconTheme: IconThemeData(color: unselectedIconColor),
        selectedIndex: currentTab,
        onDestinationSelected: onDestinationSelected,
        leading: Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: IconButton(
            // Hamburger doesn't sit on the indicator pill but it lives
            // on the same rail panel, so it uses the unselected tone.
            icon: Icon(Icons.menu, color: unselectedIconColor),
            tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
            onPressed: () => scaffoldKey.currentState?.openDrawer(),
          ),
        ),
        destinations: destinations
            .map<NavigationRailDestination>((d) {
              return NavigationRailDestination(
                icon: Icon(d.icon),
                label: Text(d.label),
                padding: EdgeInsets.symmetric(vertical: 8),
              );
            })
            .toList(),
        // The exercises FAB no longer lives in the rail trailing slot — in
        // the wide layout it floats at the bottom-right of the master pane
        // (see the Stack below). The rail just keeps a little bottom padding.
        trailing: const SizedBox(height: 16),
      ),
    );

    final masterWidth = windowSizeClass == WindowSizeClass.expanded
        ? 420.0
        : 320.0;
    const railWidth = 72.0;
    // The build() gate (`useRail`) guarantees we only reach the rail
    // layout when there is room for a usable detail pane. Narrower
    // widths render the compact narrow layout instead, so there is no
    // longer a "rail without detail" branch here.
    if (currentTab == 1) {
      return Column(
        children: [
          const MigrationBanner(),
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                rail,
                Expanded(child: tabs),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        const MigrationBanner(),
        Expanded(
          child: MasterDetailScope(
      target: contextSheetController.targetNotifier,
      emptyPaneBuilder: emptyPaneBuilder,
      child: Row(
        children: [
          // Left region: navigation rail + master pane stacked above the
          // mini player. The mini player docks at the bottom of this
          // region, spanning under the rail and the master view but NOT
          // the detail pane — the same shape as Spotify's now-playing
          // bar sitting over the left columns while the main view runs
          // full height beside it.
          SizedBox(
            width: railWidth + masterWidth,
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      rail,
                      // Master pane is painted with the master-accent tone
                      // so the selected rail indicator pill, the master
                      // AppBar and the master body all share a single
                      // colour and read as one connected "active section".
                      // The detail pane keeps the scaffold background.
                      // Cards inside the master list use `*Surface` which
                      // stays distinct against the accent.
                      Expanded(
                        child: ColoredBox(
                          color: masterAccent,
                          // In dark + rail, override `cardTheme.color` to
                          // `brandDeep` so cards in the master list sit
                          // one tone darker than `masterAccentDark` and
                          // clearly pop out as content tiles. Without
                          // this override cards default to `darkSurface`
                          // which is nearly the same lightness as the
                          // master accent. The narrow (no-rail) layout
                          // keeps the default `darkSurface` cards on the
                          // `brandDeep` scaffold.
                          child: Theme(
                            data: isDark
                                ? Theme.of(context).copyWith(
                                    cardTheme: Theme.of(context).cardTheme
                                        .copyWith(
                                          color: RingDrillColors.brandDeep,
                                        ),
                                  )
                                : Theme.of(context),
                            child: Column(
                              children: [
                                masterAppBar,
                                // Stack so the active tab's FAB (only the
                                // exercises tab has one) floats at the
                                // bottom-right of the master pane, above
                                // the docked mini player which sits below
                                // this region in the outer Column.
                                Expanded(
                                  child: Stack(
                                    children: [
                                      Positioned.fill(child: tabs),
                                      if (fab != null)
                                        Positioned(
                                          right: 16,
                                          bottom: 16,
                                          child: fab,
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Mini player spans the left region (rail + master) and
                // is pinned to the bottom. It deliberately does not
                // extend into the detail pane.
                DockedDrillMiniPlayer(
                  controller: contextSheetController,
                  openDrillPlayer: drillPlayer.openDrillPlayer,
                ),
              ],
            ),
          ),
          const Expanded(child: MasterDetailPane()),
        ],
      ),
        ),
      ),
      ],
    );
  }
}
