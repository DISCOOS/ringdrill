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

  /// Title of the in-app pre-prompt that explains why RingDrill wants to send notifications, shown before the OS permission dialog
  ///
  /// In en, this message translates to:
  /// **'Enable Notifications'**
  String get appNotificationConsent;

  /// Rationale shown in the notification pre-prompt
  ///
  /// In en, this message translates to:
  /// **'RingDrill uses notifications to alert you about station rotations, round transitions, and exercise completion — even when the app is in the background.'**
  String get appNotificationConsentMessage;

  /// Closing line of the notification pre-prompt
  ///
  /// In en, this message translates to:
  /// **'Tap Allow to receive notifications. You can change this later in Settings.'**
  String get appNotificationConsentOptIn;

  /// Equal-weight secondary button on the onboarding consent stages — declines without dismissing the flow
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get skipForNow;

  /// Heading on the first onboarding stage, above the brand mark
  ///
  /// In en, this message translates to:
  /// **'Welcome to RingDrill'**
  String get onboardingWelcomeHeading;

  /// Short tagline under the welcome heading — sets context without revealing the rotation concept, which is the reveal on the final stage
  ///
  /// In en, this message translates to:
  /// **'Plan and run station-based training drills.'**
  String get onboardingWelcomeBody;

  /// Snackbar action label that deep-links into the OS Settings app
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get openSettings;

  /// Snackbar/banner shown when the user has declined notification permission and exercises will not produce alerts
  ///
  /// In en, this message translates to:
  /// **'Notifications are off. Enable them in Settings to get rotation and station alerts.'**
  String get notificationsDeniedBanner;

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
  /// **'Get notifications'**
  String get getReliableNotifications;

  /// Message
  ///
  /// In en, this message translates to:
  /// **'RingDrill notifications aren’t supported in the browser or the installed web app. The web can’t run drill timers in the background, so scheduled alerts aren’t delivered. For notifications, use the RingDrill app from the App Store or Google Play.'**
  String get noReliableNotificationsReason;

  /// Message
  ///
  /// In en, this message translates to:
  /// **'Notifications require the RingDrill app.'**
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

  /// Generic dismiss-action label, e.g. on a SnackBar close button.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
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

  /// Shown when a chosen file is not a .drill archive at all (renamed file, wrong type, etc.).
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" is not a valid RingDrill file.'**
  String openInvalidDrill(String name);

  /// Shown when the chosen .drill file has no bytes or no entries.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" is empty or has no content.'**
  String openEmptyDrill(String name);

  /// Shown when a .drill archive is structurally valid ZIP but the program manifest is broken.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" is damaged or incomplete.'**
  String openCorruptDrill(String name);

  /// Shown when the .drill archive declares a schema this build does not understand.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" uses a newer format. Update RingDrill to open it.'**
  String openUnsupportedSchema(String name);

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

  /// Tooltip for the unified filter FAB on the map tab
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// Section header in the unified filter sheet for the stations/roleplays/labels toggles
  ///
  /// In en, this message translates to:
  /// **'Show on map'**
  String get filterShowOnMap;

  /// Action that makes every exercise visible on the map
  ///
  /// In en, this message translates to:
  /// **'Show all'**
  String get showAll;

  /// Expands a truncated text block in the program overview
  ///
  /// In en, this message translates to:
  /// **'Show more'**
  String get showMore;

  /// Collapses an expanded text block in the program overview
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get showLess;

  /// Action that hides every exercise on the map
  ///
  /// In en, this message translates to:
  /// **'Hide all'**
  String get hideAll;

  /// Tooltip for the labels FAB when labels are currently hidden
  ///
  /// In en, this message translates to:
  /// **'Show labels'**
  String get showLabels;

  /// Tooltip for the labels FAB when labels are currently visible
  ///
  /// In en, this message translates to:
  /// **'Hide labels'**
  String get hideLabels;

  /// Tooltip for the marker-types FAB that opens the visibility bottom sheet
  ///
  /// In en, this message translates to:
  /// **'Marker types'**
  String get markerTypes;

  /// Switch label in the marker-types sheet for station markers
  ///
  /// In en, this message translates to:
  /// **'Show stations'**
  String get showStations;

  /// Switch label in the marker-types sheet for roleplay markers
  ///
  /// In en, this message translates to:
  /// **'Show roleplays'**
  String get showRoleplays;

  /// Banner text shown when two or more map filter types are active simultaneously
  ///
  /// In en, this message translates to:
  /// **'Filter active'**
  String get filterActiveCombined;

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

  /// Bottom navigation label and AppBar fallback title for the Program tab. The tab hosts the active training plan (exercises, stations, markers, teams); using the singular plan term avoids colliding with the inner 'Exercises' segment label.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get programTab;

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

  /// Teaching empty-state title shown in the Program Stations segment when the active plan has no stations.
  ///
  /// In en, this message translates to:
  /// **'No stations yet'**
  String get emptyStationsTitle;

  /// Teaching empty-state body shown in the Program Stations segment when the active plan has no stations.
  ///
  /// In en, this message translates to:
  /// **'Stations are added inside your exercises. Create an exercise first and they will show up here.'**
  String get emptyStationsBody;

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
  /// **'Edit Team'**
  String get editTeam;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Team name'**
  String get teamName;

  /// Teaching empty-state title shown in the Program Teams segment when the active plan has no teams.
  ///
  /// In en, this message translates to:
  /// **'No teams yet'**
  String get emptyTeamsTitle;

  /// Teaching empty-state body shown in the Program Teams segment when the active plan has no teams.
  ///
  /// In en, this message translates to:
  /// **'Teams come from the team count in your exercises. Create an exercise first and they will show up here.'**
  String get emptyTeamsBody;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Number of members'**
  String get numberOfMembers;

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

  /// Label for the About page: shown as the drawer menu entry and as the AppBar title on the page itself.
  ///
  /// In en, this message translates to:
  /// **'About RingDrill'**
  String get about;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// Label for the git commit SHA shown on the About page
  ///
  /// In en, this message translates to:
  /// **'Commit'**
  String get commit;

  /// Tooltip on the About-page commit row that links to the GitHub commit
  ///
  /// In en, this message translates to:
  /// **'Open in GitHub'**
  String get viewOnGithub;

  /// Message
  ///
  /// In en, this message translates to:
  /// **'No exercises yet!'**
  String get noExercisesYet;

  /// Teaching empty-state title shown in the Program Exercises segment when the active plan has no exercises.
  ///
  /// In en, this message translates to:
  /// **'No exercises yet'**
  String get emptyExercisesTitle;

  /// Teaching empty-state body shown in the Program Exercises segment when the active plan has no exercises.
  ///
  /// In en, this message translates to:
  /// **'Add your first exercise to get started.'**
  String get emptyExercisesBody;

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

  /// Label for the FAB that creates a new exercise
  ///
  /// In en, this message translates to:
  /// **'New exercise'**
  String get newExercise;

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

  /// Title shown when an exercise auto-stops because its end time was reached or every round completed.
  ///
  /// In en, this message translates to:
  /// **'Exercise finished'**
  String get exerciseAutoStoppedTitle;

  /// Body of the persistent notification shown after an exercise auto-stops.
  ///
  /// In en, this message translates to:
  /// **'End time for {exercise} has passed.'**
  String exerciseAutoStoppedBody(String exercise);

  /// SnackBar message shown when an exercise auto-stops.
  ///
  /// In en, this message translates to:
  /// **'{exercise} stopped automatically'**
  String exerciseAutoStoppedSnack(String exercise);

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

  /// Tooltip for the map layer-toggle button
  ///
  /// In en, this message translates to:
  /// **'Switch map layer'**
  String get layers;

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

  /// Tooltip for the map recenter button
  ///
  /// In en, this message translates to:
  /// **'Recenter map'**
  String get recenter;

  /// Title of the Map section in settings
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get mapSettingsSectionTitle;

  /// Intro text under the Map settings section title
  ///
  /// In en, this message translates to:
  /// **'Choose how maps behave in the app.'**
  String get mapSettingsSectionDescription;

  /// Toggle label for showing zoom in/out buttons on maps
  ///
  /// In en, this message translates to:
  /// **'Show zoom buttons'**
  String get showMapZoomControls;

  /// Helper text for the show-zoom-buttons toggle
  ///
  /// In en, this message translates to:
  /// **'Show zoom in and out buttons on maps. Off by default on touch devices, where pinch to zoom also works.'**
  String get showMapZoomControlsDescription;

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

  /// Snackbar shown when launchUrl fails to open an external URL or mail client
  ///
  /// In en, this message translates to:
  /// **'Could not open link.'**
  String get couldNotOpenLink;

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

  /// Subtitle under the elapsed-time tile in the coordinator mini-player.
  ///
  /// In en, this message translates to:
  /// **'So far'**
  String get elapsedLabel;

  /// Subtitle under the total-duration tile in the coordinator mini-player.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get totalLabel;

  /// Round counter on the coordinator mini-player, e.g. 1 of 6.
  ///
  /// In en, this message translates to:
  /// **'{current} of {total}'**
  String roundOfTotal(int current, int total);

  /// Compact hours and minutes duration, e.g. 2 h 30 min.
  ///
  /// In en, this message translates to:
  /// **'{hours} h {minutes} min'**
  String hoursMinutesShort(int hours, int minutes);

  /// Subtitle under the current wall-clock time tile in the coordinator mini-player.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get clockLabel;

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
  /// **'Import a .drill file or a bundled .zip with multiple plans'**
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
  /// **'Pick a .drill file or an exported .zip with multiple plans'**
  String get libraryFromFileHint;

  /// No description provided for @libraryExportAll.
  ///
  /// In en, this message translates to:
  /// **'Download all plans'**
  String get libraryExportAll;

  /// Message
  ///
  /// In en, this message translates to:
  /// **'Imported {count} plans'**
  String importBundleSuccess(int count);

  /// Message
  ///
  /// In en, this message translates to:
  /// **'Imported {imported} plans, {skipped} skipped'**
  String importBundlePartial(int imported, int skipped);

  /// No description provided for @importBundleEmpty.
  ///
  /// In en, this message translates to:
  /// **'No plans found in the file'**
  String get importBundleEmpty;

  /// No description provided for @importGuideHint.
  ///
  /// In en, this message translates to:
  /// **'Choose the .zip you downloaded to import your plans.'**
  String get importGuideHint;

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

  /// No description provided for @planStatusUnpublished.
  ///
  /// In en, this message translates to:
  /// **'Unpublished'**
  String get planStatusUnpublished;

  /// No description provided for @planStatusUnpublishedTooltip.
  ///
  /// In en, this message translates to:
  /// **'Tap to publish your changes to the catalog'**
  String get planStatusUnpublishedTooltip;

  /// No description provided for @addExercisesMyPlansSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a plan to pull exercises from'**
  String get addExercisesMyPlansSubtitle;

  /// No description provided for @addExercisesOnlineSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pull exercises from a plan in the online library'**
  String get addExercisesOnlineSubtitle;

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

  /// No description provided for @downloadAction.
  ///
  /// In en, this message translates to:
  /// **'DOWNLOAD'**
  String get downloadAction;

  /// No description provided for @libraryDownloadAction.
  ///
  /// In en, this message translates to:
  /// **'Download…'**
  String get libraryDownloadAction;

  /// No description provided for @libraryDownloadAll.
  ///
  /// In en, this message translates to:
  /// **'Download all'**
  String get libraryDownloadAll;

  /// No description provided for @libraryDownloadPlan.
  ///
  /// In en, this message translates to:
  /// **'Download plan'**
  String get libraryDownloadPlan;

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

  /// No description provided for @selectExercisesDisabledTooltip.
  ///
  /// In en, this message translates to:
  /// **'No exercises to choose from yet'**
  String get selectExercisesDisabledTooltip;

  /// No description provided for @selectPlansDisabledTooltip.
  ///
  /// In en, this message translates to:
  /// **'No plans to choose from yet'**
  String get selectPlansDisabledTooltip;

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

  /// No description provided for @exportAllPlansHint.
  ///
  /// In en, this message translates to:
  /// **'All plans are included. Tap \'CHOOSE...\' to pick specific ones.'**
  String get exportAllPlansHint;

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

  /// Name given to an auto-created plan. Phrased to invite renaming rather than feel permanent.
  ///
  /// In en, this message translates to:
  /// **'New plan'**
  String get defaultPlanName;

  /// Snackbar shown when the user tries to delete their only remaining plan. Per ADR-0038 the app always keeps at least one plan around.
  ///
  /// In en, this message translates to:
  /// **'Can\'t delete your last plan. Rename it or add a new one first.'**
  String get cannotDeleteLastPlan;

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

  /// No description provided for @catalogConflictBodyLocalOnly.
  ///
  /// In en, this message translates to:
  /// **'This catalog plan has local changes. The online version is unchanged. Review your local changes before choosing how to continue.'**
  String get catalogConflictBodyLocalOnly;

  /// No description provided for @catalogConflictCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get catalogConflictCancel;

  /// No description provided for @catalogConflictOverwrite.
  ///
  /// In en, this message translates to:
  /// **'Discard local changes'**
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

  /// No description provided for @catalogRefreshUpToDate.
  ///
  /// In en, this message translates to:
  /// **'{name} is already up to date'**
  String catalogRefreshUpToDate(String name);

  /// No description provided for @catalogRefreshUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated {name} from the catalog'**
  String catalogRefreshUpdated(String name);

  /// No description provided for @catalogRefreshReverted.
  ///
  /// In en, this message translates to:
  /// **'Discarded local changes to {name}'**
  String catalogRefreshReverted(String name);

  /// No description provided for @catalogRefreshCancelled.
  ///
  /// In en, this message translates to:
  /// **'Catalog update cancelled'**
  String get catalogRefreshCancelled;

  /// No description provided for @catalogRefreshForked.
  ///
  /// In en, this message translates to:
  /// **'Saved a local copy'**
  String get catalogRefreshForked;

  /// No description provided for @catalogRefreshPublished.
  ///
  /// In en, this message translates to:
  /// **'Published your changes'**
  String get catalogRefreshPublished;

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

  /// No description provided for @catalogDiffTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get catalogDiffTags;

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

  /// Roleplay count noun for the Program tab overview summary line.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Roleplay} =1{Roleplay} other{Roleplays}}'**
  String roleplay(int count);

  /// Bottom-nav label for the RolePlays (Markører) tab introduced in DESIGN-003.
  ///
  /// In en, this message translates to:
  /// **'RolePlays'**
  String get rolePlaysTab;

  /// Program-tab segment label for the publishable scenario layer (Spill/Script). Holds the RolePlay roster today; SilentWitness later. Distinct from rolePlaysTab, which names the Markører role roster inside the segment.
  ///
  /// In en, this message translates to:
  /// **'Script'**
  String get scriptSegment;

  /// Section header for the publishable role fields in the expanded tile and detail screen.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get roleSection;

  /// AppBar title for the RolePlayScreen detail view.
  ///
  /// In en, this message translates to:
  /// **'Roleplay'**
  String get rolePlayScreenTitle;

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

  /// Validation message shown when no station is selected for a role/markørordre.
  ///
  /// In en, this message translates to:
  /// **'Please select a station'**
  String get pleaseSelectStation;

  /// Teaching empty-state title shown in the Program Script segment when the active plan has no plays.
  ///
  /// In en, this message translates to:
  /// **'No plays yet'**
  String get emptyRolesTitle;

  /// Teaching empty-state body shown in the Program Script segment when the active plan has no plays.
  ///
  /// In en, this message translates to:
  /// **'A play describes what the roles do at the station. Create an exercise first, then add the plays it needs.'**
  String get emptyRolesBody;

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

  /// Button and dialog title for deleting an Actor record from ActorFormScreen.
  ///
  /// In en, this message translates to:
  /// **'Delete actor'**
  String get deleteActor;

  /// Confirmation message shown before deleting an Actor record from ActorFormScreen.
  ///
  /// In en, this message translates to:
  /// **'This will delete {name} from the actor roster. Continue?'**
  String confirmDeleteActor(String name);

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

  /// AppBar title for the BriefScreen.
  ///
  /// In en, this message translates to:
  /// **'Brief'**
  String get briefScreenTitle;

  /// Audience toggle label for participant audience.
  ///
  /// In en, this message translates to:
  /// **'Participant'**
  String get briefAudienceParticipant;

  /// Audience toggle label for instructor audience.
  ///
  /// In en, this message translates to:
  /// **'Instructor'**
  String get briefAudienceInstructor;

  /// Audience toggle label for director audience (exercise leader).
  ///
  /// In en, this message translates to:
  /// **'Director'**
  String get briefAudienceDirector;

  /// Label above the audience toggle on mobile.
  ///
  /// In en, this message translates to:
  /// **'Audience'**
  String get briefAudienceLabel;

  /// Tooltip on the print button in BriefScreen.
  ///
  /// In en, this message translates to:
  /// **'Print'**
  String get briefPrint;

  /// Tooltip on the search button in BriefScreen.
  ///
  /// In en, this message translates to:
  /// **'Search in brief'**
  String get briefSearch;

  /// Placeholder inside the search field in BriefScreen.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get briefSearchHint;

  /// Shown next to the search field when the query has no hits.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get briefSearchNoMatches;

  /// Error message shown when the brief renderer throws.
  ///
  /// In en, this message translates to:
  /// **'Could not render brief: {error}'**
  String briefRenderError(String error);

  /// Shown when the brief template asset fails to load, usually because the running build's asset manifest predates a newly added template. A full restart (or clean rebuild and hard refresh on web) resolves it.
  ///
  /// In en, this message translates to:
  /// **'The brief template could not be loaded. Restart the app and try again.'**
  String get briefTemplateMissing;

  /// Empty-state when the brief route is opened with no program loaded.
  ///
  /// In en, this message translates to:
  /// **'No active program'**
  String get briefMissingProgram;

  /// Empty-state when the exerciseUuid resolves to nothing.
  ///
  /// In en, this message translates to:
  /// **'Exercise not found'**
  String get briefMissingExercise;

  /// Heading above the TOC sidebar on wide screens.
  ///
  /// In en, this message translates to:
  /// **'Contents'**
  String get briefToc;

  /// Label/tooltip for the brief entry-point action on CoordinatorScreen and ProgramView app bars.
  ///
  /// In en, this message translates to:
  /// **'Open brief'**
  String get briefAction;

  /// Tooltip/label for the close button on the brief sheet.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get briefClose;

  /// Semantics label for the drag handle on the brief sheet.
  ///
  /// In en, this message translates to:
  /// **'Drag to close'**
  String get briefDragHandle;

  /// Suffix for exercise duration breakdown in the brief, e.g. '90 min (30 min per station)'.
  ///
  /// In en, this message translates to:
  /// **'per station'**
  String get briefPerStation;

  /// Label for the ring-rotation configuration line in the brief Organisering section.
  ///
  /// In en, this message translates to:
  /// **'Ring route'**
  String get briefRingRoute;

  /// Snackbar message shown after clicking an inline code chip in the brief copies its content to the clipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get briefCodeCopied;

  /// Tooltip on the small copy icon inside an inline code chip in the brief.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get briefCodeCopyTooltip;

  /// Position indicator in the brief search bar, e.g. '3 of 12'.
  ///
  /// In en, this message translates to:
  /// **'{current} of {total}'**
  String briefSearchMatchCount(int current, int total);

  /// Tooltip on the next-match arrow button in the brief search bar.
  ///
  /// In en, this message translates to:
  /// **'Next match'**
  String get briefSearchNextMatch;

  /// Tooltip on the previous-match arrow button in the brief search bar.
  ///
  /// In en, this message translates to:
  /// **'Previous match'**
  String get briefSearchPreviousMatch;

  /// Italic placeholder shown in the brief next to 'Post Nx plassering:' when a station has no UTM position set.
  ///
  /// In en, this message translates to:
  /// **'no position'**
  String get briefStationNoPosition;

  /// Tooltip on the floating copy-markdown button at the top-right of the brief reading column.
  ///
  /// In en, this message translates to:
  /// **'Copy as markdown'**
  String get briefCopyMarkdown;

  /// Snackbar message after the user taps the copy-markdown button.
  ///
  /// In en, this message translates to:
  /// **'Brief copied as markdown'**
  String get briefMarkdownCopied;

  /// Tooltip on the floating TOC button shown at the top-left of the brief reading column on narrow screens.
  ///
  /// In en, this message translates to:
  /// **'Contents'**
  String get briefOpenToc;

  /// Tooltip on the overflow (three-dot) menu in the CoordinatorScreen app bar that groups edit and delete behind a single button.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get moreActions;

  /// Tooltip on the chevron-down close button in the DrillPlayer sheet.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get drillPlayerClose;

  /// Countdown label shown in the mini-player strip when the exercise is pending.
  ///
  /// In en, this message translates to:
  /// **'Starting in'**
  String get drillPlayerStartingIn;

  /// Round indicator in the DrillMiniPlayer, e.g. 'Round 1 / 4'.
  ///
  /// In en, this message translates to:
  /// **'Round {current} / {total}'**
  String drillPlayerRoundOf(int current, int total);

  /// Countdown shown on the DrillPlayer mini-bar while an exercise is started but has not yet reached its scheduled start time. The {time} placeholder is mm:ss.
  ///
  /// In en, this message translates to:
  /// **'Starts in {time}'**
  String drillPlayerStartingInWithCountdown(String time);

  /// Empty detail pane text shown on the exercises tab.
  ///
  /// In en, this message translates to:
  /// **'Select an exercise'**
  String get detailEmptyExercise;

  /// Empty detail pane text shown on the stations tab.
  ///
  /// In en, this message translates to:
  /// **'Select a station to see details'**
  String get detailEmptyStation;

  /// Empty detail pane text shown on the role-plays tab.
  ///
  /// In en, this message translates to:
  /// **'Select a role'**
  String get detailEmptyRolePlay;

  /// Settings section heading for the staff-role selector (DESIGN-006 step 4).
  ///
  /// In en, this message translates to:
  /// **'My role'**
  String get appUserRoleSectionTitle;

  /// Subtitle under the staff-role section heading in Settings.
  ///
  /// In en, this message translates to:
  /// **'Choose your staff role. Sets the default level of detail shown in briefs.'**
  String get appUserRoleSectionDescription;

  /// FAB label on the Markører segment that creates a new RolePlay.
  ///
  /// In en, this message translates to:
  /// **'New role'**
  String get newRole;

  /// FAB label on the Spill (Script) segment for creating a new scenario entry. Creates a RolePlay today; when SilentWitness lands this becomes a choice. Mirrors the segment name (scriptSegment).
  ///
  /// In en, this message translates to:
  /// **'New play'**
  String get newPlay;

  /// Title of the exercise-picker sheet opened before creating a new role from the Markører segment.
  ///
  /// In en, this message translates to:
  /// **'Select exercise'**
  String get pickExerciseForRole;

  /// Title of the bottom-sheet picker shown when the user taps the exercise badge in the DrillMiniPlayer to switch which exercise is bound to the current view before any exercise has started.
  ///
  /// In en, this message translates to:
  /// **'Switch exercise'**
  String get exercisePickerTitle;

  /// Empty detail pane text shown on the teams tab.
  ///
  /// In en, this message translates to:
  /// **'Select a team'**
  String get detailEmptyTeam;

  /// Bottom-nav label for the Roster (Bemanning) tab introduced in DESIGN-006 stage 4.
  ///
  /// In en, this message translates to:
  /// **'Roster'**
  String get rosterTab;

  /// Empty detail pane text shown on the Roster tab in the wide layout.
  ///
  /// In en, this message translates to:
  /// **'Select an actor to see details'**
  String get detailEmptyRoster;

  /// AppBar title for ProgramFormScreen when editing the active plan.
  ///
  /// In en, this message translates to:
  /// **'Edit plan'**
  String get editProgram;

  /// Field label for Program.name in ProgramFormScreen.
  ///
  /// In en, this message translates to:
  /// **'Plan name'**
  String get programName;

  /// Field label for Program.description in ProgramFormScreen. Renders below the title in the brief.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get programDescription;

  /// Hint text for the Program.description field.
  ///
  /// In en, this message translates to:
  /// **'Short description shown under the plan name in the brief'**
  String get programDescriptionHint;

  /// Field/section label for the tags chip editor in ProgramFormScreen.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get programEditorTagsLabel;

  /// Hint text inside the tag input field in ProgramFormScreen.
  ///
  /// In en, this message translates to:
  /// **'Add a tag'**
  String get programEditorTagsHint;

  /// Tooltip on the delete icon chip in the tags editor in ProgramFormScreen.
  ///
  /// In en, this message translates to:
  /// **'Remove tag'**
  String get programEditorTagRemoveTooltip;

  /// Validation message shown when a tag exceeds the maximum length.
  ///
  /// In en, this message translates to:
  /// **'Tag is too long (max 40 characters)'**
  String get programEditorTagTooLong;

  /// Optional section label for Program.briefIntroMd in ProgramFormScreen. Booklet label: "Generelt om spill og øvingsledelse".
  ///
  /// In en, this message translates to:
  /// **'Intro'**
  String get briefSectionProgramIntro;

  /// Optional section label for Program.commsMd in ProgramFormScreen. Booklet label: "Talegrupper".
  ///
  /// In en, this message translates to:
  /// **'Comms'**
  String get briefSectionProgramComms;

  /// Optional section label for Program.beforeRoundMd in ProgramFormScreen. Booklet label: "Før hver post".
  ///
  /// In en, this message translates to:
  /// **'Before each station'**
  String get briefSectionProgramBeforeRound;

  /// Optional section label for Exercise.methodMd. Booklet label: "Metode".
  ///
  /// In en, this message translates to:
  /// **'Method'**
  String get briefSectionExerciseMethod;

  /// Optional section label for Exercise.learningGoalsMd. Booklet label: "Læringsmål".
  ///
  /// In en, this message translates to:
  /// **'Learning goals'**
  String get briefSectionExerciseLearningGoals;

  /// Optional section label for Exercise.trainingFocusMd. Booklet label: "Øvingsmomenter".
  ///
  /// In en, this message translates to:
  /// **'Training focus'**
  String get briefSectionExerciseTrainingFocus;

  /// Optional section label for Exercise.orderFormatMd. Booklet label: "Ordreformat".
  ///
  /// In en, this message translates to:
  /// **'Order format'**
  String get briefSectionExerciseOrderFormat;

  /// Optional section label for Exercise.executionTipsMd. Booklet label: "Tips til gjennomføring".
  ///
  /// In en, this message translates to:
  /// **'Execution tips'**
  String get briefSectionExerciseExecutionTips;

  /// Optional section label for Exercise.commsMd. Booklet label: "Samband". Overrides Program.commsMd.
  ///
  /// In en, this message translates to:
  /// **'Comms'**
  String get briefSectionExerciseComms;

  /// Optional section label for Station.equipmentMd. Booklet label: "Utstyrsbehov".
  ///
  /// In en, this message translates to:
  /// **'Equipment'**
  String get briefSectionStationEquipment;

  /// Optional section label for Station.situationMd. Booklet label: "Situasjon".
  ///
  /// In en, this message translates to:
  /// **'Situation'**
  String get briefSectionStationSituation;

  /// Optional section label for Station.missionMd. Booklet label: "Oppdrag".
  ///
  /// In en, this message translates to:
  /// **'Mission'**
  String get briefSectionStationMission;

  /// Optional section label for Station.logisticsMd. Booklet label: "Administrasjon og forsyninger".
  ///
  /// In en, this message translates to:
  /// **'Administration and supplies'**
  String get briefSectionStationLogistics;

  /// Optional section label for Station.criticalQuestionsMd. Booklet label: "Kritiske spørsmål".
  ///
  /// In en, this message translates to:
  /// **'Critical questions'**
  String get briefSectionStationCriticalQuestions;

  /// Optional section label for Station.leaderAnswersMd. Booklet label: "Forslag til svar".
  ///
  /// In en, this message translates to:
  /// **'Suggested answers'**
  String get briefSectionStationLeaderAnswers;

  /// Optional section label for Station.directorNotesMd. Booklet label: "Notater". Hidden from participant audiences.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get briefSectionStationDirectorNotes;

  /// Label for the station number format picker in ProgramFormScreen.
  ///
  /// In en, this message translates to:
  /// **'Station numbering'**
  String get stationNumberFormatLabel;

  /// Option label for StationNumberFormat.dotted in the station number format picker.
  ///
  /// In en, this message translates to:
  /// **'1.1, 1.2'**
  String get stationNumberFormatDotted;

  /// Option label for StationNumberFormat.alpha in the station number format picker.
  ///
  /// In en, this message translates to:
  /// **'1a, 1b'**
  String get stationNumberFormatAlpha;

  /// Helper text under the station number format picker showing a live preview of the selected format.
  ///
  /// In en, this message translates to:
  /// **'Example: {example}'**
  String stationNumberFormatPreview(String example);

  /// List-header toggle that enters exercise reorder mode (drag handles appear, drag-to-reorder becomes active).
  ///
  /// In en, this message translates to:
  /// **'Reorder'**
  String get exerciseReorderMode;

  /// List-header toggle that exits exercise reorder mode and returns to the default list view.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get exerciseReorderDone;

  /// Full-length label for sorting exercises chronologically by start time (used in tooltips / confirmations).
  ///
  /// In en, this message translates to:
  /// **'Sort by start time'**
  String get exerciseSortByStartTime;

  /// Full-length label for sorting exercises alphabetically by name (used in tooltips / confirmations).
  ///
  /// In en, this message translates to:
  /// **'Sort alphabetically'**
  String get exerciseSortAlphabetically;

  /// Static label anchor on the left of the exercises list header, before the sort and reorder controls.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get exerciseSortBy;

  /// Compact button label in the exercises list header for the one-shot sort-by-start-time action.
  ///
  /// In en, this message translates to:
  /// **'Start time'**
  String get exerciseSortByStartTimeShort;

  /// Compact button label in the exercises list header for the one-shot sort-alphabetically action.
  ///
  /// In en, this message translates to:
  /// **'Alphabetical'**
  String get exerciseSortAlphabeticallyShort;

  /// Skip button on the concept primer — dismisses the primer and goes straight to the Program tab.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get primerSkip;

  /// Heading on the concept primer card.
  ///
  /// In en, this message translates to:
  /// **'Teams rotate'**
  String get primerHeading;

  /// Body copy on the concept primer card, explaining the ring rotation.
  ///
  /// In en, this message translates to:
  /// **'Teams rotate between stations on a shared clock. When the round ends, everyone advances at once.'**
  String get primerBody;

  /// Primary CTA on the concept primer — opens a bundled example plan (stubbed until stage 3).
  ///
  /// In en, this message translates to:
  /// **'Open an example'**
  String get primerOpenExample;

  /// Secondary CTA on the concept primer — dismisses the primer and lands on an empty Program tab.
  ///
  /// In en, this message translates to:
  /// **'Start an empty plan'**
  String get primerStartEmpty;

  /// Indexed team label shown on the team chips in the ring rotation figure.
  ///
  /// In en, this message translates to:
  /// **'Team {n}'**
  String primerTeamLabel(int n);

  /// First-run-only inline pill label beside the first Program FAB, nudging the user to create their first exercise.
  ///
  /// In en, this message translates to:
  /// **'Start here'**
  String get startHereCue;

  /// Bold heading on the in-app migration banner shown when the PWA runs on the legacy apex origin.
  ///
  /// In en, this message translates to:
  /// **'The web app is moving to web.ringdrill.app.'**
  String get migrationBannerHeading;

  /// Body line on the migration banner below the heading.
  ///
  /// In en, this message translates to:
  /// **'Download your plans here and open the new app.'**
  String get migrationBannerBody;

  /// Primary action button on the migration banner — triggers bulk ZIP export.
  ///
  /// In en, this message translates to:
  /// **'Export all my plans'**
  String get migrationBannerExport;

  /// Secondary action button on the migration banner — opens web.ringdrill.app.
  ///
  /// In en, this message translates to:
  /// **'Open the new app'**
  String get migrationBannerOpenNewApp;

  /// Tertiary action button on the migration banner — opens the full migration explainer page.
  ///
  /// In en, this message translates to:
  /// **'Read more'**
  String get migrationBannerReadMore;

  /// Short label on the persistent legacy marker shown when the PWA runs on the legacy apex origin.
  ///
  /// In en, this message translates to:
  /// **'LEGACY'**
  String get legacyBadgeLabel;

  /// Tooltip on the persistent legacy marker; tapping it re-surfaces the migration banner.
  ///
  /// In en, this message translates to:
  /// **'You\'re using the old web app. Tap to move to web.ringdrill.app.'**
  String get legacyBadgeTooltip;

  /// Settings section heading grouping web-app/PWA actions (install status, install guide, force update).
  ///
  /// In en, this message translates to:
  /// **'Web app'**
  String get settingsWebAppSection;

  /// Title of the About/Settings row showing whether the web app runs as an installed PWA.
  ///
  /// In en, this message translates to:
  /// **'Installed as app'**
  String get installStatusTitle;

  /// Value shown when the web app is running as an installed PWA (standalone display mode).
  ///
  /// In en, this message translates to:
  /// **'Installed'**
  String get installStatusInstalled;

  /// Value shown when the web app is running in a normal browser tab, not installed.
  ///
  /// In en, this message translates to:
  /// **'Running in browser'**
  String get installStatusBrowser;

  /// List tile / action that opens the install guide page.
  ///
  /// In en, this message translates to:
  /// **'How to install on your device'**
  String get installGuideEntry;

  /// Title of the install guide page.
  ///
  /// In en, this message translates to:
  /// **'Install RingDrill'**
  String get installGuideTitle;

  /// Intro paragraph on the install guide page.
  ///
  /// In en, this message translates to:
  /// **'Install RingDrill as an app for a full-screen experience, faster start-up and more reliable notifications. Pick your device below.'**
  String get installGuideIntro;

  /// Shown on the install guide when the app already runs as an installed PWA.
  ///
  /// In en, this message translates to:
  /// **'RingDrill is already installed on this device. Open it from your home screen or app list.'**
  String get installGuideAlreadyInstalled;

  /// Button that triggers the browser install prompt when available.
  ///
  /// In en, this message translates to:
  /// **'Install now'**
  String get installGuideInstallButton;

  /// Heading for the Android install instructions.
  ///
  /// In en, this message translates to:
  /// **'Android (Chrome)'**
  String get installGuideAndroidTitle;

  /// Step-by-step Android install instructions, newline separated.
  ///
  /// In en, this message translates to:
  /// **'1. Open the browser menu (⋮).\n2. Tap “Install app” or “Add to Home screen”.\n3. Confirm to add RingDrill to your home screen.'**
  String get installGuideAndroidSteps;

  /// Heading for the iOS install instructions.
  ///
  /// In en, this message translates to:
  /// **'iPhone and iPad (Safari)'**
  String get installGuideIosTitle;

  /// Step-by-step iOS install instructions, newline separated.
  ///
  /// In en, this message translates to:
  /// **'1. Open RingDrill in Safari.\n2. Tap the Share button.\n3. Choose “Add to Home Screen”, then tap “Add”.'**
  String get installGuideIosSteps;

  /// Heading for the desktop install instructions.
  ///
  /// In en, this message translates to:
  /// **'Computer (Chrome or Edge)'**
  String get installGuideDesktopTitle;

  /// Step-by-step desktop install instructions, newline separated.
  ///
  /// In en, this message translates to:
  /// **'1. Click the install icon in the address bar, or open the browser menu.\n2. Choose “Install RingDrill”.\n3. Confirm to add it as an app.'**
  String get installGuideDesktopSteps;

  /// Heading for the native app section of the install guide on Apple devices (App Store).
  ///
  /// In en, this message translates to:
  /// **'Install from App Store'**
  String get installGuideNativeTitle;

  /// Heading for the native app section of the install guide on Android (Google Play).
  ///
  /// In en, this message translates to:
  /// **'Install from Google Play'**
  String get installGuidePlayTitle;

  /// Intro line under the native app section heading.
  ///
  /// In en, this message translates to:
  /// **'The RingDrill app gives the best experience on your device.'**
  String get installGuideNativeIntro;

  /// Button linking to the App Store listing (iOS and macOS).
  ///
  /// In en, this message translates to:
  /// **'Get in App Store'**
  String get installGuideAppStoreButton;

  /// Button linking to the Google Play listing (Android).
  ///
  /// In en, this message translates to:
  /// **'Get on Google Play'**
  String get installGuidePlayStoreButton;

  /// Heading for the PWA (add-to-home-screen) section of the install guide.
  ///
  /// In en, this message translates to:
  /// **'Install as web app'**
  String get installGuidePwaTitle;

  /// Settings list tile that opens the migration explainer page.
  ///
  /// In en, this message translates to:
  /// **'How to migrate to the new web app'**
  String get migrationSettingsEntry;

  /// Heading for the first section of the migration explainer.
  ///
  /// In en, this message translates to:
  /// **'Why are we moving?'**
  String get migrationExplainerWhyTitle;

  /// Body text explaining why the migration is happening.
  ///
  /// In en, this message translates to:
  /// **'The web app is moving to a new domain, web.ringdrill.app, for better performance, stability and easier updates. The new domain will have its own dedicated app.'**
  String get migrationExplainerWhyBody;

  /// Heading for the section explaining what changes for the user.
  ///
  /// In en, this message translates to:
  /// **'What changes for you?'**
  String get migrationExplainerChangesTitle;

  /// Body text explaining what changes for the user.
  ///
  /// In en, this message translates to:
  /// **'The existing app at ringdrill.app will stop receiving updates. The new app is installed from web.ringdrill.app as a fresh PWA, just like you did when you installed this one.'**
  String get migrationExplainerChangesBody;

  /// Heading for the section with the step-by-step guide.
  ///
  /// In en, this message translates to:
  /// **'How to transfer your plans'**
  String get migrationExplainerStepsTitle;

  /// First step in the migration guide.
  ///
  /// In en, this message translates to:
  /// **'Tap \"Export all my plans\" here in the app, or in the banner at the top.'**
  String get migrationExplainerStep1;

  /// Second step in the migration guide.
  ///
  /// In en, this message translates to:
  /// **'Open web.ringdrill.app and install the new app.'**
  String get migrationExplainerStep2;

  /// Third step in the migration guide.
  ///
  /// In en, this message translates to:
  /// **'Choose Import and select the ZIP file you just downloaded.'**
  String get migrationExplainerStep3;

  /// Fourth step in the migration guide.
  ///
  /// In en, this message translates to:
  /// **'All your plans are now available in the new app.'**
  String get migrationExplainerStep4;

  /// Fifth step in the migration guide: uninstall the old PWA after a successful migration.
  ///
  /// In en, this message translates to:
  /// **'Uninstall the old app from your home screen or browser once you\'ve checked that all your plans are in place in the new one.'**
  String get migrationExplainerStep5;

  /// Heading for the section explaining what happens to local data.
  ///
  /// In en, this message translates to:
  /// **'What happens to my data here?'**
  String get migrationExplainerDataTitle;

  /// Body text explaining what happens to local data.
  ///
  /// In en, this message translates to:
  /// **'Your plans are stored in the browser at ringdrill.app and will not disappear automatically. You can export them again from here until you clear browser data for this domain. A later update will add a dedicated migration page on the new domain that can transfer your data directly.'**
  String get migrationExplainerDataBody;

  /// Heading for the debug-only section on the About page that shows active build-time flags and other developer-relevant info. See ADR-0042.
  ///
  /// In en, this message translates to:
  /// **'Developer info'**
  String get developerInfoSectionTitle;

  /// Chip label for a build-time flag scheduled to be removed once its sunset criterion is met.
  ///
  /// In en, this message translates to:
  /// **'Temporary'**
  String get buildFlagKindTemporary;

  /// Chip label for a build-time flag that is part of permanent infrastructure (typically dev tools).
  ///
  /// In en, this message translates to:
  /// **'Permanent'**
  String get buildFlagKindPermanent;
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
