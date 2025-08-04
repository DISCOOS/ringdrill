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
    final color = Theme.of(context).colorScheme.surfaceContainer;
    return Row(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          height: 24,
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
          height: 24,
          width: cellSize,
          color: color,
          child: Center(child: Text(localizations.drill.toUpperCase())),
        ),
        Container(
          height: 24,
          width: cellSize,
          color: color,
          child: Center(child: Text(localizations.eval.toUpperCase())),
        ),
        Container(
          height: 24,
          width: cellSize,
          color: color,
          child: Center(child: Text(localizations.roll.toUpperCase())),
        ),
        if (expand) Expanded(child: Container(height: 24, color: color)),
      ],
    );
  }
}
