// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'RingDrill';

  @override
  String get appDescription =>
      'RingDrill makes it easy to plan and manage station-based ring exercises – commonly used in tactical, emergency, or operational training scenarios.';

  @override
  String get developedBy => 'Developed By';

  @override
  String get website => 'Website';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get termsOfService => 'Terms Of Service';

  @override
  String get contactSupport => 'Contact Support';

  @override
  String get appAnalyticsConsent => 'App Analytics Consent';

  @override
  String get appAnalyticsConsentMessage =>
      'We use analytics to improve the app experience by collecting crash reports and general usage data from your device.';

  @override
  String get appAnalyticsConsentOptIn =>
      'You can choose whether to enable this feature now or later in the settings.';

  @override
  String get appAnalyticsConsentCollectedData =>
      'This includes information about your device (e.g., device model, OS version) and crash reports in case of failures. This data is sent to and processed by Sentry.io.';

  @override
  String get learnMoreAboutDataCollected => 'Learn More About Data Collected';

  @override
  String get allowAppAnalytics => 'Allow App Analytics';

  @override
  String get allowAppAnalyticsMessage =>
      'Enable collection of analytics and crash reports. This data is linked to your device, but not your identity.';

  @override
  String get confirm => 'CONFIRM';

  @override
  String get confirmDeleteExercise =>
      'This will delete the exercise. Do you want to continue?';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'CANCEL';

  @override
  String get yes => 'YES';

  @override
  String get no => 'NO';

  @override
  String get allow => 'ALLOW';

  @override
  String get decline => 'DECLINE';

  @override
  String get enterFileName => 'Enter File Name';

  @override
  String get fileNameHint => 'e.g., MyProgram';

  @override
  String get invalidFileName => 'Invalid file name. Please try again.';

  @override
  String openSuccess(Object name) {
    return 'Open \"$name\" was successful!';
  }

  @override
  String openFailure(Object name) {
    return 'Open failed. Please try again.';
  }

  @override
  String get exportedProgram => 'Exported Program';

  @override
  String exportSuccess(Object name) {
    return 'Export to \"$name\" was successful!';
  }

  @override
  String exportFailure(Object name) {
    return 'Export to \"$name\" failed. Please try again.';
  }

  @override
  String shareSuccess(Object name) {
    return 'Shared \"$name\" successfully!';
  }

  @override
  String shareFailure(Object name) {
    return 'Sharing \"$name\" failed. Please try again.';
  }

  @override
  String get sharedFileReceived =>
      'Choose [Open] to replace existing exercises completely, or [Import] to add to existing exercises, overwriting only if they already exist. What would you like to do?';

  @override
  String get storage => 'Storage';

  @override
  String get documents => 'Documents';

  @override
  String get downloads => 'Downloads';

  @override
  String get sdCard => 'SD Card';

  @override
  String get open => 'OPEN';

  @override
  String get import => 'OPEN';

  @override
  String get select => 'SELECT';

  @override
  String get selectDirectory => 'Select a directory';

  @override
  String get selectFile => 'Select file';

  @override
  String importSuccess(Object name) {
    return 'Program \"$name\" imported successfully!';
  }

  @override
  String importFailure(Object name) {
    return 'Failed to import \"$name\". Please try again.';
  }

  @override
  String exercise(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Exercises',
      one: 'Exercise',
      zero: 'Exercise',
    );
    return '$_temp0';
  }

  @override
  String get schedule => 'Schedule';

  @override
  String round(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Rounds',
      one: 'Round',
      zero: 'Round',
    );
    return '$_temp0';
  }

  @override
  String station(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Stations',
      one: 'Station',
      zero: 'Station',
    );
    return '$_temp0';
  }

  @override
  String get notStationsCreated => 'No stations created';

  @override
  String get stationName => 'Station Name';

  @override
  String get stationNameHint => 'Name this station';

  @override
  String get editStation => 'Edit Station';

  @override
  String get stationDescription => 'Station Description';

  @override
  String get openProgram => 'Open...';

  @override
  String get importProgram => 'Import...';

  @override
  String get exportProgram => 'Export...';

  @override
  String get stationDescriptionHint =>
      'Give a description of how this station should be executed';

  @override
  String team(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Teams',
      one: 'Team',
      zero: 'Team',
    );
    return '$_temp0';
  }

  @override
  String notification(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Notifications',
      one: 'Notification',
      zero: 'Notification',
    );
    return '$_temp0';
  }

  @override
  String get toggleNotificationDescription =>
      'Enable or disable local notifications for reminders and updates while using the app. Disabling this will stop sending all notifications immediately.';

  @override
  String get enableNotifications => 'Enable Notifications';

  @override
  String get enableNotificationsMessage =>
      'When enabled, you will receive reminders and updates via notifications.';

  @override
  String get setUrgentNotificationThreshold =>
      'Set Urgent Notification Threshold';

  @override
  String get setUrgentNotificationThresholdDescription =>
      'The number of minutes remaining before the next phase to show an urgent notification.';

  @override
  String get fullScreenNotifications => 'Full-Screen Notifications';

  @override
  String get fullScreenNotificationsDescription =>
      'Allow notifications to appear in full-screen mode for urgent updates, even when other apps are open.';

  @override
  String get playSoundWhenUrgent => 'Play Sound when urgent';

  @override
  String get playSoundWhenUrgentDescription =>
      'Toggle notification sounds on or off on urgent notifications.';

  @override
  String get vibrateWhenUrgent => 'Vibrate when urgent';

  @override
  String get vibrateWhenUrgentDescription =>
      'Enable or disable vibration for urgent notifications.';

  @override
  String get position => 'Position';

  @override
  String get settings => 'Settings';

  @override
  String get about => 'About';

  @override
  String get version => 'Version';

  @override
  String get noExercisesYet => 'No exercises yet!';

  @override
  String get teamRotations => 'Team rotations';

  @override
  String get stationRotations => 'Rotation on stations';

  @override
  String get save => 'SAVE';

  @override
  String get delete => 'DELETE';

  @override
  String get createExercise => 'Create Exercise';

  @override
  String get editExercise => 'Edit Exercise';

  @override
  String get stopExercise => 'Stop Exercise';

  @override
  String get deleteExercise => 'Delete Exercise';

  @override
  String get noRoundsScheduled => 'No rounds scheduled!';

  @override
  String get showNotification => 'Show notification';

  @override
  String get openNotification => 'Open notification';

  @override
  String get exerciseNotifications => 'Show notification';

  @override
  String stopExerciseFirst(Object exercise) {
    return 'Stop $exercise first!';
  }

  @override
  String get noLocation => 'No location';

  @override
  String get noDescription => 'No description';

  @override
  String get exerciseName => 'Exercise Name';

  @override
  String get pleaseEnterAName => 'Please enter a name';

  @override
  String get startTime => 'Start Time';

  @override
  String get numberOfRounds => 'Number of Rounds';

  @override
  String get numberOfTeams => 'Number of Teams';

  @override
  String mustBeEqualToOrLessThanNumberOf(Object name) {
    return 'Must be equal or less than $name';
  }

  @override
  String get pleaseEnterAValidNumber => 'Please enter a valid number';

  @override
  String get newPatchIsAvailable => 'New patch is available';

  @override
  String get updateRequired => 'Update required';

  @override
  String get restartAppToApplyNewPatch => 'Restart app to apply new patch';

  @override
  String get appUpdatedRestarting => 'App updated, restarting...';

  @override
  String get appUpdatedPleaseCloseAndOpen =>
      'App updated, please close app and open again';

  @override
  String get searchForPlaceOrLocation => 'Search for place or location';

  @override
  String searchFailed(Object error) {
    return 'Search failed: $error';
  }

  @override
  String get pickALocation => 'Pick a Location';

  @override
  String get switchToOSM => 'Switch to OSM';

  @override
  String get switchToTopo => 'Switch to Topo';

  @override
  String get selectAction => 'Select';

  @override
  String get analyticsEnabled => 'Analytics Enabled';

  @override
  String get analyticsDisabled => 'Analytics Disabled';

  @override
  String get analyticsIsAllowed =>
      'You have agreed to allow analytics data to be collected from your device.';

  @override
  String get analyticsIsDenied =>
      'You have opted out of analytics. No data will be collected from your device.';

  @override
  String get isRunning => 'is running';

  @override
  String get executionTime => 'Execution Time';

  @override
  String get evaluationTime => 'Evaluation Time';

  @override
  String get rotationTime => 'Rotation Time';

  @override
  String get pleaseEnterAValidTime => 'Please enter a valid time';

  @override
  String get isPending => 'is pending';

  @override
  String get isDone => 'is done';

  @override
  String get pending => 'Pending';

  @override
  String get execution => 'Execution';

  @override
  String get evaluation => 'Evaluation';

  @override
  String get rotation => 'Rotation';

  @override
  String get done => 'Done';

  @override
  String get wait => 'Wait';

  @override
  String get drill => 'Drill';

  @override
  String get eval => 'Eval';

  @override
  String get roll => 'Roll';

  @override
  String second(Object count) {
    return '$count sec';
  }

  @override
  String minute(Object count) {
    return '$count min';
  }

  @override
  String hour(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours',
      one: '1 hour',
      zero: 'now',
    );
    return '$_temp0';
  }

  @override
  String day(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
      zero: 'now',
    );
    return '$_temp0';
  }

  @override
  String week(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weeks',
      one: '1 week',
      zero: 'now',
    );
    return '$_temp0';
  }

  @override
  String month(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months',
      one: '1 month',
      zero: 'now',
    );
    return '$_temp0';
  }

  @override
  String year(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count years',
      one: '1 year',
      zero: 'now',
    );
    return '$_temp0';
  }

  @override
  String minutesLeft(Object count) {
    return '$count min left';
  }

  @override
  String timeToStart(Object time) {
    return '$time start';
  }

  @override
  String timeToNext(Object time) {
    return '$time next';
  }
}
