import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/utils/app_config.dart';
import 'package:ringdrill/utils/locale_utils.dart';
import 'package:ringdrill/utils/time_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_io/io.dart';

enum NotificationAction { exerciseStop, showSettings, promptReshow }

/// Coarse status of the OS-level notification permission, as
/// observed during the most recent [NotificationService.init].
///
/// Surfaces enough detail for UI to render an actionable
/// re-engagement affordance (Settings link, banner, etc.) without
/// re-reading the plugin or re-requesting the OS permission. See
/// [ADR-0038](../../docs/adrs/0038-notification-consent-flow.md).
enum NotificationPermissionState {
  /// `init()` has not run yet, so no signal is available.
  unknown,

  /// `FlutterLocalNotificationsPlugin.initialize` returned `true`
  /// and `requestPermissions` resolved to `true`. Notifications
  /// will fire.
  granted,

  /// Plugin initialised but `requestPermissions` returned `false`
  /// (user declined, never granted, or revoked permission from
  /// OS Settings). Calling `requestPermissions` again is a no-op
  /// on iOS — recovery requires the user to flip the toggle in
  /// the OS Settings app.
  denied,

  /// `FlutterLocalNotificationsPlugin.initialize` reported a
  /// failure. Actionable bug on our side; reported to Sentry by
  /// the caller.
  pluginFailed,
}

class NotificationEvent {
  final DateTime when;
  final Exercise? exercise;
  final NotificationAction action;

  NotificationEvent({
    required this.when,
    required this.action,
    required this.exercise,
  });
}

class NotificationService {
  static const int idExerciseNotification = 1001;
  static const String idActionStopExercise = 'stop_exercise';
  static const String idActionShowSettings = 'show_settings';
  static final NotificationService _instance = NotificationService._internal();
  final StreamController<NotificationEvent> _eventController =
      StreamController<NotificationEvent>.broadcast();

  factory NotificationService() => _instance;

  NotificationService._internal();

  /// Current OS-level notification permission state, as observed
  /// during the most recent call to [init] that requested it. See
  /// [NotificationPermissionState] for the discrete values that drive
  /// UI affordances (re-engagement banners, settings deep-links).
  NotificationPermissionState get permissionState => _permissionState;
  NotificationPermissionState _permissionState =
      NotificationPermissionState.unknown;

  /// True when [permissionState] is `granted` — convenience for old
  /// call sites that just want to know whether notifications will
  /// fire.
  bool get isEnabled =>
      _permissionState == NotificationPermissionState.granted;

  /// True when [FlutterLocalNotificationsPlugin.initialize] reported
  /// success during the most recent [init] call. Distinct from
  /// [isEnabled], which also requires the user to have granted
  /// runtime permission. A user declining the iOS/Android permission
  /// prompt is expected behaviour (notifications stay off), not a
  /// bug — callers can use this getter to tell that from a genuine
  /// plugin-side failure that warrants a Sentry report.
  bool get isPluginInitialized => _pluginInitialized;
  bool _pluginInitialized = false;

  String? _currentChannelId;

  late bool _playSound;
  late bool _enableVibration;
  late bool _fullScreenIntent;
  late int _urgentThreshold;
  late AppLocalizations _localizations;

  int _urgentCount = 0;
  bool _wasUrgent = false;

  Timer? _watchDog;
  StreamSubscription? _subscription;

  bool get isStarted => _subscription != null;

  /// Expose stream of `ExerciseEvent`s
  Stream<NotificationEvent> get events => _eventController.stream;

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<bool> initFromPrefs([SharedPreferences? prefs]) async {
    prefs ??= await SharedPreferences.getInstance();
    final enabled = prefs.getBool(AppConfig.keyIsNotificationsEnabled) ?? true;
    if (enabled) {
      final playSound =
          prefs.getBool(AppConfig.keyNotificationPlaySound) ?? true;
      final vibrateEnabled =
          prefs.getBool(AppConfig.keyIsNotificationVibrateEnabled) ?? true;
      final isFullScreenIntentEnabled =
          prefs.getBool(AppConfig.keyIsNotificationFullScreenIntentEnabled) ??
          false;
      final threshold =
          prefs.getInt(AppConfig.keyUrgentNotificationThreshold) ?? 2;
      // Defer the OS permission prompt to the dedicated pre-prompt
      // flow (see ADR-0038) — `initFromPrefs` is called from boot
      // and from the Settings page where firing the OS dialog would
      // be jarring.
      final consentAsked =
          prefs.getBool(AppConfig.keyNotificationConsentAsked) ?? false;
      return init(
        playSound: playSound,
        enableVibration: vibrateEnabled,
        fullScreenIntent: isFullScreenIntentEnabled,
        urgentThreshold: threshold,
        requestPermissions: consentAsked,
      );
    }
    await cancel(); // Disable notifications
    return false;
  }

  // Initialize notifications. Pass [requestPermissions] = `false` to
  // attach the plugin without triggering the iOS/Android system
  // permission dialog — used during the deferred-consent flow in
  // ADR-0038, where the OS prompt only fires after the user has
  // accepted the in-app rationale.
  Future<bool> init({
    required bool playSound,
    required bool enableVibration,
    required bool fullScreenIntent,
    required int urgentThreshold,
    bool requestPermissions = true,
  }) async {
    _wasUrgent = false;
    _urgentCount = 0;
    _playSound = playSound;
    _enableVibration = enableVibration;
    _fullScreenIntent = fullScreenIntent;
    _urgentThreshold = urgentThreshold;

    _localizations = await _loadLocalization();

    await _init(requestPermissions: requestPermissions);

    if (ExerciseService().last != null) {
      _notify(ExerciseService().last!);
    }

    return _permissionState == NotificationPermissionState.granted;
  }

  Future<void> _init({required bool requestPermissions}) async {
    await cancel();

    // Generate a dynamic notification channel ID based on settings
    _currentChannelId = _generateChannelId();

    // Android initialization
    const AndroidInitializationSettings androidInitializationSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    // iOS/macOS initialization
    final DarwinInitializationSettings darwinInitializationSettings =
        DarwinInitializationSettings(
          requestSoundPermission: false,
          requestBadgePermission: false,
          requestAlertPermission: false,
          notificationCategories: [
            DarwinNotificationCategory(
              _localizations.exerciseNotifications,
              actions: <DarwinNotificationAction>[
                DarwinNotificationAction.plain(
                  idActionStopExercise,
                  _localizations.stopExercise,
                  options: <DarwinNotificationActionOption>{
                    DarwinNotificationActionOption.foreground,
                  },
                ),
                DarwinNotificationAction.plain(
                  idActionShowSettings,
                  _localizations.settings,
                  options: <DarwinNotificationActionOption>{
                    DarwinNotificationActionOption.foreground,
                  },
                ),
              ],
              options: const <DarwinNotificationCategoryOption>{
                DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
              },
            ),
          ],
        );

    final LinuxInitializationSettings linuxInitializationSettings =
        LinuxInitializationSettings(
          defaultActionName: _localizations.openNotification,
        );

    final InitializationSettings initializationSettings =
        InitializationSettings(
          android: androidInitializationSettings,
          iOS: darwinInitializationSettings,
          macOS: darwinInitializationSettings,
          linux: linuxInitializationSettings,
        );

    final bool? success = await _flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          _onDidReceiveBackgroundNotificationResponse,
    );

    _pluginInitialized = success == true;

    if (success != true) {
      _permissionState = NotificationPermissionState.pluginFailed;
      return;
    }

    if (!requestPermissions) {
      // Plugin attached but the OS permission prompt is deferred to
      // the in-app rationale (ADR-0038), or this is an internal
      // channel-rebuild after a `_wasUrgent` flip. Leave
      // `_permissionState` alone so a previously-granted state is
      // preserved across the rebuild.
      return;
    }

    bool granted = false;
    // Workaround to prevent lazy permission request on Darwin platforms
    if (Platform.isAndroid) {
      granted =
          await _flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    } else if (Platform.isIOS) {
      granted =
          await _flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    } else if (Platform.isMacOS) {
      granted =
          await _flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                MacOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    } else {
      // Other platforms (Linux, Windows) do not gate notifications
      // behind a runtime permission. Treat plugin success as the
      // grant signal.
      granted = true;
    }

    _permissionState = granted
        ? NotificationPermissionState.granted
        : NotificationPermissionState.denied;
  }

  Future<AppLocalizations> _loadLocalization() async {
    // `Intl.getCurrentLocale()` mirrors the OS locale, which on some
    // Android builds still reports the legacy `no_NO` form. Feeding
    // that straight to the delegate throws (see crash report
    // 7577434203 — `unsupported locale "no_NO"`). Resolve through the
    // shared helper so legacy Norwegian codes land on `nb` and
    // unsupported languages fall back to English.
    final language = languageOfLocaleTag(Intl.getCurrentLocale());
    final candidate = Locale(language);
    final locale = AppLocalizations.delegate.isSupported(candidate)
        ? candidate
        : const Locale('en');
    return AppLocalizations.delegate.load(locale);
  }

  String _generateChannelId() {
    // Combine the parameters into a unique string and hash it
    return 'exercise_channel_${_wasUrgent ? 1 : 0}${_playSound ? 1 : 0}${_enableVibration ? 1 : 0}${_fullScreenIntent ? 1 : 0}';
  }

  void _onDidReceiveNotificationResponse(NotificationResponse details) {
    _handleAction(details);
  }

  static void _handleAction(NotificationResponse details) {
    switch (details.actionId) {
      case idActionStopExercise:
        {
          ExerciseService().stop();
          final service = NotificationService();
          unawaited(service.cancel());
          service._eventController.add(
            NotificationEvent(
              when: DateTime.now(),
              action: NotificationAction.exerciseStop,
              exercise: ExerciseService().exercise,
            ),
          );
          break;
        }
      case idActionShowSettings:
        {
          final service = NotificationService();
          service._eventController.add(
            NotificationEvent(
              when: DateTime.now(),
              action: NotificationAction.showSettings,
              exercise: ExerciseService().exercise,
            ),
          );
          break;
        }
      default:
        throw UnimplementedError(
          "Notification action id "
          "'${details.actionId}' not implemented",
        );
    }
  }

  @pragma('vm:entry-point')
  static void _onDidReceiveBackgroundNotificationResponse(
    NotificationResponse details,
  ) {
    // TODO: Does this work in the background?
    _handleAction(details);
  }

  // Start listening to ExerciseService events and show notifications
  void start() {
    // Subscribe to the exercise event stream
    _subscription = ExerciseService().events.listen((ExerciseEvent event) {
      _notify(event);
    });
    _watchDog = Timer.periodic(Duration(seconds: 1), (_) async {
      final service = ExerciseService();
      if (service.isStarted) {
        final ids = await _flutterLocalNotificationsPlugin
            .getActiveNotifications();
        if (ids.isEmpty) {
          _eventController.add(
            NotificationEvent(
              when: DateTime.now(),
              action: NotificationAction.promptReshow,
              exercise: service.exercise,
            ),
          );
        }
      }
    });
  }

  Future<void> stop() async {
    _subscription?.cancel();
    _subscription = null;
    _watchDog?.cancel();
    _watchDog = null;
    // Cancel any active notification
    await cancel();
  }

  Future<void> cancel() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  // Show or update a notification based on the ExerciseEvent
  Future<void> _notify(ExerciseEvent event) async {
    if (event.isDone) {
      _urgentCount = 0;
      _wasUrgent = false;
      // Manual stop: drop every notification, the user already
      // confirmed end-of-exercise via the stop button.
      //
      // Auto-stop (endTime / totalTime expired): swap the ongoing
      // progress notification for a persistent, dismissible "finished"
      // notification. It stays visible until the user taps or swipes
      // it — which is what the user asked for.
      if (!event.autoStopped) {
        return cancel();
      }
      return _notifyAutoStopped(event);
    }
    bool isUrgent = !event.isDone && event.remainingTime <= _urgentThreshold;

    if (isUrgent) {
      _urgentCount++;
      // Only use urgent notification the first time threshold is passed
      isUrgent = _urgentCount == 1;
    } else {
      _urgentCount = 0;
    }

    if (_wasUrgent != isUrgent) {
      _wasUrgent = isUrgent;
      // Channel-rebuild only — do not re-prompt the user. The
      // previous permission state is preserved (ADR-0038).
      await _init(requestPermissions: false);
    }

    final androidNotificationDetails = AndroidNotificationDetails(
      _currentChannelId!,
      'Exercise Notifications',
      channelDescription: 'Updates for ongoing exercises',
      ongoing: true,
      showWhen: true,
      autoCancel: false,
      channelBypassDnd: true,
      fullScreenIntent: isUrgent ? _fullScreenIntent : false,
      // NOTE: On Garmin smart watches does not show
      // notifications with Priority.defaultPriority
      priority: isUrgent ? Priority.max : Priority.high,
      importance: isUrgent ? Importance.max : Importance.defaultImportance,
      playSound: isUrgent ? _playSound : false,
      enableVibration: isUrgent ? _enableVibration : false,
      visibility: NotificationVisibility.public,
      category: isUrgent
          ? AndroidNotificationCategory.alarm
          : AndroidNotificationCategory.progress,
      audioAttributesUsage: isUrgent
          ? AudioAttributesUsage.alarm
          : AudioAttributesUsage.notification,
      actions: [
        AndroidNotificationAction(
          idActionStopExercise,
          _localizations.stopExercise,
          showsUserInterface: true,
          cancelNotification: false,
        ),
        AndroidNotificationAction(
          idActionShowSettings,
          _localizations.settings,
          showsUserInterface: true,
          cancelNotification: false,
        ),
      ],
    );

    NotificationDetails platformNotificationDetails = NotificationDetails(
      android: androidNotificationDetails,
    );

    // Display or update the notification
    await _flutterLocalNotificationsPlugin.show(
      id: idExerciseNotification,
      title: event.exercise.name,
      body: _format(event),
      notificationDetails: platformNotificationDetails,
    );
  }

  /// Posts the "exercise finished" notification used when the service
  /// auto-stops. Unlike the in-progress notification this one is NOT
  /// ongoing — the user can swipe it away or tap it — and uses the
  /// alarm category + sound + vibration so it actually grabs
  /// attention when the app is in the background.
  Future<void> _notifyAutoStopped(ExerciseEvent event) async {
    // The "urgent" channel is reused so the audio attributes + DnD
    // bypass already configured for last-minute warnings carry over.
    // We force `_wasUrgent` to true so `_init()` rebuilds the channel
    // with sound/vibration enabled before posting.
    if (!_wasUrgent) {
      _wasUrgent = true;
      // Channel-rebuild only — see comment in `_notify`.
      await _init(requestPermissions: false);
    }
    final androidNotificationDetails = AndroidNotificationDetails(
      _currentChannelId!,
      'Exercise Notifications',
      channelDescription: 'Updates for ongoing exercises',
      // NOT ongoing — the user must be able to dismiss it. Swipe and
      // tap both clear it; autoCancel covers the tap case.
      ongoing: false,
      autoCancel: true,
      showWhen: true,
      channelBypassDnd: true,
      // No fullScreenIntent: the exercise is already over, we don't
      // need to wake the screen, just leave a visible record.
      fullScreenIntent: false,
      priority: Priority.high,
      importance: Importance.max,
      playSound: _playSound,
      enableVibration: _enableVibration,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      // No actions: there is nothing left to do but acknowledge.
    );

    final platformNotificationDetails = NotificationDetails(
      android: androidNotificationDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      id: idExerciseNotification,
      title: _localizations.exerciseAutoStoppedTitle,
      body: _localizations.exerciseAutoStoppedBody(event.exercise.name),
      notificationDetails: platformNotificationDetails,
    );
  }

  String _format(ExerciseEvent e) {
    final name = e.getState(_localizations);
    return [
      "${_localizations.round(1)} ${e.currentRound + 1}: $name",
      if (!e.isDone) _localizations.minutesLeft(e.remainingTime),
      if (e.isPending) _localizations.timeToStart(e.nextTimeOfDay.formal()),
      if (e.isRunning) _localizations.timeToNext(e.nextTimeOfDay.formal()),
      if (e.isDone) _localizations.minute(e.elapsedTime),
    ].join(' | ');
  }

  /// Clean up resources when not needed
  void dispose() {
    stop();
    _eventController.close();
  }
}
