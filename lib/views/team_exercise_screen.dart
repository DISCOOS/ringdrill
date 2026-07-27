import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/numbering.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/models/team.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/utils/plan_variables.dart';
import 'package:ringdrill/views/drill_player/drill_mini_player.dart';
import 'package:ringdrill/views/drill_player/player_mode.dart';
import 'package:ringdrill/views/shell/master_detail_leading.dart';
import 'package:ringdrill/views/shell/master_detail_scope.dart';
import 'package:ringdrill/views/shell/open_form_surface.dart';
import 'package:ringdrill/views/team_form_screen.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';
import 'package:ringdrill/views/widgets/exercise_scope.dart';
import 'package:ringdrill/views/widgets/player_status_card.dart';
import 'package:ringdrill/views/widgets/schedule_card.dart';
import 'package:ringdrill/views/widgets/schedule_table.dart';
import 'package:ringdrill/views/widgets/sheet_title.dart';

class TeamExerciseScreen extends StatefulWidget {
  const TeamExerciseScreen({
    super.key,
    required this.teamIndex,
    required this.exercise,
  });

  final int teamIndex;
  final Exercise exercise;

  @override
  State<TeamExerciseScreen> createState() => _TeamExerciseScreenState();
}

class _TeamExerciseScreenState extends State<TeamExerciseScreen> {
  final _exerciseService = ExerciseService();
  final _planService = PlanService();

  int currentIndex = 0;

  @override
  void initState() {
    currentIndex = widget.teamIndex;
    super.initState();
  }

  /// The effective plan-variable map (ADR-0046) at [widget.exercise]'s
  /// scope. Empty when there is no active plan.
  Map<String, String> get _exerciseOverrides {
    final plan = _planService.activePlan;
    if (plan == null) return const {};
    return effectivePlanVariables(plan, exercise: widget.exercise);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final team = _planService.getTeam(widget.teamIndex);
    final teamLabel =
        team?.name ?? '${localizations.team(1)} ${widget.teamIndex + 1}';
    // The exercise level of the resolve cascade (ADR-0048), so `{{exercise.*}}`
    // resolves in this surface's own fields the way it does in the coordinator,
    // station and roleplay ones. Station scope is deliberately absent: a team
    // rotates through every post, so it has no single station — those tokens
    // legitimately stay literal here (docs/variables.md).
    return ExerciseScope(
      exercise: widget.exercise,
      variableOverrides: widget.exercise.variableOverrides,
      child: Scaffold(
        appBar: AppBar(
          leading: MasterDetailLeading(
            onClose: () {
              if (MasterDetailScope.maybeOf(context) != null) {
                ContextSheet.of(context).close();
              } else {
                Navigator.pop(context);
              }
            },
          ),
          toolbarHeight: 72,
          title: SheetTitle(
            primary: teamLabel,
            secondary: widget.exercise.name,
            secondaryOverrides: _exerciseOverrides,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit),
              padding: const EdgeInsets.all(8),
              onPressed: _exerciseService.isStarted ? null : _editTeam,
              tooltip: _exerciseService.isStarted
                  ? localizations.stopExerciseFirst(
                      substitutePlanVariables(
                        widget.exercise.name,
                        _exerciseOverrides,
                      ),
                    )
                  : localizations.editTeam,
            ),
          ],
          actionsPadding: const EdgeInsets.only(right: 16),
        ),
        body: SafeArea(
          child: StreamBuilder(
            stream: ExerciseService().events,
            initialData: _initialData(),
            builder: (context, asyncSnapshot) {
              final event = asyncSnapshot.data!;
              currentIndex = widget.exercise.stationIndex(
                widget.teamIndex,
                event.currentRound,
              );
              return Padding(
                padding: const EdgeInsets.all(kPlayerSurfaceHorizontalPadding),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Team Info
                    _buildTeamStatus(event),
                    const SizedBox(height: 8),
                    // Schedule Details — the shared schedule card, matching
                    // the Post/Spill viewers' Tidsplan/Når aktiv cards.
                    Expanded(child: _buildScheduleCard(event)),
                  ],
                ),
              );
            },
          ),
        ),
        // Mirror the CoordinatorScreen pattern: dock a DrillMiniPlayer for
        // the parent exercise so the user can start it from the team view
        // (modal context sheet in narrow). In master-detail (wide) the
        // docked bar lives in the master column instead.
        bottomNavigationBar: MasterDetailScope.maybeOf(context) == null
            ? DrillMiniPlayer(
                exercise: widget.exercise,
                height: 64,
                applyBottomInset: true,
                  onPlay: () {
                  unawaited(HapticFeedback.mediumImpact());
                  _exerciseService.start(widget.exercise);
                },
                mode: TeamPlayerMode(widget.teamIndex),
                // showOrReplace, not replace: this screen can be a plain pushed
                // route (a cold deep link) where the shell's controller exists but
                // was never opened, and replace asserts on that.
                onPickTarget: (target) => unawaited(
                  ContextSheet.of(context).showOrReplace(context, target),
                ),
              )
            : null,
      ),
    );
  }

  /// The shared [PlayerStatusCard] (DESIGN-010 follow-up: player-status-
  /// card). The team label lives in the sheet's AppBar
  /// (`SheetTitle.primary`), so this card only carries running-state info.
  /// Gated on `isStartedOn` (scoped to this exercise) so a different
  /// exercise running elsewhere never renders this team's card with
  /// foreign data.
  Widget _buildTeamStatus(ExerciseEvent event) {
    if (!_exerciseService.isStartedOn(widget.exercise.uuid)) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;
    return PlayerStatusCard(
      event: event,
      preStartSubline: l10n.statusPreStartSubline(
        widget.exercise.startTime.toString(),
        widget.exercise.numberOfRounds,
      ),
      leadingCell: _postAtRoundCell(l10n, event.currentRound, isNow: true),
      trailingCell: _nextPostCell(l10n, event),
    );
  }

  /// "Nå"/"Neste" post-the-team-is-at cell for [roundIndex], from
  /// `Exercise.stationIndex` — the same rotation math [_buildScheduleCard]
  /// reads. A team is always assigned a station every round, so — unlike
  /// the Post/Spill "team at post" cells — there is no "not active" case.
  PlayerStatusCell _postAtRoundCell(
    AppLocalizations l10n,
    int roundIndex, {
    required bool isNow,
    String? time,
  }) {
    final stationIndex = widget.exercise.stationIndex(
      widget.teamIndex,
      roundIndex,
    );
    final station = widget.exercise.stations[stationIndex];
    final plan = _planService.activePlan;
    final exerciseNumber = _planService.getExerciseNumber(widget.exercise.uuid);
    return PlayerStatusCell(
      icon: Icons.location_on,
      label: isNow ? l10n.statusNow : l10n.nextLabel,
      time: time,
      badge: Numbering.station(
        plan?.stationNumberFormat ?? StationNumberFormat.dotted,
        exerciseNumber: exerciseNumber < 1 ? 1 : exerciseNumber,
        stationIndex: stationIndex,
      ),
      value: plan == null
          ? station.name
          : substitutePlanVariables(
              station.name,
              effectivePlanVariables(
                plan,
                exercise: widget.exercise,
                station: station,
              ),
            ),
      isNow: isNow,
    );
  }

  /// The next round's post, falling back to [finishFallbackCell] once the
  /// current round is the last one (no further round to report).
  PlayerStatusCell? _nextPostCell(AppLocalizations l10n, ExerciseEvent event) {
    final nextRound = event.currentRound + 1;
    if (nextRound >= widget.exercise.numberOfRounds) {
      return finishFallbackCell(
        l10n,
        widget.exercise,
        icon: Icons.arrow_forward,
      );
    }
    return _postAtRoundCell(
      l10n,
      nextRound,
      isNow: false,
      time: widget.exercise.schedule[nextRound][0].toString(),
    );
  }

  Widget _buildScheduleCard(ExerciseEvent event) {
    final localizations = AppLocalizations.of(context)!;
    final plan = _planService.activePlan;
    final format = plan?.stationNumberFormat ?? StationNumberFormat.dotted;
    final exerciseNumber = () {
      final n = _planService.getExerciseNumber(widget.exercise.uuid);
      return n < 1 ? 1 : n;
    }();
    final rows = List.generate(widget.exercise.schedule.length, (index) {
      final stationIndex = widget.exercise.stationIndex(
        widget.teamIndex,
        index,
      );
      final station = widget.exercise.stations[stationIndex];
      // The formatted post number + name (Station.numberAndName), matching the
      // status card's badge + name above.
      final postLabel = station.numberAndName(
        format,
        exerciseNumber: exerciseNumber,
      );
      return ScheduleTableRow(
        roundIndex: index,
        label: plan == null
            ? postLabel
            : substitutePlanVariables(
                postLabel,
                effectivePlanVariables(
                  plan,
                  exercise: widget.exercise,
                  station: station,
                ),
              ),
        onTap: () => ContextSheet.of(context).replace(
          StationSheetTarget(
            exerciseUuid: widget.exercise.uuid,
            stationIndex: stationIndex,
          ),
        ),
      );
    });
    return SingleChildScrollView(
      child: ScheduleCard(
        sectionId: 'teamExerciseSchedule',
        title: localizations.stationTimingCardTitle,
        headerLabel: localizations.schedule,
        labelWidth: 78,
        event: event,
        exercise: widget.exercise,
        rows: rows,
      ),
    );
  }

  ExerciseEvent _initialData() {
    final last = ExerciseService().last;
    // Match the live exercise by `uuid`, not by full-object equality.
    // The `Exercise` held by the service is captured at `start()` time
    // and can differ field-for-field from the freshly-loaded instance
    // passed to this screen, so value equality misses the live event and
    // the status only corrects itself once the next stream event lands.
    // A `done` event is treated as "not live" so a stopped exercise
    // starts from `pending`, matching `TeamScreen`.
    if (last != null &&
        last.exercise.uuid == widget.exercise.uuid &&
        !last.isDone) {
      return last;
    }
    return ExerciseEvent.pending(widget.exercise);
  }

  Future<void> _editTeam() async {
    final localizations = AppLocalizations.of(context)!;
    final team = _planService.getTeam(widget.teamIndex);
    if (team == null) return;
    final updated = await openFormSurface<Team>(
      context,
      builder: (_) => TeamFormScreen(team: team),
    );
    // No mounted gate on the save: openFormSurface disposes this State when
    // it dismisses the hosting context sheet around the form push.
    if (updated == null) return;
    await _planService.saveTeam(localizations, updated);
    if (mounted) setState(() {});
  }
}
