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
  String get dismiss => 'Lukk';

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
  String get programTab => 'Øvingsplan';

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
  String get emptyStationsTitle => 'Ingen poster ennå';

  @override
  String get emptyStationsBody =>
      'Poster legges til inne i øvelsene dine. Opprett en øvelse først, så dukker postene opp her.';

  @override
  String get stationName => 'Postnavn';

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
  String get pickALocation => 'Velg plassering';

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
  String get libraryCatalogBadge => 'Fra nett-bibliotek';

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
  String get importBundleEmpty => 'Fant ingen planer i fila';

  @override
  String get importGuideHint =>
      'Velg .zip-fila du lastet ned for å importere planene dine.';

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
  String get downloadAction => 'LAST NED';

  @override
  String get libraryDownloadAction => 'Last ned…';

  @override
  String get libraryDownloadAll => 'Last ned alle';

  @override
  String get libraryDownloadPlan => 'Last ned plan';

  @override
  String get importAction => 'IMPORTER';

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
  String get catalogConflictBodyLocalOnly =>
      'Denne katalogplanen har lokale endringer. Onlineversjonen er uendret. Se gjennom dine lokale endringer før du velger hvordan du vil fortsette.';

  @override
  String get catalogConflictCancel => 'Avbryt';

  @override
  String get catalogConflictOverwrite => 'Forkast lokale endringer';

  @override
  String get catalogConflictPublish => 'Publiser mine endringer';

  @override
  String get catalogConflictFork => 'Lag lokal kopi';

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
  String get catalogDiffTags => 'Etiketter';

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
  String get deleteActor => 'Slett markør';

  @override
  String confirmDeleteActor(String name) {
    return 'Dette sletter $name fra markørlisten. Fortsette?';
  }

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
  String get briefMissingProgram => 'Ingen aktiv plan';

  @override
  String get briefMissingExercise => 'Øvelse ikke funnet';

  @override
  String get briefToc => 'Innhold';

  @override
  String get briefAction => 'Åpne brief';

  @override
  String get briefClose => 'Lukk';

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
  String get appUserRoleSectionTitle => 'Min rolle';

  @override
  String get appUserRoleSectionDescription =>
      'Velg din funksjon i staben. Styrer hvilken brevvariant som vises som standard.';

  @override
  String get newRole => 'Ny rolle';

  @override
  String get newPlay => 'Nytt spill';

  @override
  String get pickExerciseForRole => 'Velg øvelse';

  @override
  String get exercisePickerTitle => 'Bytt øvelse';

  @override
  String get detailEmptyTeam => 'Velg et lag';

  @override
  String get rosterTab => 'Bemanning';

  @override
  String get detailEmptyRoster => 'Velg en markør for å se detaljer';

  @override
  String get editProgram => 'Endre plan';

  @override
  String get programName => 'Plannavn';

  @override
  String get programDescription => 'Beskrivelse';

  @override
  String get programDescriptionHint =>
      'Kort beskrivelse som vises under plannavnet i briefen';

  @override
  String get programEditorTagsLabel => 'Etiketter';

  @override
  String get programEditorTagsHint => 'Legg til en etikett';

  @override
  String get programEditorTagRemoveTooltip => 'Fjern etikett';

  @override
  String get programEditorTagTooLong => 'Etiketten er for lang (maks 40 tegn)';

  @override
  String get briefSectionProgramIntro => 'Generelt om spill og øvingsledelse';

  @override
  String get briefSectionProgramComms => 'Talegrupper';

  @override
  String get briefSectionProgramBeforeRound => 'Før hver post';

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
  String stationNumberFormatPreview(String example) {
    return 'Eksempel: $example';
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
}
