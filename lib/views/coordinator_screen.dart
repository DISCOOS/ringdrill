import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/notification_service.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/utils/time_utils.dart';
import 'package:ringdrill/views/map_view.dart';
import 'package:ringdrill/views/phase_headers.dart';
import 'package:ringdrill/views/phase_tile.dart';
import 'package:ringdrill/views/position_widget.dart';
import 'package:ringdrill/views/team_station_widget.dart';
import 'package:ringdrill/views/vertical_divider_widget.dart';

import 'exercise_control_button.dart';
import 'exercise_form_screen.dart';

class CoordinatorScreen extends StatefulWidget {
  final String uuid;

  const CoordinatorScreen({super.key, required this.uuid});

  @override
  State<CoordinatorScreen> createState() => _CoordinatorScreenState();
}

/// Which list the coordinator is currently looking at. The two columns
/// (station rotations / team rotations) are mutually exclusive now, so the
/// coordinator picks one via a SegmentedButton at the top of the body.
enum _CoordinatorView { stations, teams }

class _CoordinatorScreenState extends State<CoordinatorScreen> {
  late bool _isStarted;

  final _programService = ProgramService();
  final _exerciseService = ExerciseService();
  final _subscriptions = <StreamSubscription>[];

  Exercise? _exercise;
  bool _promptShowNotification = false;
  _CoordinatorView _view = _CoordinatorView.stations;

  @override
  void initState() {
    _isStarted = _exerciseService.isStartedOn(widget.uuid);

    // Listen to ProgramService state changes
    _subscriptions.add(
      _programService.events.listen((event) {
        if (event.exercise?.uuid == widget.uuid) {
          if (mounted) {
            setState(() {
              _exercise = event.exercise;
            });
          }
        }
      }),
    );

    // Listen to ExerciseService state changes. The phase transition snackbar
    // that used to live here has been removed because the persistent
    // status-bar at the bottom of the screen already shows the same info
    // (round, phase, remaining time) more prominently and without dismissing
    // itself after a few seconds.
    _subscriptions.add(
      _exerciseService.events.listen((event) {
        if (mounted) {
          setState(() {
            _isStarted = event.isRunning || event.isPending;
          });
        }
      }),
    );

    // Listen to Notification Events
    _subscriptions.add(
      NotificationService().events
          .where((_) => _exercise != null)
          .where((e) => e.action == NotificationAction.promptReshow)
          .where((e) => e.exercise?.uuid == _exercise?.uuid)
          .listen((event) {
            if (mounted) {
              setState(() {
                _promptShowNotification = true;
              });
            }
          }),
    );

    super.initState();
  }

  @override
  void didChangeDependencies() {
    _exercise = _programService.getExercise(widget.uuid);
    assert(_exercise != null, 'Exercise with uuid [${widget.uuid}] not found');
    _isStarted = _exerciseService.isStartedOn(widget.uuid);
    super.didChangeDependencies();
  }

  /// Function to handle editing the exercise
  void _deleteExercise(BuildContext context) async {
    final localizations = AppLocalizations.of(context)!;
    final confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.confirm),
        content: Text(localizations.confirmDeleteExercise),
        actions: [
          // Cancel Button
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(false);
            },
            child: Text(localizations.cancel),
          ),
          // Delete Button
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.of(context).pop(true);
            },
            child: Text(
              localizations.delete,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (context.mounted && confirmed) {
      await _programService.deleteExercise(_exercise!.uuid);
      if (context.mounted) {
        Navigator.of(context).pop(false);
      }
    }
  }

  /// Function to handle editing the exercise
  void _editExercise(BuildContext context) async {
    final numberOfTeams = _programService.loadTeams().length;
    // Navigate to the edit exercise screen
    final newExercise = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExerciseFormScreen(
          exercise: _exercise,
          numberOfTeams: numberOfTeams == 0 ? null : numberOfTeams,
        ),
      ),
    );
    if (context.mounted && newExercise != null) {
      await _programService.saveExercise(
        AppLocalizations.of(context)!,
        newExercise,
      );
      setState(() {
        _exercise = newExercise;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return StreamBuilder(
      stream: _exerciseService.events,
      initialData: _exerciseService.last,
      builder: (context, asyncSnapshot) {
        final event =
            asyncSnapshot.data ??
            ExerciseEvent.pending(_programService.getExercise(widget.uuid)!);
        return Scaffold(
          appBar: AppBar(
            title: Text(
              _exercise!.name,
            ), // Dynamic title shows the exercise's name
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_on),
                padding: const EdgeInsets.all(8.0),
                onPressed: _promptShowNotification
                    ? () {
                        unawaited(NotificationService().initFromPrefs());
                        setState(() {
                          _promptShowNotification = false;
                        });
                      }
                    : null,
                tooltip: localizations.showNotification,
              ),

              // Delete Exercise Button
              IconButton(
                icon: const Icon(Icons.delete),
                padding: const EdgeInsets.all(8.0),
                onPressed: _isStarted ? null : () => _deleteExercise(context),
              ),

              // Edit Exercise Button
              IconButton(
                icon: const Icon(Icons.edit),
                padding: const EdgeInsets.all(8.0),
                onPressed: _isStarted ? null : () => _editExercise(context),
              ),
            ],
            actionsPadding: EdgeInsets.only(right: 16.0),
          ),
          body: SafeArea(
            child: _exercise!.schedule.isEmpty
                ? Center(child: Text(localizations.noRoundsScheduled))
                : _buildBody(event),
          ),
          floatingActionButton: ExerciseControlButton(
            exercise: _exercise!,
            service: _exerciseService,
            localizations: localizations,
          ),
          bottomNavigationBar: _buildExerciseStatus(event),
        );
      },
    );
  }

  Widget _buildBody(ExerciseEvent event) {
    final localizations = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: _buildRoundTable(event, true),
          ),
          const SizedBox(height: 8),
          Center(
            child: SegmentedButton<_CoordinatorView>(
              segments: [
                ButtonSegment<_CoordinatorView>(
                  value: _CoordinatorView.stations,
                  label: Text(
                    '${localizations.stationRotations}'
                    ' (${_exercise!.stations.length})',
                  ),
                  icon: const Icon(Icons.location_on),
                ),
                ButtonSegment<_CoordinatorView>(
                  value: _CoordinatorView.teams,
                  label: Text(
                    '${localizations.teamRotations}'
                    ' (${_exercise!.numberOfTeams})',
                  ),
                  icon: const Icon(Icons.group),
                ),
              ],
              selected: <_CoordinatorView>{_view},
              showSelectedIcon: false,
              onSelectionChanged: (selection) {
                setState(() => _view = selection.first);
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _view == _CoordinatorView.stations
                ? _buildStationList(event)
                : _buildTeamList(event),
          ),
        ],
      ),
    );
  }

  /// Compact live status row anchored to the bottom of the screen: round
  /// number, phase name and remaining time. Only built when the coordinator
  /// has actually pressed start on this exercise — the app is not
  /// date-driven, so "time until start" is not meaningful before the user
  /// activates the timer. Returns `null` when the bar should be hidden, so
  /// the Scaffold reclaims the bottom space entirely instead of reserving
  /// an empty strip.
  Widget? _buildExerciseStatus(ExerciseEvent event) {
    if (!_exerciseService.isStartedOn(widget.uuid)) return null;
    final localizations = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final roundLabel =
        '${localizations.round(1)} ${event.currentRound + 1}'
        ' · ${event.getState(localizations)}';
    final timeLabel = event.isPending
        ? DateTimeX.fromMinutes(event.remainingTime).formal(localizations)
        : localizations.minute(event.remainingTime);
    return Material(
      elevation: 4,
      color: colorScheme.primaryContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  roundLabel,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                timeLabel,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoundTable(ExerciseEvent event, bool isPortrait) {
    final localizations = AppLocalizations.of(context)!;
    return Container(
      padding: EdgeInsets.all(8.0),
      child: Column(
        children: [
          PhaseHeaders(
            titleWidth: 90,
            title: localizations.schedule,
            mainAxisAlignment: MainAxisAlignment.center,
          ),
          SizedBox(height: 8),
          ...List<Widget>.generate(_exercise!.schedule.length, (roundIndex) {
            // Determine whether this round is completed or current
            return PhaseTile(
              title:
                  "${AppLocalizations.of(context)!.round(1)} "
                  "${roundIndex + 1}",
              event: event,
              exercise: _exercise!,
              roundIndex: roundIndex,
              isPortrait: isPortrait,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStationList(ExerciseEvent event) {
    final localizations = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _exercise!.stations.length,
              itemBuilder: (context, stationIndex) {
                final station = _exercise!.stations[stationIndex];
                final colorScheme = Theme.of(context).colorScheme;
                // A station is "live" when the current round assigns a team to
                // it. Used to auto-expand the relevant row so the coordinator
                // sees the active station's detail without an extra tap, and
                // to highlight the card so the active station is recognisable
                // even when collapsed. Mirrors the live styling used in
                // TeamScreen._ExerciseSection.
                final isLive =
                    event.isRunning &&
                    _exercise!.teamIndex(stationIndex, event.currentRound) >= 0;
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(
                    vertical: 5,
                    horizontal: 2,
                  ),
                  clipBehavior: Clip.antiAlias,
                  color: isLive ? colorScheme.primaryContainer : null,
                  shape: isLive
                      ? RoundedRectangleBorder(
                          side: BorderSide(
                            color: colorScheme.primary,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        )
                      : null,
                  child: ExpansionTile(
                    // Do NOT use a PageStorageKey here: ExpansionTile would
                    // write a bool into the PageStorageBucket, and any
                    // SelectableText below (e.g. UtmWidget inside the
                    // station detail) reads from the same bucket-path for
                    // its scroll offset, casting the bool to double? and
                    // crashing at didChangeDependencies. Widget identity
                    // already keeps the expanded state stable across
                    // exercise-event rebuilds.
                    key: ValueKey<String>(
                      'coordinator-station-$stationIndex',
                    ),
                    initiallyExpanded: isLive,
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                    childrenPadding: EdgeInsets.zero,
                    iconColor: isLive ? colorScheme.primary : null,
                    collapsedIconColor: isLive ? colorScheme.primary : null,
                    textColor: isLive ? colorScheme.onPrimaryContainer : null,
                    collapsedTextColor: isLive
                        ? colorScheme.onPrimaryContainer
                        : null,
                    leading: isLive
                        ? Icon(
                            Icons.play_circle_fill,
                            color: colorScheme.primary,
                          )
                        : null,
                    title: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            station.name,
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: VerticalDividerWidget(),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            localizations.team(1),
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                        ...List<Widget>.generate(_exercise!.schedule.length, (
                          roundIndex,
                        ) {
                          final isCurrent =
                              event.isRunning &&
                              roundIndex == event.currentRound;
                          final teamIndex =
                              _exercise!.teamIndex(stationIndex, roundIndex) +
                              1;
                          final none = teamIndex == 0;
                          return Container(
                            padding: EdgeInsets.all(4),
                            color: isCurrent
                                ? none
                                      ? Colors.grey
                                      : Colors.blueAccent
                                : Colors.transparent,
                            child: Text(
                              '${none ? '×' : teamIndex}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: isCurrent
                                    ? FontWeight.bold
                                    : FontWeight
                                          .normal, // Emphasize current round
                                color: isCurrent ? Colors.white : null,
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                    children: [_buildStationDetail(stationIndex)],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Inline detail for a station row in the coordinator station list. Shown
  /// when the user expands the [ExpansionTile] for that station. Shows
  /// description and a static map thumbnail centred on the station's
  /// position. The round-by-round time table is intentionally NOT repeated
  /// here — that information already lives in the round table above the
  /// SegmentedButton.
  Widget _buildStationDetail(int stationIndex) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final station = _exercise!.stations[stationIndex];
    final description = station.description;
    final hasPosition = station.position != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (description != null && description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Text(description),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  hasPosition ? Icons.place : Icons.place_outlined,
                  color: hasPosition
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: hasPosition
                      ? PositionWidget(
                          wrapped: false,
                          format: PositionFormat.utm,
                          position: station.position,
                          style: theme.textTheme.bodyMedium,
                        )
                      : Text(
                          localizations.noLocation,
                          style: theme.textTheme.bodyMedium,
                        ),
                ),
              ],
            ),
          ),
          if (hasPosition)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 200,
                  // ValueKey gives each station its own MapView instance so
                  // expanding station A doesn't accidentally share map
                  // state with station B. PageStorageKey would collide
                  // with SelectableText scroll-state above — see the note
                  // on the ExpansionTile key further up.
                  child: MapView<int>(
                    key: ValueKey<String>(
                      'coordinator-station-map-$stationIndex',
                    ),
                    withCross: true,
                    initialZoom: 16,
                    initialCenter: station.position!,
                    layers: MapConfig.layers,
                    interactionFlags: MapConfig.static,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTeamList(ExerciseEvent event) {
    final localizations = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: ListView.builder(
              // Limit teams to number of teams
              itemCount: event.exercise.numberOfTeams,
              itemBuilder: (context, teamIndex) {
                // The team's current station, in plain text. Shown as the
                // ExpansionTile subtitle while the exercise is running so
                // the coordinator can read off where each team is without
                // scanning the rotation matrix column-by-column. The matrix
                // already highlights the current round, but the subtitle is
                // faster to read for exercises with many rounds.
                final currentStationIndex = event.isRunning
                    ? _exercise!.stationIndex(teamIndex, event.currentRound)
                    : -1;
                final currentStationName =
                    (currentStationIndex >= 0 &&
                        currentStationIndex < _exercise!.stations.length)
                    ? _exercise!.stations[currentStationIndex].name
                    : null;
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(
                    vertical: 5,
                    horizontal: 2,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ExpansionTile(
                    // Use ValueKey (not PageStorageKey) — see the comment
                    // on the station ExpansionTile above for the reason.
                    // Teams are NOT auto-expanded on "live": every team
                    // always has a station via the rotation, so a naive
                    // isLive check would expand every row at once. Leave
                    // the team list collapsed and let the coordinator
                    // pick which team to focus on.
                    key: ValueKey<String>(
                      'coordinator-team-$teamIndex',
                    ),
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                    childrenPadding: EdgeInsets.zero,
                    subtitle: currentStationName == null
                        ? null
                        : Text(
                            '→ $currentStationName',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                    title: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            '${localizations.team(1)} ${teamIndex + 1}',
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: VerticalDividerWidget(),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            localizations.station(1),
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                        ...List<Widget>.generate(_exercise!.schedule.length, (
                          roundIndex,
                        ) {
                          final isCurrent =
                              event.isRunning &&
                              roundIndex == event.currentRound;
                          return TeamStationWidget(
                            isCurrent: isCurrent,
                            exercise: _exercise!,
                            teamIndex: teamIndex,
                            roundIndex: roundIndex,
                          );
                        }),
                      ],
                    ),
                    children: [_buildTeamDetail(teamIndex, event)],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Inline detail for a team row in the coordinator team list. Shown when
  /// the user expands the [ExpansionTile] for that team. Lists the station
  /// rotation per round so the coordinator can track where the team is going
  /// without leaving the overview.
  Widget _buildTeamDetail(int teamIndex, ExerciseEvent event) {
    final localizations = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...List<Widget>.generate(_exercise!.schedule.length, (roundIndex) {
            final stationIndex = _exercise!.stationIndex(
              teamIndex,
              roundIndex,
            );
            final none = stationIndex < 0;
            final title = none
                ? '${localizations.station(1)} ×'
                : _exercise!.stations[stationIndex].name;
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: PhaseTile(
                  event: event,
                  title: title,
                  // Fixed width keeps station-name cells aligned across
                  // rounds so the drill/eval/roll columns line up
                  // vertically. Names longer than this are ellipsed.
                  titleWidth: 120,
                  roundIndex: roundIndex,
                  exercise: _exercise!,
                  mainAxisAlignment: MainAxisAlignment.start,
                  decoration: none ? TextDecoration.lineThrough : null,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  void dispose() {
    for (final it in _subscriptions) {
      it.cancel();
    }
    super.dispose();
  }
}
