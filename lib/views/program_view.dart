import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/utils/latlng_utils.dart';
import 'package:ringdrill/utils/time_utils.dart';
import 'package:ringdrill/views/app_routes.dart';
import 'package:ringdrill/views/dialog_widgets.dart';
import 'package:ringdrill/views/map_view.dart';
import 'package:ringdrill/views/page_widget.dart';
import 'package:ringdrill/views/shared_file_widget.dart';
import 'package:ringdrill/views/widgets/expandable_tile.dart';
import 'package:ringdrill/views/widgets/live_accent.dart';

import 'exercise_form_screen.dart';

export 'package:ringdrill/web/program_page_controller.dart'
    if (dart.library.io) 'program_page_controller.dart';

class ProgramView extends StatefulWidget {
  const ProgramView({super.key});

  @override
  State<ProgramView> createState() => _ProgramViewState();
}

class _ProgramViewState extends State<ProgramView> {
  final _programService = ProgramService();
  final List<StreamSubscription> _subscriptions = [];
  List<Exercise> _exercises = [];
  ExerciseEvent? _liveEvent;

  @override
  void initState() {
    super.initState();
    _initExercises();
    _liveEvent = ExerciseService().last;

    // Listen to exercise changes
    _subscriptions.add(
      _programService.events.listen((event) {
        setState(() {
          _exercises = _programService.loadExercises();
        });
      }),
    );

    // The play/stop control used to live on each card; that part no longer
    // needs ExerciseService updates here. We re-subscribe so the live "blue
    // card" marker on the running exercise — mirroring the team view —
    // tracks start/stop/phase transitions while the user is on this tab.
    _subscriptions.add(
      ExerciseService().events.listen((event) {
        if (!mounted) return;
        setState(() {
          _liveEvent = event;
        });
      }),
    );
  }

  @override
  void dispose() {
    super.dispose();
    for (var e in _subscriptions) {
      e.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final programs = _exercises.isEmpty
        ? Center(child: Text(localizations.noExercisesYet))
        : Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: ListView.builder(
              itemCount: _exercises.length,
              itemBuilder: (context, index) {
                final exercise = _exercises[index];
                final markers = exercise.getLocations(false);

                return Dismissible(
                  key: ValueKey(exercise.uuid),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Theme.of(context).colorScheme.primary,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Icon(
                      Icons.edit,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                  confirmDismiss: (direction) async {
                    final numberOfTeams =
                        _programService.loadTeams().length;
                    final updated = await Navigator.push<Exercise>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ExerciseFormScreen(
                          exercise: exercise,
                          numberOfTeams:
                              numberOfTeams == 0 ? null : numberOfTeams,
                        ),
                      ),
                    );
                    if (updated != null && context.mounted) {
                      await _programService.saveExercise(
                        localizations,
                        updated,
                      );
                      setState(_initExercises);
                    }
                    // Always return false — the item should not be removed.
                    return false;
                  },
                  child: ExerciseCard(
                    exercise: exercise,
                    localizations: localizations,
                    markers: markers,
                    liveEvent: _liveEvent,
                    onOpen: () =>
                        context.push('$routeProgram/${exercise.uuid}'),
                  ),
                );
              },
            ),
          );
    return kIsWeb ? programs : SharedFileWidget(child: programs);
  }

  void _initExercises() {
    _exercises = _programService.loadExercises();
  }

}

class ExerciseCard extends StatefulWidget {
  const ExerciseCard({
    super.key,
    required this.exercise,
    required this.localizations,
    this.trailing,
    required this.markers,
    this.liveEvent,
    this.onOpen,
  });

  final Widget? trailing;
  final Exercise exercise;
  final AppLocalizations localizations;
  final List<StationLocation> markers;

  /// Latest [ExerciseEvent] from [ExerciseService], if any. When this
  /// event belongs to the card's exercise, the card is rendered with
  /// the same blue "live" treatment used in `team_screen.dart` so the
  /// running exercise stands out at a glance. Default `null` keeps the
  /// neutral look — that is what the export/import picker uses, where
  /// "live" styling would be misleading.
  final ExerciseEvent? liveEvent;

  /// Fires when the row is tapped. When `null`, tapping the row toggles
  /// the inline map preview instead (used by the export/import picker
  /// where there is no detail screen to navigate to).
  final VoidCallback? onOpen;

  @override
  State<ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<ExerciseCard> {
  bool _expanded = false;

  void _toggleExpanded() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;
    final localizations = widget.localizations;
    final markers = widget.markers;
    final hasMap = markers.isNotEmpty;
    final st = exercise.startTime.toMaterial();
    final et = exercise.endTime.toMaterial();
    final liveEvent = widget.liveEvent;
    final isLive = liveEvent?.exercise.uuid == exercise.uuid;
    final accent = LiveAccent.of(context, isLive: isLive);
    final subtitleParts = <String>[
      if (isLive) liveEvent!.getState(localizations),
      '${st.formal()} - ${et.formal()}',
      et.toDateTime().formal(localizations, st.toDateTime()),
      '${exercise.numberOfRounds} ${localizations.round(exercise.numberOfRounds).toLowerCase()}',
      '${exercise.numberOfTeams} ${localizations.team(exercise.numberOfTeams).toLowerCase()}',
    ];

    return ExpandableTile(
      accent: accent,
      leading: accent.indicator,
      title: Text(
        exercise.name,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: accent.foreground,
        ),
      ),
      subtitle: Text(subtitleParts.join(' | '), style: accent.textStyle),
      trailing: widget.trailing,
      onOpen: widget.onOpen,
      onToggle: hasMap ? _toggleExpanded : null,
      expanded: _expanded,
      body: hasMap
          ? SizedBox(
              height: 200,
              child: IgnorePointer(
                child: MapView(
                  layers: MapConfig.layers,
                  withToggle: false,
                  withClustering: false,
                  markers: markers.toMarkerSpecs(),
                  initialFit: markers.fit(),
                  initialCenter: markers.average(),
                ),
              ),
            )
          : null,
    );
  }
}

abstract class ProgramPageControllerBase extends ScreenController {
  ProgramPageControllerBase();

  @protected
  final programService = ProgramService();

  @override
  String title(BuildContext context) =>
      programService.activeProgram?.name ??
      AppLocalizations.of(context)!.exercise(2);

  @override
  Widget? buildFAB(BuildContext context, BoxConstraints constraints) {
    // heroTag is intentionally null. The FAB pushes ExerciseFormScreen via a
    // MaterialPageRoute, which has no FAB to morph into, so there is no hero
    // animation to preserve. With an explicit string tag the Scaffold's
    // _FloatingActionButtonTransition can keep both the outgoing and incoming
    // FAB widgets briefly alive (in its internal Stack) when the user switches
    // tabs faster than the FAB scale-in/out animation completes — that
    // produced the "multiple heroes that share the same tag" assertion seen
    // when bouncing between /program and /stations. Disabling the Hero wrapper
    // entirely is the safe fix.
    return FloatingActionButton(
      heroTag: null,
      onPressed: () => _navigateToCreateExercise(context),
      child: const Icon(Icons.add),
    );
  }

  // Navigate to the CreateExerciseScreen to add a new exercise
  Future<void> _navigateToCreateExercise(BuildContext context) async {
    final newExercise = await Navigator.of(context).push<Exercise>(
      MaterialPageRoute(builder: (context) => ExerciseFormScreen()),
    );

    if (context.mounted && newExercise != null) {
      // Add the new exercise and reload the list
      await programService.saveExercise(
        AppLocalizations.of(context)!,
        newExercise,
      );
    }
  }

  @override
  List<Widget>? buildActions(BuildContext context, BoxConstraints constraints) {
    return null;
  }

  /// Shows the exercise picker as a bottom sheet on small form factors and as
  /// a centered modal dialog on wide ones (same responsive behaviour as
  /// `showOpenPlanDialog`).
  ///
  /// Each row renders the expandable [ExerciseCard] so the user can see start
  /// and end time, rounds, teams, and tap the chevron to peek at a small map
  /// of the exercise's stations before choosing whether to include it.
  ///
  /// Named parameters drive the export/import flows:
  /// - [confirmLabel] overrides the primary-button label (e.g. "EKSPORTER",
  ///   "IMPORTER"). When omitted, falls back to [AppLocalizations.confirm].
  /// - [preselectAll] starts with every exercise checked. The export/import
  ///   flows use this so the default state is "everything on".
  /// - [showSelectAllControls] adds a row with "VELG ALLE" / "VELG INGEN"
  ///   text buttons above the list, plus a "N av M valgt" counter.
  static Future<List<String>> selectExercises(
    BuildContext context,
    String title,
    List<Exercise> exercises,
    AppLocalizations localizations, {
    String? confirmLabel,
    bool preselectAll = false,
    bool showSelectAllControls = false,
  }) async {
    final List<String> selected = preselectAll
        ? exercises.map((e) => e.uuid).toList()
        : <String>[];
    final allUuids = exercises.map((e) => e.uuid).toList();

    // We rely on the popped return value (not the mutated [selected] list) to
    // tell cancel from confirm. The list is pre-populated when
    // [preselectAll] is true, so reading it directly would treat a cancel
    // as "everything selected" and trigger an unintended export/import.
    final List<String>? popped =
        await showResponsiveSheetOrDialog<List<String>>(
      context,
      maximizeHeight: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final headerLabelStyle = Theme.of(context).textTheme.titleSmall
                ?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                );
            return Padding(
              padding: EdgeInsets.only(
                left: 20.0,
                right: 20.0,
                top: 8.0,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20.0,
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    if (showSelectAllControls) ...[
                      const SizedBox(height: 8.0),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              localizations.selectedOfTotal(
                                selected.length,
                                exercises.length,
                              ),
                              style: headerLabelStyle,
                            ),
                          ),
                          TextButton(
                            onPressed: selected.length == exercises.length
                                ? null
                                : () {
                                    setState(() {
                                      selected
                                        ..clear()
                                        ..addAll(allUuids);
                                    });
                                  },
                            child: Text(localizations.selectAll),
                          ),
                          TextButton(
                            onPressed: selected.isEmpty
                                ? null
                                : () {
                                    setState(() => selected.clear());
                                  },
                            child: Text(localizations.selectNone),
                          ),
                        ],
                      ),
                      const Divider(height: 16.0),
                    ] else
                      const SizedBox(height: 16.0),
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: exercises.length,
                        itemBuilder: (context, index) {
                          final exercise = exercises[index];
                          final uuid = exercise.uuid;
                          final markers = exercise.getLocations(false);
                          return ExerciseCard(
                            exercise: exercise,
                            localizations: localizations,
                            markers: markers,
                            trailing: Switch(
                              value: selected.contains(uuid),
                              onChanged: (bool? value) {
                                setState(() {
                                  if (value == true) {
                                    selected.add(uuid);
                                  } else {
                                    selected.remove(uuid);
                                  }
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20.0),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: headerLabelStyle,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(width: 12.0),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context, null);
                          },
                          child: Text(localizations.cancel),
                        ),
                        const SizedBox(width: 8.0),
                        FilledButton(
                          onPressed: selected.isEmpty
                              ? null
                              : () {
                                  Navigator.pop(context, selected);
                                },
                          child: Text(
                            confirmLabel ?? localizations.confirm,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8.0),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    return popped ?? <String>[];
  }
}

