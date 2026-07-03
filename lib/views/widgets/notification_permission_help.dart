import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ringdrill/l10n/app_localizations.dart';

/// Shows a dialog that explains how to enable notifications from the OS
/// Settings app.
///
/// Used when the OS-level notification permission has been denied and can
/// no longer be re-requested programmatically — iOS only presents the
/// system permission dialog once, so the only recovery path is the
/// Settings app (see ADR-0038). [Geolocator.openAppSettings] is reused as
/// the deep-link because its implementation is platform-generic; the
/// geolocator-shaped name is misleading.
Future<void> showNotificationPermissionHelp(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        icon: const Icon(Icons.notifications_off_outlined),
        title: Text(l10n.notificationsDeniedTitle),
        content: Text(l10n.notificationsDeniedHelp),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.dismiss),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              unawaited(Geolocator.openAppSettings());
            },
            child: Text(l10n.openSettings),
          ),
        ],
      );
    },
  );
}
