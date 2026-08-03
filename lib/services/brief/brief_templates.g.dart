// GENERATED FILE — DO NOT EDIT.
//
// Regenerate with: dart run tools/generate_brief_templates.dart
// Source: assets/templates/*.mustache
//
// See tools/generate_brief_templates.dart for why the templates
// are baked in rather than loaded from the asset bundle.

/// Brief template sources, keyed by their asset path.
///
/// The key is [BriefTemplate.assetPath], so the app and the CLI
/// look a template up by exactly the same identifier.
const briefTemplateSources = <String, String>{
  'assets/templates/ringdrill-standard-v1.en.md.mustache': r'''
{{^isSingleExercise}}
# {{plan.name}}

{{#plan.description}}_{{plan.description}}_

{{/plan.description}}
{{#if_in_doc_toc}}
## Table of contents

{{#exercises}}- [{{name}}](#{{exerciseAnchor}})
{{#stations}}  - [{{stationCode}} – {{name}}{{#variantSuffix}} – {{variantSuffix}}{{/variantSuffix}}](#{{stationAnchor}})
{{/stations}}{{/exercises}}

{{/if_in_doc_toc}}
{{#plan.briefIntroMd}}
## General notes on play and exercise control

{{{plan.briefIntroMd}}}

{{/plan.briefIntroMd}}
{{#plan.commsMd}}
## Talk groups

{{{plan.commsMd}}}

{{/plan.commsMd}}
---

{{/isSingleExercise}}
{{#exercises}}
## {{name}}

#### Time
{{exerciseTimeLabel}}

#### Duration
{{exerciseDurationLabel}}

{{#methodMd}}
#### Method
{{{methodMd}}}

{{/methodMd}}
{{#learningGoalsMd}}
#### Learning goals
{{{learningGoalsMd}}}

{{/learningGoalsMd}}
{{#trainingFocusMd}}
#### Training focus
{{{trainingFocusMd}}}

{{/trainingFocusMd}}
#### Organisation
{{{organisationBlock}}}

{{#orderFormatMd}}
#### Order format
{{{orderFormatMd}}}

{{/orderFormatMd}}
{{#executionTipsMd}}
#### Execution tips
{{{executionTipsMd}}}

{{/executionTipsMd}}
{{#effectiveCommsMd}}
#### Comms
{{{effectiveCommsMd}}}

{{/effectiveCommsMd}}

{{#stations}}
### {{stationCode}} – {{name}}{{#variantSuffix}} – {{variantSuffix}}{{/variantSuffix}}

{{#descriptionMd}}
{{{descriptionMd}}}

{{/descriptionMd}}
**Station {{stationCode}} location:** {{{positionValue}}}

#### Duration
{{stationDurationLabel}}

{{#equipmentMd}}
#### Equipment
{{{equipmentMd}}}

{{/equipmentMd}}
{{#roleplays}}
#### Role-play ({{name}})
{{{behavior}}}
{{#propsMd}}
**Props:** {{{propsMd}}}
{{/propsMd}}
{{#actor}}
**Actor:** {{realName}}{{#phone}} {{{phone}}}{{/phone}}
{{/actor}}

{{/roleplays}}
{{#situationMd}}
#### Situation
{{{situationMd}}}

{{/situationMd}}
{{#missionMd}}
#### Mission
{{{missionMd}}}

{{/missionMd}}
{{#effectiveCommsMd}}
#### Comms
{{{effectiveCommsMd}}}

{{/effectiveCommsMd}}
{{#logisticsMd}}
#### Administration and supplies
{{{logisticsMd}}}

{{/logisticsMd}}
{{#criticalQuestionsMd}}
#### Critical questions
{{{criticalQuestionsMd}}}

{{/criticalQuestionsMd}}
{{#leaderAnswersMd}}
#### Suggested answers to team leader questions
{{{leaderAnswersMd}}}

{{/leaderAnswersMd}}
{{#directorNotesMd}}
> **Notes for instructor/exercise control**
>
{{{directorNotesMd}}}

{{/directorNotesMd}}
---

{{/stations}}
{{/exercises}}
''',
  'assets/templates/ringdrill-standard-v1.nb.md.mustache': r'''
{{^isSingleExercise}}
# {{plan.name}}

{{#plan.description}}_{{plan.description}}_

{{/plan.description}}
{{#if_in_doc_toc}}
## Innholdsfortegnelse

{{#exercises}}- [{{name}}](#{{exerciseAnchor}})
{{#stations}}  - [{{stationCode}} – {{name}}{{#variantSuffix}} – {{variantSuffix}}{{/variantSuffix}}](#{{stationAnchor}})
{{/stations}}{{/exercises}}

{{/if_in_doc_toc}}
{{#plan.briefIntroMd}}
## Generelt om spill og øvingsledelse

{{{plan.briefIntroMd}}}

{{/plan.briefIntroMd}}
{{#plan.commsMd}}
## Talegrupper

{{{plan.commsMd}}}

{{/plan.commsMd}}
---

{{/isSingleExercise}}
{{#exercises}}
## {{name}}

#### Tid
{{exerciseTimeLabel}}

#### Varighet
{{exerciseDurationLabel}}

{{#methodMd}}
#### Metode
{{{methodMd}}}

{{/methodMd}}
{{#learningGoalsMd}}
#### Læringsmål
{{{learningGoalsMd}}}

{{/learningGoalsMd}}
{{#trainingFocusMd}}
#### Øvingsmomenter
{{{trainingFocusMd}}}

{{/trainingFocusMd}}
#### Organisering
{{{organisationBlock}}}

{{#orderFormatMd}}
#### Ordreformat
{{{orderFormatMd}}}

{{/orderFormatMd}}
{{#executionTipsMd}}
#### Tips til gjennomføring
{{{executionTipsMd}}}

{{/executionTipsMd}}
{{#effectiveCommsMd}}
#### Samband
{{{effectiveCommsMd}}}

{{/effectiveCommsMd}}

{{#stations}}
### {{stationCode}} – {{name}}{{#variantSuffix}} – {{variantSuffix}}{{/variantSuffix}}

{{#descriptionMd}}
{{{descriptionMd}}}

{{/descriptionMd}}
**Post {{stationCode}} plassering:** {{{positionValue}}}

#### Varighet
{{stationDurationLabel}}

{{#equipmentMd}}
#### Utstyrsbehov
{{{equipmentMd}}}

{{/equipmentMd}}
{{#roleplays}}
#### Markørspill ({{name}})
{{{behavior}}}
{{#propsMd}}
**Rekvisita:** {{{propsMd}}}
{{/propsMd}}
{{#actor}}
**Markør:** {{realName}}{{#phone}} {{{phone}}}{{/phone}}
{{/actor}}

{{/roleplays}}
{{#situationMd}}
#### Situasjon
{{{situationMd}}}

{{/situationMd}}
{{#missionMd}}
#### Oppdrag
{{{missionMd}}}

{{/missionMd}}
{{#effectiveCommsMd}}
#### Samband
{{{effectiveCommsMd}}}

{{/effectiveCommsMd}}
{{#logisticsMd}}
#### Administrasjon og forsyninger
{{{logisticsMd}}}

{{/logisticsMd}}
{{#criticalQuestionsMd}}
#### Kritiske spørsmål
{{{criticalQuestionsMd}}}

{{/criticalQuestionsMd}}
{{#leaderAnswersMd}}
#### Forslag til svar på spørsmål fra lagleder
{{{leaderAnswersMd}}}

{{/leaderAnswersMd}}
{{#directorNotesMd}}
> **Notater til instruktør/øvingsledelse**
>
{{{directorNotesMd}}}

{{/directorNotesMd}}
---

{{/stations}}
{{/exercises}}
''',
};
