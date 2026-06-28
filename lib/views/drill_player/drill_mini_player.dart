import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/numbering.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/drill_player/mini_round_row.dart';
import 'package:ringdrill/views/drill_player/phase_colors.dart';
import 'package:ringdrill/views/widgets/exercise_number_badge.dart';
import 'package:ringdrill/views/widgets/live_accent.dart';

/// Builds the central content of a [DrillMiniPlayer], replacing the default
/// [MiniRoundRow]. [remainingSeconds] is the per-second-smoothed countdown of
/// the current phase and [elapsedSeconds] the per-second-smoothed time since
/// the exercise started (both 0 while idle), so a custom body can tick
/// smoothly.
typedef DrillMiniPlayerBodyBuilder =
    Widget Function(
      BuildContext context,
      ExerciseEvent event,
      int remainingSeconds,
      int elapsedSeconds,
    );

class DrillMiniPlayer extends StatefulWidget {
  const DrillMiniPlayer({
    super.key,
    this.exercise,
    this.onPlay,
    required this.onOpen,
    this.height = 48,
    this.bodyBuilder,
    this.showInlineStatus = true,
    this.applyBottomInset = false,
  });

  /// When `true`, the bar extends its own background colour down through the
  /// bottom safe-area inset (home indicator on iOS) while keeping its content
  /// above the inset. Used by the docked variants (wide/extended layout and
  /// the fullscreen player) that sit flush against the screen edge — without
  /// it the colour stops at the bar height and the inset reads as a dark
  /// strip below the bar. Left `false` for the narrow floating bar in
  /// [_buildBottomChrome], where the NavigationBar below it owns the inset.
  final bool applyBottomInset;

  /// Overrides the content shown in the central, flexible area that
  /// defaults to a horizontally-scrollable [MiniRoundRow]. Receives the
  /// current [ExerciseEvent] (a pending event in the idle state, the live
  /// event while running) and the per-second-smoothed seconds remaining in
  /// the current phase (0 in the idle state), so the override can render a
  /// smooth countdown of its own. Returns the widget placed inside the
  /// `Expanded` slot — it is NOT wrapped in a scroll view, so the override
  /// owns its own overflow handling.
  ///
  /// When null the default scrollable round row is used, so existing
  /// callers are unaffected.
  final DrillMiniPlayerBodyBuilder? bodyBuilder;

  /// When `true` (the default) the running state shows the inline phase
  /// label and countdown to the left of the stop button. Callers that move
  /// that information into [bodyBuilder] (e.g. the coordinator's tile row)
  /// pass `false` so the trailing cluster collapses to just the stop
  /// button — keeping the floating mini-bar elsewhere unchanged.
  final bool showInlineStatus;

  /// Height of the tappable strip (excluding the 4px progress bar at the
  /// bottom). Defaults to 48 for the narrow/portrait floating mini bar; the
  /// wide/extended docked bar passes a taller value for more breathing room.
  final double height;

  /// Scopes the bar to a specific exercise. When set, the bar:
  /// - shows the first round + play button while idle (instead of
  ///   collapsing to [SizedBox.shrink]),
  /// - shows the running state when this exact exercise is running,
  /// - hides itself entirely when a DIFFERENT exercise is running, so
  ///   the user looking at e.g. exercise #3's coordinator doesn't see a
  ///   stop button that would act on exercise #1.
  ///
  /// Leave null for the global floating bar (root of MainScreen, stations
  /// map) that should always mirror the running exercise regardless of
  /// which screen hosts it.
  final Exercise? exercise;

  /// Called when the play button is tapped in idle state. When null, falls
  /// back to calling [ExerciseService().start] directly.
  final VoidCallback? onPlay;

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
    // When the bar is scoped to a specific exercise (e.g. embedded in a
    // CoordinatorScreen) and a DIFFERENT exercise is the one actually
    // running, hide the bar entirely. The running-state UI (stop button,
    // countdown) belongs to whichever screen is showing the live
    // exercise, not to the bystander's. The global floating bar at the
    // root of MainScreen passes `exercise: null` and is unaffected.
    if (widget.exercise != null &&
        isStarted &&
        _event != null &&
        _event!.exercise.uuid != widget.exercise!.uuid) {
      return const SizedBox.shrink();
    }
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
    final exerciseLabel = Numbering.exercise(
      program?.exerciseNumberFormat ?? ExerciseNumberFormat.hash,
      exerciseNumber,
    );

    // The rounded shape is owned by the parent (MainScreen._buildBottomChrome).
    // This Material just fills the clipped area with the LiveAccent background.
    // The bottom inset padding lives INSIDE the Material so the accent colour
    // reaches the screen edge; the content (bar + progress strip) stays above
    // it. See [applyBottomInset].
    return Material(
      color: accent.background,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: widget.applyBottomInset
              ? MediaQuery.paddingOf(context).bottom
              : 0,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
            onTap: widget.onOpen,
            child: SizedBox(
              height: widget.height,
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
                      ExerciseNumberBadge(label: exerciseLabel, size: 36),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Padding(
                          // When the inline status is hidden, the trailing
                          // overlay shrinks to just the stop button. Reserve
                          // its width so a full-width custom body (e.g. the
                          // coordinator tiles) does not slide under it.
                          padding: EdgeInsets.only(
                            right: widget.showInlineStatus ? 0 : 60,
                          ),
                          child:
                              widget.bodyBuilder?.call(
                                context,
                                event,
                                remainingSeconds,
                                (smoothedProgress * totalDurationSeconds)
                                    .round(),
                              ) ??
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: MiniRoundRow(
                                  exercise: event.exercise,
                                  event: event,
                                ),
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
                              if (widget.showInlineStatus) ...[
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
                              ],
                              _buildStopSquare(event.phase),
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
                final fillFlex = (smoothedProgress * 10000).round().clamp(
                  0,
                  10000,
                );
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
      ),
    );
  }

  /// Stop button — red filled circle with a stop glyph. Tap stops the
  /// exercise immediately; no confirmation, matching the V1 brief. The
  /// [GestureDetector] wins the gesture arena over the enclosing [InkWell],
  /// so tapping the circle does not also fire [onOpen]. The ring pulses in
  /// pending and spins while running.
  Widget _buildStopSquare(ExercisePhase phase) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        unawaited(HapticFeedback.mediumImpact());
        ExerciseService().stop();
      },
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
                child: const Icon(Icons.stop, color: Colors.white, size: 18),
              ),
            ),
            SizedBox.expand(child: _PlayRing(phase: phase)),
          ],
        ),
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
    final exerciseLabel = Numbering.exercise(
      program?.exerciseNumberFormat ?? ExerciseNumberFormat.hash,
      exerciseNumber,
    );

    return Material(
      color: scheme.surfaceContainerHigh,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: widget.applyBottomInset
              ? MediaQuery.paddingOf(context).bottom
              : 0,
        ),
        child: InkWell(
          onTap: widget.onOpen,
          child: SizedBox(
            height: widget.height,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Row(
                  children: [
                  const SizedBox(width: 8),
                  ExerciseNumberBadge(label: exerciseLabel, size: 36),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Padding(
                      // Reserve width for the play-button overlay (16px
                      // gradient + 36px button + 8px trailing gap = 60px)
                      // so MiniRoundRow content does not slide behind it.
                      padding: const EdgeInsets.only(right: 60),
                      child:
                          widget.bodyBuilder?.call(context, event, 0, 0) ??
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: MiniRoundRow(
                              exercise: exercise,
                              event: event,
                            ),
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
                              scheme.surfaceContainerHigh.withValues(
                                alpha: 0.0,
                              ),
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
                            onTap: () {
                              if (widget.onPlay != null) {
                                widget.onPlay!();
                              } else {
                                unawaited(HapticFeedback.mediumImpact());
                                ExerciseService().start(exercise);
                              }
                            },
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
