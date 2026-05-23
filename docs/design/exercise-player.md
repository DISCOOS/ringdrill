---
id: DESIGN-001
title: Exercise Player
status: Accepted
started: 2026-05-23
accepted: 2026-05-23
owners: ["kengu"]
related_code:
  - lib/services/exercise_service.dart
  - lib/views/coordinator_screen.dart
  - lib/views/main_screen.dart
  - lib/views/exercise_control_button.dart
  - lib/views/phase_tile.dart
  - lib/views/phase_widget.dart
  - lib/views/phase_headers.dart
mockups:
  - mockups/coordinator-oversikt.html
  - mockups/coordinator-poster.html
  - mockups/coordinator-lag.html
  - mockups/mini-player.html
  - mockups/observer-lag.html
  - mockups/observer-post.html
  - mockups/wide-screen.html
---

# Exercise Player

## TL;DR

When an exercise is running, RingDrill exposes it as a **persistent player** that follows the user across the Program, Stasjoner and Lag tabs, instead of locking them to a single "run" screen. The player has two visual states:

* A **mini-player** strip that lives above the bottom navigation on mobile and along the bottom edge on bredskjerm. Always visible while an exercise is active or pending.
* A **full-player** sheet that slides up from the mini-player on demand. The full-player tar én av tre former avhengig av brukerens rolle: **koordinator-spilleren** (med fanene Oversikt, Poster, Lag), **observer-spilleren for lag** (følger ett lag) og **observer-spilleren for post** (følger én post).

The model is borrowed from Spotify. `ExerciseService` is already a singleton that runs one exercise at a time and keeps running while you navigate around. Today that fact has no surface in the UI. The player gives it one.

## Goals

1. Lar koordinator sjekke stasjoner og lag uten å miste oversikten over hvor i øvelsen man er.
2. Skiller "redigere øvelse" (CoordinatorScreen i dag) fra "spille av øvelse" (player). De to har ulike behov og fortjener ulike skall.
3. Bruker det meste av eksisterende widgets på nytt. `_buildStationList` og `_buildTeamList` fra CoordinatorScreen fungerer som Poster- og Lag-faner uten å bli skrevet om.
4. Gir en plass for en framtidig "Oversikt"-visning som koordinator i dag mangler.

## Non-goals

* Endrer ikke `ExerciseService`-mekanikken. Klokken styrer fortsatt fasene, og ingen pause/skip-knapper introduseres som del av denne designen.
* Endrer ikke datamodellen. Antall lag, stasjoner og runder forblir som de er. Designen forutsetter at antall lag aldri overstiger antall stasjoner (én lag per stasjon per runde, ingen "venter"-rad).
* Berører ikke notifikasjoner, eksport eller deling. Player er en visuell laginnpakning, ikke en ny tjeneste.

## Rationale: hvorfor "player"-metaforen?

`ExerciseService` har tre egenskaper som matcher Spotify nesten 1-til-1:

| Spotify             | RingDrill                                      |
|---------------------|------------------------------------------------|
| Én aktiv sang       | Én aktiv øvelse (singleton-tjeneste)           |
| Spilles selv om du navigerer | Timeren fortsetter når du bytter fane |
| Album / spilleliste | Plan (programmet øvelsen hører til)            |
| Track progress      | `phaseProgress` / `roundProgress`              |
| Next up             | Neste fase eller neste runde                   |
| Now playing-bar     | Mini-player                                    |
| Now playing-view    | Full-player                                    |

Brukeren kjente igjen mønsteret umiddelbart. Mini-bar over navigasjon er en konvensjon vi kan låne uten å forklare. Stopp-knappen (rød rund) signaliserer "avbryt avspilling" på samme måte som i en musikkapp.

## Anatomy

```
┌─────────────────────────────────────────────┐
│   App content (Program / Stasjoner / Lag)   │
│                                             │
├─────────────────────────────────────────────┤
│  ▍▍▍▍▍▍▍▍▍▍                      ←  phase progress
│  ⬜ EXECUTION · Runde 2/5   06:42  ⏹       │ ← MINI-PLAYER
├─────────────────────────────────────────────┤
│   Bottom Navigation                         │
└─────────────────────────────────────────────┘

                  tap mini
                     ▼

┌─────────────────────────────────────────────┐
│  ⌄        Skogbrann 2026         ⋮          │ ← FULL-PLAYER
│                                             │   (bottom-sheet)
│  [ Oversikt ]  Poster   Lag                 │ ← segmentbryter
│                                             │
│  ┌──────┐   06:42       NESTE               │
│  │ EXEC │   IGJEN       ▤ EVAL  14:34       │
│  │      │   ferdig 14:34 ▤ ROLL  14:37      │
│  └──────┘                                   │
│                                             │
│  FREMDRIFT INNEVÆRENDE RUNDE                │
│  ████████|████  ▓▓▓▓  ░░                    │
│                                             │
│  RUNDETIDSLINJE                             │
│  [R1] [R2] [R3] [R4] [R5]                   │
│                                             │
│  POSTER  RUNDE   ⏹    TID IGJEN   LAG       │
│   4     2 av 5        42:18       5         │
└─────────────────────────────────────────────┘
```

## Mini-player

The persistent strip that signals "an exercise is running" wherever the user is in the app.

**Where it lives:**

* **Smal skjerm:** Strip 56 px høy mellom innholdet og `NavigationBar`. Den deler kantlinje med navigasjonen og blir et fast lag rett over.
* **Bred skjerm:** Spans hele bredden nederst, også over `NavigationRail`. Layoutet er trekolonne (info / kontroll / linse), beskrevet under [Wide-screen behavior](#wide-screen-behavior).

**What it shows:**

* Fargekodet 36 × 36 firkant til venstre med fase-ikon (samme firkant-konsept som hero i full-player, bare mindre).
* Faseetikett (EXECUTION / EVAL / ROLL) som chip.
* Runde-indikator (Runde 2 / 5).
* Navnet på den aktive øvelsen (eller på den aktive øvelses-tittelen, hvis navn finnes).
* Nedtelling i tabular-nums (06:42).
* Rød rund stoppknapp (36 × 36).
* Tynn 3 px progress-stripe langs toppkant som viser `phaseProgress`.

**Pending-tilstand:** Når øvelsen er startet men før klokkeslettet inntreffer (`ExercisePhase.pending`), erstattes fase-chippen med "STARTER OM" og nedtellingen viser tid til start. Den fargede firkanten blir nøytral (grå) inntil execution-fasen begynner.

**Interaksjoner:**

* Tap på baren (ikke på stoppknappen): åpne full-player som bottom-sheet.
* Tap på stoppknappen: vis bekreftelses-snackbar (`stopExerciseFirst`-mønsteret finnes allerede i `ExerciseControlButton`).
* Sveip ned på baren: ingen handling. Stopp må gjøres bevisst.

Mock: [`mockups/mini-player.html`](./mockups/mini-player.html)

## Full-player

A `showModalBottomSheet` med `isScrollControlled: true` og `useSafeArea: true`. Den glir opp fra mini-player og dekker det meste av skjermen, med en chevron øverst som lukker den tilbake til mini uten å stoppe avspillingen.

For koordinator har full-player tre faner via en segmentert bryter øverst:

* **Oversikt** – aggregert status og fremdrift (ny visning).
* **Poster** – stasjonsliste med rotasjons-strip (gjenbruker `_buildStationList`).
* **Lag** – lagliste med rotasjons-strip (gjenbruker `_buildTeamList`).

Disse er på samme zoom-nivå. Alle tre ser hele øvelsen, bare med ulik linse.

### Fanevalg: hvorfor disse tre

En tidligere skisse hadde "Oversikt | Lag 3 | Stasjon A2" som segmenter, der de to siste var konkrete enheter. Det viste seg å blande to nivåer: Oversikt så på hele øvelsen, mens Lag 3 og Stasjon A2 fokuserte på én enkelt enhet. Mønsteret ble forvirrende for koordinator, fordi koordinator aldri har lyst til å se bare ett lag eller én stasjon i ett blikk. Koordinatoren vil veksle mellom hele lag-listen og hele stasjon-listen.

Faste enheter (én lag, én stasjon) tilhører Lag-fanen og Stasjon-fanen i bunnnavigasjonen (TeamScreen, StationScreen), ikke koordinator-player.

## Oversikt-fanen

Den nye delen. Den erstatter dagens "live status row" i CoordinatorScreen og fyller den med mer informasjon enn én linje med fase og tid.

Mock: [`mockups/coordinator-oversikt.html`](./mockups/coordinator-oversikt.html)

### Anatomi

Fra topp til bunn:

1. **Toppkrom** (chevron, plannavn, mer-knapp).
2. **Segmentbryter** (Oversikt valgt).
3. **Hero-rad** (tre kolonner):
   * **Fase-firkant** 92 × 92 til venstre. Solid fyllfarge per fase (Drill grønn `#1D9E75`, Eval blå `#378ADD`, Roll ravgul `#BA7517`). Ikon (ti-flame / ti-clipboard-check / ti-arrows-shuffle) over kort fase-etikett i versaler. Fungerer som "albumcover".
   * **Nedtelling-kolonne** i midten, sentrert. 44 px stort tall (`06:42`), tabular-nums. Under: "IGJEN AV FASEN" som liten etikett, deretter "ferdig 14:34" i tertiær farge.
   * **NESTE-kolonne** til høyre. To stablede 36 × 36 mini-firkanter for de to neste fasene, hver med ikon og fase-etikett pluss starttid og varighet (`14:34 · 3 min`).
4. **FREMDRIFT INNEVÆRENDE RUNDE** – en 6 px høy tre-segments-stripe med samme fargekoder som hero. Vertikal markør viser nøyaktig "you are here" innen aktivt segment. Etiketter under: "Drill 7 min · Eval 3 min · Roll 2 min".
5. **RUNDETIDSLINJE** – fem like brede pillar over hele bredden, hver med starttid under. Aktiv runde har omriss og fyll proporsjonalt med fremdrift; fullførte runder er fylte og dempede; framtidige er tomme.
6. **Bunnkontroll-rad** – fem celler:
   * **POSTER** (antall stasjoner), sentrert ytterst til venstre.
   * **RUNDE** "2 av 5", høyrejustert inntil stoppknappen.
   * **Stoppknapp**, 60 × 60 rød rund knapp i midten.
   * **TID IGJEN** "42:18", venstrejustert inntil stoppknappen.
   * **LAG** (antall lag), sentrert ytterst til høyre.

### Designvalg

**Nedtellingen er fasens, ikke øvelsens.** Koordinator handler innenfor faser ("vi har 6 minutter igjen før evaluering starter"), ikke innenfor øvelsen som helhet ("vi har 42 minutter igjen totalt"). Total tid igjen er flyttet til bunnraden som "TID IGJEN", der den er tilgjengelig som bakgrunns-informasjon uten å konkurrere med fase-nedtellingen.

**NESTE-kolonnen er en mini-kø.** Den viser alltid de to neste fasene, uansett om de hører til samme runde eller neste runde. Når vi er i Roll i runde 2, viser NESTE "DRILL · R3" og "EVAL · R3". Når vi er i siste fase av siste runde, blir kolonnen tom.

**Fargekoden går igjen.** Fase-firkanten, NESTE-firkantene, fase-stripen og rundetidslinjens fyllfarge bruker de samme tre fargene konsistent. Det gjør at brukeren ikke trenger å huske noen legende. Grønn er Drill overalt, blå er Eval, ravgul er Roll.

**Bunnraden balanserer rundt stoppknappen.** RUNDE og TID IGJEN hugger inntil stoppknappen og leses sammen med den, fordi de er tids-relaterte. POSTER og LAG er kapasitets-anker ytterst, sentrert i sine egne celler. Det gir to visuelle rytmer i samme rad uten å konkurrere.

**Vertikal "you are here"-markør på fase-stripen.** En 12 px høy strek som flytter seg fra venstre mot høyre gjennom aktivt segment. Mer presis enn ren fyll, særlig ved kort fase-varighet der prosent-fyll endrer seg i hopp på minuttgrensen.

## Poster-fanen

Bygger videre på `_buildStationList` fra `CoordinatorScreen` med kun små justeringer for å passe inn i player-skallet.

Mock: [`mockups/coordinator-poster.html`](./mockups/coordinator-poster.html)

Eksisterende oppførsel som beholdes:

* Hver stasjon er en `ExpansionTile` med navn, en mini horisontal rotasjons-strip (lag-nummer per runde, aktiv runde fremhevet i blå), og utvidet detalj med `PhaseTile` per runde.
* **Per-runde-progress i utvidet detalj gjenbruker `PhaseTile` + `PhasesWidget` direkte.** Dette er den eksisterende "DRILL | EVAL | ROLL"-cellestripen som fyller seg fra venstre basert på `event.phaseProgress`, hvor aktiv runde har `blueAccent` fyll og hvit tekst. Vi finner ikke opp en ny per-runde-visualisering. Mockupen tegner forenklede tre-segments-bjelker for å spare plass og kommunisere strukturen, men selve produksjons-koden skal vise den eksisterende `PhaseTile`-rendringen.
* Aktiv stasjon (det vil si den med tilordnet lag i nåværende runde) er automatisk utvidet og fremhevet med `primaryContainer`-farge og `Icons.play_circle_fill` som leading.
* `PageStorageKey` per stasjon bevarer utvidet/kollapset tilstand på tvers av exercise-event-oppdateringer.

Tilpasninger for player-skallet:

* Listen får hele bredden til disposisjon istedenfor å dele med Lag-listen.
* Et lite header-element "STASJONS-ROTASJONER" + "N stasjoner" sitter rett under segmentbryteren, med samme typografi som Oversikt sine seksjons-etiketter (FREMDRIFT INNEVÆRENDE RUNDE, RUNDETIDSLINJE).
* Den aktive raden får faseens grønne kantfarge (`#1D9E75`) og lys grønn fyll (`#E1F5EE`), ikke koordinator-screens generiske `primaryContainer`. Dette knytter "aktiv post" direkte til fasefargen som dominerer hero.

Footer-raden (POSTER · RUNDE · STOP · TID IGJEN · LAG) er felles for alle tre fanene og forblir synlig nederst.

## Lag-fanen

Bygger videre på `_buildTeamList` fra `CoordinatorScreen` med en endring i auto-expand-policy.

Mock: [`mockups/coordinator-lag.html`](./mockups/coordinator-lag.html)

Eksisterende oppførsel som beholdes:

* Hver lag-rad er en `ExpansionTile` med navn, "→ Stasjonsnavn"-subtitle som viser hvor laget er nå, og en mini horisontal rotasjons-strip (stasjons-koder per runde, aktiv runde fremhevet i blå).
* Utvidet detalj viser `PhaseTile` per runde med stasjons-navn som tittel. Samme PhaseTile-gjenbruk som i Poster-fanen — vi tegner ikke en ny per-runde-progress-widget.

Endringer i player-skallet:

* **Auto-expand for observert lag.** I CoordinatorScreen i dag utvides ingen lag automatisk, fordi alle lag alltid har en aktiv stasjon (en naiv "isLive"-sjekk ville utvidet hver eneste rad). I player tar vi ett skritt videre og auto-utvider det laget koordinator har "observasjons-konteksten" på, hvis en slik kontekst finnes. Kilden kan være den siste lag-raden de utvidet manuelt, det laget de sist navigerte til via TeamScreen, eller et default valg. Hvis ingen kontekst finnes, starter listen kollapset slik den gjør i dag.
* **Den utvidede raden farges lilla.** Aktiv lag-rad får lilla kantfarge (`#534AB7`) og lys lilla fyll (`#EEEDFE`), ikke grønn. Lilla er observer-spillerens "lag"-farge, så koordinator ser umiddelbart at "dette er det laget noen følger" istedenfor "dette er en aktiv post". Den fargesemantiske splitten – grønt for fasestatus, lilla for lag-identitet – er konsistent på tvers av hele player-modellen.

Footer-raden er identisk med Oversikt og Poster.

## Observer-spilleren

For brukere som ikke koordinerer hele øvelsen, men følger én bestemt enhet, finnes en egen variant av full-player. Den har ingen segmentbryter, fordi observer alltid har én linse om gangen. To roller dekkes av samme mal:

* **Observer-spiller for lag** – brukeren følger ett bestemt lag gjennom rotasjonene.
* **Observer-spiller for post** – brukeren står på en bestemt post og ser lagene rullere gjennom.

Mockups: [`mockups/observer-lag.html`](./mockups/observer-lag.html) og [`mockups/observer-post.html`](./mockups/observer-post.html).

### Felles struktur

Observer-spilleren bruker den samme visuelle malen som koordinator-spilleren, med følgende elementer hentet direkte fra Oversikt-fanen:

* Toppkrom (chevron, plannavn, mer-knapp).
* Fase-firkant 92 × 92 til venstre i hero, sentrert nedteller i midten, NESTE-kolonne til høyre.
* Fase-stripen "FREMDRIFT INNEVÆRENDE RUNDE" med samme tre fasefarger og "you are here"-markør.
* 5-cells bunnrad rundt stoppknappen, samme typografi.

Forskjellene mot koordinator-spilleren:

* **Perspektiv-pillen erstatter segmentbryteren.** Et enkelt pille-element øverst viser hvilken enhet observer følger, med et ikon i lilla (`#534AB7`) til venstre og et chevron-ned til høyre. Tap på pillen åpner en velger i bottom-sheet for å bytte enhet. Ikonet er `ti-user-circle` for lag-varianten og `ti-map-pin` for post-varianten.
* **Tittel-stripe under hero.** En egen rad mellom hero og fase-stripe viser observerens "now playing"-kontekst, parallelt med Spotifys sang-tittel under albumcoveret. For lag-varianten: stasjonsnavn stort + "Lag X står her nå" undertekst. For post-varianten: lag-navn stort + "På din post nå · Ankom HH:MM" undertekst.
* **NESTE-kolonnen viser perspektivets kø, ikke fasekøen.** For lag-varianten: de to neste stasjonene laget skal innom (lilla tiles med postkoder). For post-varianten: de to neste lagene som ankommer posten (lilla tiles med lag-numre). Den lilla fargen er reservert "ditt perspektivs kø" og distinkt fra fasefargene som dominerer hero-firkanten.
* **Kø-liste erstatter rundetidslinjen.** En vertikal liste med 3-N rader gir observer mer detalj per oppføring enn koordinatorens horisontale 5-pillars stripe, fordi observer bare har én sekvens å vise.
  * Lag-variant: header "VIDERE FOR LAG X" med "N stasjoner igjen" til høyre. Rader: rundenummer + lilla post-tile + postnavn + "Starter HH:MM".
  * Post-variant: header "VIDERE PÅ AX" med "N lag igjen" til høyre. Rader: rundenummer + lilla lag-tile + "Lag N" + "Ankommer HH:MM".
* **Bunnraden tilpasser ytter-celler.** RUNDE, STOP og TID IGJEN er identiske med koordinator. Yttercellene er felts-agnostiske og viser perspektivets fremdrift:
  * **UTFØRT** (venstre): antall stasjoner laget har gjennomført (lag-variant) eller antall lag posten har betjent (post-variant).
  * **GJENSTÅR** (høyre): antall stasjoner laget har igjen (lag-variant) eller antall lag posten har igjen å betjene (post-variant).
  * Etikettene har ingen "post" eller "lag" i seg, slik at samme felt-mal gjenbrukes på tvers av observer-rollene.

### Stoppknappen

Stoppknappen ligger på samme posisjon og samme røde fyll som hos koordinator, av hensyn til visuell konsistens. Funksjonelt er den rolleavhengig:

* **Offline:** alle (også observere) kan stoppe en øvelse. Denne fleksibiliteten er ønsket fordi enheter ofte ikke er tilkoblet hverandre, og en lokal stopp må alltid være mulig.
* **Online (synkronisert):** kun koordinator skal kunne trigge stopp. For observere bør knappen disables (`onPressed: null`) når synkronisering er aktiv. Implementasjonen kan lene seg på `ExerciseService` sin online/offline-tilstand for å bestemme dette.

## Wide-screen behavior

`NavigationRail` (venstre) + hovedinnhold (midten) + mini-player (full bredde nederst, som Spotify desktop).

* Mini-baren spenner hele bredden, også over rail-en. Det signaliserer at avspilleren er global, ikke knyttet til en kolonne.
* Trekolonne-layout i mini-baren:
  * **Venstre:** Now-playing-info (fase-firkant, chip, runde-tall, øvelsesnavn).
  * **Midten:** Tid og kontroll (nedtelling, stoppknapp).
  * **Høyre:** Linse-info (rolle-etikett, "Bytt perspektiv"-knapp, ekspander-til-full-player-knapp).
* "Ekspander"-knappen åpner full-player som en modal som dekker midten. Rail forblir synlig men disabled, omtrent som Spotifys queue-view på desktop.

Mock: [`mockups/wide-screen.html`](./mockups/wide-screen.html)

## Color tokens for phases

Fase-fargene defineres som konstanter et felles sted (foreslått: `lib/views/exercise_player/phase_colors.dart` eller via theme extension) og brukes konsistent i:

* Mini-player firkant
* Full-player hero-firkant
* NESTE-firkanter
* Fase-stripen (FREMDRIFT INNEVÆRENDE RUNDE)
* Rundetidslinje (aktiv runde sin fyll-farge følger aktiv fase)

| Fase       | Hex       | Ikon                  | Etikett     |
|------------|-----------|-----------------------|-------------|
| Execution  | `#1D9E75` | `ti-flame`            | EXECUTION   |
| Evaluation | `#378ADD` | `ti-clipboard-check`  | EVAL        |
| Rotation   | `#BA7517` | `ti-arrows-shuffle`   | ROLL        |

Ikonene må mappes fra Tabler i mockup til Material Icons eller annet i Flutter-implementasjonen. Forslag: `Icons.local_fire_department`, `Icons.fact_check`, `Icons.swap_horiz`.

## Open questions

These were raised during design and parked, not closed:

* **Fanevalg ved ulik rolle.** Koordinator-spilleren har tre faner, observer-spilleren har ingen segmentbryter, bare en perspektiv-pille. Dette er forskjellige skall over samme grunnstruktur. Resolvert.
* **PhaseTile-fargesemantikk.** Eksisterende `PhaseTile` (og `PhasesWidget`) bruker `Colors.blueAccent` ensartet for "aktiv" — både på title-cellen, fase-bakgrunnen og progress-fyllet. Player-skallet bruker derimot tre forskjellige fasefarger (grønt for execution, blått for evaluation, ravgult for rotation) i hero-firkanten, NESTE-tilene og fase-stripen. Å la PhaseTile beholde blueAccent skaper en visuell brudd der utvidet detalj ikke "snakker samme språk" som resten av spilleren. Tre alternativer:
  1. Behold PhaseTile som den er. Aksepter at utvidet detalj har sin egen, lokale fargekode. Krever ingen kodeendring.
  2. Oppdater `PhasesWidget` til å bruke fasefargene per fase-celle (Drill-cellen grønn, Eval blå, Roll ravgul) når runden er aktiv. Mer arbeid men gir konsistens.
  3. La hver fase-celle alltid være farget i sin fasefarge, og bruk fyllet (`phaseProgress`) til å markere fremdrift over den fargede cellen. Mest informasjon på minst plass.
  
  Sannsynligvis alternativ 2, men vi parker valget til vi går mot kode.
* **Tappbare celler i RUNDETIDSLINJEn.** Skal tap på "R3" hoppe Poster- eller Lag-fanen til den runden i en "preview"-modus, slik at koordinator kan se hva som vil skje? Foreløpig nei, men det er en lavterskel-utvidelse.
* **Tappbare NESTE-tiles.** Skal tap på EVAL-tilen forhåndsvise hvordan fase-stripen og rundetidslinjen vil se ut når evaluering starter? Samme spørsmål som over, samme svar.
* **CoordinatorScreen sin rolle etter at player finnes.** Forslag: bli en ren "redigere før start"-skjerm. All "spille av"-funksjonalitet flyttes til player. CoordinatorScreen får da bare øvelse-skjema, lag- og stasjon-redigering, og en stor "Start"-knapp som faktisk åpner player.
* **Versalering av fase-etiketter.** Mockup bruker `EXECUTION` / `EVAL` / `ROLL` i versaler. Eksisterende kode bruker `event.getState(localizations).toUpperCase()`. Konsistent som det er, men verdt å revurdere når lokaliseringen oversettes (DRILL / EVAL / ROLL på norsk?).
* **Norsk vs engelsk fase-navn.** Norsk app, men fase-navnene har drevet seg engelske gjennom serverdialog og kode. Beslut én vei.

## Implementation notes

These are starting points for the engineer who picks up the work, not a binding plan.

### Suggested widget tree

```
ExercisePlayerScaffold        (Scaffold-ish container)
├── ExerciseMiniPlayer        (the strip, visible whenever ExerciseService.isStarted)
└── (on demand)
    ExercisePlayerSheet       (DraggableScrollableSheet or showModalBottomSheet)
    └── one of:
        ├── CoordinatorPlayerBody
        │   ├── PlayerSegmentTabs (Oversikt | Poster | Lag)
        │   ├── (selected tab body)
        │   │   ├── OversiktTab
        │   │   ├── PosterTab     (wraps existing _buildStationList logic)
        │   │   └── LagTab        (wraps existing _buildTeamList logic)
        │   └── PlayerFooter      (POSTER · RUNDE · STOP · TID IGJEN · LAG)
        └── ObserverPlayerBody
            ├── PerspectivePill   (Følger Lag X / Følger Post AX)
            ├── PlayerHero        (delt med Oversikt-fanen)
            ├── ObserverTitleStrip(rolle-spesifikk "now playing")
            ├── PhaseProgressStrip(delt)
            ├── ObserverQueueList (lag-stasjoner eller post-lag)
            └── PlayerFooter      (UTFØRT · RUNDE · STOP · TID IGJEN · GJENSTÅR)
```

`PlayerHero`, `PhaseProgressStrip` og `PlayerFooter` bør være delte widgets på tvers av koordinator- og observer-spillerene. Innholdet i `PlayerFooter` parameteriseres med ytter-celle-data slik at den samme widgeten kan vise POSTER/LAG (koordinator) eller UTFØRT/GJENSTÅR (observer).

### Data source

All player state comes from `ExerciseService().events` (a broadcast stream of `ExerciseEvent`). The mini-player and full-player subscribe to the same stream and rebuild on every event. No new service is needed.

`ExerciseEvent` already exposes everything the design needs:

* `exercise` (for navn, antall stasjoner, antall lag, schedule)
* `phase` + `getState(localizations)` (for fase-chip og firkant-etikett)
* `currentRound` (for "Runde 2 av 5")
* `remainingTime` (for nedtelling — minutter, må vises som mm:ss)
* `phaseProgress`, `roundProgress`, `totalProgress` (for progress-stripene)
* `when` (for "ferdig 14:34" — `when + remainingTime`)

### Things to extract

To keep the existing `CoordinatorScreen` and the new `CoordinatorPlayerBody` from drifting, `_buildStationList` and `_buildTeamList` bør refaktoreres ut av `_CoordinatorScreenState` til toppnivå-widgets (for eksempel `CoordinatorStationList` og `CoordinatorTeamList`) som tar `Exercise` og `ExerciseEvent` som parametere. Da kan begge skjermene kalle de samme widgetene.

`_buildExerciseStatus` (den kompakte live status-raden i `CoordinatorScreen`) erstattes av mini-player og kan slettes når player er tatt i bruk.

### Routing

Mini-player er global, ikke per route. Plasseres derfor i `MainScreen` mellom `body` og `bottomNavigationBar` (smal) eller i `Column` etter `Row` med rail og innhold (bred). Full-player er en modal og påvirker ikke routing-treet.

### Tester

* Widget-test for mini-player som verifiserer at den vises når `ExerciseService.isStarted` er sann og skjules ellers.
* Widget-test for OversiktTab med en fiktiv `ExerciseEvent` for hver fase, som bekrefter at firkant-farge og NESTE-rekkefølge er riktig.
* Eksisterende tester på `CoordinatorScreen` må oppdateres for å reflektere at status-raden ikke lenger finnes der.

## Related ADRs

* [ADR-0011: Synchronized exercise control](../adrs/0011-synchronized-exercise-control.md) — fastsetter at fasene er klokke-styrt og synkronisert. Player respekterer dette og introduserer ingen pause/skip-knapper.

## Changelog

* 2026-05-23 — Draft opprettet etter designdialog med kengu.
* 2026-05-23 — Lagt til Observer-spilleren-seksjon med lag- og post-varianter. Oppdatert "Suggested widget tree" til å dekke `ObserverPlayerBody`. Resolvert åpne spørsmål om fanevalg per rolle. Lagt til to nye mockups: `observer-lag.html` og `observer-post.html`.
* 2026-05-23 — Fyldigere beskrivelse av Poster-fanen og Lag-fanen, med dedikerte mockups (`coordinator-poster.html` og `coordinator-lag.html`). Endring: Lag-fanen auto-utvider lag-en koordinator har observasjons-kontekst på. Fargesemantikk: grønt for "aktiv post", lilla for "observert lag". Datasettet i mockupene er strammet til 4 lag + 4 poster + 5 rounds for å respektere `lag <= poster`.
* 2026-05-23 — Eksplisitt nedfelling at per-runde-progress i utvidet detalj gjenbruker eksisterende `PhaseTile` + `PhasesWidget`. Mockupens mini-bjelker er forenklet illustrasjon. Åpent spørsmål om PhaseTile sin fargesemantikk (blueAccent vs fasefargene) lagt til.
* 2026-05-23 — Status bumpet til **Accepted**. Designet er låst som retning for implementasjonen. Mockupene fryses som referanse. Åpne spørsmål under "Open questions" er ikke blokkerende for kode-arkitekturen — de tas mens implementasjonen pågår.
