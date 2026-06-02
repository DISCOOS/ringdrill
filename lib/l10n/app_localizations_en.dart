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
  String get getReliableNotifications => 'Get reliable notifications';

  @override
  String get noReliableNotificationsReason =>
      'Local notifications aren’t fully supported on the web. Browsers can’t run our code in the background to trigger precise alerts, so timing and reliability are limited. For dependable alerts, use the RingDrill mobile app.';

  @override
  String get useMobileAppNudge =>
      'Use the RingDrill app for the best notification support.';

  @override
  String get getOnAndroid => 'On Android';

  @override
  String get getOniOS => 'On iOS';

  @override
  String get getOnDesktop => 'On Desktop';

  @override
  String get openInApp => 'Open the app';

  @override
  String get installWebApp => 'Install web app';

  @override
  String get continueOnWeb => 'Continue on web';

  @override
  String get confirm => 'CONFIRM';

  @override
  String get dismiss => 'Dismiss';

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
  String get fileNameHint => 'MyProgram';

  @override
  String get invalidFileName => 'Invalid file name. Please try again.';

  @override
  String openSuccess(Object name) {
    return 'Open \"$name\" was successful!';
  }

  @override
  String openFailure(Object name) {
    return 'Open \"$name\" failed. Please try again.';
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
  String sendToSuccess(Object name) {
    return 'Sent \"$name\" successfully!';
  }

  @override
  String sendToFailure(Object name) {
    return 'Sending \"$name\" failed. Please try again.';
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
  String get selectExercises => 'Select exercises';

  @override
  String get showExercises => 'Show exercises';

  @override
  String get filter => 'Filter';

  @override
  String get filterShowOnMap => 'Show on map';

  @override
  String get showAll => 'Show all';

  @override
  String get showMore => 'Show more';

  @override
  String get showLess => 'Show less';

  @override
  String get hideAll => 'Hide all';

  @override
  String get showLabels => 'Show labels';

  @override
  String get hideLabels => 'Hide labels';

  @override
  String get markerTypes => 'Marker types';

  @override
  String get showStations => 'Show stations';

  @override
  String get showRoleplays => 'Show roleplays';

  @override
  String get filterActiveCombined => 'Filter active';

  @override
  String exercisesShownOfTotal(int shown, int total) {
    return 'Showing $shown of $total exercises';
  }

  @override
  String importSuccess(Object name) {
    return 'Program \"$name\" imported successfully!';
  }

  @override
  String importFailure(Object name) {
    return 'Failed to import \"$name\". Please try again.';
  }

  @override
  String program(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Programs',
      one: 'Program',
      zero: 'Program',
    );
    return '$_temp0';
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
  String get mapTab => 'Map';

  @override
  String get stationsTab => 'Stations';

  @override
  String get allExercises => 'All exercises';

  @override
  String showingStationsIn(String name) {
    return 'Showing stations in: $name';
  }

  @override
  String get noStationsInExercise => 'No stations in this exercise.';

  @override
  String get noStationsYet =>
      'No stations yet. Add a station from the Exercises tab.';

  @override
  String get stationName => 'Station Name';

  @override
  String get stationNameHint => 'Name this station';

  @override
  String get editStation => 'Edit Station';

  @override
  String get editTeam => 'Edit Team';

  @override
  String get teamName => 'Team name';

  @override
  String get numberOfMembers => 'Number of members';

  @override
  String get stationDescription => 'Station Description';

  @override
  String get programFile => 'Program file';

  @override
  String get openProgramHint =>
      'Do you want to open the program, or import exercises into current program?';

  @override
  String get openProgram => 'Open...';

  @override
  String get importProgram => 'Import...';

  @override
  String get exportProgram => 'Export...';

  @override
  String get sendToProgram => 'Send to...';

  @override
  String get shareProgram => 'Share...';

  @override
  String get feedback => 'Feedback...';

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
  String member(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'members',
      one: 'member',
      zero: 'member',
    );
    return '$_temp0';
  }

  @override
  String get teamNoExercises => 'This team isn\'t part of any exercise yet.';

  @override
  String get teamsOverview => 'Teams';

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
  String get commit => 'Commit';

  @override
  String get viewOnGithub => 'Open in GitHub';

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
  String get newExercise => 'New exercise';

  @override
  String get editExercise => 'Edit Exercise';

  @override
  String get stopExercise => 'Stop Exercise';

  @override
  String get exerciseAutoStoppedTitle => 'Exercise finished';

  @override
  String exerciseAutoStoppedBody(String exercise) {
    return 'End time for $exercise has passed.';
  }

  @override
  String exerciseAutoStoppedSnack(String exercise) {
    return '$exercise stopped automatically';
  }

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
  String get numberOfStations => 'Number of stations';

  @override
  String mustBeEqualToOrLessThanNumberOf(Object name) {
    return 'Must be equal or less than $name';
  }

  @override
  String mustBeEqualToOrGreaterThanNumberOf(Object name) {
    return 'Must be equal or greater than $name';
  }

  @override
  String stationsRevisitNote(int rounds, int stations) {
    return 'Each team will revisit some stations. With $rounds rounds and $stations stations every team passes through each station roughly $rounds/$stations times.';
  }

  @override
  String stationsUnderCoverageNote(int rounds, int stations) {
    return 'Each team will only visit $rounds of $stations stations during this exercise.';
  }

  @override
  String get confirmReduceStationsTitle => 'Reduce stations?';

  @override
  String confirmReduceStationsBody(int count) {
    return 'Reducing the number of stations will remove $count stations including their names, descriptions and positions. This cannot be undone. Continue?';
  }

  @override
  String get legacyOversizedExerciseNotice =>
      'This exercise was created before the current 12-value limit. Existing values are preserved, but reducing them is permanent and values above 12 must be lowered before saving.';

  @override
  String get pleaseEnterAValidNumber => 'Please enter a valid number';

  @override
  String get newPatchIsAvailable => 'New patch is available';

  @override
  String get updateRequired => 'Update required';

  @override
  String get restartNow => 'RESTART';

  @override
  String get restartAppToApplyNewPatch => 'Restart app to apply new patch';

  @override
  String get appUpdateAvailable => 'An update is available';

  @override
  String get appUpdatedRestarting => 'App updated, restarting...';

  @override
  String get appUpdatedPleaseCloseAndOpen =>
      'App updated, please close app and open again';

  @override
  String get forceUpdateTitle => 'Force update';

  @override
  String get forceUpdateSubtitle =>
      'Clears the browser cache and reloads. Use this if the app feels stuck on an old version.';

  @override
  String get forceUpdateConfirmTitle => 'Force update?';

  @override
  String get forceUpdateConfirmBody =>
      'This clears the browser cache for ringdrill and reloads the page. Plans and settings stored on this device are kept.';

  @override
  String get forceUpdateConfirmAction => 'Update now';

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
  String get zoomIn => 'Zoom in';

  @override
  String get zoomOut => 'Zoom out';

  @override
  String get locateMe => 'Show my position';

  @override
  String get locating => 'Locating…';

  @override
  String get locationServicesDisabled =>
      'Turn on location services to use this feature.';

  @override
  String get locationPermissionDenied => 'Location permission denied.';

  @override
  String get locationPermissionDeniedForever =>
      'Location permission is permanently denied. Enable it in system settings to show your position.';

  @override
  String get locationError => 'Could not determine your position.';

  @override
  String get searchHintStation => 'Station';

  @override
  String get searchHintExercise => 'Exercise';

  @override
  String get searchHintPlace => 'Place';

  @override
  String setPositionFor(String name) {
    return 'Set position for $name';
  }

  @override
  String get positionSaved => 'Position saved';

  @override
  String get stationGone =>
      'Could not find the station — it may have been removed.';

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
  String get phaseNow => 'Phase now';

  @override
  String get nextLabel => 'Next';

  @override
  String phaseEndsAt(String time) {
    return 'ends $time';
  }

  @override
  String remainingInPhase(String phase) {
    return 'Remaining in $phase';
  }

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
  String get elapsedLabel => 'So far';

  @override
  String get totalLabel => 'Total';

  @override
  String roundOfTotal(int current, int total) {
    return '$current of $total';
  }

  @override
  String hoursMinutesShort(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String get clockLabel => 'Now';

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

  @override
  String get library => 'Library';

  @override
  String get libraryMyPlans => 'My plans';

  @override
  String get libraryCatalog => 'Catalog';

  @override
  String get libraryOnlineTab => 'Online';

  @override
  String get libraryMyPlansSubtitle => 'Pick a saved plan to continue';

  @override
  String get libraryOnlineSubtitle =>
      'Get a plan from the shared online library';

  @override
  String get libraryFromFileSubtitle => 'Import a .drill file from your device';

  @override
  String get libraryEmptyMyPlans =>
      'You have no saved plans. Browse \'Online\' or \'New from file\' to get started.';

  @override
  String get libraryFromFilePickAction => 'Choose file';

  @override
  String get libraryFromFileHint => 'Pick a .drill file from your device';

  @override
  String get libraryCatalogBadge => 'From online library';

  @override
  String get planStatusLocal => 'Local';

  @override
  String get planStatusLocalTooltip => 'This plan lives only on your device';

  @override
  String get planStatusOnlineTooltip =>
      'This plan is linked to the online library';

  @override
  String get planStatusUnpublished => 'Unpublished';

  @override
  String get planStatusUnpublishedTooltip =>
      'Tap to publish your changes to the catalog';

  @override
  String get addExercisesMyPlansSubtitle =>
      'Pick a plan to pull exercises from';

  @override
  String get addExercisesFromFileSubtitle =>
      'Import exercises from a .drill file';

  @override
  String get addExercisesEmptyMyPlans => 'No other plans to pull from yet';

  @override
  String get librarySourceLocal => 'Local';

  @override
  String librarySourceImported(Object fileName) {
    return 'Imported from $fileName';
  }

  @override
  String librarySourceCatalog(Object slug) {
    return 'From catalog · $slug';
  }

  @override
  String get libraryActive => 'Active';

  @override
  String get libraryInstalled => 'In library';

  @override
  String get libraryInstall => 'Open';

  @override
  String get libraryRefresh => 'Refresh from catalog';

  @override
  String get libraryRename => 'Rename';

  @override
  String get libraryExport => 'Export as .drill';

  @override
  String get libraryPublish => 'Publish';

  @override
  String get libraryPublishAs => 'Publish as…';

  @override
  String get libraryDelete => 'Delete';

  @override
  String get libraryEmptyCatalog => 'Nothing online yet';

  @override
  String get libraryErrorLoad => 'Could not load online plans';

  @override
  String get installedFromLink => 'Plan installed from share link';

  @override
  String get libraryRetry => 'Retry';

  @override
  String get libraryCannotSwitchRunning =>
      'Stop the running exercise before changing plans.';

  @override
  String get openPlan => 'Open plan...';

  @override
  String get openPlanTooltip => 'Open plan';

  @override
  String get newPlanAction => 'New plan';

  @override
  String get newPlanNamePrompt => 'Name your new plan';

  @override
  String get create => 'Create';

  @override
  String get fromFileAction => 'New from file';

  @override
  String get addExercisesAction => 'Add exercises from...';

  @override
  String get addFromFile => 'From file';

  @override
  String get addFromAnotherPlan => 'From another of my plans';

  @override
  String get pickFile => 'Pick file...';

  @override
  String get confirmChangesTitle => 'Confirm changes';

  @override
  String get apply => 'Apply';

  @override
  String get noOtherLocalPlans => 'No other local plans yet';

  @override
  String get requiresActivePlan => 'Open or create a plan first';

  @override
  String get shareActivePlan => 'Copy URL';

  @override
  String get planUrlCopied => 'URL copied';

  @override
  String get sendToAction => 'Send to...';

  @override
  String get sendToActionButton => 'SEND TO...';

  @override
  String get exportAsDrill => 'Export as .drill';

  @override
  String get exportAction => 'EXPORT';

  @override
  String get importAction => 'IMPORT';

  @override
  String get selectExercisesAction => 'CHOOSE...';

  @override
  String get selectAll => 'SELECT ALL';

  @override
  String get selectNone => 'SELECT NONE';

  @override
  String get exportAllExercisesHint =>
      'All exercises are included. Tap \'CHOOSE...\' to pick specific ones.';

  @override
  String selectedOfTotal(int selected, int total) {
    return '$selected of $total selected';
  }

  @override
  String get publishActivePlan => 'Publish';

  @override
  String get publishAsActivePlan => 'Publish as...';

  @override
  String get defaultPlanName => 'Default plan';

  @override
  String get libraryMigrationNotice =>
      'Library and catalog are new. Your existing plan has been moved to Default plan and is still active.';

  @override
  String installedAndActivated(Object name) {
    return 'Installed and activated $name';
  }

  @override
  String openedAndActivated(Object name) {
    return 'Opened $name';
  }

  @override
  String get catalogConflictTitle => 'Catalog update conflict';

  @override
  String get catalogConflictBody =>
      'This catalog plan has local changes. Review the differences before choosing how to continue.';

  @override
  String get catalogConflictBodyLocalOnly =>
      'This catalog plan has local changes. The online version is unchanged. Review your local changes before choosing how to continue.';

  @override
  String get catalogConflictCancel => 'Cancel';

  @override
  String get catalogConflictOverwrite => 'Discard local changes';

  @override
  String get catalogConflictPublish => 'Publish my changes';

  @override
  String get catalogConflictFork => 'Fork as local plan';

  @override
  String catalogRefreshUpToDate(String name) {
    return '$name is already up to date';
  }

  @override
  String catalogRefreshUpdated(String name) {
    return 'Updated $name from the catalog';
  }

  @override
  String catalogRefreshReverted(String name) {
    return 'Discarded local changes to $name';
  }

  @override
  String get catalogRefreshCancelled => 'Catalog update cancelled';

  @override
  String get catalogRefreshForked => 'Saved a local copy';

  @override
  String get catalogRefreshPublished => 'Published your changes';

  @override
  String get catalogDiffAdded => 'Added';

  @override
  String get catalogDiffRemoved => 'Removed';

  @override
  String get catalogDiffModified => 'Modified';

  @override
  String get catalogDiffLocal => 'Your version';

  @override
  String get catalogDiffRemote => 'Catalog version';

  @override
  String get catalogDiffName => 'Plan name';

  @override
  String get catalogDiffDescription => 'Description';

  @override
  String get catalogDiffExercises => 'Exercises';

  @override
  String get catalogDiffTeams => 'Teams';

  @override
  String get catalogDiffSessions => 'Sessions';

  @override
  String get catalogServiceChecking => 'Checking';

  @override
  String get catalogServiceOnline => 'Online';

  @override
  String get catalogServiceUnavailable => 'Unavailable';

  @override
  String get catalogServiceCorsBlocked => 'CORS blocked';

  @override
  String get catalogServiceCorsBlockedTooltip =>
      'The browser blocked the catalog request because the Netlify function does not allow this local origin. Use the deployed web app or enable CORS on the function for local web development.';

  @override
  String get libraryPublishTitle => 'Publish plan';

  @override
  String get libraryPublishAsTitle => 'Publish as';

  @override
  String get libraryPublishBody =>
      'This plan will be added to the public catalog. Anyone can install it, and anyone who has it can publish updates.';

  @override
  String get libraryPublishAsBody =>
      'Choose a slug for this version. If you change the slug on an already-published plan, a local copy will be created that tracks the new slug — the original stays linked to its current slug.';

  @override
  String get libraryPublishSlugLabel => 'Slug';

  @override
  String get libraryPublishSlugHelper =>
      'Lowercase letters, digits and hyphens only.';

  @override
  String get libraryPublishTagsLabel => 'Tags (comma separated)';

  @override
  String get libraryPublishSubmit => 'Publish';

  @override
  String libraryPublishSlugTaken(Object slug) {
    return 'Slug \'$slug\' is already in use by an unrelated plan. Choose a different slug.';
  }

  @override
  String get libraryPublishConflict =>
      'Someone updated this plan first. Try again.';

  @override
  String libraryPublishSuccess(Object name) {
    return 'Published $name';
  }

  @override
  String get libraryPublishNoChange => 'No changes to publish';

  @override
  String get libraryPublishFailed => 'Could not publish plan';

  @override
  String get rotationShareEachRound => 'Each round';

  @override
  String get rotationShareLegendPhases => 'drill | eval | roll / inbound';

  @override
  String get rotationShareTitle => 'Rotation (time of day)';

  @override
  String get rotationShareNext => 'next';

  @override
  String get rotationShareReturn => 'return';

  @override
  String shareNoteRevisits(int rounds, int stations) {
    return 'Note: $rounds rounds across $stations stations means each team will revisit some stations.';
  }

  @override
  String shareNoteUnderCoverage(int rounds, int stations) {
    return 'Note: $rounds rounds across $stations stations means each team will only visit some stations.';
  }

  @override
  String get exerciseCopied => 'Exercise copied to clipboard';

  @override
  String get exerciseCopyTooltip => 'Copy exercise';

  @override
  String roleplay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Roleplays',
      one: 'Roleplay',
      zero: 'Roleplay',
    );
    return '$_temp0';
  }

  @override
  String get rolePlaysTab => 'RolePlays';

  @override
  String get roleSection => 'Role';

  @override
  String get rolePlayScreenTitle => 'Roleplay';

  @override
  String get castSection => 'Played by';

  @override
  String get addCast => 'Add cast';

  @override
  String get editCast => 'Edit cast';

  @override
  String get clearCast => 'Clear cast';

  @override
  String get castRoster => 'Cast roster';

  @override
  String get newActor => 'New actor';

  @override
  String castedAs(String names) {
    return 'Cast as: $names';
  }

  @override
  String alreadyCastAs(String name) {
    return 'Already cast as $name';
  }

  @override
  String castPickerTitle(String role) {
    return 'Cast: $role';
  }

  @override
  String get castPrivateHint => 'Stays on this device';

  @override
  String roleSubtitleStation(String name) {
    return 'Station: $name';
  }

  @override
  String roleSubtitleExercise(String name) {
    return 'Exercise: $name';
  }

  @override
  String get noActorsInRoster => 'No actors yet. Tap + New actor to add one.';

  @override
  String get noActiveProgramHint =>
      'No active program. Open or create one in the Exercises tab.';

  @override
  String get noSignalement => 'No description';

  @override
  String get noBackground => 'No background';

  @override
  String get noBehavior => 'No behaviour';

  @override
  String get noStationAssigned => 'No station';

  @override
  String get noRolesInProgram => 'No roles yet. Tap + to add the first one.';

  @override
  String get noRolesInExercise => 'No roles in this exercise.';

  @override
  String get showAllRoles => 'Show all';

  @override
  String showingRolesIn(String exercise) {
    return 'Showing roles in: $exercise';
  }

  @override
  String castDeleteBlocked(int count) {
    return 'Cast in $count role(s). Clear before deleting.';
  }

  @override
  String get confirmReduceRoles => '(placeholder)';

  @override
  String get unknownRole => 'Unknown role';

  @override
  String get roleName => 'Name';

  @override
  String get roleAge => 'Age';

  @override
  String get optional => 'Optional';

  @override
  String get ageRange => 'Age must be between 0 and 120';

  @override
  String get stationLabel => 'Station';

  @override
  String get actorRealName => 'Full name';

  @override
  String get actorPhone => 'Phone';

  @override
  String get actorNotes => 'Notes';

  @override
  String get deleteActor => 'Delete actor';

  @override
  String confirmDeleteActor(String name) {
    return 'This will delete $name from the actor roster. Continue?';
  }

  @override
  String get addRolePlay => 'Add role';

  @override
  String get newRolePlayTitle => 'New role';

  @override
  String get editRolePlayTitle => 'Edit role';

  @override
  String get stationRolesSection => 'Roles';

  @override
  String get noRolesAtThisStation => 'No roles at this post';

  @override
  String get roleSignalement => 'Signalement';

  @override
  String get roleBackground => 'Background';

  @override
  String get roleBehavior => 'Behaviour';

  @override
  String castedByLine(String name) {
    return 'Played by $name';
  }

  @override
  String get noCastLine => 'No actor selected';

  @override
  String get briefScreenTitle => 'Brief';

  @override
  String get briefAudienceParticipant => 'Participant';

  @override
  String get briefAudienceInstructor => 'Instructor';

  @override
  String get briefAudienceDirector => 'Director';

  @override
  String get briefAudienceLabel => 'Audience';

  @override
  String get briefPrint => 'Print';

  @override
  String get briefSearch => 'Search in brief';

  @override
  String get briefSearchHint => 'Search';

  @override
  String get briefSearchNoMatches => 'No matches';

  @override
  String briefRenderError(String error) {
    return 'Could not render brief: $error';
  }

  @override
  String get briefMissingProgram => 'No active program';

  @override
  String get briefMissingExercise => 'Exercise not found';

  @override
  String get briefToc => 'Contents';

  @override
  String get briefAction => 'Open brief';

  @override
  String get briefClose => 'Close';

  @override
  String get briefDragHandle => 'Drag to close';

  @override
  String get briefPerStation => 'per station';

  @override
  String get briefRingRoute => 'Ring route';

  @override
  String get briefCodeCopied => 'Copied';

  @override
  String get briefCodeCopyTooltip => 'Copy';

  @override
  String briefSearchMatchCount(int current, int total) {
    return '$current of $total';
  }

  @override
  String get briefSearchNextMatch => 'Next match';

  @override
  String get briefSearchPreviousMatch => 'Previous match';

  @override
  String get briefStationNoPosition => 'no position';

  @override
  String get briefCopyMarkdown => 'Copy as markdown';

  @override
  String get briefMarkdownCopied => 'Brief copied as markdown';

  @override
  String get briefOpenToc => 'Contents';

  @override
  String get moreActions => 'More actions';

  @override
  String get drillPlayerClose => 'Close';

  @override
  String get drillPlayerStartingIn => 'Starting in';

  @override
  String drillPlayerRoundOf(int current, int total) {
    return 'Round $current / $total';
  }

  @override
  String drillPlayerStartingInWithCountdown(String time) {
    return 'Starts in $time';
  }

  @override
  String get detailEmptyExercise => 'Select an exercise';

  @override
  String get detailEmptyStation => 'Select a station to see details';

  @override
  String get detailEmptyRolePlay => 'Select a role';

  @override
  String get appUserRoleSectionTitle => 'My role';

  @override
  String get appUserRoleSectionDescription =>
      'Choose your staff role. Sets the default level of detail shown in briefs.';

  @override
  String get newRole => 'New role';

  @override
  String get pickExerciseForRole => 'Select exercise';

  @override
  String get detailEmptyTeam => 'Select a team';
}
