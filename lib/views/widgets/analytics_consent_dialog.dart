import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/utils/app_config.dart';
import 'package:ringdrill/utils/sentry_config.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Show the one-shot analytics consent prompt on top of the current
/// route. Persists the user's choice to
/// [AppConfig.keyAnalyticsConsent] and initialises Sentry inline when
/// the user opts in, so this same boot starts capturing events from
/// the moment consent is given.
///
/// Modal (`barrierDismissible: false`) so the user cannot interact
/// with the screen underneath until they have answered. Used by
/// `ConceptPrimerScreen` to gate the welcome flow on first launch —
/// pre-onboarding, before any analytics-affecting actions become
/// reachable.
Future<void> showAnalyticsConsentDialog(BuildContext context) async {
  final l = AppLocalizations.of(context)!;
  final consent =
      await showAdaptiveDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text(l.appAnalyticsConsent),
          content: Text(
            [
              l.appAnalyticsConsentMessage,
              l.appAnalyticsConsentOptIn,
            ].join('. '),
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

  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(AppConfig.keyAnalyticsConsent, consent);

  if (consent) {
    await SentryFlutter.init(SentryConfig.apply);
  }
}
