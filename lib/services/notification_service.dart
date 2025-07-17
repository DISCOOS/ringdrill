import 'dart:async';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/services/exercise_service.dart';

class NotificationService {
  static const int idExerciseNotification = 1001;
  static const String idActionStopExercise = 'stop_exercise';
  static final NotificationService _instance = NotificationService._internal();

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

  StreamSubscription? _subscription;

  bool get isStarted => _subscription != null;

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

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
    if (details.actionId == idActionStopExercise) {
      ExerciseService().stop();
      unawaited(cancel());
    }
  }

  @pragma('vm:entry-point')
  static void _onDidReceiveBackgroundNotificationResponse(
    NotificationResponse details,
  ) {
    if (details.actionId == idActionStopExercise) {
      // TODO: Does this work in the background?
      //  I do not think so since ExerciseService is not run in the background
      ExerciseService().stop();
    }
  }

  // Start listening to ExerciseService events and show notifications
  void start() {
    // Subscribe to the exercise event stream
    _subscription = ExerciseService().events.listen((ExerciseEvent event) {
      _notify(event);
    });
  }

  Future<void> stop() async {
    _subscription?.cancel();
    _subscription = null;
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
    bool isUrgent =
        !event.isDone && event.remainingTime.abs() <= _urgentThreshold;

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
      if (!e.isDone) "${e.nextTimeOfDay.tuple()} next",
      if (e.isDone) "${e.elapsedTime} min",
    ].join(' | ');
  }
}
