import 'dart:async';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/utils/app_config.dart';
import 'package:ringdrill/utils/time_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum NotificationAction { exerciseStop, showSettings, promptReshow }

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

  bool get isEnabled => _enabled;
  bool _enabled = false;

  String? _currentChannelId;

  late bool _playSound;
  late bool _enableVibration;
  late bool _fullScreenIntent;
  late int _urgentThreshold;

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
      return init(
        playSound: playSound,
        enableVibration: vibrateEnabled,
        fullScreenIntent: isFullScreenIntentEnabled,
        urgentThreshold: threshold,
      );
    }
    await cancel(); // Disable notifications
    return false;
  }

  // Initialize notifications
  Future<bool> init({
    required bool playSound,
    required bool enableVibration,
    required bool fullScreenIntent,
    required int urgentThreshold,
  }) async {
    _wasUrgent = false;
    _urgentCount = 0;
    _playSound = playSound;
    _enableVibration = enableVibration;
    _fullScreenIntent = fullScreenIntent;
    _urgentThreshold = urgentThreshold;

    await _init();

    if (ExerciseService().last != null) {
      _notify(ExerciseService().last!);
    }

    return _enabled;
  }

  Future<void> _init() async {
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
              'Exercise Notifications',
              actions: <DarwinNotificationAction>[
                DarwinNotificationAction.plain(
                  idActionStopExercise,
                  'Stop Exercise',
                  options: <DarwinNotificationActionOption>{
                    DarwinNotificationActionOption.foreground,
                  },
                ),
                DarwinNotificationAction.plain(
                  idActionShowSettings,
                  'Settings',
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
        LinuxInitializationSettings(defaultActionName: 'Open notification');

    final InitializationSettings initializationSettings =
        InitializationSettings(
          android: androidInitializationSettings,
          iOS: darwinInitializationSettings,
          macOS: darwinInitializationSettings,
          linux: linuxInitializationSettings,
        );

    final bool? success = await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          _onDidReceiveBackgroundNotificationResponse,
    );

    if (success == true) {
      // Workaround to prevent lazy permission request on Darwin platforms
      if (Platform.isAndroid) {
        _enabled =
            await _flutterLocalNotificationsPlugin
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >()
                ?.requestNotificationsPermission() ??
            false;
      } else if (Platform.isIOS) {
        _enabled =
            await _flutterLocalNotificationsPlugin
                .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin
                >()
                ?.requestPermissions(alert: true, badge: true, sound: true) ??
            false;
      } else if (Platform.isMacOS) {
        _enabled =
            await _flutterLocalNotificationsPlugin
                .resolvePlatformSpecificImplementation<
                  MacOSFlutterLocalNotificationsPlugin
                >()
                ?.requestPermissions(alert: true, badge: true, sound: true) ??
            false;
      }
    }
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
        final ids =
            await _flutterLocalNotificationsPlugin.getActiveNotifications();
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
      return cancel();
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
      await _init();
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
      category:
          isUrgent
              ? AndroidNotificationCategory.alarm
              : AndroidNotificationCategory.progress,
      audioAttributesUsage:
          isUrgent
              ? AudioAttributesUsage.alarm
              : AudioAttributesUsage.notification,
      actions: [
        AndroidNotificationAction(
          idActionStopExercise,
          'Stop Exercise',
          showsUserInterface: true,
          cancelNotification: false,
        ),
        AndroidNotificationAction(
          idActionShowSettings,
          'Settings',
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
      idExerciseNotification,
      event.exercise.name,
      _format(event),
      platformNotificationDetails,
    );
  }

  String _format(ExerciseEvent e) {
    return [
      "Round ${e.currentRound + 1}: ${e.phase.abbr}",
      if (!e.isDone) "${e.remainingTime} min left",
      if (e.isPending) "${e.nextTimeOfDay.formal()} start",
      if (e.isRunning) "${e.nextTimeOfDay.formal()} next",
      if (e.isDone) "${e.elapsedTime} min",
    ].join(' | ');
  }

  /// Clean up resources when not needed
  void dispose() {
    stop();
    _eventController.close();
  }
}
