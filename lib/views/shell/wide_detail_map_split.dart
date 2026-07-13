import 'package:flutter/material.dart';

/// Default cap for [WideDetailMapSplit.leftMaxWidth] — the same width the
/// coordinator's own expanded body uses for its left column, give or take;
/// kept as this widget's own constant so the Post/Spill viewers do not each
/// invent their own.
const double kWideDetailMapSplitLeftColumnWidth = 440;

/// Expanded-body two-pane split shared by the detail viewers that show a
/// map beside their content (docs/prompts/design-010-post-spill-expanded-
/// map-split.md): a capped-width, self-scrolling left column beside a map
/// pane that fills the remaining width and the full pane height. Extracted
/// so the Post and Spill viewers' identical expanded arrangement cannot
/// drift apart from one another.
class WideDetailMapSplit extends StatelessWidget {
  const WideDetailMapSplit({
    super.key,
    required this.left,
    required this.mapPane,
    this.leftMaxWidth = kWideDetailMapSplitLeftColumnWidth,
  });

  /// The textual/tabular sections, stacked in their own scrolling column.
  final List<Widget> left;

  /// The map panel — fills the remaining width and, via the row's stretch
  /// alignment, the full pane height. Callers size their own map content to
  /// match (the map pane itself does not scroll).
  final Widget mapPane;

  final double leftMaxWidth;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: leftMaxWidth,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: left,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(child: mapPane),
      ],
    );
  }
}
