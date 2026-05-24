import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_nb.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('nb'),
  ];

  /// Label
  ///
  /// In en, this message translates to:
  /// **'RingDrill'**
  String get appName;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'RingDrill makes it easy to plan and manage station-based ring exercises – commonly used in tactical, emergency, or operational training scenarios.'**
  String get appDescription;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Developed By'**
  String get developedBy;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get website;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Terms Of Service'**
  String get termsOfService;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Contact Support'**
  String get contactSupport;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'App Analytics Consent'**
  String get appAnalyticsConsent;

  /// Message
  ///
  /// In en, this message translates to:
  /// **'We use analytics to improve the app experience by collecting crash reports and general usage data from your device.'**
  String get appAnalyticsConsentMessage;

  /// Message
  ///
  /// In en, this message translates to:
  /// **'You can choose whether to enable this feature now or later in the settings.'**
  String get appAnalyticsConsentOptIn;

  /// Message
  ///
  /// In en, this message translates to:
  /// **'This includes information about your device (e.g., device model, OS version) and crash reports in case of failures. This data is sent to and processed by Sentry.io.'**
  String get appAnalyticsConsentCollectedData;

  /// Message
  ///
  /// In en, this message translates to:
  /// **'Learn More About Data Collected'**
  String get learnMoreAboutDataCollected;

  /// Lable
  ///
  /// In en, this message translates to:
  /// **'Allow App Analytics'**
  String get allowAppAnalytics;

  /// Message
  ///
  /// In en, this message translates to:
  /// **'Enable collection of analytics and crash reports. This data is linked to your device, but not your identity.'**
  String get allowAppAnalyticsMessage;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Get reliable notifications'**
  String get getReliableNotifications;

  /// Message
  ///
  /// In en, this message translates to:
  /// **'Local notifications aren’t fully supported on the web. Browsers can’t run our code in the background to trigger precise alerts, so timing and reliability are limited. For dependable alerts, use the RingDrill mobile app.'**
  String get noReliableNotificationsReason;

  /// Message
  ///
  /// In en, this message translates to:
  /// **'Use the RingDrill app for the best notification support.'**
  String get useMobileAppNudge;

  /// No description provided for @getOnAndroid.
  ///
  /// In en, this message translates to:
  /// **'On Android'**
  String get getOnAndroid;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'On iOS'**
  String get getOniOS;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'On Desktop'**
  String get getOnDesktop;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Open the app'**
  String get openInApp;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Install web app'**
  String get installWebApp;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Continue on web'**
  String get continueOnWeb;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'CONFIRM'**
  String get confirm;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'DISMISS'**
  String get dismiss;

  /// Message
  ///
  /// In en, this message translates to:
  /// **'This will delete the exercise. Do you want to continue?'**
  String get confirmDeleteExercise;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'CANCEL'**
  String get cancel;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'YES'**
  String get yes;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'NO'**
  String get no;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'ALLOW'**
  String get allow;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'DECLINE'**
  String get decline;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Enter File Name'**
  String get enterFileName;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'MyProgram'**
  String get fileNameHint;

  /// Message
  ///
  /// In en, this message translates to:
  /// **'Invalid file name. Please try again.'**
  String get invalidFileName;

  /// Message
  ///
  /// In en, this message translates to:
  /// **'Open \"{name}\" was successful!'**
  String openSuccess(Object name);

  /// Message
  ///
  /// In en, this message translates to:
  /// **'Open \"{name}\" failed. Please try again.'**
  String openFailure(Object name);

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Exported Program'**
  String get exportedProgram;

  /// Message
  ///
  /// In en, this message translates to:
  /// **'Export to \"{name}\" was successful!'**
  String exportSuccess(Object name);

  /// Message
  ///
  /// In en, this message translates to:
  /// **'Export to \"{name}\" failed. Please try again.'**
  String exportFailure(Object name);

  /// Message
  ///
  /// In en, this message translates to:
  /// **'Sent \"{name}\" successfully!'**
  String sendToSuccess(Object name);

  /// Message
  ///
  /// In en, this message translates to:
  /// **'Sending \"{name}\" failed. Please try again.'**
  String sendToFailure(Object name);

  /// Message
  ///
  /// In en, this message translates to:
  /// **'Shared \"{name}\" successfully!'**
  String shareSuccess(Object name);

  /// Message
  ///
  /// In en, this message translates to:
  /// **'Sharing \"{name}\" failed. Please try again.'**
  String shareFailure(Object name);

  /// Message
  ///
  /// In en, this message translates to:
  /// **'Choose [Open] to replace existing exercises completely, or [Import] to add to existing exercises, overwriting only if they already exist. What would you like to do?'**
  String get sharedFileReceived;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get storage;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get documents;

  /// No description provided for @downloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get downloads;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'SD Card'**
  String get sdCard;

  /// BUTTON
  ///
  /// In en, this message translates to:
  /// **'OPEN'**
  String get open;

  /// BUTTON
  ///
  /// In en, this message translates to:
  /// **'OPEN'**
  String get import;

  /// BUTTON
  ///
  /// In en, this message translates to:
  /// **'SELECT'**
  String get select;

  /// No description provided for @selectDirectory.
  ///
  /// In en, this message translates to:
  /// **'Select a directory'**
  String get selectDirectory;

  /// No description provided for @selectFile.
  ///
  /// In en, this message translates to:
  /// **'Select file'**
  String get selectFile;

  /// Message
  ///
  /// In en, this message translates to:
  /// **'Select exercises'**
  String get selectExercises;

  /// Tooltip for the map command that opens the exercise-visibility filter
  ///
  /// In en, this message translates to:
  /// **'Show exercises'**
  String get showExercises;

  /// Action that makes every exercise visible on the map
  ///
  /// In en, this message translates to:
  /// **'Show all'**
  String get showAll;

  /// Action that hides every exercise on the map
  ///
  /// In en, this message translates to:
  /// **'Hide all'**
  String get hideAll;

  /// Banner shown above the stations map when one or more exercises have been hidden via the visibility filter. Mirrors the selectedOfTotal pattern used in import/export.
  ///
  /// In en, this message translates to:
  /// **'Showing {shown} of {total} exercises'**
  String exercisesShownOfTotal(int shown, int total);

  /// Message
  ///
  /// In en, this message translates to:
  /// **'Program \"{name}\" imported successfully!'**
  String importSuccess(Object name);

  /// Message
  ///
  /// In en, this message translates to:
  /// **'Failed to import \"{name}\". Please try again.'**
  String importFailure(Object name);

  /// Program with plurals
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Program} =1{Program} other{Programs}}'**
  String program(num count);

  /// Exercise with plurals
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Exercise} =1{Exercise} other{Exercises}}'**
  String exercise(num count);

  /// Exercise schedule
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get schedule;

  /// Current exercise round
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Round} =1{Round} other{Rounds}}'**
  String round(num count);

  /// Exercise station
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Station} =1{Station} other{Stations}}'**
  String station(num count);

  /// Message
  ///
  /// In en, this message translates to:
  /// **'No stations created'**
  String get notStationsCreated;

  /// Bottom-nav label for the Map tab (formerly Stations, renamed to reflect that it shows a map of the stations).
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get mapTab;

  /// Bottom-nav label for the new Stations list tab introduced in DESIGN-002.
  ///
  /// In en, this message translates to:
  /// **'Stations'**
  String get stationsTab;

  /// Default 'no filter' row at the top of the exercise picker on the Stations tab.
  ///
  /// In en, this message translates to:
  /// **'All exercises'**
  String get allExercises;

  /// Banner shown above the bottom-nav when the Stations list tab is filtered to a single exercise.
  ///
  /// In en, this message translates to:
  /// **'Showing stations in: {name}'**
  String showingStationsIn(String name);

  /// Empty-state shown in the Stations list when the active filter excludes every station.
  ///
  /// In en, this message translates to:
  /// **'No stations in this exercise.'**
  String get noStationsInExercise;

  /// Empty-state shown in the Stations list when the active plan has no stations at all.
  ///
  /// In en, this message translates to:
  /// **'No stations yet. Add a station from the Exercises tab.'**
  String get noStationsYet;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Station Name'**
  String get stationName;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Name this station'**
  String get stationNameHint;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Edit Station'**
  String get editStation;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Station Description'**
  String get stationDescription;

  /// Message
  ///
  /// In en, this message translates to:
  /// **'Program file'**
  String get programFile;

  /// Message
  ///
  /// In en, this message translates to:
  /// **'Do you want to open the program, or import exercises into current program?'**
  String get openProgramHint;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Open...'**
  String get openProgram;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Import...'**
  String get importProgram;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Export...'**
  String get exportProgram;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Send to...'**
  String get sendToProgram;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Share...'**
  String get shareProgram;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Feedback...'**
  String get feedback;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Give a description of how this station should be executed'**
  String get stationDescriptionHint;

  /// Team doing the exercise
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Team} =1{Team} other{Teams}}'**
  String team(num count);

  /// Team member, lowercase for use inline (e.g. '5 members')
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{member} =1{member} other{members}}'**
  String member(num count);

  /// Empty state shown on TeamScreen when the team is not in any exercise
  ///
  /// In en, this message translates to:
  /// **'This team isn\'t part of any exercise yet.'**
  String get teamNoExercises;

  /// AppBar title for the Teams tab
  ///
  /// In en, this message translates to:
  /// **'Teams'**
  String get teamsOverview;

  /// Parameterized message
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Notification} =1{Notification} other{Notifications}}'**
  String notification(num count);

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Enable or disable local notifications for reminders and updates while using the app. Disabling this will stop sending all notifications immediately.'**
  String get toggleNotificationDescription;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Enable Notifications'**
  String get enableNotifications;

  /// Message
  ///
  /// In en, this message translates to:
  /// **'When enabled, you will receive reminders and updates via notifications.'**
  String get enableNotificationsMessage;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Set Urgent Notification Threshold'**
  String get setUrgentNotificationThreshold;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'The number of minutes remaining before the next phase to show an urgent notification.'**
  String get setUrgentNotificationThresholdDescription;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Full-Screen Notifications'**
  String get fullScreenNotifications;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Allow notifications to appear in full-screen mode for urgent updates, even when other apps are open.'**
  String get fullScreenNotificationsDescription;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Play Sound when urgent'**
  String get playSoundWhenUrgent;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Toggle notification sounds on or off on urgent notifications.'**
  String get playSoundWhenUrgentDescription;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Vibrate when urgent'**
  String get vibrateWhenUrgent;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Enable or disable vibration for urgent notifications.'**
  String get vibrateWhenUrgentDescription;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get position;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// Message
  ///
  /// In en, this message translates to:
  /// **'No exercises yet!'**
  String get noExercisesYet;

  /// Label for list of team rotations
  ///
  /// In en, this message translates to:
  /// **'Team rotations'**
  String get teamRotations;

  /// Label for list of rotations on each station
  ///
  /// In en, this message translates to:
  /// **'Rotation on stations'**
  String get stationRotations;

  /// Button
  ///
  /// In en, this message translates to:
  /// **'SAVE'**
  String get save;

  /// Button
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get delete;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Create Exercise'**
  String get createExercise;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Edit Exercise'**
  String get editExercise;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Stop Exercise'**
  String get stopExercise;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Delete Exercise'**
  String get deleteExercise;

  /// Message
  ///
  /// In en, this message translates to:
  /// **'No rounds scheduled!'**
  String get noRoundsScheduled;

  /// Message
  ///
  /// In en, this message translates to:
  /// **'Show notification'**
  String get showNotification;

  /// Message
  ///
  /// In en, this message translates to:
  /// **'Open notification'**
  String get openNotification;

  /// Message
  ///
  /// In en, this message translates to:
  /// **'Show notification'**
  String get exerciseNotifications;

  /// Parameterized message
  ///
  /// In en, this message translates to:
  /// **'Stop {exercise} first!'**
  String stopExerciseFirst(Object exercise);

  /// Message
  ///
  /// In en, this message translates to:
  /// **'No location'**
  String get noLocation;

  /// Message
  ///
  /// In en, this message translates to:
  /// **'No description'**
  String get noDescription;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Exercise Name'**
  String get exerciseName;

  /// Message
  ///
  /// In en, this message translates to:
  /// **'Please enter a name'**
  String get pleaseEnterAName;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Start Time'**
  String get startTime;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Number of Rounds'**
  String get numberOfRounds;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Number of Teams'**
  String get numberOfTeams;

  /// Label for the number of stations field in the exercise setup form.
  ///
  /// In en, this message translates to:
  /// **'Number of stations'**
  String get numberOfStations;

  /// Parameterized message
  ///
  /// In en, this message translates to:
  /// **'Must be equal or less than {name}'**
  String mustBeEqualToOrLessThanNumberOf(Object name);

  /// Parameterized validation message shown when a numeric field must be at least another count.
  ///
  /// In en, this message translates to:
  /// **'Must be equal or greater than {name}'**
  String mustBeEqualToOrGreaterThanNumberOf(Object name);

  /// Informational note shown when an exercise has more rounds than stations.
  ///
  /// In en, this message translates to:
  /// **'Each team will revisit some stations. With {rounds} rounds and {stations} stations every team passes through each station roughly {rounds}/{stations} times.'**
  String stationsRevisitNote(int rounds, int stations);

  /// Informational note shown when an exercise has fewer rounds than stations.
  ///
  /// In en, this message translates to:
  /// **'Each team will only visit {rounds} of {stations} stations during this exercise.'**
  String stationsUnderCoverageNote(int rounds, int stations);

  /// Title for the confirmation dialog shown before removing stations from an existing exercise.
  ///
  /// In en, this message translates to:
  /// **'Reduce stations?'**
  String get confirmReduceStationsTitle;

  /// Body for the confirmation dialog shown before removing user-edited stations from an existing exercise.
  ///
  /// In en, this message translates to:
  /// **'Reducing the number of stations will remove {count} stations including their names, descriptions and positions. This cannot be undone. Continue?'**
  String confirmReduceStationsBody(int count);

  /// Banner shown in the exercise form when loading an older exercise whose team, station, or round count is above the current cap.
  ///
  /// In en, this message translates to:
  /// **'This exercise was created before the current 12-value limit. Existing values are preserved, but reducing them is permanent and values above 12 must be lowered before saving.'**
  String get legacyOversizedExerciseNotice;

  /// Message
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid number'**
  String get pleaseEnterAValidNumber;

  /// Message
  ///
  /// In en, this message translates to:
  /// **'New patch is available'**
  String get newPatchIsAvailable;

  /// Message
  ///
  /// In en, this message translates to:
  /// **'Update required'**
  String get updateRequired;

  /// Button
  ///
  /// In en, this message translates to:
  /// **'RESTART'**
  String get restartNow;

  /// Message
  ///
  /// In en, this message translates to:
  /// **'Restart app to apply new patch'**
  String get restartAppToApplyNewPatch;

  /// No description provided for @appUpdateAvailable.
  ///
  /// In en, this message translates to:
  /// **'An update is available'**
  String get appUpdateAvailable;

  /// Message
  ///
  /// In en, this message translates to:
  /// **'App updated, restarting...'**
  String get appUpdatedRestarting;

  /// Message
  ///
  /// In en, this message translates to:
  /// **'App updated, please close app and open again'**
  String get appUpdatedPleaseCloseAndOpen;

  /// Settings tile title for clearing browser cache and reloading the PWA
  ///
  /// In en, this message translates to:
  /// **'Force update'**
  String get forceUpdateTitle;

  /// Settings tile subtitle explaining the force-update action
  ///
  /// In en, this message translates to:
  /// **'Clears the browser cache and reloads. Use this if the app feels stuck on an old version.'**
  String get forceUpdateSubtitle;

  /// Confirmation dialog title for the force-update action
  ///
  /// In en, this message translates to:
  /// **'Force update?'**
  String get forceUpdateConfirmTitle;

  /// Confirmation dialog body for the force-update action
  ///
  /// In en, this message translates to:
  /// **'This clears the browser cache for ringdrill and reloads the page. Plans and settings stored on this device are kept.'**
  String get forceUpdateConfirmBody;

  /// Confirmation dialog action button for the force-update action
  ///
  /// In en, this message translates to:
  /// **'Update now'**
  String get forceUpdateConfirmAction;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Search for place or location'**
  String get searchForPlaceOrLocation;

  /// Parameterized message
  ///
  /// In en, this message translates to:
  /// **'Search failed: {error}'**
  String searchFailed(Object error);

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Pick a Location'**
  String get pickALocation;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Switch to OSM'**
  String get switchToOSM;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Switch to Topo'**
  String get switchToTopo;

  /// Tooltip for zoom in button on the map
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get zoomIn;

  /// Tooltip for zoom out button on the map
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get zoomOut;

  /// Tooltip for the 'locate me' button on the map
  ///
  /// In en, this message translates to:
  /// **'Show my position'**
  String get locateMe;

  /// Snackbar shown while the device is acquiring a GPS fix after the user taps 'locate me'
  ///
  /// In en, this message translates to:
  /// **'Locating…'**
  String get locating;

  /// Snackbar shown when the OS-level location switch is off
  ///
  /// In en, this message translates to:
  /// **'Turn on location services to use this feature.'**
  String get locationServicesDisabled;

  /// Snackbar shown when the user declines the location permission prompt
  ///
  /// In en, this message translates to:
  /// **'Location permission denied.'**
  String get locationPermissionDenied;

  /// Snackbar shown when location permission was previously denied with 'don't ask again' and must now be re-enabled from system settings
  ///
  /// In en, this message translates to:
  /// **'Location permission is permanently denied. Enable it in system settings to show your position.'**
  String get locationPermissionDeniedForever;

  /// Snackbar shown when fetching the current position fails for an unspecified reason
  ///
  /// In en, this message translates to:
  /// **'Could not determine your position.'**
  String get locationError;

  /// Prefix shown next to station name in search results
  ///
  /// In en, this message translates to:
  /// **'Station'**
  String get searchHintStation;

  /// Prefix shown next to exercise name in search results
  ///
  /// In en, this message translates to:
  /// **'Exercise'**
  String get searchHintExercise;

  /// Chip label shown next to geocoder hits in search results
  ///
  /// In en, this message translates to:
  /// **'Place'**
  String get searchHintPlace;

  /// Banner heading shown while picking a position for a station from the map
  ///
  /// In en, this message translates to:
  /// **'Set position for {name}'**
  String setPositionFor(String name);

  /// Snackbar shown after a station's position is saved via the map picker
  ///
  /// In en, this message translates to:
  /// **'Position saved'**
  String get positionSaved;

  /// Snackbar shown when saving a picked position fails because the station no longer exists
  ///
  /// In en, this message translates to:
  /// **'Could not find the station — it may have been removed.'**
  String get stationGone;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get selectAction;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Analytics Enabled'**
  String get analyticsEnabled;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Analytics Disabled'**
  String get analyticsDisabled;

  /// Message
  ///
  /// In en, this message translates to:
  /// **'You have agreed to allow analytics data to be collected from your device.'**
  String get analyticsIsAllowed;

  /// Message
  ///
  /// In en, this message translates to:
  /// **'You have opted out of analytics. No data will be collected from your device.'**
  String get analyticsIsDenied;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'is running'**
  String get isRunning;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Execution Time'**
  String get executionTime;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Evaluation Time'**
  String get evaluationTime;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Rotation Time'**
  String get rotationTime;

  /// Message
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid time'**
  String get pleaseEnterAValidTime;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'is pending'**
  String get isPending;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'is done'**
  String get isDone;

  /// Exercise is pending
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// Exercise is executing
  ///
  /// In en, this message translates to:
  /// **'Execution'**
  String get execution;

  /// Station execution is being evaluated
  ///
  /// In en, this message translates to:
  /// **'Evaluation'**
  String get evaluation;

  /// Station execution is being evaluated
  ///
  /// In en, this message translates to:
  /// **'Rotation'**
  String get rotation;

  /// Short for rotate to exercise is completed
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// Label for the hero cell showing the current exercise phase
  ///
  /// In en, this message translates to:
  /// **'Phase now'**
  String get phaseNow;

  /// Label for the hero cell showing upcoming phases
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get nextLabel;

  /// Caption under the remaining time, showing wall-clock time when current phase ends
  ///
  /// In en, this message translates to:
  /// **'ends {time}'**
  String phaseEndsAt(String time);

  /// Subtitle under the prominent remaining-time number in the Phase Now hero cell. {phase} is the current phase name (e.g. Drill, Eval, Roll).
  ///
  /// In en, this message translates to:
  /// **'Remaining in {phase}'**
  String remainingInPhase(String phase);

  /// Short for exercise is pending
  ///
  /// In en, this message translates to:
  /// **'Wait'**
  String get wait;

  /// Short for execute station exercise
  ///
  /// In en, this message translates to:
  /// **'Drill'**
  String get drill;

  /// Short for evaluate station execution
  ///
  /// In en, this message translates to:
  /// **'Eval'**
  String get eval;

  /// Short for rotate to next station in exercise
  ///
  /// In en, this message translates to:
  /// **'Roll'**
  String get roll;

  /// number of seconds
  ///
  /// In en, this message translates to:
  /// **'{count} sec'**
  String second(Object count);

  /// number of minutes
  ///
  /// In en, this message translates to:
  /// **'{count} min'**
  String minute(Object count);

  /// number of hours
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{now} =1{1 hour} other{{count} hours}}'**
  String hour(num count);

  /// number of days
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{now} =1{1 day} other{{count} days}}'**
  String day(num count);

  /// number of weeks
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{now} =1{1 week} other{{count} weeks}}'**
  String week(num count);

  /// number of months
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{now} =1{1 month} other{{count} months}}'**
  String month(num count);

  /// number of years
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{now} =1{1 year} other{{count} years}}'**
  String year(num count);

  /// number of minutes left
  ///
  /// In en, this message translates to:
  /// **'{count} min left'**
  String minutesLeft(Object count);

  /// time of day to start
  ///
  /// In en, this message translates to:
  /// **'{time} start'**
  String timeToStart(Object time);

  /// time of day of next phase
  ///
  /// In en, this message translates to:
  /// **'{time} next'**
  String timeToNext(Object time);

  /// No description provided for @library.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get library;

  /// No description provided for @libraryMyPlans.
  ///
  /// In en, this message translates to:
  /// **'My plans'**
  String get libraryMyPlans;

  /// No description provided for @libraryCatalog.
  ///
  /// In en, this message translates to:
  /// **'Catalog'**
  String get libraryCatalog;

  /// No description provided for @libraryOnlineTab.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get libraryOnlineTab;

  /// No description provided for @libraryMyPlansSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a saved plan to continue'**
  String get libraryMyPlansSubtitle;

  /// No description provided for @libraryOnlineSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Get a plan from the shared online library'**
  String get libraryOnlineSubtitle;

  /// No description provided for @libraryFromFileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Import a .drill file from your device'**
  String get libraryFromFileSubtitle;

  /// No description provided for @libraryEmptyMyPlans.
  ///
  /// In en, this message translates to:
  /// **'You have no saved plans. Browse \'Online\' or \'New from file\' to get started.'**
  String get libraryEmptyMyPlans;

  /// No description provided for @libraryFromFilePickAction.
  ///
  /// In en, this message translates to:
  /// **'Choose file'**
  String get libraryFromFilePickAction;

  /// No description provided for @libraryFromFileHint.
  ///
  /// In en, this message translates to:
  /// **'Pick a .drill file from your device'**
  String get libraryFromFileHint;

  /// No description provided for @libraryCatalogBadge.
  ///
  /// In en, this message translates to:
  /// **'From online library'**
  String get libraryCatalogBadge;

  /// No description provided for @planStatusLocal.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get planStatusLocal;

  /// No description provided for @planStatusLocalTooltip.
  ///
  /// In en, this message translates to:
  /// **'This plan lives only on your device'**
  String get planStatusLocalTooltip;

  /// No description provided for @planStatusOnlineTooltip.
  ///
  /// In en, this message translates to:
  /// **'This plan is linked to the online library'**
  String get planStatusOnlineTooltip;

  /// No description provided for @addExercisesMyPlansSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a plan to pull exercises from'**
  String get addExercisesMyPlansSubtitle;

  /// No description provided for @addExercisesFromFileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Import exercises from a .drill file'**
  String get addExercisesFromFileSubtitle;

  /// No description provided for @addExercisesEmptyMyPlans.
  ///
  /// In en, this message translates to:
  /// **'No other plans to pull from yet'**
  String get addExercisesEmptyMyPlans;

  /// No description provided for @librarySourceLocal.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get librarySourceLocal;

  /// No description provided for @librarySourceImported.
  ///
  /// In en, this message translates to:
  /// **'Imported from {fileName}'**
  String librarySourceImported(Object fileName);

  /// No description provided for @librarySourceCatalog.
  ///
  /// In en, this message translates to:
  /// **'From catalog · {slug}'**
  String librarySourceCatalog(Object slug);

  /// No description provided for @libraryActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get libraryActive;

  /// No description provided for @libraryInstalled.
  ///
  /// In en, this message translates to:
  /// **'In library'**
  String get libraryInstalled;

  /// No description provided for @libraryInstall.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get libraryInstall;

  /// No description provided for @libraryRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh from catalog'**
  String get libraryRefresh;

  /// No description provided for @libraryRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get libraryRename;

  /// No description provided for @libraryExport.
  ///
  /// In en, this message translates to:
  /// **'Export as .drill'**
  String get libraryExport;

  /// No description provided for @libraryPublish.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get libraryPublish;

  /// No description provided for @libraryPublishAs.
  ///
  /// In en, this message translates to:
  /// **'Publish as…'**
  String get libraryPublishAs;

  /// No description provided for @libraryDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get libraryDelete;

  /// No description provided for @libraryEmptyCatalog.
  ///
  /// In en, this message translates to:
  /// **'Nothing online yet'**
  String get libraryEmptyCatalog;

  /// No description provided for @libraryErrorLoad.
  ///
  /// In en, this message translates to:
  /// **'Could not load online plans'**
  String get libraryErrorLoad;

  /// No description provided for @installedFromLink.
  ///
  /// In en, this message translates to:
  /// **'Plan installed from share link'**
  String get installedFromLink;

  /// No description provided for @libraryRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get libraryRetry;

  /// No description provided for @libraryCannotSwitchRunning.
  ///
  /// In en, this message translates to:
  /// **'Stop the running exercise before changing plans.'**
  String get libraryCannotSwitchRunning;

  /// No description provided for @openPlan.
  ///
  /// In en, this message translates to:
  /// **'Open plan...'**
  String get openPlan;

  /// No description provided for @openPlanTooltip.
  ///
  /// In en, this message translates to:
  /// **'Open plan'**
  String get openPlanTooltip;

  /// No description provided for @newPlanAction.
  ///
  /// In en, this message translates to:
  /// **'New plan'**
  String get newPlanAction;

  /// No description provided for @newPlanNamePrompt.
  ///
  /// In en, this message translates to:
  /// **'Name your new plan'**
  String get newPlanNamePrompt;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @fromFileAction.
  ///
  /// In en, this message translates to:
  /// **'New from file'**
  String get fromFileAction;

  /// No description provided for @addExercisesAction.
  ///
  /// In en, this message translates to:
  /// **'Add exercises from...'**
  String get addExercisesAction;

  /// No description provided for @addFromFile.
  ///
  /// In en, this message translates to:
  /// **'From file'**
  String get addFromFile;

  /// No description provided for @addFromAnotherPlan.
  ///
  /// In en, this message translates to:
  /// **'From another of my plans'**
  String get addFromAnotherPlan;

  /// No description provided for @pickFile.
  ///
  /// In en, this message translates to:
  /// **'Pick file...'**
  String get pickFile;

  /// No description provided for @confirmChangesTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm changes'**
  String get confirmChangesTitle;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @noOtherLocalPlans.
  ///
  /// In en, this message translates to:
  /// **'No other local plans yet'**
  String get noOtherLocalPlans;

  /// No description provided for @requiresActivePlan.
  ///
  /// In en, this message translates to:
  /// **'Open or create a plan first'**
  String get requiresActivePlan;

  /// No description provided for @shareActivePlan.
  ///
  /// In en, this message translates to:
  /// **'Copy URL'**
  String get shareActivePlan;

  /// No description provided for @planUrlCopied.
  ///
  /// In en, this message translates to:
  /// **'URL copied'**
  String get planUrlCopied;

  /// No description provided for @sendToAction.
  ///
  /// In en, this message translates to:
  /// **'Send to...'**
  String get sendToAction;

  /// No description provided for @sendToActionButton.
  ///
  /// In en, this message translates to:
  /// **'SEND TO...'**
  String get sendToActionButton;

  /// No description provided for @exportAsDrill.
  ///
  /// In en, this message translates to:
  /// **'Export as .drill'**
  String get exportAsDrill;

  /// No description provided for @exportAction.
  ///
  /// In en, this message translates to:
  /// **'EXPORT'**
  String get exportAction;

  /// No description provided for @importAction.
  ///
  /// In en, this message translates to:
  /// **'IMPORT'**
  String get importAction;

  /// No description provided for @selectExercisesAction.
  ///
  /// In en, this message translates to:
  /// **'CHOOSE...'**
  String get selectExercisesAction;

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'SELECT ALL'**
  String get selectAll;

  /// No description provided for @selectNone.
  ///
  /// In en, this message translates to:
  /// **'SELECT NONE'**
  String get selectNone;

  /// No description provided for @exportAllExercisesHint.
  ///
  /// In en, this message translates to:
  /// **'All exercises are included. Tap \'CHOOSE...\' to pick specific ones.'**
  String get exportAllExercisesHint;

  /// No description provided for @selectedOfTotal.
  ///
  /// In en, this message translates to:
  /// **'{selected} of {total} selected'**
  String selectedOfTotal(int selected, int total);

  /// No description provided for @publishActivePlan.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get publishActivePlan;

  /// No description provided for @publishAsActivePlan.
  ///
  /// In en, this message translates to:
  /// **'Publish as...'**
  String get publishAsActivePlan;

  /// No description provided for @defaultPlanName.
  ///
  /// In en, this message translates to:
  /// **'Default plan'**
  String get defaultPlanName;

  /// No description provided for @libraryMigrationNotice.
  ///
  /// In en, this message translates to:
  /// **'Library and catalog are new. Your existing plan has been moved to Default plan and is still active.'**
  String get libraryMigrationNotice;

  /// No description provided for @installedAndActivated.
  ///
  /// In en, this message translates to:
  /// **'Installed and activated {name}'**
  String installedAndActivated(Object name);

  /// No description provided for @openedAndActivated.
  ///
  /// In en, this message translates to:
  /// **'Opened {name}'**
  String openedAndActivated(Object name);

  /// No description provided for @catalogConflictTitle.
  ///
  /// In en, this message translates to:
  /// **'Catalog update conflict'**
  String get catalogConflictTitle;

  /// No description provided for @catalogConflictBody.
  ///
  /// In en, this message translates to:
  /// **'This catalog plan has local changes. Review the differences before choosing how to continue.'**
  String get catalogConflictBody;

  /// No description provided for @catalogConflictCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get catalogConflictCancel;

  /// No description provided for @catalogConflictOverwrite.
  ///
  /// In en, this message translates to:
  /// **'Overwrite local'**
  String get catalogConflictOverwrite;

  /// No description provided for @catalogConflictPublish.
  ///
  /// In en, this message translates to:
  /// **'Publish my changes'**
  String get catalogConflictPublish;

  /// No description provided for @catalogConflictFork.
  ///
  /// In en, this message translates to:
  /// **'Fork as local plan'**
  String get catalogConflictFork;

  /// No description provided for @catalogDiffAdded.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get catalogDiffAdded;

  /// No description provided for @catalogDiffRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed'**
  String get catalogDiffRemoved;

  /// No description provided for @catalogDiffModified.
  ///
  /// In en, this message translates to:
  /// **'Modified'**
  String get catalogDiffModified;

  /// No description provided for @catalogDiffLocal.
  ///
  /// In en, this message translates to:
  /// **'Your version'**
  String get catalogDiffLocal;

  /// No description provided for @catalogDiffRemote.
  ///
  /// In en, this message translates to:
  /// **'Catalog version'**
  String get catalogDiffRemote;

  /// No description provided for @catalogDiffName.
  ///
  /// In en, this message translates to:
  /// **'Plan name'**
  String get catalogDiffName;

  /// No description provided for @catalogDiffDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get catalogDiffDescription;

  /// No description provided for @catalogDiffExercises.
  ///
  /// In en, this message translates to:
  /// **'Exercises'**
  String get catalogDiffExercises;

  /// No description provided for @catalogDiffTeams.
  ///
  /// In en, this message translates to:
  /// **'Teams'**
  String get catalogDiffTeams;

  /// No description provided for @catalogDiffSessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get catalogDiffSessions;

  /// No description provided for @catalogServiceChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking'**
  String get catalogServiceChecking;

  /// No description provided for @catalogServiceOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get catalogServiceOnline;

  /// No description provided for @catalogServiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get catalogServiceUnavailable;

  /// No description provided for @catalogServiceCorsBlocked.
  ///
  /// In en, this message translates to:
  /// **'CORS blocked'**
  String get catalogServiceCorsBlocked;

  /// No description provided for @catalogServiceCorsBlockedTooltip.
  ///
  /// In en, this message translates to:
  /// **'The browser blocked the catalog request because the Netlify function does not allow this local origin. Use the deployed web app or enable CORS on the function for local web development.'**
  String get catalogServiceCorsBlockedTooltip;

  /// No description provided for @libraryPublishTitle.
  ///
  /// In en, this message translates to:
  /// **'Publish plan'**
  String get libraryPublishTitle;

  /// No description provided for @libraryPublishAsTitle.
  ///
  /// In en, this message translates to:
  /// **'Publish as'**
  String get libraryPublishAsTitle;

  /// No description provided for @libraryPublishBody.
  ///
  /// In en, this message translates to:
  /// **'This plan will be added to the public catalog. Anyone can install it, and anyone who has it can publish updates.'**
  String get libraryPublishBody;

  /// No description provided for @libraryPublishAsBody.
  ///
  /// In en, this message translates to:
  /// **'Choose a slug for this version. If you change the slug on an already-published plan, a local copy will be created that tracks the new slug — the original stays linked to its current slug.'**
  String get libraryPublishAsBody;

  /// No description provided for @libraryPublishSlugLabel.
  ///
  /// In en, this message translates to:
  /// **'Slug'**
  String get libraryPublishSlugLabel;

  /// No description provided for @libraryPublishSlugHelper.
  ///
  /// In en, this message translates to:
  /// **'Lowercase letters, digits and hyphens only.'**
  String get libraryPublishSlugHelper;

  /// No description provided for @libraryPublishTagsLabel.
  ///
  /// In en, this message translates to:
  /// **'Tags (comma separated)'**
  String get libraryPublishTagsLabel;

  /// No description provided for @libraryPublishSubmit.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get libraryPublishSubmit;

  /// No description provided for @libraryPublishSlugTaken.
  ///
  /// In en, this message translates to:
  /// **'Slug \'{slug}\' is already in use by an unrelated plan. Choose a different slug.'**
  String libraryPublishSlugTaken(Object slug);

  /// No description provided for @libraryPublishConflict.
  ///
  /// In en, this message translates to:
  /// **'Someone updated this plan first. Try again.'**
  String get libraryPublishConflict;

  /// No description provided for @libraryPublishSuccess.
  ///
  /// In en, this message translates to:
  /// **'Published {name}'**
  String libraryPublishSuccess(Object name);

  /// No description provided for @libraryPublishNoChange.
  ///
  /// In en, this message translates to:
  /// **'No changes to publish'**
  String get libraryPublishNoChange;

  /// No description provided for @libraryPublishFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not publish plan'**
  String get libraryPublishFailed;

  /// Prefix label in the shared rotation-table text, followed by the per-phase duration legend (e.g. '15 | 10 | 5 (drill | eval | roll / inbound)').
  ///
  /// In en, this message translates to:
  /// **'Each round'**
  String get rotationShareEachRound;

  /// Trailing legend in parentheses that explains what the three numbers in the rotation share text mean. Fixed phrase, do not parameterise.
  ///
  /// In en, this message translates to:
  /// **'drill | eval | roll / inbound'**
  String get rotationShareLegendPhases;

  /// Header for the rotation block in the shared rotation-table text.
  ///
  /// In en, this message translates to:
  /// **'Rotation (time of day)'**
  String get rotationShareTitle;

  /// Suffix in parentheses on every round except the last in the shared rotation-table text, indicating that the team moves to the next station after this round.
  ///
  /// In en, this message translates to:
  /// **'next'**
  String get rotationShareNext;

  /// Suffix in parentheses on the final round in the shared rotation-table text, indicating return/inbound transport after this round.
  ///
  /// In en, this message translates to:
  /// **'return'**
  String get rotationShareReturn;

  /// Informational line inserted after the meta line in copied exercise share text when rounds exceed stations.
  ///
  /// In en, this message translates to:
  /// **'Note: {rounds} rounds across {stations} stations means each team will revisit some stations.'**
  String shareNoteRevisits(int rounds, int stations);

  /// Informational line inserted after the meta line in copied exercise share text when rounds are fewer than stations.
  ///
  /// In en, this message translates to:
  /// **'Note: {rounds} rounds across {stations} stations means each team will only visit some stations.'**
  String shareNoteUnderCoverage(int rounds, int stations);

  /// SnackBar shown after copying the full exercise (header, meta, station list, rotation block) to the clipboard for sharing in Slack/Teams/Messenger. Triggered by the overlay copy button on CoordinatorScreen or by long-pressing the rotation table.
  ///
  /// In en, this message translates to:
  /// **'Exercise copied to clipboard'**
  String get exerciseCopied;

  /// Tooltip on the copy IconButton overlaid at the top-right of the scrollable list on the coordinator screen.
  ///
  /// In en, this message translates to:
  /// **'Copy exercise'**
  String get exerciseCopyTooltip;

  /// Bottom-nav label for the RolePlays (Markører) tab introduced in DESIGN-003.
  ///
  /// In en, this message translates to:
  /// **'RolePlays'**
  String get rolePlaysTab;

  /// Section header for the publishable role fields in the expanded tile and detail screen.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get roleSection;

  /// Relation label on the Cast section header in the expanded tile — answers 'who plays this role'. Norwegian: Spilles av.
  ///
  /// In en, this message translates to:
  /// **'Played by'**
  String get castSection;

  /// Button shown when no actor is assigned to a role. Opens the cast picker.
  ///
  /// In en, this message translates to:
  /// **'Add cast'**
  String get addCast;

  /// Overflow menu item to open ActorFormScreen for the currently assigned actor.
  ///
  /// In en, this message translates to:
  /// **'Edit cast'**
  String get editCast;

  /// Overflow menu item to unlink the actor from the role (sets actorUuid = null).
  ///
  /// In en, this message translates to:
  /// **'Clear cast'**
  String get clearCast;

  /// AppBar tooltip / sheet title for the full list of Actor records in the program.
  ///
  /// In en, this message translates to:
  /// **'Cast roster'**
  String get castRoster;

  /// Sticky top row in the cast picker and FAB label in the cast roster sheet.
  ///
  /// In en, this message translates to:
  /// **'New actor'**
  String get newActor;

  /// Footer shown on an actor row in the cast roster sheet listing roles they are cast to.
  ///
  /// In en, this message translates to:
  /// **'Cast as: {names}'**
  String castedAs(String names);

  /// Annotation shown in the cast picker when the actor is already cast to another role in the same exercise.
  ///
  /// In en, this message translates to:
  /// **'Already cast as {name}'**
  String alreadyCastAs(String name);

  /// Title of the cast picker bottom sheet. Displays the role name.
  ///
  /// In en, this message translates to:
  /// **'Cast: {role}'**
  String castPickerTitle(String role);

  /// Persistent hint below the Cast section header. Positively framed: the actor data stays local and is never published.
  ///
  /// In en, this message translates to:
  /// **'Stays on this device'**
  String get castPrivateHint;

  /// Collapsed-tile subtitle when the role has a stationIndex set. Displays the station name.
  ///
  /// In en, this message translates to:
  /// **'Station: {name}'**
  String roleSubtitleStation(String name);

  /// Collapsed-tile subtitle fallback when stationIndex is null. Displays the exercise name.
  ///
  /// In en, this message translates to:
  /// **'Exercise: {name}'**
  String roleSubtitleExercise(String name);

  /// Empty state shown in the cast roster sheet when no Actor records exist in the program.
  ///
  /// In en, this message translates to:
  /// **'No actors yet. Tap + New actor to add one.'**
  String get noActorsInRoster;

  /// Shown as the Markører tab body and as tooltip on the disabled cast-roster AppBar action when activeProgramUuid is null.
  ///
  /// In en, this message translates to:
  /// **'No active program. Open or create one in the Exercises tab.'**
  String get noActiveProgramHint;

  /// Placeholder shown in the Role section when the signalement field is blank.
  ///
  /// In en, this message translates to:
  /// **'No description'**
  String get noSignalement;

  /// Placeholder shown in the Role section when the background field is blank.
  ///
  /// In en, this message translates to:
  /// **'No background'**
  String get noBackground;

  /// Placeholder shown in the Role section when the behavior field is blank.
  ///
  /// In en, this message translates to:
  /// **'No behaviour'**
  String get noBehavior;

  /// Placeholder shown in the Role section when stationIndex is null.
  ///
  /// In en, this message translates to:
  /// **'No station'**
  String get noStationAssigned;

  /// Empty-state shown in the RolePlays tab when the program has no RolePlay records.
  ///
  /// In en, this message translates to:
  /// **'No roles yet. Open a post in the Stations tab to add one.'**
  String get noRolesInProgram;

  /// Empty-state shown in the RolePlays tab when the active exercise filter excludes every role.
  ///
  /// In en, this message translates to:
  /// **'No roles in this exercise.'**
  String get noRolesInExercise;

  /// Recovery button in the exercise filter banner on the RolePlays tab.
  ///
  /// In en, this message translates to:
  /// **'Show all'**
  String get showAllRoles;

  /// Banner shown above the bottom-nav when the RolePlays tab is filtered to a single exercise.
  ///
  /// In en, this message translates to:
  /// **'Showing roles in: {exercise}'**
  String showingRolesIn(String exercise);

  /// Error shown when the user tries to delete an actor who is still cast in one or more roles.
  ///
  /// In en, this message translates to:
  /// **'Cast in {count} role(s). Clear before deleting.'**
  String castDeleteBlocked(int count);

  /// Placeholder — final wording added when the confirm-reduce-roles dialog is implemented.
  ///
  /// In en, this message translates to:
  /// **'(placeholder)'**
  String get confirmReduceRoles;

  /// Fallback label on the map when a roleplayer participant's rolePlayUuid cannot be resolved to a local RolePlay record.
  ///
  /// In en, this message translates to:
  /// **'Unknown role'**
  String get unknownRole;

  /// Field label for the role name in RolePlayFormScreen.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get roleName;

  /// Field label for the optional age field in RolePlayFormScreen.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get roleAge;

  /// Hint text for optional form fields.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optional;

  /// Validation error shown when the age value is outside the valid range.
  ///
  /// In en, this message translates to:
  /// **'Age must be between 0 and 120'**
  String get ageRange;

  /// Dropdown label for the stationIndex field in RolePlayFormScreen.
  ///
  /// In en, this message translates to:
  /// **'Station'**
  String get stationLabel;

  /// Field label for the actor's real name in ActorFormScreen.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get actorRealName;

  /// Field label for the actor's phone number in ActorFormScreen.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get actorPhone;

  /// Field label for private notes about the actor in ActorFormScreen.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get actorNotes;

  /// Button label in the Markører section on StationExerciseScreen to create a new RolePlay at this post.
  ///
  /// In en, this message translates to:
  /// **'Add role'**
  String get addRolePlay;

  /// AppBar title in RolePlayFormScreen when the role has no name yet (new draft).
  ///
  /// In en, this message translates to:
  /// **'New role'**
  String get newRolePlayTitle;

  /// AppBar title in RolePlayFormScreen when editing an existing role (unused fallback — title shows role name).
  ///
  /// In en, this message translates to:
  /// **'Edit role'**
  String get editRolePlayTitle;

  /// Section header for the Markørordre list inside StationExerciseScreen.
  ///
  /// In en, this message translates to:
  /// **'Roles'**
  String get stationRolesSection;

  /// Empty-state hint shown in the Markørordre section when no RolePlays are linked to the current station.
  ///
  /// In en, this message translates to:
  /// **'No roles at this post'**
  String get noRolesAtThisStation;

  /// Form field label for the signalement field in RolePlayFormScreen.
  ///
  /// In en, this message translates to:
  /// **'Signalement'**
  String get roleSignalement;

  /// Form field label for the background field in RolePlayFormScreen.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get roleBackground;

  /// Form field label for the behavior field in RolePlayFormScreen.
  ///
  /// In en, this message translates to:
  /// **'Behaviour'**
  String get roleBehavior;

  /// Subtitle on a role row when an actor is cast. Used on the Station-screen Markørordre section and browse summaries.
  ///
  /// In en, this message translates to:
  /// **'Played by {name}'**
  String castedByLine(String name);

  /// Subtitle on a role row when no actor is cast. Styled italic + subdued.
  ///
  /// In en, this message translates to:
  /// **'No actor selected'**
  String get noCastLine;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'nb'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'nb':
      return AppLocalizationsNb();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
