import 'dart:async';
import 'dart:math';

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
import 'package:ringdrill/views/map_view.dart';
import 'package:ringdrill/views/page_widget.dart';
import 'package:ringdrill/views/shared_file_widget.dart';

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

  @override
  void initState() {
    super.initState();
    _initExercises();

    // Listen to exercise changes
    _subscriptions.add(
      _programService.events.listen((event) {
        setState(() {
          _exercises = _programService.loadExercises();
        });
      }),
    );

    // The play/stop control used to live on each card and needed live
    // ExerciseService updates here. Starting now happens from the exercise
    // detail screen, so we no longer need to rebuild the program list on
    // ExerciseService events.
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

                return GestureDetector(
                  onTap: () async {
                    // Navigate to CoordinatorViewScreen with the selected exercise
                    await context.push('$routeProgram/${exercise.uuid}');
                  },
                  child: Dismissible(
                    key: ValueKey(exercise.name),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss: (direction) => showDialog(
                      context: context,
                      barrierDismissible:
                          false, // Prevent closing without taking action
                      builder: (context) => AlertDialog(
                        title: Text(localizations.confirm),
                        content: Text(localizations.confirmDeleteExercise),
                        actions: [
                          TextButton(
                            onPressed: () async {
                              Navigator.pop(context, false);
                            },
                            child: Text(localizations.cancel),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            onPressed: () async {
                              Navigator.pop(context, true);
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
                    ),
                    onDismissed: (direction) {
                      _deleteExercise(exercise);
                    },
                    child: ExerciseCard(
                      exercise: exercise,
                      localizations: localizations,
                      markers: markers,
                    ),
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

  // Delete an exercise and refresh the list
  Future<void> _deleteExercise(Exercise exercise) async {
    if (ExerciseService().exercise == exercise) {
      ExerciseService().stop();
    }
    // Remove the exercise from the repository
    await _programService.deleteExercise(exercise.uuid);
  }
}

class ExerciseCard extends StatefulWidget {
  const ExerciseCard({
    super.key,
    required this.exercise,
    required this.localizations,
    this.trailing,
    required this.markers,
  });

  final Widget? trailing;
  final Exercise exercise;
  final AppLocalizations localizations;
  final List<StationLocation> markers;

  @override
  State<ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<ExerciseCard> {
  static const _animationDuration = Duration(milliseconds: 200);

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

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ListTile(
                  title: Text(
                    exercise.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    [
                      '${st.formal()} - ${et.formal()}',
                      et.toDateTime().formal(localizations, st.toDateTime()),
                      '${exercise.numberOfRounds} ${localizations.round(exercise.numberOfRounds).toLowerCase()}',
                      '${exercise.numberOfTeams} ${localizations.team(exercise.numberOfTeams).toLowerCase()}',
                    ].join(' | '),
                  ),
                ),
              ),
              if (hasMap)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: IconButton(
                    onPressed: _toggleExpanded,
                    icon: AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: _animationDuration,
                      child: const Icon(Icons.expand_more),
                    ),
                  ),
                ),
              if (widget.trailing != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: widget.trailing!,
                ),
            ],
          ),
          if (hasMap)
            AnimatedSize(
              duration: _animationDuration,
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: _expanded
                  ? SizedBox(
                      height: 200,
                      child: IgnorePointer(
                        child: MapView(
                          layers: MapConfig.layers,
                          withToggle: false,
                          markers: markers,
                          initialFit: markers.fit(),
                          initialCenter: markers.average(),
                        ),
                      ),
                    )
                  : const SizedBox(width: double.infinity, height: 0),
            ),
        ],
      ),
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
    return FloatingActionButton(
      heroTag: 'add',
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

  /// Shows a bottom-sheet exercise picker.
  ///
  /// The original positional contract (six positional arguments) is kept so
  /// existing callers (`add_exercises_dialog.dart`, `open_file_widget.dart`)
  /// don't need to change.
  ///
  /// New named parameters drive the export flow:
  /// - [confirmLabel] overrides the primary-button label (e.g. "Eksporter"
  ///   instead of the generic "BEKREFT"). When omitted, falls back to
  ///   [AppLocalizations.confirm].
  /// - [preselectAll] starts with every exercise checked. The export flow uses
  ///   this so the default "Velg øvelser" state is "everything on".
  /// - [showSelectAllControls] adds a row with "Velg alle" / "Velg ingen"
  ///   text buttons above the list, plus a "N of M selected" counter.
  static Future<List<String>> selectExercises(
    BuildContext context,
    String title,
    List<Exercise> exercises,
    BoxConstraints constraints,
    AppLocalizations localizations,
    bool extended, {
    String? confirmLabel,
    bool preselectAll = false,
    bool showSelectAllControls = false,
  }) async {
    final List<String> selected = preselectAll
        ? exercises.map((e) => e.uuid).toList()
        : <String>[];
    final allUuids = exercises.map((e) => e.uuid).toList();
    // Slightly taller minHeight when the header row is shown so the list
    // doesn't get squeezed.
    final double effectiveMinHeight = showSelectAllControls ? 480 : 420;
    // The compact (`extended: false`) layout used to cap the sheet at 60% of
    // the screen, which doesn't scale when the user has many exercises. We
    // now let the sheet grow as tall as it needs (up to the screen size)
    // when the caller opts into the new export-style flow with select-all
    // controls. The legacy compact callers (e.g. merge-from-another-plan)
    // keep the original cap so existing screens don't suddenly take over
    // the full viewport.
    final bool useFullHeight = extended || showSelectAllControls;

    // We rely on the popped return value (not the mutated [selected] list) to
    // tell cancel from confirm. The list is pre-populated when
    // [preselectAll] is true, so reading it directly would treat a cancel
    // as "everything selected" and trigger an unintended export.
    final List<String>? popped =
        await showModalBottomSheet<List<String>?>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: useFullHeight,
      constraints: useFullHeight
          ? constraints
          : constraints.copyWith(
              minHeight: effectiveMinHeight,
              maxHeight: max(
                effectiveMinHeight,
                constraints.maxHeight * 0.6,
              ),
            ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
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
                  mainAxisSize: MainAxisSize.min,
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
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: exercises.length,
                        separatorBuilder: (context, _) =>
                            const SizedBox(height: 4.0),
                        itemBuilder: (context, index) {
                          final exercise = exercises[index];
                          final uuid = exercise.uuid;
                          if (extended) {
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
                          }
                          final st = exercise.startTime.toMaterial();
                          final et = exercise.endTime.toMaterial();
                          final isSelected = selected.contains(uuid);
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                              vertical: 4.0,
                            ),
                            title: Text(
                              exercise.name,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '${st.formal()} – ${et.formal()}',
                            ),
                            trailing: Switch(
                              value: isSelected,
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
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  selected.remove(uuid);
                                } else {
                                  selected.add(uuid);
                                }
                              });
                            },
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

