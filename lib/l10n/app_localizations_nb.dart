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
  String get getReliableNotifications => 'Få pålitelige varsler';

  @override
  String get noReliableNotificationsReason =>
      'Lokale varsler er ikke fullt støttet på web. Nettlesere kan ikke kjøre koden vår i bakgrunnen for å utløse presise varsler, så timing og pålitelighet er begrenset. For pålitelige varsler, bruk RingDrill-appen.';

  @override
  String get useMobileAppNudge =>
      'Bruk RingDrill-appen for best mulig varslingsstøtte.';

  @override
  String get getOnAndroid => 'På Android';

  @override
  String get getOniOS => 'På iOS';

  @override
  String get getOnDesktop => 'På Desktop';

  @override
  String get openInApp => 'Åpne i app';

  @override
  String get installWebApp => 'Installer nett-app';

  @override
  String get continueOnWeb => 'Fortsett på nett';

  @override
  String get confirm => 'BEKREFT';

  @override
  String get dismiss => 'AVVIS';

  @override
  String get confirmDeleteExercise =>
      'Dette vil slette øvelsen. Vil du fortsette?';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'AVBRYT';

  @override
  String get yes => 'JA';

  @override
  String get no => 'NEI';

  @override
  String get allow => 'TILLAT';

  @override
  String get decline => 'AVSLÅ';

  @override
  String get enterFileName => 'Skriv inn filnavn';

  @override
  String get fileNameHint => 'MittProgram';

  @override
  String get invalidFileName => 'Ugyldig filnavn. Prøv igjen.';

  @override
  String openSuccess(Object name) {
    return 'Åpning av \"$name\" var vellykket!';
  }

  @override
  String openFailure(Object name) {
    return 'Åpning av \"$name\" mislyktes. Prøv igjen.';
  }

  @override
  String get exportedProgram => 'Eksportert Program';

  @override
  String exportSuccess(Object name) {
    return 'Eksport til \"$name\" var vellykket!';
  }

  @override
  String exportFailure(Object name) {
    return 'Eksport til \"$name\" mislyktes. Prøv igjen.';
  }

  @override
  String sendToSuccess(Object name) {
    return 'Sending av \"$name\" var vellykket!';
  }

  @override
  String sendToFailure(Object name) {
    return 'Sending av \"$name\" mislyktes. Prøv igjen.';
  }

  @override
  String shareSuccess(Object name) {
    return 'Deling av \"$name\" var vellykket!';
  }

  @override
  String shareFailure(Object name) {
    return 'Deling mislyktes. Prøv igjen.';
  }

  @override
  String get sharedFileReceived =>
      'Velg [Åpne] for å erstatte eksisterende øvelser fullstendig, eller [Importer] for å legge til i eksisterende øvelser, og overskrive kun hvis de allerede finnes. Hva ønsker du å gjøre?';

  @override
  String get storage => 'Lagring';

  @override
  String get documents => 'Dokumenter';

  @override
  String get downloads => 'Nedlastinger';

  @override
  String get sdCard => 'SD kort';

  @override
  String get open => 'ÅPNE';

  @override
  String get import => 'IMPORTER';

  @override
  String get select => 'VELG';

  @override
  String get selectDirectory => 'Velg en mappe';

  @override
  String get selectFile => 'Velg en fil';

  @override
  String get selectExercises => 'Velg øvelser';

  @override
  String get showExercises => 'Vis øvelser';

  @override
  String get showAll => 'Vis alle';

  @override
  String get hideAll => 'Skjul alle';

  @override
  String get showLabels => 'Vis etiketter';

  @override
  String get hideLabels => 'Skjul etiketter';

  @override
  String get markerTypes => 'Markørtyper';

  @override
  String get showStations => 'Vis poster';

  @override
  String get showRoleplays => 'Vis markører';

  @override
  String get filterActiveCombined => 'Filter aktivt';

  @override
  String exercisesShownOfTotal(int shown, int total) {
    return 'Viser $shown av $total øvelser';
  }

  @override
  String importSuccess(Object name) {
    return 'Program \"$name\" ble importert.';
  }

  @override
  String importFailure(Object name) {
    return 'Kunne ikke importere \"$name\". Prøv igjen.';
  }

  @override
  String program(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Programmer',
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
      other: 'Øvelser',
      one: 'Øvelse',
      zero: 'Øvelse',
    );
    return '$_temp0';
  }

  @override
  String get schedule => 'Plan';

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
  String get notStationsCreated => 'Ingen poster opprettet';

  @override
  String get mapTab => 'Kart';

  @override
  String get stationsTab => 'Poster';

  @override
  String get allExercises => 'Alle øvelser';

  @override
  String showingStationsIn(String name) {
    return 'Viser poster i: $name';
  }

  @override
  String get noStationsInExercise => 'Ingen poster i denne øvelsen.';

  @override
  String get noStationsYet =>
      'Ingen poster ennå. Legg til en post fra Øvelser-fanen.';

  @override
  String get stationName => 'Postnavn';

  @override
  String get stationNameHint => 'Gi posten et navn';

  @override
  String get editStation => 'Endre post';

  @override
  String get stationDescription => 'Postbeskrivelse';

  @override
  String get programFile => 'Programfil';

  @override
  String get openProgramHint =>
      'Vil du åpne programmet, eller importere øvelser inn i nåværende?';

  @override
  String get openProgram => 'Åpne...';

  @override
  String get importProgram => 'Import...';

  @override
  String get exportProgram => 'Eksport...';

  @override
  String get sendToProgram => 'Send til...';

  @override
  String get shareProgram => 'Del...';

  @override
  String get feedback => 'Tilbakemelding...';

  @override
  String get stationDescriptionHint => 'Beskriv hvordan posten skal utføres';

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
  String member(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'medlemmer',
      one: 'medlem',
      zero: 'medlem',
    );
    return '$_temp0';
  }

  @override
  String get teamNoExercises => 'Laget er ikke med i noen øvelser ennå.';

  @override
  String get teamsOverview => 'Lagsoversikt';

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
  String get teamRotations => 'Lagrullering';

  @override
  String get stationRotations => 'Postrullering';

  @override
  String get save => 'LAGRE';

  @override
  String get delete => 'SLETT';

  @override
  String get createExercise => 'Opprett øvelse';

  @override
  String get editExercise => 'Endre øvelse';

  @override
  String get stopExercise => 'Stop øvelse';

  @override
  String get deleteExercise => 'Slett øvelse';

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
  String get noLocation => 'Ingen posisjon';

  @override
  String get noDescription => 'Ingen beskrivelse';

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
  String get numberOfStations => 'Antall poster';

  @override
  String mustBeEqualToOrLessThanNumberOf(Object name) {
    return 'Må være mindre eller lik $name';
  }

  @override
  String mustBeEqualToOrGreaterThanNumberOf(Object name) {
    return 'Må være større eller lik $name';
  }

  @override
  String stationsRevisitNote(int rounds, int stations) {
    return 'Hvert lag besøker noen poster flere ganger. Med $rounds runder og $stations poster passerer hvert lag hver post omtrent $rounds/$stations ganger.';
  }

  @override
  String stationsUnderCoverageNote(int rounds, int stations) {
    return 'Hvert lag besøker bare $rounds av $stations poster under denne øvelsen.';
  }

  @override
  String get confirmReduceStationsTitle => 'Redusere antall poster?';

  @override
  String confirmReduceStationsBody(int count) {
    return 'Hvis du reduserer antall poster, fjernes $count poster med navn, beskrivelser og posisjoner. Dette kan ikke angres. Fortsette?';
  }

  @override
  String get legacyOversizedExerciseNotice =>
      'Denne øvelsen ble laget før dagens grense på 12. Eksisterende verdier beholdes, men reduksjon er permanent og verdier over 12 må senkes før lagring.';

  @override
  String get pleaseEnterAValidNumber => 'Oppgi et nummer';

  @override
  String get newPatchIsAvailable => 'Ny oppdatering er tilgjengelig';

  @override
  String get updateRequired => 'Oppdater';

  @override
  String get restartNow => 'RESTART';

  @override
  String get restartAppToApplyNewPatch =>
      'Start appen på nytt for ny oppdatering';

  @override
  String get appUpdateAvailable => 'En oppdatering er tilgjengelig';

  @override
  String get appUpdatedRestarting => 'Appen er oppdatert, starter på nytt...';

  @override
  String get appUpdatedPleaseCloseAndOpen =>
      'Appen er oppdatert. Lukk appen og åpne den igjen.';

  @override
  String get forceUpdateTitle => 'Tving oppdatering';

  @override
  String get forceUpdateSubtitle =>
      'Tømmer nettleserens cache og laster siden på nytt. Bruk dette hvis appen ser ut til å henge på en gammel versjon.';

  @override
  String get forceUpdateConfirmTitle => 'Tving oppdatering?';

  @override
  String get forceUpdateConfirmBody =>
      'Dette tømmer nettleserens cache for ringdrill og laster siden på nytt. Planer og innstillinger som er lagret på denne enheten beholdes.';

  @override
  String get forceUpdateConfirmAction => 'Oppdater nå';

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
  String get zoomIn => 'Zoom inn';

  @override
  String get zoomOut => 'Zoom ut';

  @override
  String get locateMe => 'Vis min posisjon';

  @override
  String get locating => 'Henter posisjon…';

  @override
  String get locationServicesDisabled =>
      'Slå på posisjonstjenester for å bruke denne funksjonen.';

  @override
  String get locationPermissionDenied => 'Tilgang til posisjon ble avslått.';

  @override
  String get locationPermissionDeniedForever =>
      'Tilgang til posisjon er permanent avslått. Aktiver den i systeminnstillingene for å vise posisjonen din.';

  @override
  String get locationError => 'Kunne ikke finne posisjonen din.';

  @override
  String get searchHintStation => 'Post';

  @override
  String get searchHintExercise => 'Øvelse';

  @override
  String get searchHintPlace => 'Sted';

  @override
  String setPositionFor(String name) {
    return 'Sett posisjon for $name';
  }

  @override
  String get positionSaved => 'Posisjon lagret';

  @override
  String get stationGone => 'Fant ikke posten — den kan ha blitt fjernet.';

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
  String get phaseNow => 'Fase nå';

  @override
  String get nextLabel => 'Neste';

  @override
  String phaseEndsAt(String time) {
    return 'ferdig $time';
  }

  @override
  String remainingInPhase(String phase) {
    return 'Igjen av $phase';
  }

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

  @override
  String get library => 'Bibliotek';

  @override
  String get libraryMyPlans => 'Mine planer';

  @override
  String get libraryCatalog => 'Katalog';

  @override
  String get libraryOnlineTab => 'På nett';

  @override
  String get libraryMyPlansSubtitle => 'Velg en lagret plan for å fortsette';

  @override
  String get libraryOnlineSubtitle => 'Hent en plan fra bibliotek på nett';

  @override
  String get libraryFromFileSubtitle => 'Importer en .drill-fil fra enheten';

  @override
  String get libraryEmptyMyPlans =>
      'Du har ingen lagrede planer. Bla i «På nett» eller «Ny fra fil» for å komme i gang.';

  @override
  String get libraryFromFilePickAction => 'Velg fil';

  @override
  String get libraryFromFileHint => 'Velg en .drill-fil fra enheten din';

  @override
  String get libraryCatalogBadge => 'Fra nett-bibliotek';

  @override
  String get planStatusLocal => 'Lokal';

  @override
  String get planStatusLocalTooltip =>
      'Denne planen ligger bare på enheten din';

  @override
  String get planStatusOnlineTooltip =>
      'Denne planen er koblet til nett-biblioteket';

  @override
  String get addExercisesMyPlansSubtitle => 'Velg en plan å hente øvelser fra';

  @override
  String get addExercisesFromFileSubtitle =>
      'Importer øvelser fra en .drill-fil';

  @override
  String get addExercisesEmptyMyPlans =>
      'Du har ingen andre planer å hente fra ennå';

  @override
  String get librarySourceLocal => 'Lokal';

  @override
  String librarySourceImported(Object fileName) {
    return 'Importert fra $fileName';
  }

  @override
  String librarySourceCatalog(Object slug) {
    return 'Fra katalog · $slug';
  }

  @override
  String get libraryActive => 'Aktiv';

  @override
  String get libraryInstalled => 'I bibliotek';

  @override
  String get libraryInstall => 'Åpne';

  @override
  String get libraryRefresh => 'Oppdater fra katalog';

  @override
  String get libraryRename => 'Gi nytt navn';

  @override
  String get libraryExport => 'Eksporter som .drill';

  @override
  String get libraryPublish => 'Publiser';

  @override
  String get libraryPublishAs => 'Publiser som…';

  @override
  String get libraryDelete => 'Slett';

  @override
  String get libraryEmptyCatalog => 'Ingen planer på nett ennå';

  @override
  String get libraryErrorLoad => 'Kunne ikke laste planer fra nett';

  @override
  String get installedFromLink => 'Plan lagt til fra delelenke';

  @override
  String get libraryRetry => 'Prøv igjen';

  @override
  String get libraryCannotSwitchRunning =>
      'Stopp øvelsen som kjører før du endrer planer.';

  @override
  String get openPlan => 'Åpne plan...';

  @override
  String get openPlanTooltip => 'Åpne plan';

  @override
  String get newPlanAction => 'Ny plan';

  @override
  String get newPlanNamePrompt => 'Gi den nye planen et navn';

  @override
  String get create => 'Opprett';

  @override
  String get fromFileAction => 'Ny fra fil';

  @override
  String get addExercisesAction => 'Legg til øvelser fra...';

  @override
  String get addFromFile => 'Fra fil';

  @override
  String get addFromAnotherPlan => 'Fra en annen av mine planer';

  @override
  String get pickFile => 'Velg fil...';

  @override
  String get confirmChangesTitle => 'Bekreft endringer';

  @override
  String get apply => 'Bruk';

  @override
  String get noOtherLocalPlans => 'Ingen andre lokale planer enda';

  @override
  String get requiresActivePlan => 'Åpne eller opprett en plan først';

  @override
  String get shareActivePlan => 'Kopier URL';

  @override
  String get planUrlCopied => 'URL kopiert';

  @override
  String get sendToAction => 'Send til...';

  @override
  String get sendToActionButton => 'SEND TIL...';

  @override
  String get exportAsDrill => 'Eksporter som .drill';

  @override
  String get exportAction => 'EKSPORTER';

  @override
  String get importAction => 'IMPORTER';

  @override
  String get selectExercisesAction => 'VELG...';

  @override
  String get selectAll => 'VELG ALLE';

  @override
  String get selectNone => 'VELG INGEN';

  @override
  String get exportAllExercisesHint =>
      'Alle øvelser inkluderes. Trykk «VELG...» for å plukke selv.';

  @override
  String selectedOfTotal(int selected, int total) {
    return '$selected av $total valgt';
  }

  @override
  String get publishActivePlan => 'Publiser';

  @override
  String get publishAsActivePlan => 'Publiser som...';

  @override
  String get defaultPlanName => 'Standardplan';

  @override
  String get libraryMigrationNotice =>
      'Bibliotek og katalog er nytt. Den eksisterende planen din er flyttet til Standardplan og er fortsatt aktiv.';

  @override
  String installedAndActivated(Object name) {
    return 'Installert og aktivert $name';
  }

  @override
  String openedAndActivated(Object name) {
    return 'Åpnet $name';
  }

  @override
  String get catalogConflictTitle => 'Konflikt ved katalogoppdatering';

  @override
  String get catalogConflictBody =>
      'Denne katalogplanen har lokale endringer. Se gjennom forskjellene før du velger hvordan du vil fortsette.';

  @override
  String get catalogConflictCancel => 'Avbryt';

  @override
  String get catalogConflictOverwrite => 'Overskriv lokalt';

  @override
  String get catalogConflictPublish => 'Publiser mine endringer';

  @override
  String get catalogConflictFork => 'Lag lokal kopi';

  @override
  String get catalogDiffAdded => 'Lagt til';

  @override
  String get catalogDiffRemoved => 'Fjernet';

  @override
  String get catalogDiffModified => 'Endret';

  @override
  String get catalogDiffLocal => 'Din versjon';

  @override
  String get catalogDiffRemote => 'Katalogversjon';

  @override
  String get catalogDiffName => 'Plannavn';

  @override
  String get catalogDiffDescription => 'Beskrivelse';

  @override
  String get catalogDiffExercises => 'Øvelser';

  @override
  String get catalogDiffTeams => 'Lag';

  @override
  String get catalogDiffSessions => 'Økter';

  @override
  String get catalogServiceChecking => 'Sjekker';

  @override
  String get catalogServiceOnline => 'Online';

  @override
  String get catalogServiceUnavailable => 'Utilgjengelig';

  @override
  String get catalogServiceCorsBlocked => 'CORS blokkert';

  @override
  String get catalogServiceCorsBlockedTooltip =>
      'Nettleseren blokkerte katalogforespørselen fordi Netlify-funksjonen ikke tillater denne lokale opprinnelsen. Bruk den publiserte webappen eller aktiver CORS på funksjonen for lokal webutvikling.';

  @override
  String get libraryPublishTitle => 'Publiser plan';

  @override
  String get libraryPublishAsTitle => 'Publiser som';

  @override
  String get libraryPublishBody =>
      'Planen blir lagt til i den åpne katalogen. Alle kan installere den, og alle som har den kan publisere oppdateringer.';

  @override
  String get libraryPublishAsBody =>
      'Velg en slug for denne versjonen. Hvis du endrer slug på en allerede publisert plan, lages det en lokal kopi som peker på den nye slug-en — originalen forblir koblet til sin nåværende slug.';

  @override
  String get libraryPublishSlugLabel => 'Slug';

  @override
  String get libraryPublishSlugHelper =>
      'Kun små bokstaver, tall og bindestrek.';

  @override
  String get libraryPublishTagsLabel => 'Tagger (kommaseparert)';

  @override
  String get libraryPublishSubmit => 'Publiser';

  @override
  String libraryPublishSlugTaken(Object slug) {
    return 'Slug «$slug» er allerede i bruk av en urelatert plan. Velg en annen slug.';
  }

  @override
  String get libraryPublishConflict =>
      'Noen oppdaterte denne planen først. Prøv igjen.';

  @override
  String libraryPublishSuccess(Object name) {
    return 'Publiserte $name';
  }

  @override
  String get libraryPublishNoChange => 'Ingen endringer å publisere';

  @override
  String get libraryPublishFailed => 'Kunne ikke publisere planen';

  @override
  String get rotationShareEachRound => 'Generelt hver runde';

  @override
  String get rotationShareLegendPhases =>
      'øve | evaluere | rullere / inntransport';

  @override
  String get rotationShareTitle => 'Rullering (klokkeslett)';

  @override
  String get rotationShareNext => 'neste';

  @override
  String get rotationShareReturn => 'retur';

  @override
  String shareNoteRevisits(int rounds, int stations) {
    return 'Merk: $rounds runder på $stations poster betyr at hvert lag besøker noen poster flere ganger.';
  }

  @override
  String shareNoteUnderCoverage(int rounds, int stations) {
    return 'Merk: $rounds runder på $stations poster betyr at hvert lag bare besøker noen poster.';
  }

  @override
  String get exerciseCopied => 'Øvelse kopiert til utklippstavlen';

  @override
  String get exerciseCopyTooltip => 'Kopier øvelse';

  @override
  String get rolePlaysTab => 'Markører';

  @override
  String get roleSection => 'Markørordre';

  @override
  String get castSection => 'Spilles av';

  @override
  String get addCast => 'Velg markør';

  @override
  String get editCast => 'Rediger markør';

  @override
  String get clearCast => 'Fjern markør';

  @override
  String get castRoster => 'Markører';

  @override
  String get newActor => 'Ny markør';

  @override
  String castedAs(String names) {
    return 'Markør for: $names';
  }

  @override
  String alreadyCastAs(String name) {
    return 'Allerede markør for $name';
  }

  @override
  String castPickerTitle(String role) {
    return 'Markør: $role';
  }

  @override
  String get castPrivateHint => 'Lagres lokalt';

  @override
  String roleSubtitleStation(String name) {
    return 'Post: $name';
  }

  @override
  String roleSubtitleExercise(String name) {
    return 'Øvelse: $name';
  }

  @override
  String get noActorsInRoster =>
      'Ingen markører ennå. Trykk + Ny markør for å legge til.';

  @override
  String get noActiveProgramHint =>
      'Ingen aktiv øvelsesplan. Velg eller opprett en i Øvelser-fanen.';

  @override
  String get noSignalement => 'Ingen signalement';

  @override
  String get noBackground => 'Ingen bakgrunn';

  @override
  String get noBehavior => 'Ingen oppførsel';

  @override
  String get noStationAssigned => 'Ingen post';

  @override
  String get noRolesInProgram =>
      'Ingen markører ennå. Åpne en post i Poster-fanen for å legge til en.';

  @override
  String get noRolesInExercise => 'Ingen markører for denne øvelsen.';

  @override
  String get showAllRoles => 'Vis alle';

  @override
  String showingRolesIn(String exercise) {
    return 'Viser markører i: $exercise';
  }

  @override
  String castDeleteBlocked(int count) {
    return 'Markør i $count rolle(r). Fjern først.';
  }

  @override
  String get confirmReduceRoles => '(placeholder)';

  @override
  String get unknownRole => 'Ukjent rolle';

  @override
  String get roleName => 'Navn';

  @override
  String get roleAge => 'Alder';

  @override
  String get optional => 'Valgfritt';

  @override
  String get ageRange => 'Alder må være mellom 0 og 120';

  @override
  String get stationLabel => 'Post';

  @override
  String get actorRealName => 'Fullt navn';

  @override
  String get actorPhone => 'Telefon';

  @override
  String get actorNotes => 'Notater';

  @override
  String get addRolePlay => 'Legg til markørordre';

  @override
  String get newRolePlayTitle => 'Ny markørordre';

  @override
  String get editRolePlayTitle => 'Rediger markørordre';

  @override
  String get stationRolesSection => 'Markører';

  @override
  String get noRolesAtThisStation => 'Ingen markører på denne posten';

  @override
  String get roleSignalement => 'Signalement';

  @override
  String get roleBackground => 'Bakgrunn';

  @override
  String get roleBehavior => 'Oppførsel';

  @override
  String castedByLine(String name) {
    return 'Spilles av $name';
  }

  @override
  String get noCastLine => 'Ingen markør valgt';
}
