import 'package:flutter/material.dart';
import 'package:ringdrill/views/platform_widget.dart' as native;
import 'package:ringdrill/web/mobile_app_nudge.dart';

class PlatformWidget extends StatelessWidget {
  const PlatformWidget({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        native.PlatformWidget(child: child),
        Align(
          alignment: Alignment.bottomCenter,
          child: MobileAppNudgeBanner.create(),
        ),
      ],
    );
  }
}
