import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/drill_player/drill_mini_player.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';

/// Wide-layout mini player docked at the bottom of the rail + master
/// column. Listens to [controller] for the currently-selected
/// [ContextSheetTarget] and resolves the parent exercise (via
/// [exerciseUuidOf]) so users browsing the Poster/Markører/Team segments
/// still see an idle play affordance for the selected item's owning
/// exercise.
///
/// When an exercise is already running we drop the resolved selection and
/// let the bar reflect the global running state — without this, the
/// [DrillMiniPlayer] mismatch guard would suppress the docked bar and
/// hide the only place wide users can see what's live.
class DockedDrillMiniPlayer extends StatelessWidget {
  const DockedDrillMiniPlayer({
    super.key,
    required this.controller,
    required this.openDrillPlayer,
  });

  /// The shell's [ContextSheetController]. Drives the docked bar via its
  /// target notifier.
  final ContextSheetController controller;

  /// Pushes the immersive DrillPlayer sheet on top of [context]. Wired
  /// through the host shell's [DrillPlayerCoordinator] so the upgrade
  /// guard stays single-shot.
  final Future<void> Function(BuildContext context) openDrillPlayer;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ContextSheetTarget?>(
      valueListenable: controller.targetNotifier,
      builder: (context, target, _) {
        final selectedExerciseUuid = exerciseUuidOf(target);
        final selectedExercise = selectedExerciseUuid == null
            ? null
            : ProgramService().getExercise(selectedExerciseUuid);
        final idleExercise = ExerciseService().isStarted
            ? null
            : selectedExercise;
        if (!ExerciseService().isStarted && idleExercise == null) {
          return const SizedBox.shrink();
        }
        // No rounded corners in the wide/extended layout — the mini player
        // is a flush bottom bar docked under the rail + master. Rounded
        // corners are reserved for the narrow (portrait/mobile) floating
        // mini bar in MainScreen._buildBottomChrome. `applyBottomInset`
        // lets the bar paint its own background through the bottom
        // safe-area inset (content stays above it), instead of an external
        // SafeArea that left the inset dark below the bar.
        return DrillMiniPlayer(
          // Taller than the narrow floating bar (48) so the docked wide
          // bar has more breathing room.
          height: 64,
          applyBottomInset: true,
          exercise: idleExercise,
          onPlay: idleExercise == null
              ? null
              : () {
                  unawaited(HapticFeedback.mediumImpact());
                  ExerciseService().start(idleExercise);
                  // Clear the detail target so the master/detail pane
                  // empties once the exercise goes live — the running
                  // exercise lives in the fullscreen drill player, not
                  // the detail pane. Without this the started exercise's
                  // coordinator stays pinned in the detail pane after
                  // the player is closed, until another item is
                  // selected.
                  controller.close();
                  openDrillPlayer(context);
                },
          onOpen: () => openDrillPlayer(context),
        );
      },
    );
  }
}
