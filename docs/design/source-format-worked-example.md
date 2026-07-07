# Source format — worked example

> **Status:** draft / discussion material. Not a DESIGN issue yet.
> **Purpose:** make the source format concrete against one real plan before we
> write the spec.
> **Anchor:** the published catalog plan `lsor-eidene-2026.drill`
> ("LSOR Eidene 2026", schema 1.2, 7 exercises, 4 teams, 1 roleplay). The
> example below is exercise **#2 Eidene** with 6 stations.

The source format (NO: *kildeformat*) is what a person or an agent **writes**.
The builder compiles it to `.drill` (the build artifact) and fills in everything
that can be **derived**. `decompile` goes the other way. The round-trip contract
is that `build(decompile(d))` yields the same `contentHash` as `d`.

Guiding principle: **authored fields only, never derived ones.** If a value can
be computed from something else, it does not belong here.

---

## 1. The example

One document: YAML for structure, markdown in block scalars (`|`) for brief
content. A single file is easy for an LLM to produce in full.

Example data (station names, descriptions) stays in Norwegian because the plan
itself is a real Norwegian SAR plan. Only the format prose and comments are
English.

```yaml
plan:
  name: "LSOR Eidene 2026"
  language: nb
  numbering:
    exercises: hash        # #1, #2 …   (label is derived, never written into names)
    stations: dotted       # 2.1, 2.2 …
  tags: [søk og redning, lagledelse, lsor]
  description: |
    KUN FOR STAB. Øvingsplan 2026 for kurset Lagledelse søk og redning på
    Eidene (Røde Kors Hjelpekorps Vestfold). Syv øvelser fredag–søndag,
    hovedsakelig ringøvelser med 4 lag.

  # Author-defined variables, referenced as {{var.name}} anywhere.
  # (Illustrates the variable layer — this plan has no variables today.)
  variables:
    talegruppe: { value: "RK-VFOLD-ØV2 / DMO-ANDRE-1", hint: "Talkgroup for the exercise" }

exercises:
  - name: "Førsteinnsats søk (ringøvelse)"   # not "#2 " — that is a derived label
    start: "09:45"
    teams: 4
    rounds: 6
    timing:                # minutes
      execution: 15
      evaluation: 10
      rotation: 5
    # schedule[] and endTime (12:45) are DERIVED from start + rounds + timing.

    stations:
      # In the real plan all content sits in a single field (description). On
      # decompile it goes into `situation` as the best guess. The "2a)" label
      # currently lives in the name, but should be derived from numbering —
      # see item 5.
      - name: "Fisker (Angler)"
        at: { lat: 59.09789, lng: 10.402513 }   # explicit lat/lng, not GeoJSON order
        situation: |
          Kari Fiskeløs – finsøk rundt IPP innenfor R25.
          Post {{station.position.utm}}.          # UTM derived from `at`

      - name: "Bilcamping"
        at: { lat: 59.09814, lng: 10.404234 }
        situation: |
          Hermod Hess (tysk) – finsøk fra bobil ut til R25. Post {{station.position.utm}}.

      - name: "Løper"
        at: { lat: 59.098841, lng: 10.40428 }
        situation: |
          Ine Vigerdal (42) – søk treningsløype. Post {{station.position.utm}} (start på løpeløype).

      # Richer form: shows how the blob can be split into structured fields.
      - name: "Økt selvmordsfare"
        at: { lat: 59.099762, lng: 10.403759 }
        situation: |
          Tonje Bakken (17) – ledelinjesøk ut til R50. Post {{station.position.utm}}.
        director_notes: |     # → directorNotesMd (instructor/director only)
          2–3 markører. Vurder realistisk respons ved kontakt.

      - name: "Mental sykdom"
        at: { lat: 59.098473, lng: 10.400913 }
        situation: |
          Jan Guttormsen (54) – ledelinjesøk NØ ut fra IPP (Tjøme Sykehjem). Post {{station.position.utm}}.

      - name: "Barn 4-6 år"
        at: { lat: 59.096857, lng: 10.401633 }
        situation: |
          Magnus Damslet (6) – grovsøk R25 fra IPP. Post {{station.position.utm}}. Markør bak paviljongen.

# Roleplays live at plan level with a reference to exercise + station.
# (The real plan has one: "Tiril", age 11, on exercise #1.)
roleplays:
  - role: "Tiril"
    age: 11
    exercise: "Søk og redning (ringøvelse)"   # reference by exercise name
    at_station: "…"                            # station name within that exercise
    # actor: PII, local, never published. See item 9.
```

---

## 2. Authored vs derived

Verified against the real `.drill`: `schedule`, `endTime`, `index` and
`contentHash` are all present in the artifact, and all are pure functions of
authored fields.

| Field in `.drill` | Source | Why |
|---|---|---|
| `plan.name`, `description`, `tags`, `languageCode` | **authored** | Content |
| `exerciseNumberFormat`, `stationNumberFormat` | **authored** | Choice |
| `variables[]` (value, hint) | **authored** | Author's tokens |
| `exercise.name`, `startTime`, `numberOfTeams`, `numberOfRounds`, `*Time` | **authored** | Intent |
| `station.name`, `position`, `description`/markdown fields | **authored** | Content |
| `roleplay.name`, `age`, `signalement`, markdown | **authored** | Content |
| `exercise.schedule[]` | derived | `startTime` + `rounds` + `*Time` |
| `exercise.endTime` | derived | same |
| `exercise.index`, `station.index`, `roleplay.index` | derived | ordering |
| station label "2.1", exercise label "#2" | derived | numbering + index |
| all `uuid` | derived | generated/preserved by the builder |
| `contentHash` | derived | SHA256 over content at build |
| `source` (catalog/slug/etag) | derived | set at install/publish |
| feed metadata (mapCenter, exerciseCount, place) | derived | at publish |
| `{{station.position.utm}}` in text | derived | from `position` at render |

---

## 3. Design decisions the example forces

These must be settled in the DESIGN issue itself. The real plan made several of
them concrete — items 5, 6 and 9 are actual findings, not hypotheses.

1. **Single file vs. directory.** The example is one file with inline markdown.
   Works for an LLM. Large plans with a lot of brief text can get heavy.
   Alternative: a directory with `plan.yaml` + `.md` bodies, mirroring `.drill`
   more closely. Leaning toward a single file for generation, directory as a
   possible export variant.

2. **Markdown inline vs. referenced.** Inline (block scalar) is readable and
   self-contained. A reference (`situation: ./stations/fisker.md`) scales better
   but scatters the content. Tied to item 1.

3. **Position: lat/lng vs. GeoJSON.** `.drill` stores `[lng, lat]`. The source
   should use explicit `{ lat, lng }` to kill the swap bug. The builder flips it.

4. **References by name vs. index/uuid.** Stations have no uuid (identity =
   `(exerciseUuid, index)`). The source should reference by name, since index is
   derived. Requires unique names within an exercise, or a tie-break rule.

5. **Numbering out of names — confirmed problem.** The real plan has
   `stationNumberFormat: dotted`, yet the station names still contain an *alpha*
   prefix ("2a) Fisker (Angler)"). So an embedded, inconsistent prefix. The
   source must hold a clean name ("Fisker (Angler)"); the label is derived. On
   `decompile` the prefix (both alpha and dotted) must be stripped robustly.

6. **Markdown field model — confirmed.** The real plan has no `.md` files; all
   content sits in the station `description`. The source should use the
   structured fields (`situation`, `mission`, `equipment`, `comms`,
   `director_notes` …), and `decompile` puts `description` into `situation` as
   the best guess.

7. **UTM: token vs. text.** The real plan duplicates the position as UTM text in
   prose. With `{{station.position.utm}}` it is derived from `at`. Should the
   token be the default in generated plans?

8. **Short field names.** `at`/`start`/`teams`/`rounds`/`timing` are
   LLM-friendly but diverge from the Dart names (`position`, `startTime`,
   `numberOfTeams` …). Either a deliberate mapping in the builder, or let the
   source mirror the model names 1:1. Trade-off between readability and a simple
   compiler.

9. **Actor/PII on decompile — confirmed.** The roleplay "Tiril" has an
   `actorUuid`, but the `actors/` folder is stripped at publish (ADR-0018). So
   decompiling a published plan yields a dangling actor reference. The source
   should drop the actor link on decompile of published plans, or represent it as
   an empty placeholder the author fills in locally.
```
