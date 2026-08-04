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

  /// Title of the dialog shown when the user taps the notification bell but the OS permission has been denied and cannot be re-requested programmatically
  ///
  /// In en, this message translates to:
  /// **'Notifications are off'**
  String get notificationsDeniedTitle;

  /// Body of the notification permission help dialog, explaining how to enable notifications from the OS Settings app
  ///
  /// In en, this message translates to:
  /// **'RingDrill can’t turn notifications back on for you — iOS only allows the permission dialog once. Open Settings, find RingDrill, and allow Notifications to get rotation, round, and completion alerts, even when the app runs in the background.'**
  String get notificationsDeniedHelp;

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
  /// **'MyPlan'**
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

  /// Shown when a .drill archive is structurally valid ZIP but the plan manifest is broken.
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
  /// **'Exported Plan'**
  String get exportedPlan;

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

  /// Expands a truncated text block in the plan overview
  ///
  /// In en, this message translates to:
  /// **'Show more'**
  String get showMore;

  /// Collapses an expanded text block in the plan overview
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
  /// **'Plan \"{name}\" imported successfully!'**
  String importSuccess(Object name);

  /// Message
  ///
  /// In en, this message translates to:
  /// **'Failed to import \"{name}\". Please try again.'**
  String importFailure(Object name);

  /// Plan with plurals
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Plan} =1{Plan} other{Plans}}'**
  String plan(num count);

  /// Bottom navigation label and AppBar fallback title for the Plan tab. The tab hosts the active training plan (exercises, stations, markers, teams); using the singular plan term avoids colliding with the inner 'Exercises' segment label.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get planTab;

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

  /// Segmented-control label for the non-map content of a station/role detail view, paired with mapTab.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get infoTab;

  /// Segmented-control label for the station detail view's scenario/roleplay content (persons and locations), between infoTab and mapTab.
  ///
  /// In en, this message translates to:
  /// **'Script'**
  String get scriptTab;

  /// Tooltip for the FAB that opens an exercise's all-stations map in a bigger dialog/bottom sheet, from the coordinator screen's inline map.
  ///
  /// In en, this message translates to:
  /// **'Open full map'**
  String get expandMap;

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

  /// Teaching empty-state title shown in the Plan Stations segment when the active plan has no stations.
  ///
  /// In en, this message translates to:
  /// **'No stations yet'**
  String get emptyStationsTitle;

  /// Teaching empty-state body shown in the Plan Stations segment when the active plan has no stations.
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
  /// **'Station Code'**
  String get stationCode;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Position (UTM)'**
  String get positionUtm;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'UTM'**
  String get utm;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Variant Suffix'**
  String get variantSuffix;

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

  /// Teaching empty-state title shown in the Plan Teams segment when the active plan has no teams.
  ///
  /// In en, this message translates to:
  /// **'No teams yet'**
  String get emptyTeamsTitle;

  /// Teaching empty-state body shown in the Plan Teams segment when the active plan has no teams.
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
  /// **'Plan file'**
  String get planFile;

  /// Message
  ///
  /// In en, this message translates to:
  /// **'Do you want to open the plan, or import exercises into current plan?'**
  String get openPlanHint;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Open...'**
  String get openPlanAction;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Import...'**
  String get importPlan;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Export...'**
  String get exportPlan;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Send to...'**
  String get sendToPlan;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Share...'**
  String get sharePlan;

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

  /// Tappable row shown in the station editor's base section in place of the description field when it is empty and unfocused (DESIGN-009); tapping it reveals the focused text field.
  ///
  /// In en, this message translates to:
  /// **'Add description'**
  String get stationAddDescriptionAction;

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

  /// Teaching empty-state title shown in the Plan Exercises segment when the active plan has no exercises.
  ///
  /// In en, this message translates to:
  /// **'No exercises yet'**
  String get emptyExercisesTitle;

  /// Teaching empty-state body shown in the Plan Exercises segment when the active plan has no exercises.
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

  /// Generic dismiss-action label, e.g. on a SnackBar close button.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

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
  /// **'Modified'**
  String get modified;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Placement'**
  String get placement;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Pick a placement'**
  String get pickAPlacement;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Pick a location'**
  String get pickALocation;

  /// Confirm button label on the map picker screen; confirms the centred point
  ///
  /// In en, this message translates to:
  /// **'Select here'**
  String get selectHere;

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

  /// Tooltip on a map legend entry that names a marker; tapping it moves the map onto that marker. {label} is the legend entry's own label.
  ///
  /// In en, this message translates to:
  /// **'Center the map on {label}'**
  String mapLegendFocus(String label);

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

  /// Label
  ///
  /// In en, this message translates to:
  /// **'End Time'**
  String get endTime;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Time Range'**
  String get timeLabel;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get durationLabel;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Phase Breakdown'**
  String get phaseBreakdown;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Round Table'**
  String get roundTable;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Time per Station'**
  String get stationDuration;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Number of Exercises'**
  String get exerciseCount;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Number of Teams'**
  String get teamCount;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Number of Stations'**
  String get stationCount;

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

  /// Label under the spelled-out countdown in the player status card's pre-start state.
  ///
  /// In en, this message translates to:
  /// **'To start'**
  String get statusUntilStart;

  /// Connector between the remaining-minutes number and the phase name in the player status card's running state, e.g. '5 min left of DRILL'.
  ///
  /// In en, this message translates to:
  /// **'min left of'**
  String get statusMinutesRemainingOf;

  /// Round counter in the player status card's meta cell, e.g. Round 1 of 6.
  ///
  /// In en, this message translates to:
  /// **'Round {current} of {total}'**
  String statusRoundOfTotal(int current, int total);

  /// Label for the 'now' cell in the player status card's now/next row (Post/Lag/Spill).
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get statusNow;

  /// Label for the coordinator's forward-looking 'next phase' cell in the player status card.
  ///
  /// In en, this message translates to:
  /// **'Next phase'**
  String get statusNextPhase;

  /// Label for the coordinator's forward-looking 'next round' cell in the player status card.
  ///
  /// In en, this message translates to:
  /// **'Next round'**
  String get statusNextRound;

  /// Shown in the Spill (marker) player's 'now' cell when the marker's post has no team assigned this round.
  ///
  /// In en, this message translates to:
  /// **'Not active now'**
  String get statusNotActiveNow;

  /// Value shown in the player status card's next-cell once a surface has no further round/phase of its own to report (the last round is already running) — paired with the exercise's finish time in the label row (e.g. 'Next · 10:55').
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get statusFinishValue;

  /// Subline in the player status card's pre-start state: scheduled start time and round count (Post/Lag/Coordinator).
  ///
  /// In en, this message translates to:
  /// **'starts {startTime} · {rounds, plural, =1{1 round} other{{rounds} rounds}}'**
  String statusPreStartSubline(String startTime, int rounds);

  /// Subline in the Spill (marker) player's status card pre-start state: when the marker becomes active and which post it's at.
  ///
  /// In en, this message translates to:
  /// **'active from {activeFrom} · at {postBadge}'**
  String statusPreStartSublineMarker(String activeFrom, String postBadge);

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

  /// Message
  ///
  /// In en, this message translates to:
  /// **'+{count} more'**
  String importBundleMoreSkipped(int count);

  /// No description provided for @importBundleEmpty.
  ///
  /// In en, this message translates to:
  /// **'No plans found in the file'**
  String get importBundleEmpty;

  /// No description provided for @importGuideHint.
  ///
  /// In en, this message translates to:
  /// **'You\'ve just downloaded a .zip with all your plans from the old app. Pick that file below to import them here — nothing is activated automatically, and the plan you\'re using now is untouched.'**
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

  /// Exercise-count line shown on a catalog card (ADR-0040).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 exercise} other{{count} exercises}}'**
  String catalogExerciseCount(num count);

  /// No description provided for @libraryActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get libraryActive;

  /// No description provided for @libraryInstalled.
  ///
  /// In en, this message translates to:
  /// **'In my plans'**
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

  /// No description provided for @addExercisesTitle.
  ///
  /// In en, this message translates to:
  /// **'Add exercises'**
  String get addExercisesTitle;

  /// No description provided for @addAction.
  ///
  /// In en, this message translates to:
  /// **'ADD'**
  String get addAction;

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

  /// Title of the picker that lets the user choose between downloading all plans or just the active plan.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get downloadTitle;

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

  /// Snackbar shown when the user tries to delete the currently active plan. Deleting it would leave no plan active, so another plan must be activated first.
  ///
  /// In en, this message translates to:
  /// **'Open a different plan first, then delete this one.'**
  String get cannotDeleteActivePlan;

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
  /// **'Your local changes differ from the catalog.'**
  String get catalogConflictBody;

  /// No description provided for @catalogConflictBodyLocalOnly.
  ///
  /// In en, this message translates to:
  /// **'The catalog plan is unchanged. You have local changes.'**
  String get catalogConflictBodyLocalOnly;

  /// No description provided for @catalogConflictCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get catalogConflictCancel;

  /// No description provided for @catalogConflictOverwrite.
  ///
  /// In en, this message translates to:
  /// **'Discard mine'**
  String get catalogConflictOverwrite;

  /// No description provided for @catalogConflictPublish.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get catalogConflictPublish;

  /// No description provided for @catalogConflictFork.
  ///
  /// In en, this message translates to:
  /// **'Make a copy'**
  String get catalogConflictFork;

  /// No description provided for @catalogConflictVersionLocalLabel.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get catalogConflictVersionLocalLabel;

  /// No description provided for @catalogConflictVersionCatalogLabel.
  ///
  /// In en, this message translates to:
  /// **'Catalog'**
  String get catalogConflictVersionCatalogLabel;

  /// No description provided for @catalogConflictVersionUnknown.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get catalogConflictVersionUnknown;

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

  /// Shown when a catalog refresh finds the plan's slug no longer exists on the server (HTTP 404) — distinct from catalogServiceUnavailable, which means the catalog service itself could not be reached.
  ///
  /// In en, this message translates to:
  /// **'{name} is no longer available in the catalog'**
  String catalogRefreshRemoved(String name);

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

  /// No description provided for @catalogDiffShowDeletions.
  ///
  /// In en, this message translates to:
  /// **'Show deletions'**
  String get catalogDiffShowDeletions;

  /// No description provided for @catalogDiffReorderedFromTo.
  ///
  /// In en, this message translates to:
  /// **'Moved {from} → {to}'**
  String catalogDiffReorderedFromTo(String from, String to);

  /// No description provided for @catalogDiffFieldChanged.
  ///
  /// In en, this message translates to:
  /// **'{field} changed: {from} → {to}'**
  String catalogDiffFieldChanged(String field, String from, String to);

  /// No description provided for @catalogDiffFieldChangedGeneric.
  ///
  /// In en, this message translates to:
  /// **'{field} changed'**
  String catalogDiffFieldChangedGeneric(String field);

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

  /// No description provided for @catalogDiffPlan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get catalogDiffPlan;

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

  /// No description provided for @catalogDiffFieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get catalogDiffFieldName;

  /// No description provided for @catalogDiffFieldEndTime.
  ///
  /// In en, this message translates to:
  /// **'End time'**
  String get catalogDiffFieldEndTime;

  /// No description provided for @catalogDiffFieldStartedAt.
  ///
  /// In en, this message translates to:
  /// **'Started'**
  String get catalogDiffFieldStartedAt;

  /// No description provided for @catalogDiffFieldEndedAt.
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get catalogDiffFieldEndedAt;

  /// No description provided for @catalogDiffFieldProps.
  ///
  /// In en, this message translates to:
  /// **'Props'**
  String get catalogDiffFieldProps;

  /// No description provided for @catalogDiffFieldOther.
  ///
  /// In en, this message translates to:
  /// **'Other changes'**
  String get catalogDiffFieldOther;

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

  /// Tooltip on the copy action in the exercise description card's header on the coordinator screen. Copies the whole exercise, not just the description.
  ///
  /// In en, this message translates to:
  /// **'Copy exercise'**
  String get exerciseCopyTooltip;

  /// Roleplay count noun for the Plan tab overview summary line.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Roleplay} =1{Roleplay} other{Roleplays}}'**
  String roleplay(int count);

  /// Bottom-nav label for the RolePlays (Markører) tab introduced in DESIGN-003.
  ///
  /// In en, this message translates to:
  /// **'RolePlays'**
  String get rolePlaysTab;

  /// Plan-tab segment label for the publishable scenario layer (Spill/Script). Holds the RolePlay roster today; SilentWitness later. Distinct from rolePlaysTab, which names the Markører role roster inside the segment.
  ///
  /// In en, this message translates to:
  /// **'Script'**
  String get scriptSegment;

  /// Section-card title for the consolidated Spill card in the RolePlay viewer (identity + script + cast). Nb: Spill. Collapsed the card appends the actor's first name in parentheses.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get playSection;

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

  /// AppBar tooltip / sheet title for the full list of Actor records in the plan.
  ///
  /// In en, this message translates to:
  /// **'Cast roster'**
  String get castRoster;

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

  /// Teaching empty-state title shown on the Roster tab when the active plan has no Actor records.
  ///
  /// In en, this message translates to:
  /// **'No staff yet'**
  String get emptyRosterTitle;

  /// Teaching empty-state body shown on the Roster tab when the active plan has no Actor records.
  ///
  /// In en, this message translates to:
  /// **'Add exercise directors, instructors and markers here.'**
  String get emptyRosterBody;

  /// Shown as the Markører tab body and as tooltip on the disabled cast-roster AppBar action when activePlanUuid is null.
  ///
  /// In en, this message translates to:
  /// **'No active plan. Open or create one in the Exercises tab.'**
  String get noActivePlanHint;

  /// Placeholder shown in the Role section when the description field is blank.
  ///
  /// In en, this message translates to:
  /// **'No description'**
  String get noRoleDescription;

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

  /// Teaching empty-state title shown in the Plan Script segment when the active plan has no plays.
  ///
  /// In en, this message translates to:
  /// **'No plays yet'**
  String get emptyRolesTitle;

  /// Teaching empty-state body shown in the Plan Script segment when the active plan has no plays.
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

  /// Field label for the role name in RolePlayFormScreen; reused by PersonsSection (Person.name, DESIGN-009 prompt 3).
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get roleName;

  /// Field label for the optional age field in RolePlayFormScreen; reused by PersonsSection (Person.age, DESIGN-009 prompt 3).
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get roleAge;

  /// Hint text for optional form fields.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optional;

  /// Validation error shown when the age value is outside the valid range. Shared by RolePlayFormScreen and PersonsSection (DESIGN-009 prompt 3).
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

  /// Confirmation message shown before deleting an Actor record from ActorFormScreen.
  ///
  /// In en, this message translates to:
  /// **'This will delete {name} from the actor roster. Continue?'**
  String confirmDeleteActor(String name);

  /// Button and dialog title for deleting a RolePlay (spill) from RolePlayFormScreen.
  ///
  /// In en, this message translates to:
  /// **'Delete role'**
  String get deleteRolePlay;

  /// Confirmation message before deleting a RolePlay that has no cast actor.
  ///
  /// In en, this message translates to:
  /// **'Delete the role \"{name}\"?'**
  String confirmDeleteRolePlay(String name);

  /// Confirmation message before deleting a RolePlay whose actor is cast; names the actor that gets unassigned.
  ///
  /// In en, this message translates to:
  /// **'Delete the role \"{name}\"? The actor {actor} is unassigned from it, but kept in the roster.'**
  String confirmDeleteRolePlayWithActor(String name, String actor);

  /// Button label in the Markører section on StationScreen to create a new RolePlay at this post.
  ///
  /// In en, this message translates to:
  /// **'Add role'**
  String get addRolePlay;

  /// AppBar title in RolePlayFormScreen when the role has no name yet (new draft).
  ///
  /// In en, this message translates to:
  /// **'New role'**
  String get newRolePlayTitle;

  /// AppBar title in RolePlayFormScreen when editing an existing role (DESIGN-009 prompt 4j) — a static type title; the marker's own name lives in the identity card, not the AppBar.
  ///
  /// In en, this message translates to:
  /// **'Edit role'**
  String get editRolePlayTitle;

  /// DESIGN-008 default-section label for RolePlayFormScreen's section-navigated editor. Carries RolePlay's short structural fields (name, age, description, station, position).
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get roleplaySectionRole;

  /// Section header for the Markørordre list inside StationScreen.
  ///
  /// In en, this message translates to:
  /// **'Roles'**
  String get stationRolesSection;

  /// Empty-state hint shown in the Markørordre section when no RolePlays are linked to the current station.
  ///
  /// In en, this message translates to:
  /// **'No roles at this post'**
  String get noRolesAtThisStation;

  /// Form field label for the description field in RolePlayFormScreen; reused by PersonsSection (Person.description, DESIGN-009 prompt 3).
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get roleDescription;

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

  /// DESIGN-010 stage 3b: the Spill viewer's Markørordre card third section — RolePlay.propsMd, not previously shown on this screen.
  ///
  /// In en, this message translates to:
  /// **'Props'**
  String get roleProps;

  /// Subtitle on a role row when an actor is cast. Used on the Station-screen Markørordre section and browse summaries.
  ///
  /// In en, this message translates to:
  /// **'Played by {name}'**
  String castedByLine(String name);

  /// Subtitle on a role row when no actor is cast. Styled italic + subdued.
  ///
  /// In en, this message translates to:
  /// **'No actor'**
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

  /// Empty-state when the brief route is opened with no plan loaded.
  ///
  /// In en, this message translates to:
  /// **'No active plan'**
  String get briefMissingPlan;

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

  /// Label/tooltip for the brief entry-point action on CoordinatorScreen and PlanView app bars.
  ///
  /// In en, this message translates to:
  /// **'Open brief'**
  String get briefAction;

  /// Tooltip/label for the close button on the brief sheet.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get briefClose;

  /// Tooltip for the sidebar-toggle icon button that replaces the detail pane's close-X in the wide master/detail layout (collapses/expands the master list pane).
  ///
  /// In en, this message translates to:
  /// **'Show/hide list'**
  String get masterPaneToggle;

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
  /// **'Ring Route'**
  String get briefRingRoute;

  /// ADR-0062: the same Organisering line for `mode: together`. Spelled out rather than the picker's one-word "Together", because the brief has room and a veileder reading it has no picker beside it for context.
  ///
  /// In en, this message translates to:
  /// **'All teams together'**
  String get briefModeTogether;

  /// ADR-0062: the same Organisering line for `mode: split`. Names what the reader sees on the ground — several posts running at once — rather than the mode's own name.
  ///
  /// In en, this message translates to:
  /// **'Parallel stations'**
  String get briefModeSplit;

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

  /// Rendered in place of {{var.<name>}} in a brief when <name> is not a declared plan variable (DESIGN-008/ADR-0046).
  ///
  /// In en, this message translates to:
  /// **'‹missing variable: {name}›'**
  String briefUnknownVariable(String name);

  /// Rendered in place of {{station.loc.<slug>}} or {{station.person.<slug>}} in a brief when <slug> does not name a location/person on the station (DESIGN-009/ADR-0047). {name} is the full reference, e.g. 'station.loc.lkp'.
  ///
  /// In en, this message translates to:
  /// **'‹missing reference: {name}›'**
  String briefUnknownReference(String name);

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

  /// Shown in the role viewer when the role it was opened for cannot be resolved — deleted from another pane, or a stale deep link. The viewer stays open with a close action rather than dismissing itself.
  ///
  /// In en, this message translates to:
  /// **'This role is no longer available. It may have been deleted.'**
  String get detailGoneRolePlay;

  /// Shown in the exercise (coordinator) viewer when the exercise it was opened for cannot be resolved — deleted from another pane, or a stale deep link. The viewer stays open with a close action rather than dismissing itself.
  ///
  /// In en, this message translates to:
  /// **'This exercise is no longer available. It may have been deleted.'**
  String get detailGoneExercise;

  /// Shown in the station viewer when neither the station nor its parent exercise can be resolved — deleted from another pane, a stale deep link, or a station index that no longer exists. The viewer stays open with a close action rather than dismissing itself.
  ///
  /// In en, this message translates to:
  /// **'This station is no longer available. It, or its exercise, may have been deleted.'**
  String get detailGoneStation;

  /// Label for AppUserRole.actor — the person who portrays a marker (ADR-0057). Norwegian uses the same word for both (markør), matching field practice; the RolePlay entity is the role itself.
  ///
  /// In en, this message translates to:
  /// **'Actor'**
  String get appUserRoleActor;

  /// Settings section heading for the staff-role selector (DESIGN-006 step 4).
  ///
  /// In en, this message translates to:
  /// **'My role'**
  String get appUserRoleSectionTitle;

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

  /// Empty detail pane text shown on the teams tab.
  ///
  /// In en, this message translates to:
  /// **'Select a team'**
  String get detailEmptyTeam;

  /// Bottom-nav label for the Roster (Bemanning) tab introduced in DESIGN-006 stage 4.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get rosterTab;

  /// Empty detail pane text shown on the Roster tab in the wide layout.
  ///
  /// In en, this message translates to:
  /// **'Select a member to see details'**
  String get detailEmptyRoster;

  /// AppBar title for PlanFormScreen when editing the active plan.
  ///
  /// In en, this message translates to:
  /// **'Edit plan'**
  String get editPlan;

  /// DESIGN-008 default-section label for PlanFormScreen's section-navigated editor. Carries Plan's short structural fields (name, description, tags, formats, language).
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get planSectionPlan;

  /// Field label for Plan.name in PlanFormScreen.
  ///
  /// In en, this message translates to:
  /// **'Plan name'**
  String get planName;

  /// Field label for Plan.description in PlanFormScreen. Renders below the title in the brief.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get planDescription;

  /// Hint text for the Plan.description field.
  ///
  /// In en, this message translates to:
  /// **'Short description shown under the plan name in the brief'**
  String get planDescriptionHint;

  /// Field/section label for the tags chip editor in PlanFormScreen.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get planEditorTagsLabel;

  /// Hint text inside the tag input field in PlanFormScreen.
  ///
  /// In en, this message translates to:
  /// **'Add a tag'**
  String get planEditorTagsHint;

  /// Tooltip on the delete icon chip in the tags editor in PlanFormScreen.
  ///
  /// In en, this message translates to:
  /// **'Remove tag'**
  String get planEditorTagRemoveTooltip;

  /// Validation message shown when a tag exceeds the maximum length.
  ///
  /// In en, this message translates to:
  /// **'Tag is too long (max 40 characters)'**
  String get planEditorTagTooLong;

  /// Optional section label for Plan.briefIntroMd in PlanFormScreen. Booklet label: "Generelt om spill og øvingsledelse".
  ///
  /// In en, this message translates to:
  /// **'Intro'**
  String get briefSectionPlanIntro;

  /// Optional section label for Plan.commsMd in PlanFormScreen. Booklet label: "Talegrupper".
  ///
  /// In en, this message translates to:
  /// **'Comms'**
  String get briefSectionPlanComms;

  /// Optional section label for Plan.beforeRoundMd in PlanFormScreen. Booklet label: "Før hver post".
  ///
  /// In en, this message translates to:
  /// **'Before each station'**
  String get briefSectionPlanBeforeRound;

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

  /// Optional section label for Exercise.commsMd. Booklet label: "Samband". Overrides Plan.commsMd.
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

  /// Label for the station number format picker in PlanFormScreen.
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

  /// Label for the plan-content language picker in PlanFormScreen. Kept short since the picker sits beside the plan-name field. Distinct from the app's own UI language.
  ///
  /// In en, this message translates to:
  /// **'Lang'**
  String get planLanguageLabel;

  /// Hint text shown in the plan-language picker before a language is chosen. Not itself a selectable option — selecting a language is required to save the form.
  ///
  /// In en, this message translates to:
  /// **'Choose'**
  String get planLanguageChooseHint;

  /// Validation message shown when the plan-language picker is submitted without a language chosen.
  ///
  /// In en, this message translates to:
  /// **'Please select a language'**
  String get pleaseSelectALanguage;

  /// DESIGN-008 SectionNavigatedForm entry that reveals the unused optional sections, in the compact switcher and the wide rail.
  ///
  /// In en, this message translates to:
  /// **'Add section'**
  String get formSectionAddAction;

  /// DESIGN-008 SectionNavigatedForm overflow-menu action that removes the current (removable) section. Never offered for the default section.
  ///
  /// In en, this message translates to:
  /// **'Remove section'**
  String get formSectionRemoveAction;

  /// Tooltip on the compact AppBar title switcher in DESIGN-008 SectionNavigatedForm.
  ///
  /// In en, this message translates to:
  /// **'Switch section'**
  String get formSectionSwitcherTooltip;

  /// Tooltip on DESIGN-008 SectionNavigatedForm's previous-section arrow. Disabled on the first active section.
  ///
  /// In en, this message translates to:
  /// **'Previous section'**
  String get formSectionPrevious;

  /// Tooltip on DESIGN-008 SectionNavigatedForm's next-section arrow. Disabled on the last active section.
  ///
  /// In en, this message translates to:
  /// **'Next section'**
  String get formSectionNext;

  /// DESIGN-010 SectionNavigatedForm AppBar toggle tooltip shown while a previewable section is in its editable (chip) state — tapping switches it to the resolved-markdown preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get formSectionPreviewAction;

  /// DESIGN-010 SectionNavigatedForm AppBar toggle tooltip shown while a previewable section is showing its resolved-markdown preview — tapping switches it back to the editable (chip) state.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get formSectionEditAction;

  /// Button. SectionNavigatedForm's primary action label when the form only folds its result into a parent's own unsaved working copy (openFormSurface's commitsToParent) — nothing is written to disk until that parent is itself saved.
  ///
  /// In en, this message translates to:
  /// **'DONE'**
  String get formDoneAction;

  /// DESIGN-010 default-section rollup toggle label shown while the rollup is hidden — tapping shows the whole entity's active sections resolved, stacked under the structural fields. Deliberately not "preview" (that word is reserved for the per-section eye toggle) and not "brief" (the rollup is one post/marker's slice, not the exported document).
  ///
  /// In en, this message translates to:
  /// **'Show details'**
  String get rollupShowAction;

  /// DESIGN-010 default-section rollup toggle label shown while the rollup is visible — tapping hides it again.
  ///
  /// In en, this message translates to:
  /// **'Hide details'**
  String get rollupHideAction;

  /// Placeholder in the base section's preview (DESIGN-010, revised 2026-07-10) when none of the entity's sections have content to show yet.
  ///
  /// In en, this message translates to:
  /// **'Nothing to preview yet'**
  String get rollupEmptyPreview;

  /// Title of the exercise-description rollup card in the coordinator's Info segment — the exercise's own markdown sections (method, order format, comms, learning goals, training focus, execution tips). Mirrors postDescriptionCardTitle for a station.
  ///
  /// In en, this message translates to:
  /// **'Exercise Description'**
  String get exerciseDescriptionCardTitle;

  /// DESIGN-010 stage 3b: the Post viewer's first card — the resolved lead description plus its labeled sections.
  ///
  /// In en, this message translates to:
  /// **'Post Description'**
  String get postDescriptionCardTitle;

  /// DESIGN-010 stage 3b: small pill next to a role-gated section's heading in the Post viewer's rollup card, shown alongside directorNotesMd (only rendered at all when the settings role is director).
  ///
  /// In en, this message translates to:
  /// **'Director only'**
  String get directorOnlyBadge;

  /// DESIGN-010 stage 3b: hint under the Post viewer's rollup card, telling the author that tapping a resolved section jumps into that section of the station editor.
  ///
  /// In en, this message translates to:
  /// **'Tap a section to edit'**
  String get tapSectionToEditHint;

  /// Button in a description card's teaching empty state (exercise, post, roleplay) — opens the entity editor at the section the surface marks as mandatory.
  ///
  /// In en, this message translates to:
  /// **'Add description'**
  String get descriptionAddAction;

  /// Nudge under a description card that has some content but is still missing a section the surface marks as mandatory. Nothing in the model requires these — the author is told, not stopped.
  ///
  /// In en, this message translates to:
  /// **'Missing: {sections}'**
  String descriptionMissingSections(String sections);

  /// Inline action on the descriptionMissingSections nudge — opens the editor at the first missing mandatory section. Short because it sits on one row next to the nudge text, which already names what is missing.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get descriptionMissingSectionsAction;

  /// Teaching empty state in the exercise-description card (coordinator Info segment, Plan tab's expanded exercise) when none of the exercise's markdown sections have content.
  ///
  /// In en, this message translates to:
  /// **'No exercise description yet'**
  String get exerciseDescriptionEmptyTitle;

  /// Body of the exercise-description teaching empty state — names the sections the author can fill, in the order the card presents them.
  ///
  /// In en, this message translates to:
  /// **'Describe the method, order format, comms and learning goals so instructors and team leaders know what this exercise is meant to train.'**
  String get exerciseDescriptionEmptyBody;

  /// Teaching empty state in the post-description card (Post viewer, Poster list's expanded tile) when neither the lead description nor any labeled section has content.
  ///
  /// In en, this message translates to:
  /// **'No post description yet'**
  String get stationDescriptionEmptyTitle;

  /// Body of the post-description teaching empty state — names the sections the author can fill, in the order the card presents them.
  ///
  /// In en, this message translates to:
  /// **'Describe the situation, mission, logistics and equipment at this post so markers and instructors can prepare before the exercise starts.'**
  String get stationDescriptionEmptyBody;

  /// Teaching empty state in the roleplay-description rollup (Spill list's expanded tile) when the roleplay has no description, background, behaviour or props.
  ///
  /// In en, this message translates to:
  /// **'No marker order yet'**
  String get rolePlayDescriptionEmptyTitle;

  /// Body of the roleplay-description teaching empty state — names the sections the author can fill, in the order the rollup presents them.
  ///
  /// In en, this message translates to:
  /// **'Describe the role — appearance, background, behaviour and props — so the marker knows who to play and how.'**
  String get rolePlayDescriptionEmptyBody;

  /// DESIGN-010 stage 3b: the Post viewer's schedule card title — the per-team drill/eval/roll clock times for this station.
  ///
  /// In en, this message translates to:
  /// **'Timing'**
  String get stationTimingCardTitle;

  /// DESIGN-010 stage 3b: the Spill viewer's schedule card title — the round(s) this roleplay's station is staffed by a team.
  ///
  /// In en, this message translates to:
  /// **'When Active'**
  String get roleActiveScheduleCardTitle;

  /// Empty-state text in the DESIGN-008 Stage 4 token insertion menu (the `/` command menu and `{{` autocomplete) when no variable or plan field matches the typed filter.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get tokenMenuEmpty;

  /// Token browser (ADR-0067): one line explaining what a token resolves to, shown under its value.
  ///
  /// In en, this message translates to:
  /// **'The plan\'s name, as it reads in the plan list and in the brief\'s title.'**
  String get tokenDescPlanName;

  /// Token browser (ADR-0067): one line explaining what a token resolves to, shown under its value.
  ///
  /// In en, this message translates to:
  /// **'The plan\'s own description, from the plan editor.'**
  String get tokenDescPlanDescription;

  /// Token browser (ADR-0067): one line explaining what a token resolves to, shown under its value.
  ///
  /// In en, this message translates to:
  /// **'How many exercises the plan has.'**
  String get tokenDescPlanExerciseCount;

  /// Token browser (ADR-0067): one line explaining what a token resolves to, shown under its value.
  ///
  /// In en, this message translates to:
  /// **'How many teams the plan has.'**
  String get tokenDescPlanTeamCount;

  /// Token browser (ADR-0067): one line explaining what a token resolves to, shown under its value.
  ///
  /// In en, this message translates to:
  /// **'How many stations the plan has in total, across every exercise.'**
  String get tokenDescPlanStationCount;

  /// Token browser (ADR-0067): one line explaining what a token resolves to, shown under its value.
  ///
  /// In en, this message translates to:
  /// **'The exercise\'s name. The number in front of it is rendered by the app.'**
  String get tokenDescExerciseName;

  /// Token browser (ADR-0067): one line explaining what a token resolves to, shown under its value.
  ///
  /// In en, this message translates to:
  /// **'How many teams rotate through this exercise.'**
  String get tokenDescExerciseNumberOfTeams;

  /// Token browser (ADR-0067): one line explaining what a token resolves to, shown under its value.
  ///
  /// In en, this message translates to:
  /// **'How many rounds the rotation runs.'**
  String get tokenDescExerciseNumberOfRounds;

  /// Token browser (ADR-0067): one line explaining what a token resolves to, shown under its value.
  ///
  /// In en, this message translates to:
  /// **'Clock time the first round starts.'**
  String get tokenDescExerciseStartTime;

  /// Token browser (ADR-0067): one line explaining what a token resolves to, shown under its value.
  ///
  /// In en, this message translates to:
  /// **'Clock time the last round ends. Derived from the start time and the three phase lengths.'**
  String get tokenDescExerciseEndTime;

  /// Token browser (ADR-0067): one line explaining what a token resolves to, shown under its value.
  ///
  /// In en, this message translates to:
  /// **'Start and end time as one expression.'**
  String get tokenDescExerciseTimeLabel;

  /// Token browser (ADR-0067): one line explaining what a token resolves to, shown under its value.
  ///
  /// In en, this message translates to:
  /// **'Total duration, with the per-round length in parentheses.'**
  String get tokenDescExerciseDurationLabel;

  /// Token browser (ADR-0067): one line explaining what a token resolves to, shown under its value.
  ///
  /// In en, this message translates to:
  /// **'Minutes a team spends drilling at a station, per round.'**
  String get tokenDescExerciseExecutionTime;

  /// Token browser (ADR-0067): one line explaining what a token resolves to, shown under its value.
  ///
  /// In en, this message translates to:
  /// **'Minutes set aside for evaluation, per round.'**
  String get tokenDescExerciseEvaluationTime;

  /// Token browser (ADR-0067): one line explaining what a token resolves to, shown under its value.
  ///
  /// In en, this message translates to:
  /// **'Minutes set aside for moving on to the next station.'**
  String get tokenDescExerciseRotationTime;

  /// Token browser (ADR-0067): one line explaining what a token resolves to, shown under its value.
  ///
  /// In en, this message translates to:
  /// **'The three phase lengths in minutes, separated by vertical bars.'**
  String get tokenDescExercisePhaseBreakdown;

  /// Token browser (ADR-0067): one line explaining what a token resolves to, shown under its value.
  ///
  /// In en, this message translates to:
  /// **'The whole rotation as a table: one row per round, with each phase\'s clock time. Built when the brief renders.'**
  String get tokenDescExerciseRoundTable;

  /// Token browser (ADR-0067): one line explaining what a token resolves to, shown under its value.
  ///
  /// In en, this message translates to:
  /// **'The station\'s name. The code in front of it is rendered by the app.'**
  String get tokenDescStationName;

  /// Token browser (ADR-0067): one line explaining what a token resolves to, shown under its value.
  ///
  /// In en, this message translates to:
  /// **'The station\'s code, derived from where it sits in the exercise.'**
  String get tokenDescStationCode;

  /// Token browser (ADR-0067): one line explaining what a token resolves to, shown under its value.
  ///
  /// In en, this message translates to:
  /// **'The station\'s own position, as a coordinate the reader can tap. Empty until the station is placed on the map.'**
  String get tokenDescStationPosition;

  /// Token browser (ADR-0067): one line explaining what a token resolves to, shown under its value.
  ///
  /// In en, this message translates to:
  /// **'The letter that tells apart two stations sharing a number.'**
  String get tokenDescStationVariantSuffix;

  /// Token browser (ADR-0067): one line explaining what a token resolves to, shown under its value.
  ///
  /// In en, this message translates to:
  /// **'How long a team gets at this station, with the phase breakdown.'**
  String get tokenDescStationDuration;

  /// Token browser (ADR-0067): one line explaining what a token resolves to, shown under its value.
  ///
  /// In en, this message translates to:
  /// **'The role\'s name.'**
  String get tokenDescRoleplayName;

  /// Token browser (ADR-0067): one line explaining what a token resolves to, shown under its value.
  ///
  /// In en, this message translates to:
  /// **'The role\'s age.'**
  String get tokenDescRoleplayAge;

  /// Token browser (ADR-0067): one line explaining what a token resolves to, shown under its value.
  ///
  /// In en, this message translates to:
  /// **'The role\'s short description.'**
  String get tokenDescRoleplayDescription;

  /// Token browser (ADR-0067): one line explaining what a token resolves to, shown under its value.
  ///
  /// In en, this message translates to:
  /// **'Where the role is placed, as a coordinate the reader can tap.'**
  String get tokenDescRoleplayPosition;

  /// ADR-0062: parallel-group editor for split mode.
  ///
  /// In en, this message translates to:
  /// **'Parallel groups'**
  String get exerciseGroupsSection;

  /// ADR-0062: parallel-group editor for split mode.
  ///
  /// In en, this message translates to:
  /// **'No groups yet. Each group is one round: the stations running at the same time, and which teams go to each.'**
  String get exerciseGroupsEmpty;

  /// ADR-0062: parallel-group editor for split mode.
  ///
  /// In en, this message translates to:
  /// **'New parallel group'**
  String get exerciseGroupAdd;

  /// ADR-0062: parallel-group editor for split mode.
  ///
  /// In en, this message translates to:
  /// **'Add station'**
  String get exerciseGroupAddStation;

  /// ADR-0062: parallel-group editor for split mode.
  ///
  /// In en, this message translates to:
  /// **'Add team'**
  String get exerciseGroupAddTeam;

  /// ADR-0062: parallel-group editor for split mode.
  ///
  /// In en, this message translates to:
  /// **'Remove group'**
  String get exerciseGroupRemove;

  /// ADR-0062: parallel-group editor for split mode.
  ///
  /// In en, this message translates to:
  /// **'The stations in this round and their team assignments are removed.'**
  String get exerciseGroupRemoveMessage;

  /// ADR-0062: parallel-group editor for split mode.
  ///
  /// In en, this message translates to:
  /// **'{team} is at two stations at once. These stations run at the same time.'**
  String exerciseGroupTeamCollision(String team);

  /// ADR-0062: parallel-group editor for split mode.
  ///
  /// In en, this message translates to:
  /// **'{teams} have no station in this round.'**
  String exerciseGroupTeamsUnplaced(String teams);

  /// ADR-0062: parallel-group editor for split mode.
  ///
  /// In en, this message translates to:
  /// **'No stations in this group yet.'**
  String get exerciseGroupNoStations;

  /// ADR-0062: a station that no round uses — possible once rounds are groups rather than a rotation over every station.
  ///
  /// In en, this message translates to:
  /// **'Not used in this exercise. No round has teams at this station.'**
  String get stationNotUsedInExercise;

  /// ADR-0062: a station that no round uses — possible once rounds are groups rather than a rotation over every station.
  ///
  /// In en, this message translates to:
  /// **'Not in use'**
  String get stationNotUsedBadge;

  /// ADR-0062: exercise conduct mode (ring route / together / split) and the station duration override.
  ///
  /// In en, this message translates to:
  /// **'Conduct'**
  String get exerciseMode;

  /// ADR-0062: the ring mode in the conduct picker. One word, so it sits beside Together and Split as a set. The brief keeps briefRingRoute ("Ring Route" / "Ringløype"), which names the route rather than the mode.
  ///
  /// In en, this message translates to:
  /// **'Ring'**
  String get exerciseModeRing;

  /// ADR-0062: exercise conduct mode (ring route / together / split) and the station duration override.
  ///
  /// In en, this message translates to:
  /// **'Together'**
  String get exerciseModeTogether;

  /// ADR-0062: exercise conduct mode (ring route / together / split) and the station duration override.
  ///
  /// In en, this message translates to:
  /// **'Split'**
  String get exerciseModeSplit;

  /// ADR-0062: exercise conduct mode (ring route / together / split) and the station duration override.
  ///
  /// In en, this message translates to:
  /// **'One team per station. Teams rotate; the app works out who is where.'**
  String get exerciseModeRingDescription;

  /// ADR-0062: exercise conduct mode (ring route / together / split) and the station duration override.
  ///
  /// In en, this message translates to:
  /// **'One station, all teams. Everyone works the same station, then moves on together.'**
  String get exerciseModeTogetherDescription;

  /// ADR-0062: exercise conduct mode (ring route / together / split) and the station duration override.
  ///
  /// In en, this message translates to:
  /// **'Anything in between. You group the stations that run together and say which teams go to each.'**
  String get exerciseModeSplitDescription;

  /// ADR-0062: exercise conduct mode (ring route / together / split) and the station duration override.
  ///
  /// In en, this message translates to:
  /// **'How is it run?'**
  String get exerciseModePickerTitle;

  /// ADR-0062: shown under the exercise's three phase fields when stations override them and every round still comes out the same length, as in ring mode.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 station overrides these} other{{count} stations override these}} — every round runs {minutes} min.'**
  String exerciseStationsOverrideUniform(int count, int minutes);

  /// ADR-0062: the same note where the rounds differ in length, as in together and split.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 station overrides these} other{{count} stations override these}} — rounds run {shortest}–{longest} min.'**
  String exerciseStationsOverrideRange(int count, int shortest, int longest);

  /// ADR-0062: the derived round count in `together` mode, stated in the note under the counter row rather than in a disabled field.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 round — one per station} other{{count} rounds — one per station}}'**
  String exerciseRoundsDerivedPerStation(int count);

  /// ADR-0062: the derived round count in `split` mode, where one round runs each parallel group.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 round — one per parallel group} other{{count} rounds — one per parallel group}}'**
  String exerciseRoundsDerivedPerGroup(int count);

  /// ADR-0062: exercise conduct mode (ring route / together / split) and the station duration override.
  ///
  /// In en, this message translates to:
  /// **'Change conduct?'**
  String get exerciseModeSwitchTitle;

  /// ADR-0062: exercise conduct mode (ring route / together / split) and the station duration override.
  ///
  /// In en, this message translates to:
  /// **'The parallel groups and their team assignments will be removed. The app generates the assignment in this mode, so there is nowhere for hand-placed teams to go.'**
  String get exerciseModeSwitchDiscardsGroups;

  /// ADR-0062: exercise conduct mode (ring route / together / split) and the station duration override.
  ///
  /// In en, this message translates to:
  /// **'Inherited from the exercise. Override for this station.'**
  String get stationTimingInherits;

  /// ADR-0062: helper under a station's three timing overrides, stating the round length they produce.
  ///
  /// In en, this message translates to:
  /// **'The round holding this station becomes {minutes} min.'**
  String stationTimingOverridden(int minutes);

  /// Token browser (ADR-0067): one line explaining what a token resolves to, shown under its value.
  ///
  /// In en, this message translates to:
  /// **'Insert token'**
  String get tokenBrowserTitle;

  /// Token browser (ADR-0067): the insertion menu's pinned footer, which opens the full token browser. Short because the list it belongs to is directly above it; the section editor's overflow menu uses tokenBrowserTitle instead, where there is no such context.
  ///
  /// In en, this message translates to:
  /// **'Show all …'**
  String get tokenBrowserBrowseAll;

  /// Token browser (ADR-0067): one line explaining what a token resolves to, shown under its value.
  ///
  /// In en, this message translates to:
  /// **'Search names and descriptions'**
  String get tokenBrowserSearchHint;

  /// Token browser (ADR-0067): one line explaining what a token resolves to, shown under its value.
  ///
  /// In en, this message translates to:
  /// **'EXAMPLE'**
  String get tokenBrowserExample;

  /// Token browser (ADR-0067): one line explaining what a token resolves to, shown under its value.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get tokenBrowserFilterAll;

  /// Token browser (ADR-0067): a filter chip and section header naming one category of token. Singular — it names a kind, it does not count one.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get tokenBrowserCategoryLocation;

  /// Token browser (ADR-0067): a filter chip and section header naming one category of token. Singular — it names a kind, it does not count one.
  ///
  /// In en, this message translates to:
  /// **'Person'**
  String get tokenBrowserCategoryPerson;

  /// Token browser (ADR-0067): one line explaining what a token resolves to, shown under its value.
  ///
  /// In en, this message translates to:
  /// **'Variable'**
  String get tokenBrowserCategoryVariable;

  /// Token browser (ADR-0067): one line explaining what a token resolves to, shown under its value.
  ///
  /// In en, this message translates to:
  /// **'No variables declared in this plan. Declare one in the plan\'s variables section.'**
  String get tokenBrowserNoVariables;

  /// Token browser (ADR-0067): one line explaining what a token resolves to, shown under its value.
  ///
  /// In en, this message translates to:
  /// **'This station owns no locations yet.'**
  String get tokenBrowserNoLocations;

  /// Token browser (ADR-0067): one line explaining what a token resolves to, shown under its value.
  ///
  /// In en, this message translates to:
  /// **'This station owns no persons yet.'**
  String get tokenBrowserNoPersons;

  /// Token browser (ADR-0067): one line explaining what a token resolves to, shown under its value.
  ///
  /// In en, this message translates to:
  /// **'Declared on the plan; exercises and stations may override the value.'**
  String get tokenBrowserVariableDescription;

  /// Token browser (ADR-0067): one line explaining what a token resolves to, shown under its value.
  ///
  /// In en, this message translates to:
  /// **'Name and position. Add .place, .label or .position for one part alone.'**
  String get tokenBrowserLocationDescription;

  /// Token browser (ADR-0067): one line explaining what a token resolves to, shown under its value.
  ///
  /// In en, this message translates to:
  /// **'Name and age. Add .age, .description or .loc.* for one part alone.'**
  String get tokenBrowserPersonDescription;

  /// Muted hint shown instead of a value next to a derived plan-field entry in the token insertion menu (e.g. exercise.name), distinguishing it from a variable entry which shows its effective value. DESIGN-008 calls this term out explicitly for both languages.
  ///
  /// In en, this message translates to:
  /// **'planfelt'**
  String get tokenMenuPlanFieldHint;

  /// Entry in the token insertion menu offered when the typed filter matches no declared variable, wired to an onCreateVariable callback (dormant until DESIGN-008 Stage 5 supplies it).
  ///
  /// In en, this message translates to:
  /// **'Create variable “{name}”'**
  String tokenMenuCreateVariable(String name);

  /// Entry in the token insertion menu offered when the typed filter matches no station location, wired to an onCreateLocation callback (ADR-0047, DESIGN-009 follow-up 4).
  ///
  /// In en, this message translates to:
  /// **'Create location “{label}”'**
  String tokenMenuCreateLocation(String label);

  /// Entry in the token insertion menu offered when the typed filter matches no station person, wired to an onCreatePerson callback (ADR-0047, DESIGN-009 follow-up 4).
  ///
  /// In en, this message translates to:
  /// **'Create person “{label}”'**
  String tokenMenuCreatePerson(String label);

  /// DESIGN-008 Stage 5 section label for the plan-variable declaration section (Plan editor, section-navigated shell).
  ///
  /// In en, this message translates to:
  /// **'Variables'**
  String get variablesSectionTitle;

  /// Amber warning note at the top of the Variabler section — variable values are stored in the .drill archive and published with it.
  ///
  /// In en, this message translates to:
  /// **'Published with the plan. Do not enter real personal data.'**
  String get variablesSectionPublishNote;

  /// "+ Ny variabel" action label in the Variabler section, and the title of the dialog it opens.
  ///
  /// In en, this message translates to:
  /// **'New variable'**
  String get variablesSectionAddAction;

  /// Placeholder of the Variabler section's bottom search field (DESIGN-008 follow-up 12), matching persons/locations' own search bar. Filters by name and hint.
  ///
  /// In en, this message translates to:
  /// **'Search variables'**
  String get variablesSectionSearchHint;

  /// Field label for a variable's name (the slug referenced as {{var.<name>}}) in the add-variable dialog.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get variablesSectionNameLabel;

  /// Placeholder for a declaration card's inline type-aware value field (DESIGN-008 follow-up 12).
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get variablesSectionValueLabel;

  /// Field label for a variable's optional hint, shown in the insertion picker and on the declaration card's inline hint field.
  ///
  /// In en, this message translates to:
  /// **'Hint (optional)'**
  String get variablesSectionHintLabel;

  /// Context-menu action (ADR-0031) that renames a variable, and the title/confirm-button text of the dialogs it opens.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get variablesSectionRenameAction;

  /// Context-menu action (ADR-0031) that deletes an unreferenced variable.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get variablesSectionDeleteAction;

  /// Label of the declaration card's expand/collapse disclosure bar (DESIGN-008 follow-up 12, mirroring RolePlayFormScreen's identity-card "Tilpass" bar) — reveals the type picker and the inline value/hint fields.
  ///
  /// In en, this message translates to:
  /// **'Customize'**
  String get variablesSectionCustomizeAction;

  /// Collapsed declaration card's subtitle when the variable's value (or location) is empty (DESIGN-008 follow-up 12).
  ///
  /// In en, this message translates to:
  /// **'No value'**
  String get variablesSectionNoValuePlaceholder;

  /// Validation message when a variable name does not match the ADR-0046 slug rule ^[a-z][a-z0-9_]*$.
  ///
  /// In en, this message translates to:
  /// **'Must start with a lowercase letter and contain only lowercase letters, numbers and underscores'**
  String get variablesSectionInvalidSlugError;

  /// Validation message when a variable name is already declared elsewhere in the plan.
  ///
  /// In en, this message translates to:
  /// **'This name is already in use'**
  String get variablesSectionDuplicateNameError;

  /// Field label used in a variable-reference location (e.g. delete-blocked usage list) when the reference is a variableOverrides map key, not a markdown field.
  ///
  /// In en, this message translates to:
  /// **'Variable override'**
  String get variablesSectionOverrideFieldLabel;

  /// Confirmation dialog body before a plan-wide rename rewrite (ADR-0046).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Not referenced yet.} =1{This updates 1 reference across the plan.} other{This updates {count} references across the plan.}}'**
  String variablesSectionRenameConfirmMessage(num count);

  /// Title of the dialog shown when deleting a still-referenced variable is blocked.
  ///
  /// In en, this message translates to:
  /// **'Can’t delete this variable'**
  String get variablesSectionDeleteBlockedTitle;

  /// Body text introducing the usage list in the delete-blocked dialog.
  ///
  /// In en, this message translates to:
  /// **'“{name}” is still used here:'**
  String variablesSectionDeleteBlockedMessage(String name);

  /// Label of the per-row local-value text field in VariableOverridesSection. An empty field means inherit the parent scope's value.
  ///
  /// In en, this message translates to:
  /// **'Local value'**
  String get variableOverridesSectionLocalValueLabel;

  /// Shown in VariableOverridesSection instead of the row list when the plan has no declared variables to override.
  ///
  /// In en, this message translates to:
  /// **'No variables in the plan yet'**
  String get variableOverridesSectionEmptyState;

  /// Per-card action in VariableOverridesSection that clears the local override so the variable inherits its parenthesized default again (DESIGN-008 follow-up 11).
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get variableOverridesSectionResetAction;

  /// VariableType.string label, shown on the declaration card's type chip and in the type picker (DESIGN-008 follow-up 11).
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get variableTypeLabelString;

  /// VariableType.number label.
  ///
  /// In en, this message translates to:
  /// **'Number'**
  String get variableTypeLabelNumber;

  /// VariableType.time label (24-hour clock time, HH:MM).
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get variableTypeLabelTime;

  /// VariableType.date label.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get variableTypeLabelDate;

  /// VariableType.duration label (a span in minutes).
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get variableTypeLabelDuration;

  /// VariableType.location label (a place with a coordinate).
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get variableTypeLabelLocation;

  /// Inline validation error under a number-typed variable value field. An invalid value blocks save (DESIGN-008 follow-up 11).
  ///
  /// In en, this message translates to:
  /// **'Enter a number'**
  String get variableValueInvalidNumber;

  /// Inline validation error under a time-typed variable value field.
  ///
  /// In en, this message translates to:
  /// **'Enter a time as HH:MM'**
  String get variableValueInvalidTime;

  /// Inline validation error under a date-typed variable value field.
  ///
  /// In en, this message translates to:
  /// **'Enter a date as YYYY-MM-DD'**
  String get variableValueInvalidDate;

  /// Inline validation error under a duration-typed variable value field.
  ///
  /// In en, this message translates to:
  /// **'Enter minutes as a whole number'**
  String get variableValueInvalidDuration;

  /// Inline validation error under a location-typed variable's coordinate field when the typed/pasted text parses as neither a decimal lat,lng pair nor a UTM string.
  ///
  /// In en, this message translates to:
  /// **'Enter a coordinate as lat,lng or UTM'**
  String get variableValueInvalidCoordinate;

  /// Snackbar shown when saving a form is blocked because one or more typed variable values (defaults or overrides) do not read as their declared type — the same blocking rule as an unknown token (DESIGN-008 follow-up 11). {names} is a comma-separated list of variable names.
  ///
  /// In en, this message translates to:
  /// **'Can’t save: invalid value for {names}'**
  String variableSaveBlockedInvalidValue(String names);

  /// Short hour unit used when rendering a duration-typed variable ("1 h 30 min"). Keep it short — it sits between the hour and minute counts.
  ///
  /// In en, this message translates to:
  /// **'h'**
  String get variableDurationHourUnit;

  /// Label of the location-typed variable's coordinate text field.
  ///
  /// In en, this message translates to:
  /// **'Coordinate'**
  String get variableLocationCoordinateLabel;

  /// Hint of the location-typed variable's coordinate text field — it accepts a decimal lat,lng pair or a UTM string, typed or pasted.
  ///
  /// In en, this message translates to:
  /// **'Type or paste lat,lng or UTM'**
  String get variableLocationCoordinateHint;

  /// LocationKind.lkp label, shown in the kind picker and on the map (ADR-0047/DESIGN-009).
  ///
  /// In en, this message translates to:
  /// **'Last known position (LKP)'**
  String get locationKindLkpLabel;

  /// LocationKind.lkp helper description, shown under the label in the kind picker.
  ///
  /// In en, this message translates to:
  /// **'The last confirmed position of the missing person.'**
  String get locationKindLkpDescription;

  /// LocationKind.ipp label, shown in the kind picker and on the map.
  ///
  /// In en, this message translates to:
  /// **'Initial planning point (IPP)'**
  String get locationKindIppLabel;

  /// LocationKind.ipp helper description, shown under the label in the kind picker.
  ///
  /// In en, this message translates to:
  /// **'The point search sectors are measured from.'**
  String get locationKindIppDescription;

  /// LocationKind.pp label, shown in the kind picker and on the map.
  ///
  /// In en, this message translates to:
  /// **'Planning point (PP)'**
  String get locationKindPpLabel;

  /// LocationKind.pp helper description, shown under the label in the kind picker.
  ///
  /// In en, this message translates to:
  /// **'A planning point used to structure the search area.'**
  String get locationKindPpDescription;

  /// LocationKind.rendezvous label, shown in the kind picker and on the map.
  ///
  /// In en, this message translates to:
  /// **'Rendezvous point'**
  String get locationKindRendezvousLabel;

  /// LocationKind.rendezvous helper description, shown under the label in the kind picker.
  ///
  /// In en, this message translates to:
  /// **'Where teams meet before deployment.'**
  String get locationKindRendezvousDescription;

  /// LocationKind.commandPost label, shown in the kind picker and on the map.
  ///
  /// In en, this message translates to:
  /// **'Command post'**
  String get locationKindCommandPostLabel;

  /// LocationKind.commandPost helper description, shown under the label in the kind picker.
  ///
  /// In en, this message translates to:
  /// **'Where the exercise is led from.'**
  String get locationKindCommandPostDescription;

  /// LocationKind.home label, shown in the kind picker and on the map.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get locationKindHomeLabel;

  /// LocationKind.home helper description, shown under the label in the kind picker.
  ///
  /// In en, this message translates to:
  /// **'The person\'s home address.'**
  String get locationKindHomeDescription;

  /// LocationKind.trackFound label, shown in the kind picker and on the map.
  ///
  /// In en, this message translates to:
  /// **'Track found'**
  String get locationKindTrackFoundLabel;

  /// LocationKind.trackFound helper description, shown under the label in the kind picker.
  ///
  /// In en, this message translates to:
  /// **'A place where a track was found.'**
  String get locationKindTrackFoundDescription;

  /// LocationKind.dogInterest label, shown in the kind picker and on the map.
  ///
  /// In en, this message translates to:
  /// **'Dog interest'**
  String get locationKindDogInterestLabel;

  /// LocationKind.dogInterest helper description, shown under the label in the kind picker.
  ///
  /// In en, this message translates to:
  /// **'A place a search dog showed interest.'**
  String get locationKindDogInterestDescription;

  /// LocationKind.obstacle label, shown in the kind picker and on the map.
  ///
  /// In en, this message translates to:
  /// **'Obstacle'**
  String get locationKindObstacleLabel;

  /// LocationKind.obstacle helper description, shown under the label in the kind picker.
  ///
  /// In en, this message translates to:
  /// **'An obstacle affecting the search.'**
  String get locationKindObstacleDescription;

  /// LocationKind.notSearchable label, shown in the kind picker and on the map.
  ///
  /// In en, this message translates to:
  /// **'Not searchable'**
  String get locationKindNotSearchableLabel;

  /// LocationKind.notSearchable helper description, shown under the label in the kind picker.
  ///
  /// In en, this message translates to:
  /// **'An area that could not be searched.'**
  String get locationKindNotSearchableDescription;

  /// LocationKind.phoneTrace label, shown in the kind picker and on the map.
  ///
  /// In en, this message translates to:
  /// **'Phone trace'**
  String get locationKindPhoneTraceLabel;

  /// LocationKind.phoneTrace helper description, shown under the label in the kind picker.
  ///
  /// In en, this message translates to:
  /// **'A location derived from a phone trace.'**
  String get locationKindPhoneTraceDescription;

  /// LocationKind.observation label, shown in the kind picker and on the map.
  ///
  /// In en, this message translates to:
  /// **'Observation'**
  String get locationKindObservationLabel;

  /// LocationKind.observation helper description, shown under the label in the kind picker.
  ///
  /// In en, this message translates to:
  /// **'A reported sighting or observation.'**
  String get locationKindObservationDescription;

  /// LocationKind.vantagePoint label, shown in the kind picker and on the map.
  ///
  /// In en, this message translates to:
  /// **'Vantage point'**
  String get locationKindVantagePointLabel;

  /// LocationKind.vantagePoint helper description, shown under the label in the kind picker.
  ///
  /// In en, this message translates to:
  /// **'A point with good visibility over the search area.'**
  String get locationKindVantagePointDescription;

  /// LocationKind.containmentPost label, shown in the kind picker and on the map.
  ///
  /// In en, this message translates to:
  /// **'Containment post'**
  String get locationKindContainmentPostLabel;

  /// LocationKind.containmentPost helper description, shown under the label in the kind picker.
  ///
  /// In en, this message translates to:
  /// **'A post used to contain the search area.'**
  String get locationKindContainmentPostDescription;

  /// LocationKind.personFound label, shown in the kind picker and on the map.
  ///
  /// In en, this message translates to:
  /// **'Person found'**
  String get locationKindPersonFoundLabel;

  /// LocationKind.personFound helper description, shown under the label in the kind picker.
  ///
  /// In en, this message translates to:
  /// **'Where the missing person was found.'**
  String get locationKindPersonFoundDescription;

  /// LocationKind.other label, shown in the kind picker and on the map.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get locationKindOtherLabel;

  /// LocationKind.other helper description, shown under the label in the kind picker.
  ///
  /// In en, this message translates to:
  /// **'Any other kind of location.'**
  String get locationKindOtherDescription;

  /// DESIGN-009 first-class station-editor section label for the station's Location list (section-navigated shell).
  ///
  /// In en, this message translates to:
  /// **'Locations'**
  String get locationsSectionTitle;

  /// "+ Ny lokasjon" action label in the Locations section, and the title of the add dialog it opens.
  ///
  /// In en, this message translates to:
  /// **'New location'**
  String get locationsSectionAddAction;

  /// AppBar title of LocationFormScreen when editing an existing location (DESIGN-009 follow-up 3b). The reference is auto-generated and never shown/edited; position is set inline in the form via its own map-pick control.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get locationsSectionEditAction;

  /// confirmDestructive message before a swipe-to-dismiss delete of a location (ADR-0031). Plain delete -- the reference guard (blocked-while-referenced) is a future action, ADR-0047.
  ///
  /// In en, this message translates to:
  /// **'Delete “{name}”?'**
  String locationsSectionDeleteConfirmMessage(String name);

  /// Field label for a location's display label in the add/edit-location dialog.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get locationsSectionLabelLabel;

  /// Field label for a location's LocationKind dropdown in the add/edit-location dialog.
  ///
  /// In en, this message translates to:
  /// **'Kind'**
  String get locationsSectionKindLabel;

  /// Field label for a location's place/address text in the add/edit-location dialog.
  ///
  /// In en, this message translates to:
  /// **'Place'**
  String get locationsSectionPlaceLabel;

  /// Hint text on the geocoder-backed place field (DESIGN-009 follow-up 3c): typing debounces into a forward-geocode search whose suggestions set both place and position.
  ///
  /// In en, this message translates to:
  /// **'Search for a place'**
  String get locationsSectionPlaceSearchHint;

  /// Small caption shown under the place field after a forward-geocode search completes with zero hits (or fails, e.g. offline) -- never blocking, matching the field's best-effort contract (ADR-0047 follow-up 3c).
  ///
  /// In en, this message translates to:
  /// **'No matches found'**
  String get locationsSectionPlaceNoResults;

  /// Field label for a location's optional note in the add/edit-location dialog.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get locationsSectionNoteLabel;

  /// Expansion link below the collapsed LocationKind category grid in the Location form (DESIGN-009 follow-up 3b). {count} is LocationKind.values.length, not hard-coded.
  ///
  /// In en, this message translates to:
  /// **'Show all {count} categories'**
  String locationsSectionShowAllKinds(int count);

  /// Collapse link below the expanded LocationKind category grid in the Location form, the counterpart to locationsSectionShowAllKinds.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get locationsSectionShowFewerKinds;

  /// Placeholder text in the Locations section's search field (filters by label/place).
  ///
  /// In en, this message translates to:
  /// **'Search locations'**
  String get locationsSectionSearchHint;

  /// Sort-toggle label when the Locations list is sorted by kind then label (the default). Tapping switches to locationsSectionSortByLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get locationsSectionSortByKind;

  /// Sort-toggle label when the Locations list is sorted alphabetically by label. Tapping switches to locationsSectionSortByKind.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get locationsSectionSortByLabel;

  /// DESIGN-009 first-class station-editor section label for the station's Person list (section-navigated shell).
  ///
  /// In en, this message translates to:
  /// **'Persons'**
  String get personsSectionTitle;

  /// "+ Ny person" action label in the Persons section, and the title of the add dialog it opens.
  ///
  /// In en, this message translates to:
  /// **'New person'**
  String get personsSectionAddAction;

  /// Inline row on a person's card in the Persons section (DESIGN-009 prompt 4j) naming the RolePlay that enacts them. Tapping opens that roleplay in the RolePlay editor. {name} is the roleplay's own display name.
  ///
  /// In en, this message translates to:
  /// **'Played by {name}'**
  String personsSectionEnactedByAction(String name);

  /// Inline row on a person's card in the Persons section, shown instead of personsSectionEnactedByAction when the person has no enacting RolePlay yet (DESIGN-009 prompt 4j). Opens the RolePlay editor with the post and this person pre-set. "Role" mirrors editRolePlayTitle/newRolePlayTitle's nb "spill" / en "role" convention -- intentionally not a calque of the nb string.
  ///
  /// In en, this message translates to:
  /// **'Add role'**
  String get personsSectionAddMarkerAction;

  /// AppBar title of PersonFormScreen when editing an existing person (DESIGN-009 follow-up 3b). The reference is auto-generated and never shown/edited; home has its own inline picker in the form.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get personsSectionEditAction;

  /// confirmDestructive message before a swipe-to-dismiss delete of a person (ADR-0031). Plain delete -- the reference guard (blocked-while-referenced, including a locSlug pointing at it) is a future action, ADR-0047.
  ///
  /// In en, this message translates to:
  /// **'Delete “{name}”?'**
  String personsSectionDeleteConfirmMessage(String name);

  /// Field label for a person's location picker (sets Person.locSlug to one of the station's own locations) on the Persons section row. Also the picker's display label for the person 'loc' facet (DESIGN-009 prompt 4i, renamed from 'home').
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get personsSectionLocationLabel;

  /// The "no location selected" option in the location picker dropdown, and shown when a person has no locSlug.
  ///
  /// In en, this message translates to:
  /// **'No location'**
  String get personsSectionLocationNone;

  /// Field label for a person's optional notes in the add/edit-person dialog.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get personsSectionNotesLabel;

  /// Placeholder text in the Persons section's search field (filters by name/description).
  ///
  /// In en, this message translates to:
  /// **'Search persons'**
  String get personsSectionSearchHint;

  /// Sort-toggle label when the Persons list is sorted alphabetically by name (the default). Tapping switches to personsSectionSortByAge.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get personsSectionSortByName;

  /// Sort-toggle label when the Persons list is sorted by age. Tapping switches to personsSectionSortByName.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get personsSectionSortByAge;

  /// Label above the GenderSegmentedControl, shared by PersonsSection (Person.gender) and, from DESIGN-009 prompt 4, RolePlayFormScreen's own gender field (ADR-0047) -- named roleGender for the roleName/roleAge/roleDescription family it joins, even though PersonsSection uses it first.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get roleGender;

  /// Dropdown label for the personRef selector in RolePlayFormScreen (ADR-0047, DESIGN-009 follow-up 4).
  ///
  /// In en, this message translates to:
  /// **'Person'**
  String get rolePlayPersonLabel;

  /// Inline hint shown in place of the identity and position sections in RolePlayFormScreen while no post is selected (ADR-0047, amended 2026-07-10). Identity and position are overrides scoped to a post's person, so nothing below the Post card is active until a post is chosen.
  ///
  /// In en, this message translates to:
  /// **'Select a post to continue'**
  String get rolePlayPostRequiredHint;

  /// Placeholder text in the identity card header when no person is selected yet (ADR-0047, amended 2026-07-10) -- reads as a prompt to pick or create a person, not as a nameless marker.
  ///
  /// In en, this message translates to:
  /// **'Select or create a person'**
  String get rolePlaySelectPersonPrompt;

  /// Validation message shown when no person is selected for a roleplay (ADR-0047's mandatory personRef, an editor-level invariant).
  ///
  /// In en, this message translates to:
  /// **'Please select a person'**
  String get pleaseSelectPerson;

  /// Lead-in to the warning shown under the Post selector when switching the linked station has left a station.loc/station.person token unresolved in one of this roleplay's own fields (DESIGN-009 prompt 5). Followed by one chip per affected section; each chip opens that section so the author can fix it. Save is already blocked separately; this only surfaces the problem earlier.
  ///
  /// In en, this message translates to:
  /// **'Broken reference in'**
  String get rolePlayBrokenReferencePrefix;

  /// Trailing action on the Post card (DESIGN-009 prompt 4j) that opens the station picker dialog to change which post a marker is linked to — a discreet action rather than a full-width dropdown, since re-pointing a marker's post after creation is rare.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get rolePlayPostEditAction;

  /// Small field-group label above the effective-identity card in RolePlayFormScreen (DESIGN-009 prompt 4i), matching the "Post"/"Position" labels above their own selectors.
  ///
  /// In en, this message translates to:
  /// **'Identity'**
  String get rolePlayIdentitySectionLabel;

  /// Trailing action label on the identity card's disclosure row that expands/collapses the "Tilpass" override panel (DESIGN-009 prompt 4i/4j) -- the only toggle for the panel, with a chevron (down closed / up open) showing which state it is in. There is no other disclosure text (DESIGN-009 prompt 4j): an untouched field simply reads as it is.
  ///
  /// In en, this message translates to:
  /// **'Customize'**
  String get rolePlayIdentityCustomizeAction;

  /// Single collective action at the foot of the identity card's override panel (DESIGN-009 prompt 4j) that clears every overridden facet at once back to the selected Person's current values -- superseding 4i's per-field reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get rolePlayIdentityResetAction;

  /// Identity card's collapsed-header third line, shown instead of the description when the roleplay's displayed name itself is an override (DESIGN-009 prompt 4j, superseding 4i's "Portraying {name}"), so the reader still knows which Person is actually being portrayed. {name} is that Person's own name.
  ///
  /// In en, this message translates to:
  /// **'Customized from {name}'**
  String rolePlayCustomizedFrom(String name);

  /// Age with its unit, used in the identity card's collapsed-header meta line (DESIGN-009 prompt 4i), e.g. "34 years · Woman".
  ///
  /// In en, this message translates to:
  /// **'{age, plural, =1{1 year} other{{age} years}}'**
  String rolePlayAgeYears(int age);

  /// Title in the marker's position card bar when it has its own coordinate (an override), shown instead of the followed location's name (DESIGN-009 prompt 4i/4j).
  ///
  /// In en, this message translates to:
  /// **'Own position'**
  String get rolePlayPositionOwnLabel;

  /// GenderSegmentedControl option label for the stable code "woman" (DESIGN-009 follow-up 3b, ADR-0047). Shared by Person.gender and, from prompt 4, RolePlay.gender.
  ///
  /// In en, this message translates to:
  /// **'Woman'**
  String get genderWomanLabel;

  /// GenderSegmentedControl option label for the stable code "man".
  ///
  /// In en, this message translates to:
  /// **'Man'**
  String get genderManLabel;

  /// GenderSegmentedControl option label for the stable code "other".
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get genderOtherLabel;

  /// Snackbar shown when Save is blocked because a Plan-scope markdown section contains {{var.<name>}} for an undeclared name. {sections} is a comma-joined list of the offending section labels.
  ///
  /// In en, this message translates to:
  /// **'Can’t save: {sections} contains an unknown variable'**
  String planSaveBlockedUndeclaredVariable(String sections);

  /// Snackbar shown when Save is blocked because a station or roleplay field contains a {{station.loc.<slug>}}/{{station.person.<slug>}} token whose slug does not resolve against the (linked) station's own locations/persons (DESIGN-009 prompt 5). {sections} is a comma-joined list of the offending field/section labels, {references} a comma-joined list of the broken reference tokens (e.g. station.loc.ghost).
  ///
  /// In en, this message translates to:
  /// **'Can’t save: {sections} references an unknown location or person: {references}'**
  String saveBlockedUnresolvedReference(String sections, String references);

  /// Title of the dialog shown when deleting a station-owned Location/Person is blocked because it is still referenced (DESIGN-009 prompt 5). {name} is the location's label or person's name.
  ///
  /// In en, this message translates to:
  /// **'Can’t delete “{name}”'**
  String stationReferenceGuardTitle(String name);

  /// Intro line above the bullet list of usages in the delete-guard dialog (DESIGN-009 prompt 5).
  ///
  /// In en, this message translates to:
  /// **'Still referenced:'**
  String get stationReferenceGuardMessage;

  /// One delete-guard usage line (DESIGN-009 prompt 5): the location/person is referenced by this station's own field. {field} is the field/section label (e.g. "Situation").
  ///
  /// In en, this message translates to:
  /// **'In {field}'**
  String stationReferenceUsageInField(String field);

  /// One delete-guard usage line (DESIGN-009 prompt 5): the location/person is referenced by a linked roleplay's field. {roleplay} is the roleplay's name, {field} the field label.
  ///
  /// In en, this message translates to:
  /// **'In {roleplay}’s {field}'**
  String stationReferenceUsageInRoleplayField(String roleplay, String field);

  /// One delete-guard usage line (DESIGN-009 prompt 5): the location is set as a person's home (Person.locSlug). {person} is that person's name.
  ///
  /// In en, this message translates to:
  /// **'Is {person}’s location'**
  String stationReferenceUsageIsPersonHome(String person);

  /// One delete-guard usage line (DESIGN-009 prompt 5): the person is portrayed by a roleplay (RolePlay.personRef). {roleplay} is that roleplay's name.
  ///
  /// In en, this message translates to:
  /// **'Portrayed by {roleplay}'**
  String stationReferenceUsagePortrayedBy(String roleplay);

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

  /// Skip button on the concept primer — dismisses the primer and goes straight to the Plan tab.
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

  /// Secondary CTA on the concept primer — dismisses the primer and lands on an empty Plan tab.
  ///
  /// In en, this message translates to:
  /// **'Start an empty plan'**
  String get primerStartEmpty;

  /// Indexed team label shown on the team chips in the ring rotation figure.
  ///
  /// In en, this message translates to:
  /// **'Team {n}'**
  String primerTeamLabel(int n);

  /// First-run-only inline pill label beside the first Plan FAB, nudging the user to create their first exercise.
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

  /// Title of the adaptive selector picker (ADR-0049, showRingdrillPicker) when picking a RolePlayFormScreen post/station.
  ///
  /// In en, this message translates to:
  /// **'Select post'**
  String get pickerSelectStationTitle;

  /// Title of the adaptive selector picker (ADR-0049, showRingdrillPicker) when picking a RolePlayFormScreen person.
  ///
  /// In en, this message translates to:
  /// **'Select person'**
  String get pickerSelectPersonTitle;

  /// Title of the adaptive selector picker (ADR-0049, showRingdrillPicker) used by CastPickerSheet, superseding castPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Select marker'**
  String get pickerSelectRolePlayTitle;

  /// Title of the drill player's target picker (ADR-0056): every target reachable from the player, grouped by kind. Not kind-specific, since the list spans exercises, posts, markers and teams.
  ///
  /// In en, this message translates to:
  /// **'Go to'**
  String get pickerGoToTitle;

  /// Hint text of the search field the adaptive selector picker (ADR-0049, showRingdrillPicker) shows once a list passes its search threshold.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get pickerSearchHint;

  /// Title of the adaptive selector picker (ADR-0049, showRingdrillPicker) that filters the marker list by exercise; the first choice is "All exercises", the rest one per exercise.
  ///
  /// In en, this message translates to:
  /// **'Filter by exercise'**
  String get pickerFilterByExerciseTitle;

  /// Edit where something is placed
  ///
  /// In en, this message translates to:
  /// **'Edit placement'**
  String get editPlacement;

  /// Sticky top row in the cast picker and FAB label in the cast roster sheet.
  ///
  /// In en, this message translates to:
  /// **'New member'**
  String get newStaff;

  /// Button and dialog title for deleting an Actor record from ActorFormScreen.
  ///
  /// In en, this message translates to:
  /// **'Delete member'**
  String get deleteStaff;

  /// Empty state shown in the cast roster sheet when no Actor records exist in the plan.
  ///
  /// In en, this message translates to:
  /// **'No staff yet. Tap + New member to add one.'**
  String get noStaffInRoster;

  /// Section label above the role multi-select in the staff editor (DESIGN-011).
  ///
  /// In en, this message translates to:
  /// **'Roles'**
  String get staffRolesLabel;

  /// Read-only section label listing the markører a staff member plays (DESIGN-011). Set by casting, not editable here.
  ///
  /// In en, this message translates to:
  /// **'Plays'**
  String get staffPlaysLabel;

  /// A markør a staff member plays, in the editor's read-only Spiller list (DESIGN-011). Set by casting in the Spill segment, not editable here.
  ///
  /// In en, this message translates to:
  /// **'{name} at station {badge} {window}'**
  String staffPlaysRow(String name, String badge, String window);

  /// Validation error when creating a staff member with no organizational role selected (DESIGN-011). Only enforced on create.
  ///
  /// In en, this message translates to:
  /// **'Select at least one role'**
  String get staffRolesRequired;

  /// StaffRole.other label (DESIGN-011) — a support role the enum does not name. Selectable both on the roster and as this device own role. Carries no edit rights.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get staffRoleOther;

  /// Swipe-to-edit label on a staff row (ADR-0031), matching editStation/editTeam.
  ///
  /// In en, this message translates to:
  /// **'Edit member'**
  String get editStaff;

  /// Plan status badge label and tooltip while an upload started from the badge is in flight.
  ///
  /// In en, this message translates to:
  /// **'Publishing …'**
  String get planStatusPublishing;

  /// Coordinate-bar value when no position is set, in place of the UTM string.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get positionNotSet;

  /// Title of the teaching empty state shown in a map slot with no position.
  ///
  /// In en, this message translates to:
  /// **'No position set'**
  String get noPositionTitle;

  /// Body of the no-position empty state on a station: what is lost by leaving it unset.
  ///
  /// In en, this message translates to:
  /// **'This station isn\'t shown on the map, and the brief gets no coordinate.'**
  String get noPositionStationBody;

  /// Body of the no-position empty state on a markør. Names both causes, because the central position is null only when neither the markør nor its station has one.
  ///
  /// In en, this message translates to:
  /// **'This markør follows its station, but the station has no position. Set a position on the station, or give the markør its own.'**
  String get noPositionRolePlayBody;

  /// Body of the no-position empty state on the all-stations map. Plural: the map has nothing to draw because no station is placed, so it names the fix rather than the loss (a single station's own card says what is lost).
  ///
  /// In en, this message translates to:
  /// **'No station in this exercise has a position yet. Set one on a station and it appears on the map.'**
  String get noPositionExerciseBody;

  /// Body of the all-stations map empty state when the exercise has no stations at all — a different fix from an unplaced station, and one step earlier.
  ///
  /// In en, this message translates to:
  /// **'There are no stations to place yet. Add one to this exercise, then give it a position.'**
  String get noStationsForMapBody;

  /// Action on the no-position empty state for a station.
  ///
  /// In en, this message translates to:
  /// **'Set position'**
  String get setPosition;

  /// Action on the no-position empty state for a markør: gives the markør its own position rather than following the station's.
  ///
  /// In en, this message translates to:
  /// **'Set own position'**
  String get setOwnPosition;
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
