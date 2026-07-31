/// The localized strings the brief layer needs, as a plain-Dart interface.
///
/// This is the ADR-0048 amendment DESIGN-014 specifies. `field_resolver.dart`,
/// `brief_renderer.dart` and `utils/exercise_share_format.dart` all took an
/// `AppLocalizations`, which is a Flutter type — so the resolver could not run
/// under `dart run` even though it never touched a widget. The resolver already
/// took `l10n` as an explicit parameter rather than reaching through a
/// `BuildContext`, so only the *type* leaked Flutter; inverting the dependency is
/// the whole fix.
///
/// **Member names deliberately match `AppLocalizations`.** That is not laziness:
/// it means the bodies of the three files above did not change at all when their
/// parameter type did, so the refactor could not silently alter a rendered brief.
/// The two implementations are [AppBriefLabels] (wrapping `AppLocalizations`,
/// used by the app) and [HeadlessBriefLabels] (reading the baked-in ARB subset,
/// used by the CLI).
///
/// Free of `package:flutter/*` (AGENTS.md rule 7).
library;

import 'package:ringdrill/l10n/headless_labels.dart';

/// Localized strings for rendering a brief.
///
/// Adding a member here means adding it to both implementations *and* to
/// `headlessKeys` in `tools/generate_headless_labels.dart`; the analyzer catches
/// the first, and `test/l10n/headless_labels_sync_test.dart` the second.
abstract class BriefLabels {
  /// The language actually in use, as a locale name. Selects the brief template
  /// (`template_registry.dart`) and formats numbers and durations.
  String get localeName;

  // Field resolution (field_resolver.dart).
  String get variableDurationHourUnit;
  String briefUnknownVariable(String name);
  String briefUnknownReference(String name);

  // Brief rendering (brief_renderer.dart).
  String get briefStationNoPosition;
  String get briefRingRoute;
  String get rotationShareTitle;
  String get rotationShareLegendPhases;

  /// The three phase names, as the round table's column headers. The pipe-joined
  /// [rotationShareLegendPhases] is the one-line form for prose; a table wants
  /// them one per column.
  String get execution;
  String get evaluation;
  String get rotation;
  String round(int count);

  // The rotation share block (exercise_share_format.dart).
  String get briefPerStation;
  String get rotationShareEachRound;
  String get rotationShareReturn;
  String get rotationShareNext;
  String team(int count);
  String station(int count);
  String hour(int count);
  String shareNoteRevisits(int rounds, int stations);
  String shareNoteUnderCoverage(int rounds, int stations);
}

/// [BriefLabels] served from the baked-in ARB subset, without Flutter.
///
/// Used by the CLI's `render`. Takes a plan's `metadata.languageCode` so a brief
/// renders in the plan's own content language (ADR-0007 addendum) rather than the
/// host machine's locale — a rendered brief must not depend on who rendered it.
class HeadlessBriefLabels implements BriefLabels {
  HeadlessBriefLabels({String? languageCode})
    : _labels = HeadlessLabels(languageCode: languageCode);

  HeadlessBriefLabels.from(this._labels);

  final HeadlessLabels _labels;

  @override
  String get localeName => _labels.localeName;

  @override
  String get variableDurationHourUnit =>
      _labels.message('variableDurationHourUnit');

  @override
  String briefUnknownVariable(String name) =>
      _labels.message('briefUnknownVariable', args: {'name': name});

  @override
  String briefUnknownReference(String name) =>
      _labels.message('briefUnknownReference', args: {'name': name});

  @override
  String get briefStationNoPosition =>
      _labels.message('briefStationNoPosition');

  @override
  String get briefRingRoute => _labels.message('briefRingRoute');

  @override
  String get rotationShareTitle => _labels.message('rotationShareTitle');

  @override
  String get rotationShareLegendPhases =>
      _labels.message('rotationShareLegendPhases');

  @override
  String get execution => _labels.message('execution');

  @override
  String get evaluation => _labels.message('evaluation');

  @override
  String get rotation => _labels.message('rotation');

  @override
  String round(int count) => _labels.plural('round', count);

  @override
  String get briefPerStation => _labels.message('briefPerStation');

  @override
  String get rotationShareEachRound =>
      _labels.message('rotationShareEachRound');

  @override
  String get rotationShareReturn => _labels.message('rotationShareReturn');

  @override
  String get rotationShareNext => _labels.message('rotationShareNext');

  @override
  String team(int count) => _labels.plural('team', count);

  @override
  String station(int count) => _labels.plural('station', count);

  @override
  String hour(int count) => _labels.plural('hour', count);

  @override
  String shareNoteRevisits(int rounds, int stations) => _labels.message(
    'shareNoteRevisits',
    args: {'rounds': rounds, 'stations': stations},
  );

  @override
  String shareNoteUnderCoverage(int rounds, int stations) => _labels.message(
    'shareNoteUnderCoverage',
    args: {'rounds': rounds, 'stations': stations},
  );
}
