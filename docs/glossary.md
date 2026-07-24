# Glossary and naming

The authoritative names are **English** — used in code, tests and all documentation (`AGENTS.md` rule 12). Norwegian appears only as the user-facing UI labels the app ships in `nb`. This file pins the domain vocabulary so names don't drift; quote the Norwegian label in double quotes when it matters, never as a code identifier.

## Domain entities

* **Station** — a rotation post in an exercise; rotation math lives in the `stationIndex` extension. The Norwegian UI label is "post"/"poster". Code, tests, file names and docs always say **station(s)**, never "post".
* **RolePlay** — the publishable *role* a marker enacts (behaviour, background, effective identity). Norwegian UI: "Rolle", and "Markør" for the marker as a whole. Never model it as `RolePlayer`.
* **Actor** — the real person cast to play a `RolePlay` (`enacted by`). Carries PII, stored locally, stripped on publish (ADR-0018, ADR-0047). "Spilles av {actor}" / "played by {actor}" names the Actor, not the role. The Norwegian "Markør" spans the RolePlay+Actor concept in the UI; in code they are separate types.
* **Location** — a station-owned scenario place (label, kind, coordinate, note). `station.loc.<slug>` (ADR-0047, DESIGN-009).
* **Person** — a station-owned fictional scenario person (name, age, gender, description, notes, linked location). **No PII** — the real human is the `Actor`. `station.person.<slug>`.
* **Plan** — the model type backing the "Plan" UI tab (`PlanScope`, `PlanVariables`, …). Named `Plan` throughout, matching the UI; it does **not** change the `.drill` wire format — the archive root stays `program.json` (ADR-0007) and JSON keys are unaffected.

## Roles / audience

* **BriefAudience** — `participant` / `instructor` / `director` (IDs stay English in code). Norwegian labels: `participant` → "Deltaker", `instructor` → "Veileder" (not "Instruktør"), `director` → "Øvelsesleder".

## Surfaces

* **Site** — the public website (the Site / PWA / API origin split, ADR-0039). Do not call it "marketing" — that is too narrow.

See also: `docs/ui-conventions.md`, and the ADRs referenced above.
