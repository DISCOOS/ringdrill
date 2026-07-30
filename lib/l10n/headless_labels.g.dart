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
    'round': <String, String>{'=0': 'Round', '=1': 'Round', 'other': 'Rounds'},
    'briefRingRoute': 'Ring route',
    'briefStationNoPosition': 'no position',
    'briefUnknownReference': '‹missing reference: {name}›',
    'briefUnknownVariable': '‹missing variable: {name}›',
    'rotationShareLegendPhases': 'drill | eval | roll / inbound',
    'rotationShareTitle': 'Rotation (time of day)',
    'variableDurationHourUnit': 'h',
  },
  'nb': {
    'team': <String, String>{'=0': 'Lag', 'other': 'Lag'},
    'station': <String, String>{'=0': 'Post', '=1': 'Post', 'other': 'Poster'},
    'round': <String, String>{'=0': 'Runde', '=1': 'Runde', 'other': 'Runder'},
    'briefRingRoute': 'Ringløype',
    'briefStationNoPosition': 'ingen posisjon',
    'briefUnknownReference': '‹mangler referanse: {name}›',
    'briefUnknownVariable': '‹mangler variabel: {name}›',
    'rotationShareLegendPhases': 'øve | eval | rull / retur',
    'rotationShareTitle': 'Rullering (klokkeslett)',
    'variableDurationHourUnit': 't',
  },
};
