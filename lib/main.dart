import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl_browser.dart'
    if (dart.library.io) 'package:intl/intl_standalone.dart';
import 'package:ringdrill/services/notification_service.dart';
import 'package:ringdrill/utils/app_config.dart';
import 'package:ringdrill/utils/sentry_config.dart';
import 'package:ringdrill/views/feedback.dart';
import 'package:ringdrill/views/main_screen.dart';
import 'package:ringdrill/views/patch_alert_widget.dart';
import 'package:ringdrill/views/shared_file_widget.dart';
import 'package:ringdrill/web/pwa_update_web.dart'
    if (dart.library.io) 'package:ringdrill/web/pwa_update_stub.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:upgrader/upgrader.dart';

import 'l10n/app_localizations.dart' show AppLocalizations;

Future<void> main() async {
  SentryWidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    usePathUrlStrategy();
  }

  if (kDebugMode) {
    // Only call clearSavedSettings() during testing to reset internal values.
    await Upgrader.clearSavedSettings(); // REMOVE this for release builds
  }

  // Load user consent for analytics from SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  final isFirstLaunch = prefs.getBool(AppConfig.keyIsFirstLaunch) ?? true;
  final analyticsConsent =
      prefs.getBool(AppConfig.keyAnalyticsConsent) ?? false;

  // Ensure system locale is set
  await findSystemLocale();

  if (isFirstLaunch) {
    // Set default "analyticsConsent" to false (opt-out by default)
    await prefs.setBool(AppConfig.keyAnalyticsConsent, false);
    await prefs.setBool(AppConfig.keyIsFirstLaunch, false);
  }

  if (analyticsConsent) {
    // Run app with Sentry on consent
    await SentryFlutter.init(
      SentryConfig.apply,
      appRunner: () => runApp(
        FeedbackBoundary(
          child: SentryWidget(child: RingDrillApp(isFirstLaunch: false)),
        ),
      ),
    );
  } else {
    // Run app without Sentry if no consent
    runApp(RingDrillApp(isFirstLaunch: isFirstLaunch));
  }
}

class RingDrillApp extends StatefulWidget {
  const RingDrillApp({super.key, required this.isFirstLaunch});

  final bool isFirstLaunch;

  @override
  State<RingDrillApp> createState() => _RingDrillAppState();
}

class _RingDrillAppState extends State<RingDrillApp> {
  @override
  void initState() {
    if (!kIsWeb) _startNotificationService();
    if (kIsWeb) {
      listenForPwaUpdates(() {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            showCloseIcon: true,
            dismissDirection: DismissDirection.endToStart,
            content: Text(
              AppLocalizations.of(context)!.appUpdatedPleaseCloseAndOpen,
            ),
          ),
        );
      });
    }

    super.initState();
  }

  Future<void> _startNotificationService() async {
    final prefs = await SharedPreferences.getInstance();
    final isNotificationsEnabled =
        prefs.getBool(AppConfig.keyIsNotificationsEnabled) ?? true;
    if (isNotificationsEnabled) {
      final playSound =
          prefs.getBool(AppConfig.keyNotificationPlaySound) ?? true;
      final vibrateEnabled =
          prefs.getBool(AppConfig.keyIsNotificationVibrateEnabled) ?? true;
      final isFullScreenIntentEnabled =
          prefs.getBool(AppConfig.keyIsNotificationFullScreenIntentEnabled) ??
          false;
      final threshold =
          prefs.getInt(AppConfig.keyUrgentNotificationThreshold) ?? 2;
      final service = NotificationService();

      final init = await service.init(
        playSound: playSound,
        enableVibration: vibrateEnabled,
        fullScreenIntent: isFullScreenIntentEnabled,
        urgentThreshold: threshold,
      );

      if (!init) {
        if (Sentry.isEnabled) {
          await Sentry.captureMessage(
            'NotificationService failed to initialize',
          );
        }
        return;
      }
      service.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RingDrill',
      theme: ringDrillTheme,
      darkTheme: ringDrillDarkTheme,
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      // ---------------------------------
      // Upgrader
      // ---------------------------------
      // On Android, the default behavior will be to use
      // the Google Play Store version of the app.
      // On iOS, the default behavior will be to use the
      // App Store version of the app, so update the
      // Bundle Identifier in example/ios/Runner with a
      // valid identifier already in the App Store.
      home: UpgradeAlert(
        // ---------------------------------
        // Shorebird patch upgrades
        // ---------------------------------
        // Notifies user of new patch when app is running
        child: PatchAlertWidget(
          // ---------------------------------
          // Handle incoming files from OS
          // ---------------------------------
          child: SharedFileWidget(
            child: MainScreen(isFirstLaunch: widget.isFirstLaunch),
          ),
        ),
      ),
    );
  }
}

final ThemeData ringDrillTheme = ThemeData(
  brightness: Brightness.light,
  scaffoldBackgroundColor: const Color(0xFFF8FAFC),
  primaryColor: const Color(0xFF1E3A8A),
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF1E3A8A),
    primary: const Color(0xFF1E3A8A),
    secondary: const Color(0xFF4B5563),
    surface: const Color(0xFFE5E7EB),
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onSurface: const Color(0xFF111827),
    onSurfaceVariant: const Color(0xFF374151),
    error: const Color(0xFFF59E0B),
    brightness: Brightness.light,
  ),
  textTheme: GoogleFonts.robotoFlexTextTheme(),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF1E3A8A),
      foregroundColor: Colors.white,
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF1E3A8A),
    foregroundColor: Colors.white,
    elevation: 2,
  ),
  cardTheme: const CardThemeData(
    color: Color(0xFFE5E7EB),
    surfaceTintColor: Colors.transparent,
    elevation: 2,
    shadowColor: Colors.black54,
    margin: EdgeInsets.all(12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
    ),
    clipBehavior: Clip.antiAlias,
  ),
);

final ThemeData ringDrillDarkTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: const Color(0xFF111827),
  primaryColor: const Color(0xFF60A5FA),
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF60A5FA),
    primary: const Color(0xFF60A5FA),
    primaryFixed: const Color(0xFF1E3A8A),
    secondary: const Color(0xFF9CA3AF),
    surface: const Color(0xFF1F2937),
    onPrimary: Colors.black,
    onSecondary: Colors.black,
    onSurface: Colors.white,
    onSurfaceVariant: Color(0xFF9CA3AF),
    error: const Color(0xFFF5800B),
    brightness: Brightness.dark,
  ),
  textTheme: GoogleFonts.robotoFlexTextTheme(ThemeData.dark().textTheme),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF60A5FA),
      foregroundColor: Colors.black,
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF1E3A8A),
    foregroundColor: Colors.white,
    elevation: 2,
  ),
  cardTheme: const CardThemeData(
    color: Color(0xFF1F2937),
    surfaceTintColor: Colors.transparent,
    elevation: 2,
    shadowColor: Colors.black54,
    margin: EdgeInsets.all(12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
    ),
    clipBehavior: Clip.antiAlias,
  ),
);
