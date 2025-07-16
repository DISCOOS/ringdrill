import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _loadConsent();
  }

  Future<void> _loadConsent() async {
    // Load saved consent state from shared preferences
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      analyticsConsent = prefs.getBool(AppConfig.keyAnalyticsConsent) ?? false;
    });
  }

  Future<void> _saveConsent(bool consent) async {
    // Save consent state to shared preferences
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

    // Save the updated consent state
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

          // Learn More Button
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
              'Enable collection of analytics and crash reports. This data is linked to your device but does not identify you personally.',
            ),
            secondary: const Icon(Icons.analytics_outlined),
          ),
        ],
      ),
    );
  }
}
