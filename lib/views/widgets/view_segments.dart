/// One rule for what a view selector's segments show at a given width.
///
/// Four screens build a `SegmentedButton` to switch between views of the same
/// subject — the coordinator, the station and roleplay viewers, and the plan
/// browser's master pane. Each decided independently whether to draw icons, and
/// they disagreed: three drew icon *and* label and wrapped them in a horizontal
/// scroll view when that overflowed, which does not overflow but hides segments
/// off the edge instead. `PlanView` had already worked out that four icon+label
/// segments cannot fit a narrow pane and dropped one of the two — the right
/// answer, reached in one place only.
///
/// The rule now lives here, so a new selector cannot ship with the old one.
library;

import 'package:flutter/material.dart';
import 'package:ringdrill/views/shell/window_size_class.dart';

/// What each segment draws.
enum SegmentDisplay {
  /// Both, which needs real room: an icon costs roughly 26px per segment.
  iconAndLabel,

  /// Label alone. The label names the view; the icon beside it is decoration,
  /// and it is the first thing to go.
  labelOnly,

  /// Icon alone, with the label as its tooltip. Only where text cannot fit at
  /// all — a narrow master pane — since it asks the reader to know the glyphs.
  iconOnly,
}

/// Below this a label is squeezed to a few characters, so the icon carries it
/// instead. `PlanView`'s master pane runs 320–420px and is the case this exists
/// for.
const double _labelFloor = 340;

/// Selectors with this many segments never carry icons: four labels plus four
/// icons overflow a phone, and both of the screens with four had that bug.
const int _crowded = 4;

/// The rule.
///
/// [paneWidth] is the width the selector actually gets — a `LayoutBuilder`'s
/// `constraints.maxWidth` — which is not the window's in a master/detail shell.
/// Omit it and only the window class is consulted.
SegmentDisplay segmentDisplayFor(
  BuildContext context, {
  required int segments,
  double? paneWidth,
}) {
  if (paneWidth != null && paneWidth < _labelFloor) {
    return SegmentDisplay.iconOnly;
  }
  if (segments >= _crowded) return SegmentDisplay.labelOnly;
  return WindowSizeClass.of(context) == WindowSizeClass.compact
      ? SegmentDisplay.labelOnly
      : SegmentDisplay.iconAndLabel;
}

/// A [ButtonSegment] honouring [display].
///
/// The label never wraps: a `SegmentedButton` given a wrapping label grows taller
/// than the row it sits in rather than eliding.
ButtonSegment<T> viewSegment<T>({
  required T value,
  required IconData icon,
  required String label,
  required SegmentDisplay display,
}) => ButtonSegment<T>(
  value: value,
  icon: display == SegmentDisplay.labelOnly
      ? null
      : (display == SegmentDisplay.iconOnly
            ? Tooltip(message: label, child: Icon(icon))
            : Icon(icon)),
  label: display == SegmentDisplay.iconOnly
      ? null
      : Text(
          label,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
        ),
);
