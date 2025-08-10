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
  /// **'Open failed. Please try again.'**
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
  /// **'Share...'**
  String get shareProgram;

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

  /// Parameterized message
  ///
  /// In en, this message translates to:
  /// **'Must be equal or less than {name}'**
  String mustBeEqualToOrLessThanNumberOf(Object name);

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

  /// Message
  ///
  /// In en, this message translates to:
  /// **'Restart app to apply new patch'**
  String get restartAppToApplyNewPatch;

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
