# ADR-0017 follow-up

Tre oppfølgingsoppgaver etter ADR-0017-implementasjonen. Hver oppgave er én commit. Samme ground rules og commit-format som forrige prompt.

## 1. Annotér revisits og under-coverage i delingsteksten

ADR-0017 listet dette som en uadressert "Bad consequence". I `formatExerciseForShare`, legg til én informasjonslinje etter meta-linjen når `numberOfRounds != numberOfStations`. Nye ARB-nøkler `shareNoteRevisits(rounds, stations)` og `shareNoteUnderCoverage(rounds, stations)`. Rullerings-blokken under er fredet (jf. `feedback_rotation_share_format`). Oppdater golden strings i `exercise_share_format_test.dart`.

Commit: `feat(coordinator): annotate revisits and under-coverage in rotation-share text`.

## 2. Eksisterende øvelser med verdier over 12

En lagret øvelse kan ha `numberOfTeams = 14` eller `stations.length = 14` fra før kapselen. I `ExerciseFormScreen.initState`, hvis noen av de tre tellerene laster en verdi > 12: behold verdien i feltet (ikke clampe), og vis en banner over feltene som forklarer at øvelsen er fra før dagens grense og at reduksjon er permanent. Ny ARB-nøkkel `legacyOversizedExerciseNotice`. Validatorene skal fortsatt blokkere lagring uten redigering. Test load-stien.

Commit: `fix(exercise): preserve legacy counter values above the 12-cap on load`.

## 3. Migrér koordinator-stations-tab til `StationExpansionTile`

DESIGN-002 flagget dette som follow-up. I `coordinator_screen.dart _buildStationList`, bytt ut Material `ExpansionTile` med `StationExpansionTile`. Title-Row blir `title`-slot, `_buildStationDetail` blir `body`-slot, `_expandedStationIndex` holder mutex via `expanded`/`onToggle`. Live-styling (`isLive`-farger og border) blir på `Card`, ikke på den delte widgeten.

Commit: `refactor(coordinator): use shared StationExpansionTile in the Stations tab`.

## Out of scope

Option D fra ADR-0017 trenger eget designdokument og er ikke en del av denne runden.
