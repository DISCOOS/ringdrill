import 'package:flutter/material.dart';
import 'package:ringdrill/views/patch_alert_widget.dart';
import 'package:ringdrill/views/shared_file_widget.dart';
import 'package:upgrader/upgrader.dart';

class PlatformWidget extends StatelessWidget {
  const PlatformWidget({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // ---------------------------------
    // Upgrader
    // ---------------------------------
    // On Android, the default behavior will be to use
    // the Google Play Store version of the app.
    // On iOS, the default behavior will be to use the
    // App Store version of the app, so update the
    // Bundle Identifier in example/ios/Runner with a
    // valid identifier already in the App Store.
    return UpgradeAlert(
      // ---------------------------------
      // Shorebird patch upgrades
      // ---------------------------------
      // Notifies user of new patch when app is running
      child: PatchAlertWidget(
        // ---------------------------------
        // Handle incoming files from OS
        // ---------------------------------
        child: SharedFileWidget(child: child),
      ),
    );
  }
}
