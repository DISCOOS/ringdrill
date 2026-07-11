import 'package:flutter/material.dart';

class VerticalDividerWidget extends StatelessWidget {
  const VerticalDividerWidget({
    super.key,
    this.width = defaultWidth,
    this.isCurrent = false,
    this.isComplete = false,
  });

  /// The width every schedule row's divider uses unless overridden.
  /// `PhaseHeaders` reads this too, so its own inter-column spacing always
  /// matches `ScheduleRow`'s regardless of which literal happens to be
  /// chosen here.
  static const double defaultWidth = 8;

  final double width;
  final bool isCurrent;
  final bool isComplete;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      width: width,
      color: isCurrent
          ? (isComplete
                ? Colors.blueAccent
                : Theme.of(context).colorScheme.secondary)
          : Colors.transparent,
      child: Center(
        child: SizedBox(
          height: 16,
          child: VerticalDivider(
            thickness: 1,
            color: isCurrent
                ? Theme.of(context).colorScheme.onInverseSurface
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
