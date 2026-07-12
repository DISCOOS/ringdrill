import 'package:flutter/material.dart';

enum WindowSizeClass implements Comparable<WindowSizeClass> {
  compact,
  medium,
  expanded;

  /// Pure width-to-class mapping — no [BuildContext] — so callers that read
  /// a specific pane's width (e.g. a `LayoutBuilder`'s `constraints.maxWidth`
  /// inside a master/detail shell) instead of the whole window can still use
  /// the same thresholds as [of].
  static WindowSizeClass fromWidth(double width) {
    if (width >= 840) return WindowSizeClass.expanded;
    if (width >= 600) return WindowSizeClass.medium;
    return WindowSizeClass.compact;
  }

  static WindowSizeClass of(BuildContext context) =>
      fromWidth(MediaQuery.sizeOf(context).width);

  bool get hasRail => index >= WindowSizeClass.medium.index;
  bool get hasMasterDetail => index >= WindowSizeClass.medium.index;

  @override
  int compareTo(WindowSizeClass other) => index.compareTo(other.index);
}
