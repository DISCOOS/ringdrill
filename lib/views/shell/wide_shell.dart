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
    this.masterCollapsed = false,
    this.onToggleMaster,
  });

  final BoxConstraints constraints;
  final PageWidget<ScreenController> page;
  final WindowSizeClass windowSizeClass;
  final int currentTab;
  final GlobalKey<ScaffoldState> scaffoldKey;
  final List<Destination> destinations;
  final ValueChanged<int> onDestinationSelected;

  /// Whether the master (list) pane is collapsed, leaving the detail pane to
  /// fill the width. Ignored on the Map tab, which has no master/detail
  /// split to begin with.
  final bool masterCollapsed;

  /// Flips [masterCollapsed]. Forwarded into [MasterDetailScope] so the
  /// detail's leading (`MasterDetailLeading`) can reach it. Null only when
  /// the host has no collapse concept to offer (defensive — the wide shell
  /// itself always supplies one outside the Map tab).
  final VoidCallback? onToggleMaster;

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
        // Narrower than the M3 default (80). The rail shows icons only
        // (labelType none), so 72 is ample and keeps the left side compact;
        // `railWidth` above matches this so the column reserves exactly the
        // rail's width in both states.
        minWidth: 72,
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
    // Matches the NavigationRail's explicit `minWidth: 72` below, so the rail
    // column reserves exactly the rail's width in both the expanded and the
    // collapsed (clipped) state — narrower than the M3 default 80. Plus the
    // extra left inset `wrapInRailPadding` adds on iOS landscape: without it
    // the padded rail is 12px wider than reserved and the rail+master Row
    // overflows its parent SizedBox by that 12px (a landscape iPhone).
    final railWidth = 72.0 + railLeadingInset(context);
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

    // Rail + master pane, painted with the master-accent tone so the
    // selected rail indicator pill, the master AppBar and the master body
    // all share a single colour and read as one connected "active
    // section". The detail pane keeps the scaffold background. Cards
    // inside the master list use `*Surface` which stays distinct against
    // the accent. Only built (and only occupies width) when the master
    // pane is not collapsed.
    // The master column content (without the rail) — extracted so it can
    // be kept mounted across collapse toggles. tabs lives here and must
    // never be disposed by a toggle.
    //
    // In dark + rail, override `cardTheme.color` to `brandDeep` so cards
    // in the master list sit one tone darker than `masterAccentDark` and
    // clearly pop out as content tiles. Without this override cards default
    // to `darkSurface` which is nearly the same lightness as the master
    // accent. The narrow (no-rail) layout keeps the default `darkSurface`
    // cards on the `brandDeep` scaffold.
    final masterColumnContent = ColoredBox(
      color: masterAccent,
      child: Theme(
        data: isDark
            ? Theme.of(context).copyWith(
                cardTheme: Theme.of(
                  context,
                ).cardTheme.copyWith(color: RingDrillColors.brandDeep),
              )
            : Theme.of(context),
        child: Column(
          children: [
            masterAppBar,
            // Stack so the active tab's FAB (only the exercises tab has
            // one) floats at the bottom-right of the master pane, above
            // the docked mini player which sits below this region in the
            // outer Column.
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(child: tabs),
                  if (fab != null)
                    Positioned(right: 16, bottom: 16, child: fab),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final miniPlayer = DockedDrillMiniPlayer(
      controller: contextSheetController,
      openDrillPlayer: drillPlayer.openDrillPlayer,
    );

    // Keep the master column (and thus `tabs`) mounted at the same tree
    // position regardless of collapse state. Collapsing clips the master
    // column to zero width via ClipRect + SizedBox(width: 0) while the
    // OverflowBox keeps the content laid out at masterWidth so the segment
    // pages are not reflowed or re-initialised.
    //
    // Mini-player placement preserves today's behaviour:
    //   expanded → docked under the rail+master region only
    //   collapsed → spans the full shell width (sibling of the main row)
    // The mini-player rebuilds on toggle; tabs does not.
    final body = Column(
      children: [
        Expanded(
          child: Row(
            children: [
              // Explicitly sized so its inner Row widgets get bounded width
              // constraints regardless of collapse state.
              SizedBox(
                width: masterCollapsed ? railWidth : railWidth + masterWidth,
                child: Column(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          rail,
                          // Always mounted; width collapses to 0 when hidden.
                          ClipRect(
                            child: SizedBox(
                              width: masterCollapsed ? 0.0 : masterWidth,
                              child: OverflowBox(
                                alignment: Alignment.topLeft,
                                maxWidth: masterWidth,
                                child: SizedBox(
                                  width: masterWidth,
                                  child: masterColumnContent,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!masterCollapsed) miniPlayer,
                  ],
                ),
              ),
              const Expanded(child: MasterDetailPane()),
            ],
          ),
        ),
        if (masterCollapsed) miniPlayer,
      ],
    );

    return Column(
      children: [
        const MigrationBanner(),
        Expanded(
          child: MasterDetailScope(
            target: contextSheetController.targetNotifier,
            emptyPaneBuilder: emptyPaneBuilder,
            onToggleMaster: onToggleMaster,
            child: body,
          ),
        ),
      ],
    );
  }
}
