import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';

class PhaseHeaders extends StatelessWidget {
  const PhaseHeaders({
    super.key,
    required this.title,
    required this.titleWidth,
    required this.mainAxisAlignment,
    this.cellSize = 62,
    this.expand = false,
  });

  final bool expand;
  final String title;
  final double cellSize;
  final double titleWidth;

  final MainAxisAlignment mainAxisAlignment;

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
    return Row(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          height: headerHeight,
          width: titleWidth,
          color: color,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Text(title),
            ),
          ),
        ),
        Container(
          height: headerHeight,
          width: cellSize,
          color: color,
          child: Center(child: Text(localizations.drill.toUpperCase())),
        ),
        Container(
          height: headerHeight,
          width: cellSize,
          color: color,
          child: Center(child: Text(localizations.eval.toUpperCase())),
        ),
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
