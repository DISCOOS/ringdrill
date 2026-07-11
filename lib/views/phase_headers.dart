import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/vertical_divider_widget.dart';

class PhaseHeaders extends StatelessWidget {
  const PhaseHeaders({
    super.key,
    required this.title,
    required this.titleWidth,
    required this.mainAxisAlignment,
    this.cellSize = 62,
    this.expand = false,
    this.expandTitle = false,
  });

  final bool expand;
  final String title;
  final double cellSize;
  final double titleWidth;

  final MainAxisAlignment mainAxisAlignment;

  /// Grows the title cell to fill the row's leftover width instead of
  /// sitting at a fixed [titleWidth] — the header-side half of
  /// `ScheduleTable`'s width mode (see `ScheduleRow.labelWidth`, which grows
  /// the row's label cell the same way so the header bar and the rows
  /// always agree on total width and the phase columns stay aligned).
  /// Independent of [expand] (an unrelated trailing filler used by callers
  /// outside `ScheduleTable`).
  final bool expandTitle;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    // One tonal step darker in light mode so the header band reads distinctly
    // against the light scaffold; dark mode keeps the default container tone.
    final color = scheme.brightness == Brightness.light
        ? scheme.surfaceContainerHigh
        : scheme.surfaceContainer;
    // Cell height is 28 (not 24): at the 1.3 text-scale cap the ~26px label
    // line-height fits with ~2px to spare, so DRILL/EVAL/ROLL no longer clip
    // their descenders (ADR-0037 part-2 verification finding). A fully
    // scale-driven version (IntrinsicHeight + stretch) is the path to a 1.5
    // cap, deferred to that raise.
    const headerHeight = 28.0;
    final titleCell = Container(
      height: headerHeight,
      width: expandTitle ? null : titleWidth,
      constraints: expandTitle
          ? BoxConstraints(minWidth: titleWidth)
          : null,
      color: color,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Text(title.toUpperCase()),
        ),
      ),
    );
    // A same-colour spacer — not a visible divider glyph, just reserved
    // width — matching each `VerticalDividerWidget` gap `ScheduleRow` lays
    // out between its label and phase cells (leading + between phase0/1 +
    // between phase1/2, no trailing gap). Without it, DRILL/EVAL/ROLL sit
    // one-to-three divider-widths left of the time columns they're meant
    // to label.
    Widget dividerSpacer() => Container(
      height: headerHeight,
      width: VerticalDividerWidget.defaultWidth,
      color: color,
    );
    return Row(
      mainAxisSize: expandTitle ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        expandTitle ? Expanded(child: titleCell) : titleCell,
        dividerSpacer(),
        Container(
          height: headerHeight,
          width: cellSize,
          color: color,
          child: Center(child: Text(localizations.drill.toUpperCase())),
        ),
        dividerSpacer(),
        Container(
          height: headerHeight,
          width: cellSize,
          color: color,
          child: Center(child: Text(localizations.eval.toUpperCase())),
        ),
        dividerSpacer(),
        Container(
          height: headerHeight,
          width: cellSize,
          color: color,
          child: Center(child: Text(localizations.roll.toUpperCase())),
        ),
        if (expand) Expanded(child: Container(height: headerHeight, color: color)),
      ],
    );
  }
}
