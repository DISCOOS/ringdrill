import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/app_user_role.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/utils/plan_variables.dart';
import 'package:ringdrill/views/widgets/rollup.dart';

class StationDescriptionCard extends StatelessWidget {
  const StationDescriptionCard({
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
  /// Null disables tap-to-edit entirely (every block renders without an
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
    final overrides = _overridesFor();
    return RollupCard(
      sectionId: 'description',
      icon: Icons.description,
      title: l10n.postDescriptionCardTitle,
      sections: [
        RollupSection(
          id: 'description',
          text: station.description,
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
      ],
      onTapSection: onTapSection,
    );
  }
}
