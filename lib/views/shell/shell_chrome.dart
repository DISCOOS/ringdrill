// Small chrome helpers shared by the narrow Scaffold AppBar (built in
// MainScreen) and the wide-layout master AppBar + NavigationRail (built
// in [WideShell]). Kept as top-level functions so both files can read
// them without bouncing through the host state object.

import 'package:flutter/material.dart';
import 'package:ringdrill/theme.dart';

/// Bare icon + label pair used to drive both the wide-layout
/// [NavigationRail] and the narrow-layout [NavigationBar] from one list,
/// so each layout doesn't independently spell out the shell's tab set.
class Destination {
  const Destination({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

/// Panel tone for the NavigationRail body in the wide layout. The rail
/// reads as a distinct sidebar surface; the selected tab's indicator
/// pill ([shellMasterAccent]) "extends" into the master pane.
Color shellPanelColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? RingDrillColors.panelDark
      : RingDrillColors.panelLight;
}

/// Active-surface tone shared by the rail selection indicator, the master
/// pane background and the master AppBar. Visually links the selected tab
/// to the master content so the active section reads as one connected
/// block.
Color shellMasterAccent(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? RingDrillColors.masterAccentDark
      : RingDrillColors.masterAccentLight;
}

/// Removes the system safe-area padding on the rail side in iOS
/// landscape so the rail panel paints flush to the screen edge, then
/// re-injects the visual rail tone via a [ColoredBox] so the rail and
/// the master pane line up as one continuous surface. Other platforms /
/// orientations leave the padding intact.
Widget wrapInRailPadding({
  required BuildContext context,
  required Widget child,
  double paddingLeft = 12,
}) {
  final mq = MediaQuery.of(context);
  final isLandscape = mq.orientation == Orientation.landscape;
  final isCupertino = Theme.of(context).platform == TargetPlatform.iOS;

  final removeForRail = isCupertino && isLandscape;
  return MediaQuery.removePadding(
    context: context,
    removeTop: false,
    removeBottom: false,
    removeLeft: removeForRail,
    removeRight: removeForRail,
    child: ColoredBox(
      color: shellPanelColor(context),
      child: Padding(
        padding: removeForRail
            ? EdgeInsets.only(left: paddingLeft)
            : EdgeInsets.zero,
        child: child,
      ),
    ),
  );
}
