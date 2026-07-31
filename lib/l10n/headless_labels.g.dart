// GENERATED FILE — DO NOT EDIT.
//
// Regenerate with: dart run tools/generate_headless_labels.dart
// Source: lib/l10n/app_en.arb, lib/l10n/app_nb.arb
//
// See tools/generate_headless_labels.dart for why the headless
// label provider bakes these in instead of reading the ARB at
// runtime, and lib/l10n/headless_labels.dart for the reader.

/// ARB messages the headless label provider serves, by locale.
///
/// A plain message is a `String`. An ICU plural is a
/// `Map<String, String>` keyed by its arms (`=0`, `=1`, `one`,
/// `other`, …), already parsed so the reader only has to pick
/// one and substitute placeholders.
const headlessLabelMessages = <String, Map<String, Object>>{
  'en': {
    'team': <String, String>{'=0': 'Team', '=1': 'Team', 'other': 'Teams'},
    'station': <String, String>{
      '=0': 'Station',
      '=1': 'Station',
      'other': 'Stations',
    },
    'exercise': <String, String>{
      '=0': 'Exercise',
      '=1': 'Exercise',
      'other': 'Exercises',
    },
    'round': <String, String>{'=0': 'Round', '=1': 'Round', 'other': 'Rounds'},
    'briefRingRoute': 'Ring route',
    'briefStationNoPosition': 'no position',
    'briefUnknownReference': '‹missing reference: {name}›',
    'briefUnknownVariable': '‹missing variable: {name}›',
    'rotationShareLegendPhases': 'drill | eval | roll / inbound',
    'execution': 'Execution',
    'evaluation': 'Evaluation',
    'rotation': 'Rotation',
    'rotationShareTitle': 'Rotation (time of day)',
    'variableDurationHourUnit': 'h',
    'hour': <String, String>{
      '=0': 'now',
      '=1': '1 hour',
      'other': '{count} hours',
    },
    'briefPerStation': 'per station',
    'shareNoteRevisits':
        'Note: {rounds} rounds across {stations} stations means each team will revisit some stations.',
    'shareNoteUnderCoverage':
        'Note: {rounds} rounds across {stations} stations means each team will only visit some stations.',
    'rotationShareEachRound': 'Each round',
    'rotationShareReturn': 'return',
    'rotationShareNext': 'next',
  },
  'nb': {
    'team': <String, String>{'=0': 'Lag', 'other': 'Lag'},
    'station': <String, String>{'=0': 'Post', '=1': 'Post', 'other': 'Poster'},
    'exercise': <String, String>{
      '=0': 'Øvelse',
      '=1': 'Øvelse',
      'other': 'Øvelser',
    },
    'round': <String, String>{'=0': 'Runde', '=1': 'Runde', 'other': 'Runder'},
    'briefRingRoute': 'Ringløype',
    'briefStationNoPosition': 'ingen posisjon',
    'briefUnknownReference': '‹mangler referanse: {name}›',
    'briefUnknownVariable': '‹mangler variabel: {name}›',
    'rotationShareLegendPhases': 'øve | eval | rull / retur',
    'execution': 'Øving',
    'evaluation': 'Evaluering',
    'rotation': 'Rullering',
    'rotationShareTitle': 'Rullering (klokkeslett)',
    'variableDurationHourUnit': 't',
    'hour': <String, String>{
      '=0': 'nå',
      '=1': '1 time',
      'other': '{count} timer',
    },
    'briefPerStation': 'pr oppdrag',
    'shareNoteRevisits':
        'Merk: {rounds} runder på {stations} poster betyr at hvert lag besøker noen poster flere ganger.',
    'shareNoteUnderCoverage':
        'Merk: {rounds} runder på {stations} poster betyr at hvert lag bare besøker noen poster.',
    'rotationShareEachRound': 'Generelt hver runde',
    'rotationShareReturn': 'retur',
    'rotationShareNext': 'neste',
  },
};
