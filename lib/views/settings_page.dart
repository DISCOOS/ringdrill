import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/services/map_settings.dart';
import 'package:ringdrill/services/notification_service.dart';
import 'package:ringdrill/utils/app_config.dart';
import 'package:ringdrill/utils/prefs.dart';
import 'package:ringdrill/utils/sentry_config.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: localizations.cancel,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(localizations.settings),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            const Divider(),
            AnalyticsConsentSettings(),
            const Divider(),
            NotificationSettingsWidget(),
            const Divider(),
            const MapSettingsWidget(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// App-user role
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Analytics consent
// ---------------------------------------------------------------------------

class AnalyticsConsentSettings extends StatefulWidget {
  const AnalyticsConsentSettings({super.key});

  @override
  State<AnalyticsConsentSettings> createState() =>
      _AnalyticsConsentSettingsState();
}

class _AnalyticsConsentSettingsState extends State<AnalyticsConsentSettings> {
  bool analyticsConsent = false; // User consent for analytics

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    // Load saved preferences from SharedPreferences
    setState(() {
      analyticsConsent = Prefs.getBool(AppConfig.keyAnalyticsConsent) ?? false;
    });
  }

  Future<void> _saveConsent(bool consent) async {
    // Save consent state to SharedPreferences
    unawaited(Prefs.setBool(AppConfig.keyAnalyticsConsent, consent));
    await _toggleSentryAnalytics(consent);

    if (mounted) {
      final localization = AppLocalizations.of(context)!;
      // Show a confirmation message to the user
      showAdaptiveDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            consent
                ? localization.analyticsEnabled
                : localization.analyticsDisabled,
          ),
          content: Text(
            consent
                ? localization.analyticsIsAllowed
                : localization.analyticsIsDenied,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(localization.ok),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _toggleSentryAnalytics(bool value) async {
    // Save updated consent state
    unawaited(Prefs.setBool(AppConfig.keyAnalyticsConsent, value));

    if (value) {
      // Enable Sentry dynamically
      await SentryFlutter.init(SentryConfig.apply);
    } else {
      // Disable Sentry dynamically
      await Sentry.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Analytics Consent Section
        Text(
          localizations.appAnalyticsConsent,
          // ADR-0037: themed titleMedium instead of a hardcoded 20.
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16.0),
        Text(
          [
            localizations.appAnalyticsConsentMessage,
            localizations.appAnalyticsConsentCollectedData,
          ].join('. '),
        ),
        const SizedBox(height: 12.0),

        TextButton.icon(
          onPressed: () {
            launchUrl(
              Uri.parse(
                'https://docs.sentry.io/platforms/dart/guides/flutter/data-management/data-collected',
              ),
            );
          },
          icon: const Icon(Icons.open_in_new),
          label: Text(localizations.learnMoreAboutDataCollected),
        ),

        const Divider(),

        // Analytics Consent Toggle
        SwitchListTile.adaptive(
          value: analyticsConsent,
          onChanged: (value) {
            unawaited(HapticFeedback.selectionClick());
            setState(() {
              analyticsConsent = value;
            });
            _saveConsent(value);
          },
          title: Text(localizations.allowAppAnalytics),
          subtitle: Text(localizations.allowAppAnalyticsMessage),
        ),
      ],
    );
  }
}

class NotificationSettingsWidget extends StatefulWidget {
  const NotificationSettingsWidget({super.key});

  @override
  State<NotificationSettingsWidget> createState() =>
      _NotificationSettingsWidgetState();
}

class _NotificationSettingsWidgetState
    extends State<NotificationSettingsWidget> {
  bool isNotificationsEnabled = true; // Main notification toggle
  bool isFullScreenIntentEnabled = false; // Full-screen intent notifications
  bool playSound = true; // Notification sound toggle
  bool vibrateEnabled = true; // Notification vibration toggle
  int urgentNotificationThreshold =
      2; // Minutes remaining for an urgent notification

  static const List<int> thresholdOptions = [1, 2, 3, 4, 5];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    // Load saved preferences from SharedPreferences
    setState(() {
      isNotificationsEnabled =
          Prefs.getBool(AppConfig.keyIsNotificationsEnabled) ??
          true; // Default ON
      isFullScreenIntentEnabled =
          Prefs.getBool(AppConfig.keyIsNotificationFullScreenIntentEnabled) ??
          false; // Default OFF
      playSound = Prefs.getBool(AppConfig.keyNotificationPlaySound) ?? true;
      vibrateEnabled =
          Prefs.getBool(AppConfig.keyIsNotificationVibrateEnabled) ?? true;
      urgentNotificationThreshold =
          Prefs.getInt(AppConfig.keyUrgentNotificationThreshold) ?? 2;
    });
  }

  Future<void> _saveNotificationPreference({
    bool? enabled,
    bool? fullScreen,
    bool? sound,
    bool? vibrate,
    int? threshold,
  }) async {
    if (enabled != null) {
      await Prefs.setBool(AppConfig.keyIsNotificationsEnabled, enabled);
      if (enabled) {
        // Turning the toggle on is itself an explicit opt-in, so it must
        // be allowed to fire the OS permission dialog even when the user
        // never went through the first-launch consent stage (upgraders,
        // and any device that has had a previous build installed, where
        // `isFirstLaunch` is already false so `NotificationConsentStage`
        // never showed). Without this the toggle looked "on" in-app while
        // iOS was never asked, so RingDrill never registered and never
        // appeared under Settings > Notifications. See ADR-0038.
        await Prefs.setBool(AppConfig.keyNotificationConsentAsked, true);
      }
      await NotificationService().initFromPrefs(Prefs.instance);
      setState(() {
        isNotificationsEnabled = enabled;
      });
    }

    if (fullScreen != null) {
      await Prefs.setBool(
        AppConfig.keyIsNotificationFullScreenIntentEnabled,
        fullScreen,
      );
      await NotificationService().initFromPrefs(Prefs.instance);
      setState(() {
        isFullScreenIntentEnabled = fullScreen;
      });
    }

    if (sound != null) {
      await Prefs.setBool(AppConfig.keyNotificationPlaySound, sound);
      await NotificationService().initFromPrefs(Prefs.instance);
      setState(() {
        playSound = sound;
      });
    }

    if (vibrate != null) {
      await Prefs.setBool(AppConfig.keyIsNotificationVibrateEnabled, vibrate);
      await NotificationService().initFromPrefs(Prefs.instance);
      setState(() {
        vibrateEnabled = vibrate;
      });
    }

    if (threshold != null) {
      await Prefs.setInt(AppConfig.keyUrgentNotificationThreshold, threshold);
      await NotificationService().initFromPrefs(Prefs.instance);
      setState(() {
        urgentNotificationThreshold = threshold;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Notifications Settings Section
        Text(
          localizations.notification(2),
          // ADR-0037: themed titleMedium instead of a hardcoded 20.
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16.0),
        Text(localizations.toggleNotificationDescription),
        const SizedBox(height: 12.0),

        // Global Notifications Toggle
        SwitchListTile.adaptive(
          value: isNotificationsEnabled,
          onChanged: (value) {
            unawaited(HapticFeedback.selectionClick());
            _saveNotificationPreference(enabled: value); // Save user preference
          },
          title: Text(localizations.enableNotifications),
          subtitle: Text(localizations.enableNotificationsMessage),
        ),

        // Re-engagement affordance for users who have the in-app
        // toggle on but the OS-level permission off (declined the
        // system prompt, or revoked it from OS Settings). Deep-link
        // them straight to Settings — iOS does not let us re-show
        // the permission dialog (ADR-0038). `Geolocator.openAppSettings`
        // is reused because its implementation is platform-generic;
        // the geolocator-shaped name is misleading.
        if (isNotificationsEnabled &&
            NotificationService().permissionState ==
                NotificationPermissionState.denied)
          ListTile(
            leading: const Icon(Icons.notifications_off_outlined),
            title: Text(localizations.notificationsDeniedBanner),
            trailing: TextButton(
              onPressed: () => unawaited(Geolocator.openAppSettings()),
              child: Text(localizations.openSettings),
            ),
          ),

        const Divider(),

        // Urgent Notification Threshold
        ListTile(
          title: Text(localizations.setUrgentNotificationThreshold),
          subtitle: Text(
            localizations.setUrgentNotificationThresholdDescription,
          ),
          trailing: DropdownButton<int>(
            value: urgentNotificationThreshold,
            items: thresholdOptions
                .map(
                  (minute) => DropdownMenuItem<int>(
                    value: minute,
                    child: Text(localizations.minute(minute)),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                _saveNotificationPreference(threshold: value);
              }
            },
          ),
        ),

        // Full-Screen Intent Toggle
        SwitchListTile.adaptive(
          value: isFullScreenIntentEnabled,
          onChanged: isNotificationsEnabled
              ? (value) {
                  unawaited(HapticFeedback.selectionClick());
                  _saveNotificationPreference(fullScreen: value);
                }
              : null, // Disable if notifications are off
          title: Text(localizations.fullScreenNotifications),
          subtitle: Text(localizations.fullScreenNotificationsDescription),
        ),

        // Play Sound Toggle
        SwitchListTile.adaptive(
          value: playSound,
          onChanged: isNotificationsEnabled
              ? (value) {
                  unawaited(HapticFeedback.selectionClick());
                  _saveNotificationPreference(sound: value);
                }
              : null, // Disable if notifications are off
          title: Text(localizations.playSoundWhenUrgent),
          subtitle: Text(localizations.playSoundWhenUrgentDescription),
        ),

        // Vibrate Toggle
        SwitchListTile.adaptive(
          value: vibrateEnabled,
          onChanged: isNotificationsEnabled
              ? (value) {
                  unawaited(HapticFeedback.selectionClick());
                  _saveNotificationPreference(vibrate: value);
                }
              : null, // Disable if notifications are off
          title: Text(localizations.vibrateWhenUrgent),
          subtitle: Text(localizations.vibrateWhenUrgentDescription),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Map
// ---------------------------------------------------------------------------

/// Map-related preferences. Currently a single toggle for the zoom in/out
/// buttons. Only shown on pointer (non-touch) platforms, where the buttons
/// actually appear — touch devices rely on pinch-to-zoom regardless.
class MapSettingsWidget extends StatelessWidget {
  const MapSettingsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localizations.mapSettingsSectionTitle,
          // ADR-0037: themed titleMedium instead of a hardcoded size.
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16.0),
        Text(localizations.mapSettingsSectionDescription),
        const SizedBox(height: 12.0),
        ValueListenableBuilder<bool>(
          valueListenable: MapSettings.instance.showZoomControls,
          builder: (context, showZoom, _) {
            return SwitchListTile.adaptive(
              value: showZoom,
              onChanged: (value) {
                unawaited(HapticFeedback.selectionClick());
                MapSettings.instance.setShowZoomControls(value);
              },
              title: Text(localizations.showMapZoomControls),
              subtitle: Text(localizations.showMapZoomControlsDescription),
            );
          },
        ),
      ],
    );
  }
}
