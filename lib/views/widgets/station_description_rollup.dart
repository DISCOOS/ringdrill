import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/app_user_role.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/utils/plan_variables.dart';
import 'package:ringdrill/views/widgets/rollup.dart';

/// The station's descriptive sections, in the order the brief presents them:
/// the plain `description` lead (no heading of its own), then the labeled
/// markdown sections, then the director-gated planning note.
///
/// Shared by [StationDescriptionRollup] (bare, inside the Poster list's
/// expanded tile) and `StationDescriptionCard` (chromed, the Post viewer's
/// first card) — the two used to hand-roll the same list side by side, which is
/// exactly how the mandatory mark below would end up on one surface and not the
/// other. Mirrors `exerciseDescriptionSections`.
///
/// `description` carries a [RollupSection.mandatoryLabel]: it is the lead a
/// reader starts from, and the one section the editor's own
/// `stationAddDescriptionAction` invites first. Still optional in the model —
/// see that field's doc. `directorNotesMd` is the mockup's "Notat til
/// øvelsesleder", included only when [role] is the director.
List<RollupSection> stationDescriptionSections(
  AppLocalizations l10n,
  Station station,
  StaffRole role,
  Map<String, String> overrides,
) => [
  RollupSection(
    id: 'description',
    text: station.description,
    mandatoryLabel: l10n.stationDescription,
    overrides: overrides,
  ),
  RollupSection(
    id: 'situation',
    label: l10n.briefSectionStationSituation,
    text: station.situationMd,
    overrides: overrides,
  ),
  RollupSection(
    id: 'mission',
    label: l10n.briefSectionStationMission,
    text: station.missionMd,
    overrides: overrides,
  ),
  RollupSection(
    id: 'logistics',
    label: l10n.briefSectionStationLogistics,
    text: station.logisticsMd,
    overrides: overrides,
  ),
  RollupSection(
    id: 'equipment',
    label: l10n.briefSectionStationEquipment,
    text: station.equipmentMd,
    overrides: overrides,
  ),
  RollupSection(
    id: 'criticalQuestions',
    label: l10n.briefSectionStationCriticalQuestions,
    text: station.criticalQuestionsMd,
    overrides: overrides,
  ),
  RollupSection(
    id: 'leaderAnswers',
    label: l10n.briefSectionStationLeaderAnswers,
    text: station.leaderAnswersMd,
    overrides: overrides,
  ),
  if (role == StaffRole.director)
    RollupSection(
      id: 'directorNotes',
      label: l10n.briefSectionStationDirectorNotes,
      text: station.directorNotesMd,
      overrides: overrides,
      gated: true,
    ),
];

/// The teaching copy both station-description surfaces show when the post has
/// nothing written at all — shared for the same reason
/// [stationDescriptionSections] is.
RollupTeaching stationDescriptionTeaching(AppLocalizations l10n) =>
    RollupTeaching(
      title: l10n.stationDescriptionEmptyTitle,
      body: l10n.stationDescriptionEmptyBody,
      actionLabel: l10n.descriptionAddAction,
    );

class StationDescriptionRollup extends StatelessWidget {
  const StationDescriptionRollup({
    super.key,
    required this.exercise,
    required this.station,
    required this.role,
    this.onTapSection,
  });

  final Exercise exercise;
  final Station station;
  final StaffRole role;

  /// Called with a section's (or the lead's) id when its block is tapped.
  /// Null disables taps entirely (every block renders without an
  /// `InkWell`).
  final ValueChanged<String>? onTapSection;

  /// The effective plan-variable map (ADR-0046) at [exercise]'s scope,
  /// optionally narrowed to [station]'s — the active plan's declared
  /// values overlaid by [exercise]'s overrides, then [station]'s. Empty
  /// when there is no active plan (defense-in-depth; this screen only
  /// ever renders inside one).
  Map<String, String> _overridesFor() {
    final plan = PlanService().activePlan;
    if (plan == null) return const {};
    return effectivePlanVariables(plan, exercise: exercise, station: station);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Rollup(
      sections: stationDescriptionSections(
        l10n,
        station,
        role,
        _overridesFor(),
      ),
      teaching: stationDescriptionTeaching(l10n),
      onTapSection: onTapSection,
    );
  }
}
