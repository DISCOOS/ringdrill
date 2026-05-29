import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/drill_player/mini_round_row.dart';
import 'package:ringdrill/views/drill_player/phase_colors.dart';
import 'package:ringdrill/views/widgets/exercise_number_badge.dart';
import 'package:ringdrill/views/widgets/live_accent.dart';

class DrillMiniPlayer extends StatefulWidget {
  const DrillMiniPlayer({super.key, this.exercise, required this.onOpen});

  /// Optional exercise to show in idle (not-yet-started) state. When set,
  /// the mini player displays the first round and a play button instead of
  /// collapsing to [SizedBox.shrink]. Ignored when an exercise is running.
  final Exercise? exercise;

  final VoidCallback onOpen;

  @override
  State<DrillMiniPlayer> createState() => _DrillMiniPlayerState();
}

class _DrillMiniPlayerState extends State<DrillMiniPlayer> {
  ExerciseEvent? _event;
  StreamSubscription<ExerciseEvent>? _sub;
  // Per-second ticker interpolates between minute-granular service events so
  // the countdown reads mm:ss and the progress bar moves smoothly.
  // The service still emits per minute — see V1 followup-01 Gap 2.
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _event = ExerciseService().last;
    _sub = ExerciseService().events.listen((event) {
      if (!mounted) return;
      setState(() => _event = event);
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isStarted = ExerciseService().isStarted;
    final event = isStarted ? _event : null;
    final idleExercise = !isStarted ? widget.exercise : null;

    if (event == null && idleExercise == null) {
      return const SizedBox.shrink();
    }

    if (idleExercise != null) {
      return _buildIdle(context, idleExercise);
    }

    final localizations = AppLocalizations.of(context)!;
    final phase = event!.phase;
    final color = colorForPhase(phase);

    final secondsSinceEvent = _now
        .difference(event.when)
        .inSeconds
        .clamp(0, 1 << 30);
    final remainingSeconds = (event.remainingTime * 60 - secondsSinceEvent)
        .clamp(0, 1 << 30);
    // Pending no longer carries the "Starter om" prefix — the phase label
    // ("VENT") next to the countdown already provides that context. Past
    // 90 minutes we drop the MM:SS reading because reading "94:12" mentally
    // forces the user to do the divide; show "2 timer" instead.
    final String countdown;
    if (remainingSeconds >= 90 * 60) {
      final hours = (remainingSeconds / 3600).round();
      countdown = localizations.hour(hours);
    } else {
      final mm = (remainingSeconds ~/ 60).toString().padLeft(2, '0');
      final ss = (remainingSeconds % 60).toString().padLeft(2, '0');
      countdown = '$mm:$ss';
    }

    // Bottom strip = total exercise progress. Per-phase progress lives inside
    // MiniRoundRow via PhasesWidget cell fills (Step 7).
    final totalDurationMinutes =
        event.exercise.numberOfRounds *
        (event.exercise.executionTime +
            event.exercise.evaluationTime +
            event.exercise.rotationTime);
    final totalDurationSeconds = (totalDurationMinutes * 60).clamp(1, 1 << 30);
    final smoothedProgress =
        (event.totalProgress + secondsSinceEvent / totalDurationSeconds).clamp(
          0.0,
          1.0,
        );

    final accent = LiveAccent.of(context, isLive: true);
    // LiveAccent fields are nullable for `inactive()`, but `of(isLive: true)`
    // always populates them. Capture the non-null colour once so we can use
    // it for the overlay mask + gradient without `!` at every call site.
    final accentBg =
        accent.background ?? Theme.of(context).colorScheme.primaryContainer;

    final program = ProgramService().activeProgram;
    final exerciseNumber = program == null
        ? 1
        : program.exercises
                  .indexWhere((e) => e.uuid == event.exercise.uuid)
                  .clamp(0, 1 << 30) +
              1;

    // The rounded shape is owned by the parent (MainScreen._buildBottomChrome).
    // This Material just fills the clipped area with the LiveAccent background.
    return Material(
      color: accent.background,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: widget.onOpen,
            child: SizedBox(
              height: 48,
              // Stack layout: the round-row (badge + MiniRoundRow) scrolls
              // horizontally on the bottom layer; the right cluster (phase
              // label + countdown + play) floats on top with the accent
              // background as a mask so scrolled content slides under it.
              // This stops "n runder" / wide countdowns ("11 timer") from
              // colliding with the play button — content that doesn't fit
              // can be revealed by scrolling instead.
              child: Stack(
                // Center non-positioned children vertically so MiniRoundRow
                // (which only needs 32px) lines up with the 36px play button
                // instead of sticking to the top of the 48px strip.
                alignment: Alignment.centerLeft,
                children: [
                  // Background layer: badge + scrollable MiniRoundRow.
                  Row(
                    children: [
                      const SizedBox(width: 8),
                      ExerciseNumberBadge(number: exerciseNumber, size: 36),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: MiniRoundRow(
                            exercise: event.exercise,
                            event: event,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Foreground overlay: phase label, countdown, play button.
                  // Leading gradient fades scrolled content into the accent
                  // background so the user gets a scroll affordance.
                  Positioned(
                    top: 0,
                    bottom: 0,
                    right: 0,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      // Stretch children vertically so the gradient mask and
                      // accent-background fill the full row height — otherwise
                      // scrolled MiniRoundRow content leaks through the
                      // top/bottom gap above and below the play button.
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        IgnorePointer(
                          child: Container(
                            width: 16,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  accentBg.withValues(alpha: 0.0),
                                  accentBg,
                                ],
                              ),
                            ),
                          ),
                        ),
                        ColoredBox(
                          color: accentBg,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!event.isDone)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Text(
                                    event.getState(localizations),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: colorForPhase(event.phase),
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                              Text(
                                countdown,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: accent.foreground,
                                      fontWeight: FontWeight.w600,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                              ),
                              const SizedBox(width: 8),
                              // Stop button — red filled circle with a stop
                              // glyph. Tap stops the exercise immediately; no
                              // confirmation, matching the user's V1 brief.
                              // GestureDetector wins the gesture arena over
                              // the enclosing InkWell, so tapping the circle
                              // does not also open the sheet.
                              //
                              // The ring around the circle is intentionally
                              // kept (pulses in pending, spins while running)
                              // pending visual review — it may be dropped in
                              // a follow-up.
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => ExerciseService().stop(),
                                child: SizedBox(
                                  width: 36,
                                  height: 36,
                                  child: Stack(
                                    children: [
                                      Center(
                                        child: Container(
                                          width: 30,
                                          height: 30,
                                          decoration: const BoxDecoration(
                                            color: Colors.redAccent,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.stop,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                      SizedBox.expand(
                                        child: _PlayRing(phase: event.phase),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Custom strip instead of LinearProgressIndicator because the
          // indicator's backgroundColor washed the phase colour out on the
          // primaryContainer surface. A dark wash track maximises contrast
          // with the saturated fill.
          //
          // Split the strip into two Expanded flex children rather than a
          // Stack + FractionallySizedBox: the FSB was non-positioned, so the
          // Stack shrank to FSB's partial width and the Positioned.fill
          // wash track followed it, leaving the right side of the strip
          // empty whenever progress < 1.
          SizedBox(
            height: 4,
            child: Builder(
              builder: (context) {
                final fillFlex =
                    (smoothedProgress * 10000).round().clamp(0, 10000);
                final trackFlex = 10000 - fillFlex;
                return Row(
                  children: [
                    if (fillFlex > 0)
                      Expanded(
                        flex: fillFlex,
                        child: Container(color: color),
                      ),
                    if (trackFlex > 0)
                      Expanded(
                        flex: trackFlex,
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.18),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Idle state: first round + play button. Same layout structure as the
  /// playing state so the transition is seamless.
  Widget _buildIdle(BuildContext context, Exercise exercise) {
    final event = ExerciseEvent.pending(exercise);
    final scheme = Theme.of(context).colorScheme;

    final program = ProgramService().activeProgram;
    final exerciseNumber = program == null
        ? 1
        : program.exercises
                  .indexWhere((e) => e.uuid == exercise.uuid)
                  .clamp(0, 1 << 30) +
              1;

    return Material(
      color: scheme.surfaceContainerHigh,
      child: InkWell(
        onTap: widget.onOpen,
        child: SizedBox(
          height: 48,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Row(
                children: [
                  const SizedBox(width: 8),
                  ExerciseNumberBadge(number: exerciseNumber, size: 36),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: MiniRoundRow(
                        exercise: exercise,
                        event: event,
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                top: 0,
                bottom: 0,
                right: 0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    IgnorePointer(
                      child: Container(
                        width: 16,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              scheme.surfaceContainerHigh.withValues(alpha: 0.0),
                              scheme.surfaceContainerHigh,
                            ],
                          ),
                        ),
                      ),
                    ),
                    ColoredBox(
                      color: scheme.surfaceContainerHigh,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => ExerciseService().start(exercise),
                            child: SizedBox(
                              width: 36,
                              height: 36,
                              child: Center(
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: const BoxDecoration(
                                    color: Colors.greenAccent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.play_arrow,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Animated ring around the play icon
// ---------------------------------------------------------------------------

/// Switches between a pulsing ring (pending) and an indeterminate spinning
/// ring (running/eval/rotation/done). Decorative only.
class _PlayRing extends StatelessWidget {
  const _PlayRing({required this.phase});
  final ExercisePhase phase;

  @override
  Widget build(BuildContext context) {
    final ringColor = colorForPhase(phase).withValues(alpha: 0.85);
    if (phase == ExercisePhase.pending) {
      return _PulsingRing(color: ringColor);
    }
    return CircularProgressIndicator(
      strokeWidth: 2.5,
      valueColor: AlwaysStoppedAnimation<Color>(ringColor),
      backgroundColor: Colors.transparent,
    );
  }
}

/// Pulsing ring used in the pending state. Cycles opacity and stroke width
/// on a ~1.2 s loop so the play icon reads as "warming up".
class _PulsingRing extends StatefulWidget {
  const _PulsingRing({required this.color});
  final Color color;

  @override
  State<_PulsingRing> createState() => _PulsingRingState();
}

class _PulsingRingState extends State<_PulsingRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, _) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Container(
          key: const ValueKey('drill-mini-player-pulsing-ring'),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.color.withValues(alpha: 0.3 + 0.55 * t),
              width: 2 + 1.5 * t,
            ),
          ),
        );
      },
    );
  }
}
