import 'package:flutter/material.dart';

enum WindowSizeClass implements Comparable<WindowSizeClass> {
  compact,
  medium,
  expanded;

  static WindowSizeClass of(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= 840) return WindowSizeClass.expanded;
    if (w >= 600) return WindowSizeClass.medium;
    return WindowSizeClass.compact;
  }

  bool get hasRail => index >= WindowSizeClass.medium.index;
  bool get hasMasterDetail => index >= WindowSizeClass.medium.index;

  @override
  int compareTo(WindowSizeClass other) => index.compareTo(other.index);
}
