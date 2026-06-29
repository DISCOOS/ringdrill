import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/services/app_user_role.dart';
import 'package:ringdrill/services/map_settings.dart';
import 'package:ringdrill/services/notification_service.dart';
import 'package:ringdrill/utils/app_config.dart';
import 'package:ringdrill/utils/sentry_config.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
            AppUserRoleSettings(),
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

/// Lets the device user declare whether they are an Øvelsesleder (director)
/// or a Veileder (instructor). The selection drives the default [BriefAudience]
/// when the brief screen opens without an explicit audience argument.
///
/// Participants do not use the app, so [AppUserRole.participant] is not offered
/// here. It remains a valid export/print brief audience (DESIGN-006 step 4).
class AppUserRoleSettings extends StatefulWidget {
  const AppUserRoleSettings({super.key});

  @override
  State<AppUserRoleSettings> createState() => _AppUserRoleSettingsState();
}

class _AppUserRoleSettingsState extends State<AppUserRoleSettings> {
  AppUserRole? _role;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(AppConfig.keyAppUserRole);
    if (!mounted) return;
    final role = stored == null
        ? null
        : AppUserRole.values.where((r) => r.name == stored).firstOrNull;
    setState(() => _role = role);
  }

  Future<void> _save(AppUserRole? role) async {
    final prefs = await SharedPreferences.getInstance();
    if (role == null) {
      await prefs.remove(AppConfig.keyAppUserRole);
    } else {
      await prefs.setString(AppConfig.keyAppUserRole, role.name);
    }
    if (mounted) setState(() => _role = role);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.appUserRoleSectionTitle,
          // ADR-0037: themed titleMedium instead of a hardcoded 20.
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8.0),
        Text(l10n.appUserRoleSectionDescription),
        const SizedBox(height: 4.0),
        RadioGroup<AppUserRole>(
          groupValue: _role,
          onChanged: _save,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Radio<AppUserRole>(value: AppUserRole.director),
                title: Text(l10n.briefAudienceDirector),
                onTap: () => _save(AppUserRole.director),
              ),
              ListTile(
                leading: const Radio<AppUserRole>(
                  value: AppUserRole.instructor,
                ),
                title: Text(l10n.briefAudienceInstructor),
                onTap: () => _save(AppUserRole.instructor),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

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
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      analyticsConsent = prefs.getBool(AppConfig.keyAnalyticsConsent) ?? false;
    });
  }

  Future<void> _saveConsent(bool consent) async {
    // Save consent state to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool(AppConfig.keyAnalyticsConsent, consent);
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
    final prefs = await SharedPreferences.getInstance();
    setState(() {
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
              onPressed: () =>
                  unawaited(Geolocator.openAppSettings()),
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
