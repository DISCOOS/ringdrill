import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/services/notification_service.dart';
import 'package:ringdrill/utils/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Show the in-app notification rationale on top of the current
/// route, then — if the user accepts — re-initialise
/// [NotificationService] with `requestPermissions: true` so the OS
/// system dialog fires from a known, user-initiated context.
///
/// No-op when [AppConfig.keyNotificationConsentAsked] is already
/// `true`, so this is safe to call unconditionally from first-launch
/// flows. See [ADR-0038].
///
/// The pre-prompt only runs when [AppConfig.keyIsNotificationsEnabled]
/// is true (the user has not turned notifications off globally) and
/// when the plugin reports it has not been asked yet — i.e. on the
/// very first launch after install.
Future<void> maybeShowNotificationConsentPrompt(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  final asked =
      prefs.getBool(AppConfig.keyNotificationConsentAsked) ?? false;
  if (asked) return;

  final enabled =
      prefs.getBool(AppConfig.keyIsNotificationsEnabled) ?? true;
  if (!enabled) {
    // User has turned notifications off globally before ever being
    // asked. Mark consent as asked so we do not re-prompt later.
    await prefs.setBool(AppConfig.keyNotificationConsentAsked, true);
    return;
  }

  if (!context.mounted) return;
  final l = AppLocalizations.of(context)!;

  final accepted =
      await showAdaptiveDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text(l.appNotificationConsent),
          content: Text(
            [
              l.appNotificationConsentMessage,
              l.appNotificationConsentOptIn,
            ].join('\n\n'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.decline),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.allow),
            ),
          ],
        ),
      ) ??
      false;

  await prefs.setBool(AppConfig.keyNotificationConsentAsked, true);

  if (!accepted) {
    // User said no in-app. Skip the OS dialog entirely so iOS does
    // not record a permanent denial that only the OS Settings app
    // can reverse.
    return;
  }

  // Re-init the service with permission request enabled. This is
  // the call that triggers the iOS/Android system dialog.
  await NotificationService().initFromPrefs(prefs);
}
