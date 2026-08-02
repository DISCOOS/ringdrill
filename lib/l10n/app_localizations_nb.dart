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
  String get appNotificationConsent => 'Tillat varsler';

  @override
  String get appNotificationConsentMessage =>
      'RingDrill bruker varsler for å varsle om post-overganger, rundeskifter og når en øvelse er ferdig — også når appen ligger i bakgrunnen.';

  @override
  String get appNotificationConsentOptIn =>
      'Trykk Tillat for å motta varsler. Du kan endre dette senere i innstillingene.';

  @override
  String get skipForNow => 'Hopp over for nå';

  @override
  String get onboardingWelcomeHeading => 'Velkommen til RingDrill';

  @override
  String get onboardingWelcomeBody =>
      'Planlegg og gjennomfør postbaserte øvelser.';

  @override
  String get openSettings => 'Åpne innstillinger';

  @override
  String get notificationsDeniedBanner =>
      'Varsler er av. Slå dem på i innstillingene for å få rotasjons- og post-varsler.';

  @override
  String get notificationsDeniedTitle => 'Varsler er av';

  @override
  String get notificationsDeniedHelp =>
      'RingDrill kan ikke slå på varsler for deg — iOS tillater varselsdialogen bare én gang. Åpne Innstillinger, finn RingDrill og tillat Varsler for å få varsler om rotasjon, runder og fullført øvelse, også når appen kjører i bakgrunnen.';

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
  String get getReliableNotifications => 'Få varsler';

  @override
  String get noReliableNotificationsReason =>
      'RingDrill-varsler støttes ikke i nettleseren eller den installerte web-appen. Web-en kan ikke kjøre øvelses-timere i bakgrunnen, så planlagte varsler blir ikke levert. For varsler, bruk RingDrill-appen fra App Store eller Google Play.';

  @override
  String get useMobileAppNudge => 'Varsler krever RingDrill-appen.';

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
  String get fileNameHint => 'MinPlan';

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
  String openInvalidDrill(String name) {
    return '\"$name\" er ikke en gyldig RingDrill-fil.';
  }

  @override
  String openEmptyDrill(String name) {
    return '\"$name\" er tom eller mangler innhold.';
  }

  @override
  String openCorruptDrill(String name) {
    return '\"$name\" er skadet eller ufullstendig.';
  }

  @override
  String openUnsupportedSchema(String name) {
    return '\"$name\" bruker et nyere format. Oppdater RingDrill for å åpne den.';
  }

  @override
  String get exportedPlan => 'Eksportert Plan';

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
  String get filter => 'Filter';

  @override
  String get filterShowOnMap => 'Vis på kart';

  @override
  String get showAll => 'Vis alle';

  @override
  String get showMore => 'Les mer';

  @override
  String get showLess => 'Vis mindre';

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
    return 'Plan \"$name\" ble importert.';
  }

  @override
  String importFailure(Object name) {
    return 'Kunne ikke importere \"$name\". Prøv igjen.';
  }

  @override
  String plan(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Planer',
      one: 'Plan',
      zero: 'Plan',
    );
    return '$_temp0';
  }

  @override
  String get planTab => 'Øvingsplan';

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
  String get infoTab => 'Info';

  @override
  String get scriptTab => 'Spill';

  @override
  String get expandMap => 'Åpne fullt kart';

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
  String get emptyStationsTitle => 'Ingen poster ennå';

  @override
  String get emptyStationsBody =>
      'Poster legges til inne i øvelsene dine. Opprett en øvelse først, så dukker postene opp her.';

  @override
  String get stationName => 'Postnavn';

  @override
  String get stationCode => 'Postkode';

  @override
  String get positionUtm => 'Posisjon (UTM)';

  @override
  String get utm => 'UTM';

  @override
  String get variantSuffix => 'Variantsuffiks';

  @override
  String get stationNameHint => 'Gi posten et navn';

  @override
  String get editStation => 'Endre post';

  @override
  String get editTeam => 'Endre lag';

  @override
  String get teamName => 'Navn på lag';

  @override
  String get emptyTeamsTitle => 'Ingen lag ennå';

  @override
  String get emptyTeamsBody =>
      'Lag kommer fra antall lag i øvelsene dine. Opprett en øvelse først, så dukker lagene opp her.';

  @override
  String get numberOfMembers => 'Antall medlemmer';

  @override
  String get stationDescription => 'Postbeskrivelse';

  @override
  String get planFile => 'Planfil';

  @override
  String get openPlanHint =>
      'Vil du åpne planen, eller importere øvelser inn i nåværende?';

  @override
  String get openPlanAction => 'Åpne...';

  @override
  String get importPlan => 'Import...';

  @override
  String get exportPlan => 'Eksport...';

  @override
  String get sendToPlan => 'Send til...';

  @override
  String get sharePlan => 'Del...';

  @override
  String get feedback => 'Tilbakemelding...';

  @override
  String get stationDescriptionHint => 'Beskriv hvordan posten skal utføres';

  @override
  String get stationAddDescriptionAction => 'Legg til beskrivelse';

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
  String get about => 'Om RingDrill';

  @override
  String get version => 'Versjon';

  @override
  String get commit => 'Commit';

  @override
  String get viewOnGithub => 'Åpne i GitHub';

  @override
  String get noExercisesYet => 'Ingen øvelser ennå!';

  @override
  String get emptyExercisesTitle => 'Ingen øvelser ennå';

  @override
  String get emptyExercisesBody =>
      'Legg til den første øvelsen for å komme i gang.';

  @override
  String get save => 'LAGRE';

  @override
  String get delete => 'SLETT';

  @override
  String get createExercise => 'Opprett øvelse';

  @override
  String get newExercise => 'Ny øvelse';

  @override
  String get editExercise => 'Endre øvelse';

  @override
  String get stopExercise => 'Stop øvelse';

  @override
  String get exerciseAutoStoppedTitle => 'Øvelse avsluttet';

  @override
  String exerciseAutoStoppedBody(String exercise) {
    return 'Sluttiden for $exercise er passert.';
  }

  @override
  String exerciseAutoStoppedSnack(String exercise) {
    return '$exercise avsluttet automatisk';
  }

  @override
  String get dismiss => 'Lukk';

  @override
  String get deleteExercise => 'Slett øvelse';

  @override
  String get noRoundsScheduled => 'Ingen runder planlagt!';

  @override
  String get showNotification => 'Vis varsel';

  @override
  String get openNotification => 'Åpne varsel';

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
  String get modified => 'Tilpasset';

  @override
  String get placement => 'Plassering';

  @override
  String get pickAPlacement => 'Pick a placement';

  @override
  String get pickALocation => 'Velg lokasjon';

  @override
  String get selectHere => 'Velg her';

  @override
  String get switchToOSM => 'Bytt til OSM';

  @override
  String get switchToTopo => 'Bytt til Topo';

  @override
  String get layers => 'Bytt kartlag';

  @override
  String get zoomIn => 'Zoom inn';

  @override
  String get zoomOut => 'Zoom ut';

  @override
  String get locateMe => 'Vis min posisjon';

  @override
  String get recenter => 'Sentrer kartet';

  @override
  String get mapSettingsSectionTitle => 'Kart';

  @override
  String get mapSettingsSectionDescription =>
      'Velg hvordan kart oppfører seg i appen.';

  @override
  String get showMapZoomControls => 'Vis zoom-knapper';

  @override
  String get showMapZoomControlsDescription =>
      'Vis zoom inn/ut-knapper på kart. Av som standard på berøringsenheter, der knipebevegelse også fungerer.';

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
  String get couldNotOpenLink => 'Kunne ikke åpne lenken.';

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
  String get endTime => 'Sluttid';

  @override
  String get timeLabel => 'Tidsrom';

  @override
  String get durationLabel => 'Varighet';

  @override
  String get phaseBreakdown => 'Faseinndeling';

  @override
  String get roundTable => 'Rundetabell';

  @override
  String get stationDuration => 'Tid per post';

  @override
  String get exerciseCount => 'Antall øvelser';

  @override
  String get teamCount => 'Antall lag';

  @override
  String get stationCount => 'Antall poster';

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
  String get elapsedLabel => 'Til nå';

  @override
  String get totalLabel => 'Totalt';

  @override
  String roundOfTotal(int current, int total) {
    return '$current av $total';
  }

  @override
  String hoursMinutesShort(int hours, int minutes) {
    return '$hours t $minutes min';
  }

  @override
  String get statusUntilStart => 'Til start';

  @override
  String get statusMinutesRemainingOf => 'min igjen av';

  @override
  String statusRoundOfTotal(int current, int total) {
    return 'Runde $current av $total';
  }

  @override
  String get statusNow => 'Nå';

  @override
  String get statusNextPhase => 'Neste fase';

  @override
  String get statusNextRound => 'Neste runde';

  @override
  String get statusNotActiveNow => 'Ikke aktiv nå';

  @override
  String get statusFinishValue => 'Ferdig';

  @override
  String statusPreStartSubline(String startTime, int rounds) {
    String _temp0 = intl.Intl.pluralLogic(
      rounds,
      locale: localeName,
      other: '$rounds runder',
      one: '1 runde',
    );
    return 'starter $startTime · $_temp0';
  }

  @override
  String statusPreStartSublineMarker(String activeFrom, String postBadge) {
    return 'aktiv fra $activeFrom · på $postBadge';
  }

  @override
  String get clockLabel => 'Tid nå';

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
  String get libraryFromFileSubtitle =>
      'Importer en .drill-fil eller en pakket .zip med flere planer';

  @override
  String get libraryEmptyMyPlans =>
      'Du har ingen lagrede planer. Bla i «På nett» eller «Ny fra fil» for å komme i gang.';

  @override
  String get libraryFromFilePickAction => 'Velg fil';

  @override
  String get libraryFromFileHint =>
      'Velg en .drill-fil eller en eksportert .zip med flere planer';

  @override
  String get libraryExportAll => 'Last ned alle planer';

  @override
  String importBundleSuccess(int count) {
    return 'Importerte $count planer';
  }

  @override
  String importBundlePartial(int imported, int skipped) {
    return 'Importerte $imported planer, $skipped hoppet over';
  }

  @override
  String importBundleMoreSkipped(int count) {
    return '+$count flere';
  }

  @override
  String get importBundleEmpty => 'Fant ingen planer i fila';

  @override
  String get importGuideHint =>
      'Du har nettopp lastet ned en .zip med alle planene dine fra den gamle appen. Velg den fila under for å importere dem hit — ingen blir aktivert automatisk, og planen du bruker nå berøres ikke.';

  @override
  String get planStatusLocal => 'Lokal';

  @override
  String get planStatusLocalTooltip =>
      'Denne planen ligger bare på enheten din';

  @override
  String get planStatusOnlineTooltip =>
      'Denne planen er koblet til nett-biblioteket';

  @override
  String get planStatusUnpublished => 'Upublisert';

  @override
  String get planStatusUnpublishedTooltip =>
      'Trykk for å publisere endringene dine til katalogen';

  @override
  String get addExercisesMyPlansSubtitle => 'Velg en plan å hente øvelser fra';

  @override
  String get addExercisesOnlineSubtitle =>
      'Hent øvelser fra en plan i nett-biblioteket';

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
  String catalogExerciseCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count øvelser',
      one: '1 øvelse',
    );
    return '$_temp0';
  }

  @override
  String get libraryActive => 'Aktiv';

  @override
  String get libraryInstalled => 'I mine planer';

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
  String get addExercisesTitle => 'Legg til øvelser';

  @override
  String get addAction => 'LEGG TIL';

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
  String get downloadAction => 'LAST NED';

  @override
  String get libraryDownloadAction => 'Last ned…';

  @override
  String get libraryDownloadAll => 'Last ned alle';

  @override
  String get libraryDownloadPlan => 'Last ned plan';

  @override
  String get downloadTitle => 'Last ned';

  @override
  String get selectExercisesAction => 'VELG...';

  @override
  String get selectExercisesDisabledTooltip =>
      'Ingen øvelser å velge blant enda';

  @override
  String get selectPlansDisabledTooltip => 'Ingen planer å velge blant enda';

  @override
  String get selectAll => 'VELG ALLE';

  @override
  String get selectNone => 'VELG INGEN';

  @override
  String get exportAllExercisesHint =>
      'Alle øvelser inkluderes. Trykk «VELG...» for å plukke selv.';

  @override
  String get exportAllPlansHint =>
      'Alle planer inkluderes. Trykk «VELG...» for å plukke selv.';

  @override
  String selectedOfTotal(int selected, int total) {
    return '$selected av $total valgt';
  }

  @override
  String get publishActivePlan => 'Publiser';

  @override
  String get publishAsActivePlan => 'Publiser som...';

  @override
  String get defaultPlanName => 'Ny plan';

  @override
  String get cannotDeleteLastPlan =>
      'Kan ikke slette eneste plan. Endre navn eller legg til en ny først.';

  @override
  String get cannotDeleteActivePlan =>
      'Åpne en annen plan først, og slett så denne.';

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
      'Dine lokale endringer skiller seg fra katalogen.';

  @override
  String get catalogConflictBodyLocalOnly =>
      'Planen i katalogen er uendret. Du har lokale endringer.';

  @override
  String get catalogConflictCancel => 'Avbryt';

  @override
  String get catalogConflictOverwrite => 'Forkast mine';

  @override
  String get catalogConflictPublish => 'Publiser';

  @override
  String get catalogConflictFork => 'Lag kopi';

  @override
  String get catalogConflictVersionLocalLabel => 'Lokal';

  @override
  String get catalogConflictVersionCatalogLabel => 'Katalog';

  @override
  String get catalogConflictVersionUnknown => 'Ingen';

  @override
  String catalogRefreshUpToDate(String name) {
    return '$name er allerede oppdatert';
  }

  @override
  String catalogRefreshUpdated(String name) {
    return 'Oppdaterte $name fra katalogen';
  }

  @override
  String catalogRefreshReverted(String name) {
    return 'Forkastet lokale endringer i $name';
  }

  @override
  String get catalogRefreshCancelled => 'Katalogoppdatering avbrutt';

  @override
  String get catalogRefreshForked => 'Lagret en lokal kopi';

  @override
  String get catalogRefreshPublished => 'Publiserte endringene dine';

  @override
  String catalogRefreshRemoved(String name) {
    return '$name finnes ikke lenger i katalogen';
  }

  @override
  String get catalogDiffAdded => 'Lagt til';

  @override
  String get catalogDiffRemoved => 'Fjernet';

  @override
  String get catalogDiffModified => 'Endret';

  @override
  String get catalogDiffShowDeletions => 'Vis slettinger';

  @override
  String catalogDiffReorderedFromTo(String from, String to) {
    return 'Flyttet $from → $to';
  }

  @override
  String catalogDiffFieldChanged(String field, String from, String to) {
    return '$field endret: $from → $to';
  }

  @override
  String catalogDiffFieldChangedGeneric(String field) {
    return '$field endret';
  }

  @override
  String get catalogDiffLocal => 'Din versjon';

  @override
  String get catalogDiffRemote => 'Katalogversjon';

  @override
  String get catalogDiffPlan => 'Plan';

  @override
  String get catalogDiffName => 'Plannavn';

  @override
  String get catalogDiffDescription => 'Beskrivelse';

  @override
  String get catalogDiffTags => 'Etiketter';

  @override
  String get catalogDiffExercises => 'Øvelser';

  @override
  String get catalogDiffTeams => 'Lag';

  @override
  String get catalogDiffSessions => 'Økter';

  @override
  String get catalogDiffFieldName => 'Navn';

  @override
  String get catalogDiffFieldEndTime => 'Sluttid';

  @override
  String get catalogDiffFieldStartedAt => 'Startet';

  @override
  String get catalogDiffFieldEndedAt => 'Avsluttet';

  @override
  String get catalogDiffFieldProps => 'Rekvisitter';

  @override
  String get catalogDiffFieldOther => 'Andre endringer';

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
  String get rotationShareLegendPhases => 'øve | eval | rull / retur';

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
  String roleplay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Markører',
      one: 'Markør',
      zero: 'Markør',
    );
    return '$_temp0';
  }

  @override
  String get rolePlaysTab => 'Markører';

  @override
  String get scriptSegment => 'Spill';

  @override
  String get playSection => 'Spill';

  @override
  String get roleSection => 'Markørordre';

  @override
  String get rolePlayScreenTitle => 'Markørordre';

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
  String castedAs(String names) {
    return 'Markør for: $names';
  }

  @override
  String alreadyCastAs(String name) {
    return 'Allerede markør for $name';
  }

  @override
  String roleSubtitleStation(String name) {
    return 'Post: $name';
  }

  @override
  String roleSubtitleExercise(String name) {
    return 'Øvelse: $name';
  }

  @override
  String get emptyRosterTitle => 'Ingen i staben ennå';

  @override
  String get emptyRosterBody =>
      'Legg til øvelsesledere, veiledere og markører her.';

  @override
  String get noActivePlanHint =>
      'Ingen aktiv øvelsesplan. Velg eller opprett en i Øvelser-fanen.';

  @override
  String get noRoleDescription => 'Ingen signalement';

  @override
  String get noBackground => 'Ingen bakgrunn';

  @override
  String get noBehavior => 'Ingen oppførsel';

  @override
  String get noStationAssigned => 'Ingen post';

  @override
  String get pleaseSelectStation => 'Velg en post';

  @override
  String get emptyRolesTitle => 'Ingen spill ennå';

  @override
  String get emptyRolesBody =>
      'Spill beskriver det markørene skal gjøre på posten. Opprett en øvelse først, og legg deretter til spillene den trenger.';

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
  String confirmDeleteActor(String name) {
    return 'Dette sletter $name fra markørlisten. Fortsette?';
  }

  @override
  String get deleteRolePlay => 'Slett spill';

  @override
  String confirmDeleteRolePlay(String name) {
    return 'Vil du slette spillet «$name»?';
  }

  @override
  String confirmDeleteRolePlayWithActor(String name, String actor) {
    return 'Vil du slette spillet «$name»? Markøren $actor frigjøres fra spillet, men beholdes i markørlista.';
  }

  @override
  String get addRolePlay => 'Legg til markørordre';

  @override
  String get newRolePlayTitle => 'Nytt spill';

  @override
  String get editRolePlayTitle => 'Endre spill';

  @override
  String get roleplaySectionRole => 'Rolle';

  @override
  String get stationRolesSection => 'Markører';

  @override
  String get noRolesAtThisStation => 'Ingen markører på denne posten';

  @override
  String get roleDescription => 'Signalement';

  @override
  String get roleBackground => 'Bakgrunn';

  @override
  String get roleBehavior => 'Oppførsel';

  @override
  String get roleProps => 'Rekvisitter';

  @override
  String castedByLine(String name) {
    return 'Spilles av $name';
  }

  @override
  String get noCastLine => 'Ingen markør';

  @override
  String get briefScreenTitle => 'Brief';

  @override
  String get briefAudienceParticipant => 'Deltaker';

  @override
  String get briefAudienceInstructor => 'Veileder';

  @override
  String get briefAudienceDirector => 'Øvelsesleder';

  @override
  String get briefAudienceLabel => 'Målgruppe';

  @override
  String get briefPrint => 'Skriv ut';

  @override
  String get briefSearch => 'Søk i brief';

  @override
  String get briefSearchHint => 'Søk';

  @override
  String get briefSearchNoMatches => 'Ingen treff';

  @override
  String briefRenderError(String error) {
    return 'Kunne ikke lage brief: $error';
  }

  @override
  String get briefTemplateMissing =>
      'Brief-malen kunne ikke lastes. Start appen på nytt og prøv igjen.';

  @override
  String get briefMissingPlan => 'Ingen aktiv plan';

  @override
  String get briefMissingExercise => 'Øvelse ikke funnet';

  @override
  String get briefToc => 'Innhold';

  @override
  String get briefAction => 'Åpne brief';

  @override
  String get briefClose => 'Lukk';

  @override
  String get masterPaneToggle => 'Vis/skjul liste';

  @override
  String get briefDragHandle => 'Dra for å lukke';

  @override
  String get briefPerStation => 'pr oppdrag';

  @override
  String get briefRingRoute => 'Ringløype';

  @override
  String get briefCodeCopied => 'Kopiert';

  @override
  String get briefCodeCopyTooltip => 'Kopier';

  @override
  String briefSearchMatchCount(int current, int total) {
    return '$current av $total';
  }

  @override
  String get briefSearchNextMatch => 'Neste treff';

  @override
  String get briefSearchPreviousMatch => 'Forrige treff';

  @override
  String get briefStationNoPosition => 'ingen posisjon';

  @override
  String briefUnknownVariable(String name) {
    return '‹mangler variabel: $name›';
  }

  @override
  String briefUnknownReference(String name) {
    return '‹mangler referanse: $name›';
  }

  @override
  String get briefCopyMarkdown => 'Kopier som markdown';

  @override
  String get briefMarkdownCopied => 'Brief kopiert som markdown';

  @override
  String get briefOpenToc => 'Innhold';

  @override
  String get moreActions => 'Flere handlinger';

  @override
  String get drillPlayerClose => 'Lukk';

  @override
  String get drillPlayerStartingIn => 'Starter om';

  @override
  String drillPlayerRoundOf(int current, int total) {
    return 'Runde $current / $total';
  }

  @override
  String drillPlayerStartingInWithCountdown(String time) {
    return 'Starter om $time';
  }

  @override
  String get detailEmptyExercise => 'Velg en øvelse';

  @override
  String get detailEmptyStation => 'Velg en post for å se detaljer';

  @override
  String get detailEmptyRolePlay => 'Velg en markør';

  @override
  String get detailGoneRolePlay =>
      'Denne markøren er ikke tilgjengelig lenger. Den kan ha blitt slettet.';

  @override
  String get detailGoneExercise =>
      'Denne øvelsen er ikke tilgjengelig lenger. Den kan ha blitt slettet.';

  @override
  String get detailGoneStation =>
      'Denne posten er ikke tilgjengelig lenger. Posten, eller øvelsen den hører til, kan ha blitt slettet.';

  @override
  String get appUserRoleActor => 'Markør';

  @override
  String get appUserRoleSectionTitle => 'Min rolle';

  @override
  String get newRole => 'Ny rolle';

  @override
  String get newPlay => 'Nytt spill';

  @override
  String get pickExerciseForRole => 'Velg øvelse';

  @override
  String get detailEmptyTeam => 'Velg et lag';

  @override
  String get rosterTab => 'Stab';

  @override
  String get detailEmptyRoster => 'Velg et medlem for å se detaljer';

  @override
  String get editPlan => 'Endre plan';

  @override
  String get planSectionPlan => 'Plan';

  @override
  String get planName => 'Plannavn';

  @override
  String get planDescription => 'Beskrivelse';

  @override
  String get planDescriptionHint =>
      'Kort beskrivelse som vises under plannavnet i briefen';

  @override
  String get planEditorTagsLabel => 'Etiketter';

  @override
  String get planEditorTagsHint => 'Legg til en etikett';

  @override
  String get planEditorTagRemoveTooltip => 'Fjern etikett';

  @override
  String get planEditorTagTooLong => 'Etiketten er for lang (maks 40 tegn)';

  @override
  String get briefSectionPlanIntro => 'Generelt om spill og øvingsledelse';

  @override
  String get briefSectionPlanComms => 'Talegrupper';

  @override
  String get briefSectionPlanBeforeRound => 'Før hver post';

  @override
  String get briefSectionExerciseMethod => 'Metode';

  @override
  String get briefSectionExerciseLearningGoals => 'Læringsmål';

  @override
  String get briefSectionExerciseTrainingFocus => 'Øvingsmomenter';

  @override
  String get briefSectionExerciseOrderFormat => 'Ordreformat';

  @override
  String get briefSectionExerciseExecutionTips => 'Tips til gjennomføring';

  @override
  String get briefSectionExerciseComms => 'Samband';

  @override
  String get briefSectionStationEquipment => 'Utstyrsbehov';

  @override
  String get briefSectionStationSituation => 'Situasjon';

  @override
  String get briefSectionStationMission => 'Oppdrag';

  @override
  String get briefSectionStationLogistics => 'Administrasjon og forsyninger';

  @override
  String get briefSectionStationCriticalQuestions => 'Kritiske spørsmål';

  @override
  String get briefSectionStationLeaderAnswers => 'Forslag til svar';

  @override
  String get briefSectionStationDirectorNotes => 'Notater';

  @override
  String get stationNumberFormatLabel => 'Postnummerering';

  @override
  String get stationNumberFormatDotted => '1.1, 1.2';

  @override
  String get stationNumberFormatAlpha => '1a, 1b';

  @override
  String get planLanguageLabel => 'Språk';

  @override
  String get planLanguageChooseHint => 'Velg';

  @override
  String get pleaseSelectALanguage => 'Velg et språk';

  @override
  String get formSectionAddAction => 'Legg til seksjon';

  @override
  String get formSectionRemoveAction => 'Fjern seksjon';

  @override
  String get formSectionSwitcherTooltip => 'Bytt seksjon';

  @override
  String get formSectionPrevious => 'Forrige seksjon';

  @override
  String get formSectionNext => 'Neste seksjon';

  @override
  String get formSectionPreviewAction => 'Forhåndsvis';

  @override
  String get formSectionEditAction => 'Rediger';

  @override
  String get formDoneAction => 'FERDIG';

  @override
  String get rollupShowAction => 'Vis detaljer';

  @override
  String get rollupHideAction => 'Skjul detaljer';

  @override
  String get rollupEmptyPreview => 'Ingenting å forhåndsvise ennå';

  @override
  String get exerciseDescriptionCardTitle => 'Øvingsbeskrivelse';

  @override
  String get postDescriptionCardTitle => 'Postbeskrivelse';

  @override
  String get directorOnlyBadge => 'Kun øvelsesleder';

  @override
  String get tapSectionToEditHint => 'Trykk en seksjon for å redigere';

  @override
  String get descriptionAddAction => 'Legg til beskrivelse';

  @override
  String descriptionMissingSections(String sections) {
    return 'Mangler: $sections';
  }

  @override
  String get descriptionMissingSectionsAction => 'Legg til';

  @override
  String get exerciseDescriptionEmptyTitle => 'Ingen øvingsbeskrivelse ennå';

  @override
  String get exerciseDescriptionEmptyBody =>
      'Beskriv metode, ordreformat, samband og læringsmål, slik at instruktører og lagledere vet hva øvelsen skal trene.';

  @override
  String get stationDescriptionEmptyTitle => 'Ingen postbeskrivelse ennå';

  @override
  String get stationDescriptionEmptyBody =>
      'Beskriv situasjon, oppdrag, logistikk og utstyr på posten, slik at markører og instruktører kan forberede seg før øvelsen starter.';

  @override
  String get rolePlayDescriptionEmptyTitle => 'Ingen markørordre ennå';

  @override
  String get rolePlayDescriptionEmptyBody =>
      'Beskriv rollen — signalement, bakgrunn, oppførsel og rekvisitter — slik at markøren vet hvem som skal spilles, og hvordan.';

  @override
  String get stationTimingCardTitle => 'Tidsplan';

  @override
  String get roleActiveScheduleCardTitle => 'Når aktiv';

  @override
  String get tokenMenuEmpty => 'Ingen treff';

  @override
  String get tokenDescPlanName =>
      'Navnet på planen, slik det står i planlista og i tittelen på briefen.';

  @override
  String get tokenDescPlanDescription =>
      'Planens egen beskrivelse, fra planredigeringen.';

  @override
  String get tokenDescPlanExerciseCount => 'Hvor mange øvelser planen har.';

  @override
  String get tokenDescPlanTeamCount => 'Hvor mange lag planen har.';

  @override
  String get tokenDescPlanStationCount =>
      'Hvor mange poster planen har i alt, på tvers av alle øvelsene.';

  @override
  String get tokenDescExerciseName =>
      'Navnet på øvelsen. Nummeret foran settes av appen.';

  @override
  String get tokenDescExerciseNumberOfTeams =>
      'Hvor mange lag som rullerer gjennom øvelsen.';

  @override
  String get tokenDescExerciseNumberOfRounds =>
      'Hvor mange runder rulleringen går.';

  @override
  String get tokenDescExerciseStartTime =>
      'Klokkeslettet den første runden starter.';

  @override
  String get tokenDescExerciseEndTime =>
      'Klokkeslettet siste runde slutter. Beregnet ut fra starttid og de tre faselengdene.';

  @override
  String get tokenDescExerciseTimeLabel => 'Start og slutt som ett uttrykk.';

  @override
  String get tokenDescExerciseDurationLabel =>
      'Total varighet, med rundelengden i parentes.';

  @override
  String get tokenDescExerciseExecutionTime =>
      'Minutter et lag øver på en post, per runde.';

  @override
  String get tokenDescExerciseEvaluationTime =>
      'Minutter satt av til evaluering, per runde.';

  @override
  String get tokenDescExerciseRotationTime =>
      'Minutter satt av til å rullere til neste post.';

  @override
  String get tokenDescExercisePhaseBreakdown =>
      'De tre faselengdene i minutter, skilt med loddrette streker.';

  @override
  String get tokenDescExerciseRoundTable =>
      'Hele rulleringen som tabell: én rad per runde, med klokkeslett for hver fase. Bygges når briefen genereres.';

  @override
  String get tokenDescStationName =>
      'Navnet på posten. Koden foran settes av appen.';

  @override
  String get tokenDescStationCode =>
      'Postens kode, beregnet ut fra hvor den ligger i øvelsen.';

  @override
  String get tokenDescStationPosition =>
      'Postens egen posisjon, som en koordinat leseren kan trykke på. Tom til posten er plassert i kartet.';

  @override
  String get tokenDescStationVariantSuffix =>
      'Bokstaven som skiller to poster som deler nummer.';

  @override
  String get tokenDescStationDuration =>
      'Hvor lang tid et lag får på posten, med faseinndelingen.';

  @override
  String get tokenDescRoleplayName => 'Navnet på rollen.';

  @override
  String get tokenDescRoleplayAge => 'Alderen på rollen.';

  @override
  String get tokenDescRoleplayDescription =>
      'Den korte beskrivelsen av rollen.';

  @override
  String get tokenDescRoleplayPosition =>
      'Hvor rollen står, som en koordinat leseren kan trykke på.';

  @override
  String get exerciseGroupsSection => 'Parallellgrupper';

  @override
  String get exerciseGroupsEmpty =>
      'Ingen grupper ennå. Hver gruppe er én runde: postene som går samtidig, og hvilke lag som går hvor.';

  @override
  String get exerciseGroupAdd => 'Ny parallellgruppe';

  @override
  String get exerciseGroupAddStation => 'Legg til post';

  @override
  String get exerciseGroupAddTeam => 'Legg til lag';

  @override
  String get exerciseGroupRemove => 'Fjern gruppe';

  @override
  String get exerciseGroupRemoveMessage =>
      'Postene i denne runden og lagfordelingen blir fjernet.';

  @override
  String exerciseGroupTeamCollision(String team) {
    return '$team står på to poster samtidig. Disse postene går på samme tid.';
  }

  @override
  String exerciseGroupTeamsUnplaced(String teams) {
    return '$teams har ingen post i denne runden.';
  }

  @override
  String get exerciseGroupNoStations => 'Ingen poster i denne gruppa ennå.';

  @override
  String get stationNotUsedInExercise =>
      'Ikke i bruk i denne øvelsen. Ingen runde har lag på denne posten.';

  @override
  String get stationNotUsedBadge => 'Ikke i bruk';

  @override
  String get exerciseMode => 'Gjennomføring';

  @override
  String get exerciseModeRing => 'Ring';

  @override
  String get exerciseModeTogether => 'Samlet';

  @override
  String get exerciseModeSplit => 'Delt';

  @override
  String get exerciseModeRingDescription =>
      'Ett lag per post. Lagene rullerer, og appen regner ut hvem som er hvor.';

  @override
  String get exerciseModeTogetherDescription =>
      'Én post, alle lag. Alle arbeider på samme post og rykker videre sammen.';

  @override
  String get exerciseModeSplitDescription =>
      'Alt mellom. Du grupperer postene som går samtidig og sier hvilke lag som går hvor.';

  @override
  String get exerciseModePickerTitle => 'Hvordan gjennomføres den?';

  @override
  String get exerciseModeRoundsDerived => '= antall poster';

  @override
  String get exerciseModeSwitchTitle => 'Endre gjennomføring?';

  @override
  String get exerciseModeSwitchDiscardsGroups =>
      'Parallellgruppene og lagfordelingen blir fjernet. Appen fordeler lagene selv i denne modusen, så det er ingen plass til lag du har satt inn manuelt.';

  @override
  String get stationExecutionTimeInherits =>
      'Arver fra øvelsen. Overstyr for denne posten.';

  @override
  String stationExecutionTimeOverridden(int minutes) {
    return 'Runden med denne posten blir $minutes min.';
  }

  @override
  String get tokenBrowserTitle => 'Sett inn token';

  @override
  String get tokenBrowserBrowseAll => 'Vis alle …';

  @override
  String get tokenBrowserSearchHint => 'Søk i navn og beskrivelser';

  @override
  String get tokenBrowserExample => 'EKSEMPEL';

  @override
  String get tokenBrowserFilterAll => 'Alle';

  @override
  String get tokenBrowserCategoryLocation => 'Sted';

  @override
  String get tokenBrowserCategoryPerson => 'Person';

  @override
  String get tokenBrowserCategoryVariable => 'Variabel';

  @override
  String get tokenBrowserNoVariables =>
      'Ingen variabler er deklarert i denne planen. Deklarer en i variabelseksjonen i planen.';

  @override
  String get tokenBrowserNoLocations => 'Denne posten har ingen steder ennå.';

  @override
  String get tokenBrowserNoPersons => 'Denne posten har ingen personer ennå.';

  @override
  String get tokenBrowserVariableDescription =>
      'Deklarert på planen; øvelser og poster kan overstyre verdien.';

  @override
  String get tokenBrowserLocationDescription =>
      'Navn og posisjon. Legg til .place, .label eller .position for én del alene.';

  @override
  String get tokenBrowserPersonDescription =>
      'Navn og alder. Legg til .age, .description eller .loc.* for én del alene.';

  @override
  String get tokenMenuPlanFieldHint => 'planfelt';

  @override
  String tokenMenuCreateVariable(String name) {
    return 'Opprett variabel «$name»';
  }

  @override
  String tokenMenuCreateLocation(String label) {
    return 'Opprett lokasjon «$label»';
  }

  @override
  String tokenMenuCreatePerson(String label) {
    return 'Opprett person «$label»';
  }

  @override
  String get variablesSectionTitle => 'Variabler';

  @override
  String get variablesSectionPublishNote =>
      'Publiseres med planen. Ikke legg inn reelle persondata.';

  @override
  String get variablesSectionAddAction => 'Ny variabel';

  @override
  String get variablesSectionSearchHint => 'Søk i variabler';

  @override
  String get variablesSectionNameLabel => 'Navn';

  @override
  String get variablesSectionValueLabel => 'Verdi';

  @override
  String get variablesSectionHintLabel => 'Hint (valgfritt)';

  @override
  String get variablesSectionRenameAction => 'Gi nytt navn';

  @override
  String get variablesSectionDeleteAction => 'Slett';

  @override
  String get variablesSectionCustomizeAction => 'Tilpass';

  @override
  String get variablesSectionNoValuePlaceholder => 'Ingen verdi';

  @override
  String get variablesSectionInvalidSlugError =>
      'Må starte med en liten bokstav og bare inneholde små bokstaver, tall og understrek';

  @override
  String get variablesSectionDuplicateNameError =>
      'Dette navnet er allerede i bruk';

  @override
  String get variablesSectionOverrideFieldLabel => 'Variabeloverstyring';

  @override
  String variablesSectionRenameConfirmMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Dette oppdaterer $count referanser i planen.',
      one: 'Dette oppdaterer 1 referanse i planen.',
      zero: 'Brukes ikke ennå.',
    );
    return '$_temp0';
  }

  @override
  String get variablesSectionDeleteBlockedTitle =>
      'Kan ikke slette denne variabelen';

  @override
  String variablesSectionDeleteBlockedMessage(String name) {
    return '«$name» brukes fortsatt her:';
  }

  @override
  String get variableOverridesSectionLocalValueLabel => 'Lokal verdi';

  @override
  String get variableOverridesSectionEmptyState =>
      'Ingen variabler i planen ennå';

  @override
  String get variableOverridesSectionResetAction => 'Tilbakestill';

  @override
  String get variableTypeLabelString => 'Tekst';

  @override
  String get variableTypeLabelNumber => 'Tall';

  @override
  String get variableTypeLabelTime => 'Tid';

  @override
  String get variableTypeLabelDate => 'Dato';

  @override
  String get variableTypeLabelDuration => 'Varighet';

  @override
  String get variableTypeLabelLocation => 'Lokasjon';

  @override
  String get variableValueInvalidNumber => 'Oppgi et tall';

  @override
  String get variableValueInvalidTime => 'Oppgi et klokkeslett som TT:MM';

  @override
  String get variableValueInvalidDate => 'Oppgi en dato som ÅÅÅÅ-MM-DD';

  @override
  String get variableValueInvalidDuration =>
      'Oppgi antall minutter som et heltall';

  @override
  String get variableValueInvalidCoordinate =>
      'Oppgi et koordinat som lat,lng eller UTM';

  @override
  String variableSaveBlockedInvalidValue(String names) {
    return 'Kan ikke lagre: ugyldig verdi for $names';
  }

  @override
  String get variableDurationHourUnit => 't';

  @override
  String get variableLocationCoordinateLabel => 'Koordinat';

  @override
  String get variableLocationCoordinateHint =>
      'Skriv eller lim inn lat,lng eller UTM';

  @override
  String get locationKindLkpLabel => 'Sist kjent posisjon (LKP)';

  @override
  String get locationKindLkpDescription =>
      'Siste bekreftede posisjon til den savnede.';

  @override
  String get locationKindIppLabel => 'Initielt planleggingspunkt (IPP)';

  @override
  String get locationKindIppDescription =>
      'Utgangspunktet søkesektorer måles fra.';

  @override
  String get locationKindPpLabel => 'Planleggingspunkt (PP)';

  @override
  String get locationKindPpDescription =>
      'Et planleggingspunkt brukt til å strukturere søksområdet.';

  @override
  String get locationKindRendezvousLabel => 'Oppmøtested';

  @override
  String get locationKindRendezvousDescription =>
      'Hvor mannskaper møtes før utrykning.';

  @override
  String get locationKindCommandPostLabel => 'Kommandoplass';

  @override
  String get locationKindCommandPostDescription => 'Hvor øvelsen ledes fra.';

  @override
  String get locationKindHomeLabel => 'Bosted';

  @override
  String get locationKindHomeDescription => 'Personens bosted.';

  @override
  String get locationKindTrackFoundLabel => 'Funn av spor';

  @override
  String get locationKindTrackFoundDescription =>
      'Et sted hvor det ble funnet spor.';

  @override
  String get locationKindDogInterestLabel => 'Interesse av hund';

  @override
  String get locationKindDogInterestDescription =>
      'Et sted hvor en søkshund viste interesse.';

  @override
  String get locationKindObstacleLabel => 'Hindring';

  @override
  String get locationKindObstacleDescription =>
      'En hindring som påvirker søket.';

  @override
  String get locationKindNotSearchableLabel => 'Ikke søkbart';

  @override
  String get locationKindNotSearchableDescription =>
      'Et område som ikke kunne søkes.';

  @override
  String get locationKindPhoneTraceLabel => 'Mobilspor';

  @override
  String get locationKindPhoneTraceDescription =>
      'En posisjon avledet fra mobilsporing.';

  @override
  String get locationKindObservationLabel => 'Observasjon';

  @override
  String get locationKindObservationDescription => 'En rapportert observasjon.';

  @override
  String get locationKindVantagePointLabel => 'Utkikkspunkt';

  @override
  String get locationKindVantagePointDescription =>
      'Et punkt med god utsikt over søksområdet.';

  @override
  String get locationKindContainmentPostLabel => 'Sperrepost';

  @override
  String get locationKindContainmentPostDescription =>
      'En post brukt for å avgrense søksområdet.';

  @override
  String get locationKindPersonFoundLabel => 'Funn av person';

  @override
  String get locationKindPersonFoundDescription =>
      'Hvor den savnede ble funnet.';

  @override
  String get locationKindOtherLabel => 'Annet';

  @override
  String get locationKindOtherDescription => 'Enhver annen type lokasjon.';

  @override
  String get locationsSectionTitle => 'Lokasjoner';

  @override
  String get locationsSectionAddAction => 'Ny lokasjon';

  @override
  String get locationsSectionEditAction => 'Rediger';

  @override
  String locationsSectionDeleteConfirmMessage(String name) {
    return 'Slette «$name»?';
  }

  @override
  String get locationsSectionLabelLabel => 'Navn';

  @override
  String get locationsSectionKindLabel => 'Type';

  @override
  String get locationsSectionPlaceLabel => 'Sted';

  @override
  String get locationsSectionPlaceSearchHint => 'Søk etter sted';

  @override
  String get locationsSectionPlaceNoResults => 'Fant ingen treff';

  @override
  String get locationsSectionNoteLabel => 'Notat';

  @override
  String locationsSectionShowAllKinds(int count) {
    return 'Vis alle $count kategorier';
  }

  @override
  String get locationsSectionShowFewerKinds => 'Vis mindre';

  @override
  String get locationsSectionSearchHint => 'Søk i lokasjoner';

  @override
  String get locationsSectionSortByKind => 'Kategori';

  @override
  String get locationsSectionSortByLabel => 'Navn';

  @override
  String get personsSectionTitle => 'Personer';

  @override
  String get personsSectionAddAction => 'Ny person';

  @override
  String personsSectionEnactedByAction(String name) {
    return 'Spilles av $name';
  }

  @override
  String get personsSectionAddMarkerAction => 'Legg til spill';

  @override
  String get personsSectionEditAction => 'Rediger';

  @override
  String personsSectionDeleteConfirmMessage(String name) {
    return 'Slette «$name»?';
  }

  @override
  String get personsSectionLocationLabel => 'Lokasjon';

  @override
  String get personsSectionLocationNone => 'Ingen lokasjon';

  @override
  String get personsSectionNotesLabel => 'Notater';

  @override
  String get personsSectionSearchHint => 'Søk i personer';

  @override
  String get personsSectionSortByName => 'Navn';

  @override
  String get personsSectionSortByAge => 'Alder';

  @override
  String get roleGender => 'Kjønn';

  @override
  String get rolePlayPersonLabel => 'Person';

  @override
  String get rolePlayPostRequiredHint => 'Velg post for å fortsette';

  @override
  String get rolePlaySelectPersonPrompt => 'Velg eller opprett person';

  @override
  String get pleaseSelectPerson => 'Velg en person';

  @override
  String get rolePlayBrokenReferencePrefix => 'Brutt referanse i';

  @override
  String get rolePlayPostEditAction => 'Endre';

  @override
  String get rolePlayIdentitySectionLabel => 'Identitet';

  @override
  String get rolePlayIdentityCustomizeAction => 'Tilpass';

  @override
  String get rolePlayIdentityResetAction => 'Tilbakestill';

  @override
  String rolePlayCustomizedFrom(String name) {
    return 'Tilpasset fra $name';
  }

  @override
  String rolePlayAgeYears(int age) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: '$age år',
      one: '1 år',
    );
    return '$_temp0';
  }

  @override
  String get rolePlayPositionOwnLabel => 'Egen posisjon';

  @override
  String get genderWomanLabel => 'Kvinne';

  @override
  String get genderManLabel => 'Mann';

  @override
  String get genderOtherLabel => 'Annet';

  @override
  String planSaveBlockedUndeclaredVariable(String sections) {
    return 'Kan ikke lagre: $sections inneholder en ukjent variabel';
  }

  @override
  String saveBlockedUnresolvedReference(String sections, String references) {
    return 'Kan ikke lagre: $sections refererer til en ukjent lokasjon eller person: $references';
  }

  @override
  String stationReferenceGuardTitle(String name) {
    return 'Kan ikke slette «$name»';
  }

  @override
  String get stationReferenceGuardMessage => 'Fremdeles referert fra:';

  @override
  String stationReferenceUsageInField(String field) {
    return 'I $field';
  }

  @override
  String stationReferenceUsageInRoleplayField(String roleplay, String field) {
    return 'I ${roleplay}s $field';
  }

  @override
  String stationReferenceUsageIsPersonHome(String person) {
    return 'Er ${person}s lokasjon';
  }

  @override
  String stationReferenceUsagePortrayedBy(String roleplay) {
    return 'Spilles av $roleplay';
  }

  @override
  String get exerciseReorderMode => 'Ordne';

  @override
  String get exerciseReorderDone => 'Ferdig';

  @override
  String get exerciseSortByStartTime => 'Sorter etter starttid';

  @override
  String get exerciseSortAlphabetically => 'Sorter alfabetisk';

  @override
  String get exerciseSortBy => 'Rekkefølge';

  @override
  String get exerciseSortByStartTimeShort => 'Starttid';

  @override
  String get exerciseSortAlphabeticallyShort => 'Alfabetisk';

  @override
  String get primerSkip => 'Hopp over';

  @override
  String get primerHeading => 'Lagene roterer';

  @override
  String get primerBody =>
      'Lagene roterer mellom postene på felles klokke. Når runden er over, rykker alle videre samtidig.';

  @override
  String get primerOpenExample => 'Åpne et eksempel';

  @override
  String get primerStartEmpty => 'Start en tom plan';

  @override
  String primerTeamLabel(int n) {
    return 'Lag $n';
  }

  @override
  String get startHereCue => 'Start her';

  @override
  String get migrationBannerHeading =>
      'Web-appen flytter til web.ringdrill.app.';

  @override
  String get migrationBannerBody =>
      'Last ned planene dine her og åpne den nye appen.';

  @override
  String get migrationBannerExport => 'Eksporter alle planene mine';

  @override
  String get migrationBannerOpenNewApp => 'Åpne den nye appen';

  @override
  String get migrationBannerReadMore => 'Les mer';

  @override
  String get legacyBadgeLabel => 'LEGACY';

  @override
  String get legacyBadgeTooltip =>
      'Du bruker den gamle web-appen. Trykk for å flytte til web.ringdrill.app.';

  @override
  String get settingsWebAppSection => 'Web-app';

  @override
  String get installStatusTitle => 'Installert som app';

  @override
  String get installStatusInstalled => 'Installert';

  @override
  String get installStatusBrowser => 'Kjører i nettleser';

  @override
  String get installGuideEntry => 'Slik installerer du lokalt';

  @override
  String get installGuideTitle => 'Installer RingDrill';

  @override
  String get installGuideIntro =>
      'Installer RingDrill som app for fullskjerm, raskere oppstart og mer pålitelige varsler. Velg enheten din under.';

  @override
  String get installGuideAlreadyInstalled =>
      'RingDrill er allerede installert på denne enheten. Åpne den fra hjem-skjermen eller app-listen.';

  @override
  String get installGuideInstallButton => 'Installer nå';

  @override
  String get installGuideAndroidTitle => 'Android (Chrome)';

  @override
  String get installGuideAndroidSteps =>
      '1. Åpne nettlesermenyen (⋮).\n2. Trykk «Installer app» eller «Legg til på startskjerm».\n3. Bekreft for å legge RingDrill til på startskjermen.';

  @override
  String get installGuideIosTitle => 'iPhone og iPad (Safari)';

  @override
  String get installGuideIosSteps =>
      '1. Åpne RingDrill i Safari.\n2. Trykk Del-knappen.\n3. Velg «Legg til på Hjem-skjerm», og trykk «Legg til».';

  @override
  String get installGuideDesktopTitle => 'Datamaskin (Chrome eller Edge)';

  @override
  String get installGuideDesktopSteps =>
      '1. Klikk installer-ikonet i adressefeltet, eller åpne nettlesermenyen.\n2. Velg «Installer RingDrill».\n3. Bekreft for å legge den til som app.';

  @override
  String get installGuideNativeTitle => 'Installer fra App Store';

  @override
  String get installGuidePlayTitle => 'Installer fra Google Play';

  @override
  String get installGuideNativeIntro =>
      'RingDrill-appen gir den beste opplevelsen på enheten din.';

  @override
  String get installGuideAppStoreButton => 'Hent i App Store';

  @override
  String get installGuidePlayStoreButton => 'Hent på Google Play';

  @override
  String get installGuidePwaTitle => 'Installer som web-app';

  @override
  String get migrationSettingsEntry => 'Slik migrerer du til ny web-app';

  @override
  String get migrationExplainerWhyTitle => 'Hvorfor flytter vi?';

  @override
  String get migrationExplainerWhyBody =>
      'Web-appen flyttes til et nytt domene, web.ringdrill.app, for bedre ytelse, stabilitet og enklere oppdateringer. Det nye domenet vil ha sin egen dedikerte app-løsning.';

  @override
  String get migrationExplainerChangesTitle => 'Hva endrer seg for deg?';

  @override
  String get migrationExplainerChangesBody =>
      'Den eksisterende appen på ringdrill.app slutter å motta oppdateringer. Den nye appen installeres fra web.ringdrill.app som en ny PWA, akkurat som du gjorde da du installerte denne.';

  @override
  String get migrationExplainerStepsTitle => 'Slik overfører du planene dine';

  @override
  String get migrationExplainerStep1 =>
      'Trykk «Eksporter alle planene mine» her i appen, eller i varselet øverst.';

  @override
  String get migrationExplainerStep2 =>
      'Åpne web.ringdrill.app og installer den nye appen.';

  @override
  String get migrationExplainerStep3 =>
      'Velg Importer og pek på ZIP-filen du nettopp lastet ned.';

  @override
  String get migrationExplainerStep4 =>
      'Alle planene dine er nå tilgjengelige i den nye appen.';

  @override
  String get migrationExplainerStep5 =>
      'Avinstaller den gamle appen fra hjemskjermen eller nettleseren når du har sjekket at alle planene er på plass i den nye.';

  @override
  String get migrationExplainerDataTitle => 'Hva skjer med dataene mine her?';

  @override
  String get migrationExplainerDataBody =>
      'Planene dine er lagret i nettleseren på ringdrill.app og forsvinner ikke automatisk. Du kan eksportere dem igjen her frem til du sletter nettleserdata for dette domenet. Etter neste oppdatering vil en egen migrasjonside på det nye domenet hjelpe deg med å overføre direkte.';

  @override
  String get developerInfoSectionTitle => 'Utviklerinformasjon';

  @override
  String get buildFlagKindTemporary => 'Midlertidig';

  @override
  String get buildFlagKindPermanent => 'Permanent';

  @override
  String get pickerSelectStationTitle => 'Velg post';

  @override
  String get pickerSelectPersonTitle => 'Velg person';

  @override
  String get pickerSelectRolePlayTitle => 'Velg markør';

  @override
  String get pickerGoToTitle => 'Gå til';

  @override
  String get pickerSearchHint => 'Søk';

  @override
  String get pickerFilterByExerciseTitle => 'Filtrer på øvelse';

  @override
  String get editPlacement => 'Endre plassering';

  @override
  String get newStaff => 'Nytt medlem';

  @override
  String get deleteStaff => 'Slett medlem';

  @override
  String get noStaffInRoster =>
      'Ingen i staben ennå. Trykk + Nytt medlem for å legge til.';

  @override
  String get staffRolesLabel => 'Roller';

  @override
  String get staffPlaysLabel => 'Spiller';

  @override
  String staffPlaysRow(String name, String badge, String window) {
    return '$name på post $badge $window';
  }

  @override
  String get staffRolesRequired => 'Velg minst én rolle';

  @override
  String get staffRoleOther => 'Annet';

  @override
  String get editStaff => 'Rediger medlem';

  @override
  String get planStatusPublishing => 'Publiserer …';

  @override
  String get positionNotSet => 'Ikke satt';

  @override
  String get noPositionTitle => 'Ingen posisjon satt';

  @override
  String get noPositionStationBody =>
      'Posten vises ikke i kartet, og heftet får ingen koordinat.';

  @override
  String get noPositionRolePlayBody =>
      'Markøren følger posten, men posten har ingen posisjon. Sett posisjon på posten, eller gi markøren sin egen.';

  @override
  String get setPosition => 'Sett posisjon';

  @override
  String get setOwnPosition => 'Sett egen posisjon';
}
