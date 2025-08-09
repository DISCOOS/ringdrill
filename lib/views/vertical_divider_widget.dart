import 'package:flutter/material.dart';

class VerticalDividerWidget extends StatelessWidget {
  const VerticalDividerWidget({
    super.key,
    this.width = 8,
    this.isCurrent = false,
    this.isComplete = false,
  });

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
