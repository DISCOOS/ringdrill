import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart' show GoRouter;
import 'package:intl/intl_browser.dart'
    if (dart.library.io) 'package:intl/intl_standalone.dart';
import 'package:ringdrill/services/map_settings.dart';
import 'package:ringdrill/services/notification_service.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/theme.dart';
import 'package:ringdrill/utils/app_config.dart';
import 'package:ringdrill/utils/sentry_config.dart';
import 'package:ringdrill/views/feedback.dart';
import 'package:ringdrill/views/main_screen.dart';
import 'package:ringdrill/web/pwa_update_web.dart'
    if (dart.library.io) 'package:ringdrill/web/pwa_update_stub.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:upgrader/upgrader.dart';

import 'l10n/app_localizations.dart' show AppLocalizations;

Future<void> main() async {
  SentryWidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    GoRouter.optionURLReflectsImperativeAPIs = true;
    usePathUrlStrategy();
  }

  // Any uncaught error in the async boot below must NOT be allowed to skip
  // runApp(): on web, the native splash screen is removed by Flutter's
  // first-frame callback. If main() throws before runApp(), Flutter never
  // renders a frame, the splash stays forever, and the only recovery path
  // is for the user to clear site data. Wrap the whole boot so the worst
  // case is a visible error screen rather than an invisible hang.
  try {
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

    // TODO: Make a widget that does this with progress
    //  indicator until all services are initialized and
    //  MainScreen is shown
    // Initialize services
    await ProgramService().init();
    await MapSettings.instance.load();

    if (isFirstLaunch) {
      // Set default "analyticsConsent" to false (opt-out by default)
      await prefs.setBool(AppConfig.keyAnalyticsConsent, false);
      await prefs.setBool(AppConfig.keyIsFirstLaunch, false);
    }

    if (analyticsConsent) {
      // Run app with Sentry on consent
      await SentryFlutter.init(SentryConfig.apply);
      runApp(
        FeedbackBoundary(
          child: SentryWidget(child: RingDrillApp(isFirstLaunch: isFirstLaunch)),
        ),
      );
    } else {
      // Run app without Sentry if no consent
      runApp(RingDrillApp(isFirstLaunch: isFirstLaunch));
    }
  } catch (error, stackTrace) {
    // Best-effort error reporting. Sentry may not have been initialized
    // yet — its global captureException is a safe no-op in that case.
    debugPrint('RingDrill boot failed: $error\n$stackTrace');
    unawaited(Sentry.captureException(error, stackTrace: stackTrace));
    runApp(_BootFailureApp(error: error));
  }
}

/// Fallback shown when [main] fails before the normal app tree can be
/// constructed. The point is twofold: (1) cause Flutter to render a first
/// frame so the web splash screen is dismissed, and (2) give the user
/// a visible action to recover (reload + clear local data) rather than
/// stranding them in front of a frozen splash with no way out.
class _BootFailureApp extends StatelessWidget {
  const _BootFailureApp({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ringDrillTheme,
      darkTheme: ringDrillDarkTheme,
      themeMode: ThemeMode.system,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'RingDrill could not start',
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Stored data appears to be corrupt. You can try '
                      'reloading the page. If that does not help, clear '
                      'site data in your browser to recover.',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    SelectableText(
                      '$error',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    if (kIsWeb) ...[
                      ElevatedButton.icon(
                        onPressed: reloadCurrentPage,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reload'),
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: clearWebStorageAndReload,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Clear local data and reload'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RingDrillApp extends StatefulWidget {
  const RingDrillApp({super.key, required this.isFirstLaunch});

  final bool isFirstLaunch;

  @override
  State<RingDrillApp> createState() => _RingDrillAppState();
}

class _RingDrillAppState extends State<RingDrillApp> {
  late final RouterConfig<Object> router;
  @override
  void initState() {
    _startNotificationService();
    _startPwaUpdatesListener();
    // Create exactly one router instance and keep it stable.
    router = buildRouter(widget.isFirstLaunch);
    super.initState();
  }

  void _startPwaUpdatesListener() {
    if (kIsWeb) {
      listenForPwaUpdates(
        onUpdateReady: (reloadNow) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              showCloseIcon: true,
              content: Text(AppLocalizations.of(context)!.appUpdateAvailable),
              dismissDirection: DismissDirection.endToStart,
              action: SnackBarAction(
                label: AppLocalizations.of(context)!.restartNow,
                onPressed: reloadNow,
              ),
            ),
          );
        },
      );
    }
  }

  Future<void> _startNotificationService() async {
    if (!kIsWeb) {
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
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'RingDrill',
      theme: ringDrillTheme,
      darkTheme: ringDrillDarkTheme,
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      // ADR-0037 part 2: clamp the upper text-scale bound app-wide so Dynamic
      // Type is honoured up to 1.3 (which the chrome can absorb) but cannot
      // grow past it. Smaller user sizes are left untouched.
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: child ?? const SizedBox.shrink(),
      ),
      routerConfig: router,
    );
  }
}

