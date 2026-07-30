/// The app-side [BriefLabels], wrapping `AppLocalizations`.
///
/// Lives under `lib/views/` because that is where the Flutter dependency belongs
/// — the same placement rule the rest of the repo follows for l10n (see
/// `plan_variable_refs.dart`'s note about keeping `AppLocalizations` in the views
/// layer). Behaviour-preserving by construction: every member forwards to the
/// `AppLocalizations` member of the same name, so a brief rendered in the app
/// reads exactly as it did before the ADR-0048 amendment.
library;

import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/services/brief/brief_labels.dart';

class AppBriefLabels implements BriefLabels {
  const AppBriefLabels(this._l10n);

  final AppLocalizations _l10n;

  @override
  String get localeName => _l10n.localeName;

  @override
  String get variableDurationHourUnit => _l10n.variableDurationHourUnit;

  @override
  String briefUnknownVariable(String name) => _l10n.briefUnknownVariable(name);

  @override
  String briefUnknownReference(String name) =>
      _l10n.briefUnknownReference(name);

  @override
  String get briefStationNoPosition => _l10n.briefStationNoPosition;

  @override
  String get briefRingRoute => _l10n.briefRingRoute;

  @override
  String get rotationShareTitle => _l10n.rotationShareTitle;

  @override
  String get rotationShareLegendPhases => _l10n.rotationShareLegendPhases;

  @override
  String round(int count) => _l10n.round(count);

  @override
  String get briefPerStation => _l10n.briefPerStation;

  @override
  String get rotationShareEachRound => _l10n.rotationShareEachRound;

  @override
  String get rotationShareReturn => _l10n.rotationShareReturn;

  @override
  String get rotationShareNext => _l10n.rotationShareNext;

  @override
  String team(int count) => _l10n.team(count);

  @override
  String station(int count) => _l10n.station(count);

  @override
  String hour(int count) => _l10n.hour(count);

  @override
  String shareNoteRevisits(int rounds, int stations) =>
      _l10n.shareNoteRevisits(rounds, stations);

  @override
  String shareNoteUnderCoverage(int rounds, int stations) =>
      _l10n.shareNoteUnderCoverage(rounds, stations);
}

/// `l10n.brief` at a call site, so wiring the brief layer stays a one-word change.
extension AppLocalizationsBriefLabels on AppLocalizations {
  BriefLabels get brief => AppBriefLabels(this);
}
