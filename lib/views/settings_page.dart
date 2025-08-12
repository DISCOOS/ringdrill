import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/services/notification_service.dart';
import 'package:ringdrill/utils/app_config.dart';
import 'package:ringdrill/utils/sentry_config.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool analyticsConsent = false; // User consent for analytics
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
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      analyticsConsent = prefs.getBool(AppConfig.keyAnalyticsConsent) ?? false;
      isNotificationsEnabled =
          prefs.getBool(AppConfig.keyIsNotificationsEnabled) ??
          true; // Default ON
      isFullScreenIntentEnabled =
          prefs.getBool(AppConfig.keyIsNotificationFullScreenIntentEnabled) ??
          false; // Default OFF
      playSound = prefs.getBool(AppConfig.keyNotificationPlaySound) ?? true;
      vibrateEnabled =
          prefs.getBool(AppConfig.keyIsNotificationVibrateEnabled) ?? true;
      urgentNotificationThreshold =
          prefs.getInt(AppConfig.keyUrgentNotificationThreshold) ?? 2;
    });
  }

  Future<void> _saveNotificationPreference({
    bool? enabled,
    bool? fullScreen,
    bool? sound,
    bool? vibrate,
    int? threshold,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (enabled != null) {
      await prefs.setBool(AppConfig.keyIsNotificationsEnabled, enabled);
      await NotificationService().initFromPrefs(prefs);
      setState(() {
        isNotificationsEnabled = enabled;
      });
    }

    if (fullScreen != null) {
      await prefs.setBool(
        AppConfig.keyIsNotificationFullScreenIntentEnabled,
        fullScreen,
      );
      await NotificationService().initFromPrefs(prefs);
      setState(() {
        isFullScreenIntentEnabled = fullScreen;
      });
    }

    if (sound != null) {
      await prefs.setBool(AppConfig.keyNotificationPlaySound, sound);
      await NotificationService().initFromPrefs(prefs);
      setState(() {
        playSound = sound;
      });
    }

    if (vibrate != null) {
      await prefs.setBool(AppConfig.keyIsNotificationVibrateEnabled, vibrate);
      await NotificationService().initFromPrefs(prefs);
      setState(() {
        vibrateEnabled = vibrate;
      });
    }

    if (threshold != null) {
      await prefs.setInt(AppConfig.keyUrgentNotificationThreshold, threshold);
      await NotificationService().initFromPrefs(prefs);
      setState(() {
        urgentNotificationThreshold = threshold;
      });
    }
  }

  Future<void> _saveConsent(bool consent) async {
    // Save consent state to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool(AppConfig.keyAnalyticsConsent, consent);
    await _toggleSentryAnalytics(consent);

    if (mounted) {
      final localization = AppLocalizations.of(context)!;
      // Show a confirmation message to the user
      showDialog(
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
    final prefs = await SharedPreferences.getInstance();

    // Save updated consent state
    prefs.setBool(AppConfig.keyAnalyticsConsent, value);

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
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.settings)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildAnalyticsConsentSection(),
            if (kIsWeb) ...[
              const Divider(),
              _buildNotificationSettingsSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsConsentSection() {
    final localizations = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Analytics Consent Section
        Text(
          localizations.appAnalyticsConsent,
          style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
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
        SwitchListTile(
          value: analyticsConsent,
          onChanged: (value) {
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

  Widget _buildNotificationSettingsSection() {
    final localizations = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Notifications Settings Section
        Text(
          localizations.notification(2),
          style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16.0),
        Text(localizations.toggleNotificationDescription),
        const SizedBox(height: 12.0),

        // Global Notifications Toggle
        SwitchListTile(
          value: isNotificationsEnabled,
          onChanged: (value) {
            _saveNotificationPreference(enabled: value); // Save user preference
          },
          title: Text(localizations.enableNotifications),
          subtitle: Text(localizations.enableNotificationsMessage),
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
        SwitchListTile(
          value: isFullScreenIntentEnabled,
          onChanged: isNotificationsEnabled
              ? (value) {
                  _saveNotificationPreference(fullScreen: value);
                }
              : null, // Disable if notifications are off
          title: Text(localizations.fullScreenNotifications),
          subtitle: Text(localizations.fullScreenNotificationsDescription),
        ),

        // Play Sound Toggle
        SwitchListTile(
          value: playSound,
          onChanged: isNotificationsEnabled
              ? (value) {
                  _saveNotificationPreference(sound: value);
                }
              : null, // Disable if notifications are off
          title: Text(localizations.playSoundWhenUrgent),
          subtitle: Text(localizations.playSoundWhenUrgentDescription),
        ),

        // Vibrate Toggle
        SwitchListTile(
          value: vibrateEnabled,
          onChanged: isNotificationsEnabled
              ? (value) {
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
