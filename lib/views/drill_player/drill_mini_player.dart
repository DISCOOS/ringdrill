import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/numbering.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/views/drill_player/mini_round_row.dart';
import 'package:ringdrill/views/drill_player/phase_colors.dart';
import 'package:ringdrill/views/drill_player/player_mode.dart';
import 'package:ringdrill/views/drill_player/player_target_picker.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';
import 'package:ringdrill/views/widgets/exercise_number_badge.dart';
import 'package:ringdrill/views/widgets/live_accent.dart';
import 'package:ringdrill/views/widgets/role_number_badge.dart';
import 'package:ringdrill/views/widgets/station_number_badge.dart';
import 'package:ringdrill/views/widgets/team_number_badge.dart';

/// Badge edge, matching the 36×36 play/stop square opposite it in the strip
/// (the badge family's own default is the 40 used in list rows).
const double _kBadgeSize = 36;

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
    this.onPickTarget,
    this.mode = const ExercisePlayerMode(),
    this.onOpen,
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

  /// Which of the player's peer modes the host surface is showing (ADR-0056).
  /// Picks the badge kind — exercise `#n`, station `n.m`, role `n.m-k`, team
  /// `n` — and scopes the badge's picker to siblings of that kind.
  final PlayerMode mode;

  /// Called with the picked target when the user taps the badge and chooses a
  /// different one. When null the badge is plain and no picker opens.
  ///
  /// The badge is inert while an exercise is live *in exercise mode* — the
  /// running exercise must not be switched out from under the operator — but
  /// stays tappable in the station, roleplay and team modes, where it only moves
  /// between siblings inside that same live exercise.
  final ValueChanged<ContextSheetTarget>? onPickTarget;

  /// What tapping the strip does when there is somewhere to go: the docked and
  /// floating bars open the fullscreen player.
  ///
  /// Null means the bar is *inside* the surface it describes, so there is nothing
  /// to open — the strip then opens the target picker instead, the same one the
  /// badge opens. The whole bar is a much larger tap target than a 36px chip, and
  /// inside the player it was previously inert.
  final VoidCallback? onOpen;

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
              onTap: _stripTap(context, event.exercise, true),
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
                        _buildBadge(context, event.exercise, isStarted: true),
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
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
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

    return Material(
      color: scheme.surfaceContainerHigh,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: widget.applyBottomInset
              ? MediaQuery.paddingOf(context).bottom
              : 0,
        ),
        child: InkWell(
          onTap: _stripTap(context, exercise, false),
          child: SizedBox(
            height: widget.height,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Row(
                  children: [
                    const SizedBox(width: 8),
                    _buildBadge(context, exercise, isStarted: false),
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

  /// The leading badge, for both the running and the idle strip.
  ///
  /// One builder rather than one per state: the two states used to compute the
  /// exercise label separately, which is exactly the kind of duplication that
  /// drifts once the label depends on the player's [PlayerMode] as well.
  ///
  /// [isStarted] gates interactivity, not appearance: switching the *exercise*
  /// out from under a live session is the thing the original guard prevented,
  /// so exercise mode's badge goes inert while running. The station, roleplay
  /// and team modes stay tappable — they move between siblings within that same
  /// live exercise, which is the whole point of the consolidated player.
  Widget _buildBadge(
    BuildContext context,
    Exercise exercise, {
    required bool isStarted,
  }) {
    final plan = PlanService().activePlan;
    // Not PlanService.getExerciseNumber: that yields 0 for an exercise outside
    // the active plan, and the bar would render "#0". Falling back to 1 keeps
    // the badge plausible for a plain pushed route (a cold deep link).
    final exerciseNumber = plan == null
        ? 1
        : plan.exercises
                  .indexWhere((e) => e.uuid == exercise.uuid)
                  .clamp(0, 1 << 30) +
              1;
    final stationFormat =
        plan?.stationNumberFormat ?? StationNumberFormat.dotted;

    final badge = switch (widget.mode) {
      ExercisePlayerMode() => ExerciseNumberBadge(
        label: Numbering.exercise(
          plan?.exerciseNumberFormat ?? ExerciseNumberFormat.hash,
          exerciseNumber,
        ),
        size: _kBadgeSize,
      ),
      StationPlayerMode(:final stationIndex) => StationNumberBadge(
        label: Numbering.station(
          stationFormat,
          exerciseNumber: exerciseNumber,
          stationIndex: stationIndex,
        ),
        size: _kBadgeSize,
      ),
      RolePlayerMode(:final rolePlayUuid) => RoleNumberBadge(
        label: _roleBadgeLabel(rolePlayUuid, stationFormat, exerciseNumber),
        size: _kBadgeSize,
      ),
      TeamPlayerMode(:final teamIndex) => TeamNumberBadge(
        label: Numbering.team(teamIndex + 1),
        size: _kBadgeSize,
      ),
    };

    if (!_canPick(isStarted)) return badge;
    return InkWell(
      // Keyed because the whole strip is itself an InkWell (onOpen), so "is the
      // badge tappable" cannot be answered by looking for an InkWell ancestor.
      key: const Key('drill-mini-player-badge'),
      onTap: () => unawaited(_openPicker(context, exercise)),
      borderRadius: BorderRadius.circular(18),
      child: badge,
    );
  }

  /// Whether this bar may open the target picker.
  ///
  /// Preserves the original guard exactly: exercise mode goes inert while a
  /// session is live, so the running exercise can never be switched out from
  /// under the operator. The station, roleplay and team modes stay live — they
  /// only move within that same running exercise.
  ///
  /// Shared by the badge and the strip, so the strip cannot become a way around
  /// the guard.
  bool _canPick(bool isStarted) =>
      widget.onPickTarget != null &&
      (widget.mode is! ExercisePlayerMode || !isStarted);

  /// The strip's tap action: [DrillMiniPlayer.onOpen] where there is something
  /// to open, otherwise the picker.
  VoidCallback? _stripTap(
    BuildContext context,
    Exercise exercise,
    bool isStarted,
  ) {
    final onOpen = widget.onOpen;
    if (onOpen != null) return onOpen;
    if (!_canPick(isStarted)) return null;
    return () => unawaited(_openPicker(context, exercise));
  }

  /// A roleplay that has been deleted while the bar is up renders as `?`
  /// rather than throwing; the host screen's own gone-state pane is what
  /// actually tells the user.
  String _roleBadgeLabel(
    String rolePlayUuid,
    StationNumberFormat format,
    int exerciseNumber,
  ) {
    final service = PlanService();
    final role = service.getRolePlay(rolePlayUuid);
    if (role == null) return '$exerciseNumber.?';
    return service.roleLabel(
      role,
      format: format,
      exerciseNumber: exerciseNumber,
    );
  }

  /// Opens the mode-scoped picker and forwards the choice to
  /// [DrillMiniPlayer.onPickTarget]. The picker returns null for "no change"
  /// (dismissed, or re-picked what is already showing), which we drop, so the
  /// host can rely on being called with a real switch.
  Future<void> _openPicker(BuildContext context, Exercise exercise) async {
    final picked = await showPlayerTargetPicker(
      context,
      mode: widget.mode,
      exercise: exercise,
    );
    if (picked == null) return;
    widget.onPickTarget?.call(picked);
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
