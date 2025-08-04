// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Norwegian Bokmål (`nb`).
class AppLocalizationsNb extends AppLocalizations {
  AppLocalizationsNb([String locale = 'nb']) : super(locale);

  @override
  String get appName => 'RingDrill';

  @override
  String get appDescription =>
      'RingDrill gjør det enkelt å planlegge og administrere postbaserte ringøvelser – som ofte brukes i taktiske, nød- eller operative treningsscenarioer.';

  @override
  String get developedBy => 'Utviklet av';

  @override
  String get website => 'Nettside';

  @override
  String get privacyPolicy => 'Personvernerklæring';

  @override
  String get termsOfService => 'Brukervilkår';

  @override
  String get contactSupport => 'Kontakt brukerstøtte';

  @override
  String get appAnalyticsConsent => 'Samtykke til appanalyse';

  @override
  String get appAnalyticsConsentMessage =>
      'Vi bruker analyser for å forbedre appopplevelsen ved å samle inn krasjrapporter og generelle bruksdata fra enheten din.';

  @override
  String get appAnalyticsConsentOptIn =>
      'Du kan velge om du vil aktivere denne funksjonen nå eller senere i innstillingene.';

  @override
  String get appAnalyticsConsentCollectedData =>
      'Dette inkluderer informasjon om enheten din (f.eks. enhetsmodell, OS-versjon) og krasjrapporter i tilfelle feil. Disse dataene sendes til og behandles av Sentry.io.';

  @override
  String get learnMoreAboutDataCollected => 'Lær mer om innsamlede data';

  @override
  String get allowAppAnalytics => 'Tillat appanalyse';

  @override
  String get allowAppAnalyticsMessage =>
      'Aktiver innsamling av analyser og krasjrapporter. Disse dataene er knyttet til enheten din, men ikke identiteten din.';

  @override
  String get confirm => 'Bekreft';

  @override
  String get confirmDeleteExercise =>
      'Dette vil slette øvelsen. Vil du fortsette?';

  @override
  String get ok => 'OK';

  @override
  String get yes => 'JA';

  @override
  String get no => 'NEI';

  @override
  String get allow => 'TILLAT';

  @override
  String get decline => 'AVSLÅ';

  @override
  String exercise(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Øvelser',
      one: 'Øvelse',
      zero: 'Øvelse',
    );
    return '$_temp0';
  }

  @override
  String round(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Runder',
      one: 'Runde',
      zero: 'Runde',
    );
    return '$_temp0';
  }

  @override
  String station(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Poster',
      one: 'Post',
      zero: 'Post',
    );
    return '$_temp0';
  }

  @override
  String get stationName => 'Postnavn';

  @override
  String get stationNameHint => 'Gi posten et navn';

  @override
  String get editStation => 'Endre post';

  @override
  String get saveStation => 'LAGRE POST';

  @override
  String get stationDescription => 'Postbeskrivelse';

  @override
  String get stationDescriptionHint =>
      'Gi en beskrivelse av hvordan denne posten skal utføres';

  @override
  String team(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Lag',
      zero: 'Lag',
    );
    return '$_temp0';
  }

  @override
  String notification(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Varsler',
      one: 'Varsel',
      zero: 'Varsel',
    );
    return '$_temp0';
  }

  @override
  String get toggleNotificationDescription =>
      'Aktiver eller deaktiver lokale varsler for påminnelser og oppdateringer mens du bruker appen. Hvis du deaktiverer dette, stoppes sendingen av alle varsler umiddelbart.';

  @override
  String get enableNotifications => 'Aktiver varsler';

  @override
  String get enableNotificationsMessage =>
      'Når det er aktivert, vil du motta påminnelser og oppdateringer via varsler.';

  @override
  String get setUrgentNotificationThreshold => 'Angi terskel for hastevarsling';

  @override
  String get setUrgentNotificationThresholdDescription =>
      'Antall minutter som gjenstår før neste fase for å vise et hastevarsel.';

  @override
  String get fullScreenNotifications => 'Fullskjerm varlser';

  @override
  String get fullScreenNotificationsDescription =>
      'Tillat at varsler vises i fullskjermmodus for hastevarsler, selv når andre apper er åpne.';

  @override
  String get playSoundWhenUrgent => 'Spill av lyd når det haster';

  @override
  String get playSoundWhenUrgentDescription =>
      'Slå varslingslyder av eller på for hastevarsler.';

  @override
  String get vibrateWhenUrgent => 'Vibrer når det haster';

  @override
  String get vibrateWhenUrgentDescription =>
      'Aktiver eller deaktiver vibrasjon for hastevarsler.';

  @override
  String get position => 'Posisjon';

  @override
  String get settings => 'Innstillinger';

  @override
  String get about => 'Om';

  @override
  String get version => 'Versjon';

  @override
  String get noExercisesYet => 'Ingen øvelser ennå!';

  @override
  String get teamRotations => 'Lagrulleringer';

  @override
  String get stationRotations => 'Postrulleringer';

  @override
  String get createExercise => 'Opprett øvelse';

  @override
  String get editExercise => 'Endre øvelse';

  @override
  String get saveExercise => 'Lagre øvelse';

  @override
  String get stopExercise => 'Stop øvelse';

  @override
  String get noRoundsScheduled => 'Ingen runder planlagt!';

  @override
  String get showNotification => 'Vis varsel';

  @override
  String get openNotification => 'Åpne varsel';

  @override
  String get exerciseNotifications => 'Vis varsel';

  @override
  String stopExerciseFirst(Object exercise) {
    return 'Stop $exercise først!';
  }

  @override
  String get noLocation => 'Ingen posisjon oppgitt';

  @override
  String get noDescription => 'Ingen beskrivelse oppgitt';

  @override
  String get exerciseName => 'Øvingsnavn';

  @override
  String get pleaseEnterAName => 'Oppgi navn på øvelse';

  @override
  String get startTime => 'Starttid';

  @override
  String get numberOfRounds => 'Antall runder';

  @override
  String get numberOfTeams => 'Antall lag';

  @override
  String mustBeEqualToOrLessThanNumberOf(Object name) {
    return 'Må være lik eller mindre enn antall $name';
  }

  @override
  String get pleaseEnterAValidNumber => 'Oppgi et nummer';

  @override
  String get newPatchIsAvailable => 'Ny oppdatering er tilgjengelig';

  @override
  String get restartAppToApplyNewPatch =>
      'Start appen på nytt for ny oppdatering';

  @override
  String get appUpdatedRestarting => 'Appen er oppdatert, starter på nytt...';

  @override
  String get appUpdatedPleaseCloseAndOpen =>
      'Appen er oppdatert. Lukk appen og åpne den igjen.';

  @override
  String get searchForPlaceOrLocation => 'Søk etter sted eller posisjon';

  @override
  String searchFailed(Object error) {
    return 'Søk feilet: $error';
  }

  @override
  String get pickALocation => 'Velg plassering';

  @override
  String get switchToOSM => 'Bytt til OSM';

  @override
  String get switchToTopo => 'Bytt til Topo';

  @override
  String get selectAction => 'Velg';

  @override
  String get analyticsEnabled => 'Appanalyse er aktivert';

  @override
  String get analyticsDisabled => 'Appanalyse er deaktivert';

  @override
  String get analyticsIsAllowed => 'Appanalyse er tillatt';

  @override
  String get analyticsIsDenied => 'Appanalyse er ikke tillatt';

  @override
  String get isRunning => 'kjører';

  @override
  String get executionTime => 'Øvingstid';

  @override
  String get evaluationTime => 'Evalueringstid';

  @override
  String get rotationTime => 'Rulleringstid';

  @override
  String get pleaseEnterAValidTime => 'Oppgi tid';

  @override
  String get isPending => 'venter';

  @override
  String get isDone => 'er ferdig';

  @override
  String get pending => 'Venter';

  @override
  String get execution => 'Øving';

  @override
  String get evaluation => 'Evaluering';

  @override
  String get rotation => 'Rullering';

  @override
  String get done => 'Ferdig';

  @override
  String get wait => 'Vent';

  @override
  String get drill => 'Øve';

  @override
  String get eval => 'Eval';

  @override
  String get roll => 'Rull';

  @override
  String second(Object count) {
    return '$count sek';
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
      other: '$count timer',
      one: '1 time',
      zero: 'nå',
    );
    return '$_temp0';
  }

  @override
  String day(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dager',
      one: '1 dag',
      zero: 'nå',
    );
    return '$_temp0';
  }

  @override
  String week(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count uker',
      one: '1 uke',
      zero: 'nå',
    );
    return '$_temp0';
  }

  @override
  String month(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count måneder',
      one: '1 måned',
      zero: 'nå',
    );
    return '$_temp0';
  }

  @override
  String year(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count år',
      one: '1 år',
      zero: 'nå',
    );
    return '$_temp0';
  }

  @override
  String minutesLeft(Object count) {
    return '$count min igjen';
  }

  @override
  String timeToStart(Object time) {
    return '$time start';
  }

  @override
  String timeToNext(Object time) {
    return '$time neste';
  }
}
