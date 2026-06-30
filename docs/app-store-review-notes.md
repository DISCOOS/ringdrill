# App Store Review Information

Reusable answers for the **App Review Information → Notes** field in App Store
Connect. Paste the relevant sections on every submission. Fill the `[ ]`
placeholders before sending.

Background: the first submission was held under **Guideline 2.1 – Information
Needed** (not a bug or rejection — App Review just needed more context). These
notes answer all seven points Apple asked for.

---

## Notes field (paste into App Store Connect)

Answers follow Apple's numbering 1–7.

### 1. Screen recording

A screen recording captured on a physical device is attached, beginning with the
app launching from the home screen and showing the typical user flow through the
core features (see the demo video script below). The app has no account, in-app
purchase, user-generated-content reporting or App Tracking Transparency flows; the
only sensitive-data prompt is the location permission, which is shown in the
recording.

### 2. Devices and operating systems tested

- [ iPhone model, e.g. iPhone 13 ] — iOS [ version, e.g. 18.5 ]
- [ iPad model, e.g. iPad (10th gen) ] — iPadOS [ version ]

### 3. Purpose and target audience

RingDrill is a planning and facilitation tool for field training exercises that
use a station-rotation format. An exercise leader lays out stations (posts) on a
map, assigns teams, schedules rotation rounds, optionally adds role-play markers,
and generates printable briefing documents for participants, instructors and
exercise directors. It is built for volunteer and professional organizations that
run multi-station drills, such as search-and-rescue teams, emergency-preparedness
groups and similar. It replaces manual, paper-based exercise planning.

### 4. Setup and access to main features

No account, login or credentials are required. All features are available
immediately on first launch, with no paywall and no sample files needed.

Typical flow:

1. Create an exercise.
2. Add stations and teams.
3. Set the number of rotation rounds.
4. Open the live session player to run the rotation.
5. Generate a brief document for participants / instructors / director.

The app ships with example data so the reviewer can explore without setup.

### 5. External services used

- Map tiles: Kartverket (Norwegian Mapping Authority) public topographic WMTS
  service — `cache.kartverket.no`.
- Optional shared-catalog backend: Netlify Functions at `ringdrill.netlify.app`,
  used to publish and download shared exercise plans. The app is fully usable
  offline/locally without it.
- Crash and error reporting: Sentry (opt-out; disabled unless the user consents).
- No authentication service, no payment processor, no AI services, no advertising.

### 6. Regional differences

The app is designed for running training exercises in Norway. Its map base layer
uses the Norwegian national topographic service (Kartverket), which only covers
Norway, so map tiles are blank outside Norwegian territory. A reviewer testing
from outside Norway will therefore see no map background; this is expected and not
a bug. All other functionality (creating exercises, stations, teams, rounds,
role-play and brief generation) is the same everywhere and does not depend on
location. The app's interface is localized in Norwegian and English.

### 7. Regulated industry / protected third-party material

Not applicable. The app does not operate in a regulated industry and includes no
protected third-party material. Map data is provided by Kartverket under their
open-data terms, with attribution shown in the app.

### Supplementary: location purpose string (Guideline 5.1.1)

Location is used only when the user taps the "locate me" button on the map,
solely to centre the map on the current position. It is never stored or
transmitted off the device.

### Supplementary: privacy policy and terms URLs

The pages are bilingual and live on the RingDrill site:

- Privacy policy: `https://ringdrill.app/privacy` (Norwegian), `https://ringdrill.app/en/privacy` (English)
- Terms of use: `https://ringdrill.app/terms` (Norwegian), `https://ringdrill.app/en/terms` (English)

Use the privacy URL that matches the App Store Connect primary language in the
**App Privacy → Privacy Policy URL** field (a per-locale URL can be set as well).
The earlier `discoos.org/projects/ringdrill/*` pages have been retired, so make
sure no store listing still points there.

---

## Demo video script

Record on a physical device, ~30–60 seconds:

1. Launch the app from the home screen (not from Xcode/TestFlight).
2. Show the list / example data, open an exercise.
3. Add or show a station on the map — tap "locate me" so the location-permission
   prompt appears in the recording.
4. Show teams and rounds.
5. Start the live player and show the rotation running.
6. Generate a brief and show the finished document.

The person who records the video should be the device/OS listed under point 2 —
one tester covers both requirements. Since the app has not been run on physical
hardware before, this TestFlight walkthrough also serves as a real crash check
before Apple tests it.

## iPhone + iPad note

The app is universal. Apple's literal request is one recording on *a* physical
device, so a single iPhone recording satisfies the request. But iPad apps are
reviewed on iPad hardware, and RingDrill has a distinct wide-screen master/detail
layout (ADR-0030 / DESIGN-005), so the iPad codepath is worth verifying before
submission to avoid a follow-up 2.1 bugs rejection. List both an iPhone and an
iPad under point 2 if possible; one combined recording that shows both is ideal
but not required.

---

## Tester communication

### Where each text goes

- **Long message below** — sent directly to the tester by email/SMS, together
  with the TestFlight invite link. It is *not* entered into App Store Connect.
- **"What to Test" (short text below)** — entered per build under TestFlight →
  open the build/version → **Test Details → What to Test**. This is what the
  tester sees in the TestFlight app for that build.
- Do **not** put tester instructions under *Beta App Review Information → Review
  Notes* — that section is for Apple's beta reviewers, not testers.

### Message to the tester (Norwegian — paste into email/SMS)

> Hei! Takk for at du tester RingDrill for meg før vi legger den ut på App Store.
> Det tar 5–10 minutter.
>
> **Viktig:** Gjør dette mens du er fysisk i Norge — appen bruker norske kart, så
> kartet er blankt utenfor Norge.
>
> **Slik kommer du i gang:**
> 1. Installer den gratis appen «TestFlight» fra App Store.
> 2. Åpne invitasjonslenken jeg sender deg (den åpner TestFlight automatisk).
> 3. Trykk «Install» for å hente RingDrill.
>
> **Før du starter:** Slå på skjermopptak. Sveip ned fra øvre høyre hjørne
> (Kontrollsenter) og trykk opptaks-knappen. Start opptaket *før* du åpner appen.
>
> **Gjør så dette, rolig nok til at det vises på opptaket:**
> 1. Åpne RingDrill fra hjemskjermen.
> 2. På velkomstskjermen, trykk **«Åpne med et eksempel»** (laster inn en ferdig
>    plan).
> 3. I **«Øvelser»**-fanen, åpne en øvelse i listen og se på runder og lag.
> 4. Trykk **play-knappen (▶)** for å starte øvelsen — spilleren viser rundene som
>    teller ned.
> 5. Gå til **«Kart»**-fanen og trykk **«Vis min posisjon»**. Godta posisjonstilgang
>    når appen spør.
> 6. Trykk **«Åpne brief»** og bytt **«Målgruppe»** mellom Deltaker, Veileder og
>    Øvelsesleder.
> 7. Trykk **«Stop øvelse»** for å avslutte.
> 8. *(Valgfritt, men fint:)* Åpne plan-listen, gå til fanen **«På nett»**, og
>    trykk **«Åpne»** på en plan (f.eks. `lsor-eidene-2026`) for å vise at en plan
>    lastes ned fra nett.
> 9. Stopp skjermopptaket.
>
> **Send meg til slutt:**
> - Videoopptaket
> - Hvilken enhet du brukte (f.eks. iPhone 13)
> - Hvilken iOS-versjon (Innstillinger → Generelt → Om → Programvareversjon)
>
> Si fra om noe krasjer eller ser rart ut. Tusen takk!

### "What to Test" (Norwegian — paste into TestFlight → Test Details)

> Test hovedflyten med eksempelplanen. Vær fysisk i Norge så kartet vises, og ta
> opp skjermen under hele forløpet.
> 1. På velkomstskjermen, trykk «Åpne med et eksempel».
> 2. I «Øvelser»-fanen, åpne en øvelse og se på runder og lag.
> 3. Trykk play-knappen (▶) for å starte øvelsen.
> 4. Gå til «Kart»-fanen, trykk «Vis min posisjon», og godta posisjonstilgang.
> 5. Trykk «Åpne brief» og bytt «Målgruppe» mellom Deltaker, Veileder og
>    Øvelsesleder.
> 6. Trykk «Stop øvelse» for å avslutte.
> 7. (Valgfritt) Åpne plan-listen, gå til «På nett», og trykk «Åpne» på en plan
>    (f.eks. lsor-eidene-2026) for å vise nedlasting fra nett.

### Message to the tester (English — paste into email/SMS)

> Hi! Thanks for testing RingDrill for me before we release it on the App Store.
> It takes 5–10 minutes.
>
> **Important:** Do this while you are physically in Norway — the app uses
> Norwegian maps, so the map is blank outside Norway.
>
> **Getting started:**
> 1. Install the free "TestFlight" app from the App Store.
> 2. Open the invite link I send you (it opens TestFlight automatically).
> 3. Tap "Install" to get RingDrill.
>
> **Before you start:** Turn on screen recording. Swipe down from the top-right
> corner (Control Centre) and tap the record button. Start recording *before* you
> open the app.
>
> **Then do this, slowly enough that it shows on the recording:**
> 1. Open RingDrill from the home screen.
> 2. On the welcome screen, tap **"Open an example"** (loads a ready-made plan).
> 3. In the **"Exercises"** tab, open an exercise and look at rounds and teams.
> 4. Tap the **play button (▶)** to start the exercise — the player shows the
>    rounds counting down.
> 5. Go to the **"Map"** tab and tap **"Show my position"**. Allow location access
>    when prompted.
> 6. Tap **"Open brief"** and switch **"Audience"** between Participant, Instructor
>    and Director.
> 7. Tap **"Stop Exercise"** to finish.
> 8. *(Optional, but nice:)* Open the plan list, go to the **"Online"** tab, and
>    tap **"Open"** on a plan (e.g. `lsor-eidene-2026`) to show a plan downloading
>    from the network.
> 9. Stop the screen recording.
>
> **Finally, send me:**
> - The screen recording
> - Which device you used (e.g. iPhone 13)
> - Which iOS version (Settings → General → About → Software Version)
>
> Let me know if anything crashes or looks wrong. Thank you!

### "What to Test" (English — paste into TestFlight → Test Details)

> Test the main flow with the example plan. Be physically in Norway so the map
> shows, and record your screen throughout.
> 1. On the welcome screen, tap "Open an example".
> 2. In the "Exercises" tab, open an exercise and look at rounds and teams.
> 3. Tap the play button (▶) to start the exercise.
> 4. Go to the "Map" tab, tap "Show my position", and allow location access.
> 5. Tap "Open brief" and switch "Audience" between Participant, Instructor and
>    Director.
> 6. Tap "Stop Exercise" to finish.
> 7. (Optional) Open the plan list, go to "Online", and tap "Open" on a plan
>    (e.g. lsor-eidene-2026) to show it downloading from the network.
