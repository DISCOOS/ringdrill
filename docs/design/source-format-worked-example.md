# Source format — worked example

> **Status:** draft / discussion material. Not a DESIGN issue yet.
> **Purpose:** make the source format concrete against one real plan before we
> write the spec.
> **Target model:** DESIGN-008 (variables + overrides + tokens, *Accepted*) and
> DESIGN-009 (station-owned locations/persons, `personRef`, *Proposed*). The
> example is written against where the model is going, not the legacy inline
> roleplay identity.
> **Anchor:** the published catalog plan `lsor-eidene-2026.drill`
> ("LSOR Eidene 2026", 7 exercises, 4 teams). The example below is exercise
> **#2 Eidene**. Its scenario `locations`/`persons` are forward-ported to
> illustrate the DESIGN-009 target — the real plan still encodes them as prose.

The source format (NO: *kildeformat*) is what a person or an agent **writes**.
The builder compiles it to `.drill` (the build artifact) and fills in everything
that can be **derived**. `decompile` goes the other way. The round-trip contract
is that `build(decompile(d))` yields the same `contentHash` as `d`.

Guiding principle: **authored fields only, never derived ones.** If a value can
be computed from something else, it does not belong here.

Two conventions settled during design: field **names mirror the Dart model 1:1**
(only value *shapes* are source-friendly — times as `"HH:MM"`, coordinates as
`{lat, lng}`), and the document is **one YAML file with markdown in block
scalars** (`|`). Example data (station names, prose) stays Norwegian because the
plan is a real Norwegian SAR plan; only format prose and comments are English.

---

## 1. The example

```yaml
plan:
  name: "LSOR Eidene 2026"
  language: nb
  exerciseNumberFormat: hash        # #1, #2 …   (label is derived, never in names)
  stationNumberFormat: dotted       # 2.1, 2.2 …
  tags: [søk og redning, lagledelse, lsor]
  description: |
    KUN FOR STAB. Øvingsplan 2026 for kurset Lagledelse søk og redning på
    Eidene (Røde Kors Hjelpekorps Vestfold). Syv øvelser fredag–søndag.

  # DESIGN-008: variables are DECLARED once here (name / value / hint).
  # Exercises and stations may only OVERRIDE the value, never redeclare.
  variables:
    talegruppe: { value: "RK-VFOLD-ØV2 / DMO-ANDRE-1", hint: "Talkgroup for the exercise" }

exercises:
  - name: "Førsteinnsats søk (ringøvelse)"   # not "#2 " — that is a derived label
    startTime: "09:45"
    numberOfTeams: 4
    numberOfRounds: 6
    executionTime: 15                 # minutes
    evaluationTime: 10
    rotationTime: 5
    # schedule[] and endTime (12:45) are DERIVED from startTime + rounds + times.

    stations:
      # Baseline station: administrative position + a single narrative field.
      - name: "Fisker (Angler)"
        position: { lat: 59.09789, lng: 10.402513 }   # game-technical placement
        situation: |
          Kari Fiskeløs – finsøk rundt IPP innenfor R25.

      - name: "Bilcamping"
        position: { lat: 59.09814, lng: 10.404234 }
        situation: |
          Hermod Hess (tysk) – finsøk fra bobil ut til R25.

      - name: "Løper"
        position: { lat: 59.098841, lng: 10.40428 }
        situation: |
          Ine Vigerdal (42) – søk treningsløype.

      - name: "Mental sykdom"
        position: { lat: 59.098473, lng: 10.400913 }
        situation: |
          Jan Guttormsen (54) – ledelinjesøk NØ ut fra IPP (Tjøme Sykehjem).

      # Rich station: DESIGN-008 override + DESIGN-009 locations/persons/roleplay.
      - name: "Barn 4-6 år"
        position: { lat: 59.096857, lng: 10.401633 }
        variableOverrides: { talegruppe: "RK-VFOLD-ØV3" }   # DESIGN-008 override

        # DESIGN-009: station-owned scenario data, referenced by slug in prose.
        locations:
          - slug: lkp
            kind: lkp
            label: "Sist kjent posisjon"
            position: { lat: 59.09672, lng: 10.40201 }
        persons:
          - slug: magnus
            name: "Magnus Damslet"
            age: 6
            gender: male
            signalement: "Rød jakke, blå lue."
            homeSlug: lkp

        situation: |
          {{station.person.magnus}} ({{station.person.magnus.age}} år) –
          grovsøk R25 fra IPP. Sist sett {{station.loc.lkp.utm}}.
          Samband på {{var.talegruppe}}.
        director_notes: |     # → directorNotesMd (instructor/director only)
          Markør bak paviljongen. Passiv første minutt, svarer på direkte tiltale.

        # DESIGN-009: a roleplay PORTRAYS a station-owned person (personRef).
        # Nested under the station → stationIndex is derived from ownership.
        # Identity is inherited from the person unless a field is overridden here.
        roleplays:
          - personRef: magnus
            # age: 7          # example: an override; omit to inherit from person
            behavior: |
              Gjemmer seg bak paviljongen, svarer ikke på rop.
            # actor casting is PII (the roster layer) — never in the source.

      - name: "Økt selvmordsfare"
        position: { lat: 59.099762, lng: 10.403759 }
        situation: |
          Tonje Bakken (17) – ledelinjesøk ut til R50.
        director_notes: |
          2–3 markører. Vurder realistisk respons ved kontakt.
```

---

## 2. Authored vs derived

Verified against the real `.drill`: `schedule`, `endTime`, `index` and
`contentHash` are all present in the artifact and are pure functions of authored
fields.

| Field in `.drill` | Source | Why |
|---|---|---|
| `plan.name`, `description`, `tags`, `languageCode`, number formats | **authored** | Content / choice |
| `variables[]` (value, hint); `variableOverrides{}` on exercise/station | **authored** | DESIGN-008 |
| `exercise.name`, `startTime`, `numberOfTeams`, `numberOfRounds`, `*Time` | **authored** | Intent |
| `station.name`, `position`, markdown fields | **authored** | Content |
| `station.locations[]`, `station.persons[]` | **authored** | DESIGN-009 scenario data |
| `roleplay.personRef`, `behavior`, `background`, `propsMd`, identity overrides | **authored** | Content |
| `exercise.schedule[]`, `exercise.endTime` | derived | `startTime` + `rounds` + `*Time` |
| `exercise.index`, `station.index`, `roleplay.index` | derived | ordering |
| `roleplay.stationIndex` | derived | the station it is nested under (DESIGN-009) |
| roleplay effective identity (denormalized `name`/`age`/…) | derived | person + overrides (DESIGN-009) |
| station/exercise labels ("2.1", "#2") | derived | number format + index |
| all `uuid`; `source`; `contentHash` | derived | generated/preserved at build/publish |
| feed metadata (mapCenter, exerciseCount, place) | derived | at publish |
| `{{station.loc.lkp.utm}}` in text | derived | from the location's coordinate at render |

---

## 3. Decided

Settled during the design dialogue.

1. **Single file, YAML + inline block scalars.** An LLM emits one coherent
   document; a single string is a clean MCP contract. The directory form already
   exists — it is the unzipped `.drill`. Markdown inline (item 2 folds in here):
   block-scalar content is literal, so markdown `#`/`-`/`:` need no escaping.
2. **Mirror model field names, reshape values only.** Names match the Dart model
   1:1 (`startTime`, `numberOfTeams`, `position`); only value shapes are
   source-friendly. Keeps schema, builder and decompile on one vocabulary. The
   format is agent-oriented, so verbosity costs nothing.
3. **Position as `{lat, lng}`.** `.drill` stores `[lng, lat]`; the builder flips
   it. Kills the swap bug at the source.
4. **References by array position; roleplays nested under the station.** Stations
   have no uuid (identity = `(exerciseUuid, index)`). A roleplay portrays a
   station-owned person (`personRef`) and nests under that station, so its
   `stationIndex` is fully derived. Broader descendant addressing (a plan-intro
   pointing at "post 2's location") is **DESIGN-008 open question 4**, unresolved
   in the app itself — the source format must not get ahead of it.
5. **Numbering out of names.** The real plan has `stationNumberFormat: dotted`
   yet names still carry an alpha prefix ("2a) Fisker") — an inconsistent baked-in
   label. The source holds a clean name; the label is derived; decompile strips
   the prefix (alpha and dotted) robustly.
6. **Structured markdown fields.** The source uses `situation`, `mission`,
   `director_notes`, … Decompiling a legacy plan (all content in one
   `description`) puts it into `situation` as the best guess.
7. **UTM via a location token.** DESIGN-009 puts coordinates on station-owned
   `locations` with a `.utm` facet. Generated plans reference
   `{{station.loc.<slug>.utm}}` so the coordinate lives once and prose stays in
   sync. The administrative `position` stays text-free. Decompile keeps existing
   literal UTM text as-is (no reverse-tokenizing).
8. **Effective identity by inheritance.** A roleplay inherits the person's
   identity; the source expresses an override by *including* the field and
   inheritance by *omitting* it. The builder denormalizes the effective value
   onto the roleplay (DESIGN-009 / ADR-0047), so a reader never sees a blank
   marker.
9. **Actor/PII on decompile.** `personRef` and `persons` are publishable (no PII)
   and resolve fine. Only the `Actor` (the real human) is stripped at publish, and
   effective identity is denormalized, so decompile just drops the actor casting —
   nothing dangles.

---

## 4. Still open

1. **Station-owned locations duplicate shared points.** DESIGN-009 chose
   station-owned data over a central registry (roll-up deferred, open question 3
   there). A point every station references — an IPP for the whole exercise —
   would be declared once per station in the source. Watch for authoring pain; a
   future exercise-level shared-location surface may be wanted.
2. **Sequencing.** The source-format compiler targets DESIGN-008 (stable) and
   should wait for DESIGN-009 stage 1 (model + format) to land, so it does not
   compile against a moving model.
3. **Which markdown fields are effectively required** for a usable brief
   (`situation`? `mission`?) — a generation/validation guideline for the skill,
   not a format rule.
```
