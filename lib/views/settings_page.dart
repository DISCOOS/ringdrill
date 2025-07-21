import 'package:flutter/material.dart';
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
      // Show a confirmation message to the user
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text(consent ? 'Analytics Enabled' : 'Analytics Disabled'),
              content: Text(
                consent
                    ? 'You have agreed to allow analytics data to be collected from your device.'
                    : 'You have opted out of analytics. No data will be collected from your device.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
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
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildAnalyticsConsentSection(),
          const Divider(),
          _buildNotificationSettingsSection(),
        ],
      ),
    );
  }

  Widget _buildAnalyticsConsentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Analytics Consent Section
        const Text(
          'App Analytics Consent',
          style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16.0),
        const Text(
          'We use analytics to improve the app experience by collecting certain data from your device. '
          'This includes information about your device (e.g., device model, OS version) and crash reports '
          'in case of failures. This data is sent to and processed by Sentry.io.',
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
          label: const Text('Learn More About Data Collected'),
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
          title: const Text('Allow App Analytics'),
          subtitle: const Text(
            'Enable collection of analytics and crash reports. This data is linked '
            'to your device, but not your identity.',
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Notifications Settings Section
        const Text(
          'Notifications',
          style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16.0),
        const Text(
          'Enable or disable local notifications for reminders and updates while using the app. '
          'Disabling this will stop sending all notifications immediately.',
        ),
        const SizedBox(height: 12.0),

        // Global Notifications Toggle
        SwitchListTile(
          value: isNotificationsEnabled,
          onChanged: (value) {
            _saveNotificationPreference(enabled: value); // Save user preference
          },
          title: const Text('Enable Notifications'),
          subtitle: const Text(
            'When enabled, you will receive reminders and updates via notifications.',
          ),
        ),

        const Divider(),

        // Urgent Notification Threshold
        ListTile(
          title: const Text('Set Urgent Notification Threshold'),
          subtitle: const Text(
            'The number of minutes remaining before the next phase to show an urgent notification.',
          ),
          trailing: DropdownButton<int>(
            value: urgentNotificationThreshold,
            items:
                thresholdOptions
                    .map(
                      (minute) => DropdownMenuItem<int>(
                        value: minute,
                        child: Text('$minute min'),
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
          onChanged:
              isNotificationsEnabled
                  ? (value) {
                    _saveNotificationPreference(fullScreen: value);
                  }
                  : null, // Disable if notifications are off
          title: const Text('Full-Screen Notifications'),
          subtitle: const Text(
            'Allow notifications to appear in full-screen mode for urgent updates, '
            'even when other apps are open.',
          ),
        ),

        // Play Sound Toggle
        SwitchListTile(
          value: playSound,
          onChanged:
              isNotificationsEnabled
                  ? (value) {
                    _saveNotificationPreference(sound: value);
                  }
                  : null, // Disable if notifications are off
          title: const Text('Play Sound when urgent'),
          subtitle: const Text(
            'Toggle notification sounds on or off on urgent notifications.',
          ),
        ),

        // Vibrate Toggle
        SwitchListTile(
          value: vibrateEnabled,
          onChanged:
              isNotificationsEnabled
                  ? (value) {
                    _saveNotificationPreference(vibrate: value);
                  }
                  : null, // Disable if notifications are off
          title: const Text('Vibrate when urgent'),
          subtitle: const Text(
            'Enable or disable vibration for urgent notifications.',
          ),
        ),
      ],
    );
  }
}
