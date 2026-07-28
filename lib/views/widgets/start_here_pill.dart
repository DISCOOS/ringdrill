import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/utils/app_config.dart';
import 'package:ringdrill/utils/prefs.dart';

/// First-run-only pill that sits inline beside the Øvelser FAB.
///
/// Shows once while [AppConfig.keyStartHereSeen] is unset. Dismisses
/// permanently on any of:
/// - user taps the pill (opening the create-exercise flow),
/// - the first exercise is created via any path,
/// - the user demonstrates knowledge of the app by editing the plan
///   form (description / brief sections), saving a team or roleplay,
///   or importing a plan from a file.
///
/// The broader set of dismissal triggers stops the pill from
/// outstaying its welcome once the user has done substantive work
/// elsewhere in the plan but happens not to have added an exercise
/// yet.
class StartHerePill extends StatefulWidget {
  const StartHerePill({super.key, required this.onActivate});

  /// Called when the pill is tapped — typically [_navigateToCreateExercise].
  final VoidCallback onActivate;

  @override
  State<StartHerePill> createState() => _StartHerePillState();
}

class _StartHerePillState extends State<StartHerePill> {
  bool _seen = true; // conservative default — overwritten in initState
  StreamSubscription<PlanEvent>? _sub;

  /// Plan-service events that count as "user knows what they are
  /// doing" and dismiss the start-here cue. Limited to user-driven
  /// modifications — passive lifecycle events (planOpened,
  /// planActivated, planCreated by the defense-in-depth
  /// ensureActivePlan, etc.) do not count, otherwise the pill
  /// would dismiss before the user has done anything.
  static const _dismissingEvents = <PlanEventType>{
    PlanEventType.exerciseAdded,
    PlanEventType.teamSaved,
    PlanEventType.rolePlaySaved,
    PlanEventType.planRefreshed,
    PlanEventType.planImported,
    PlanEventType.planInstalled,
  };

  @override
  void initState() {
    super.initState();
    _loadFlag();
    _sub = PlanService().events.listen((event) {
      if (_dismissingEvents.contains(event.type)) {
        _markSeen();
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  /// Synchronous: this flag decides whether the pill shows at all, so awaiting
  /// it made the pill appear a frame *after* the surface had settled — the one
  /// thing a coach-mark must not do.
  void _loadFlag() {
    _seen = Prefs.getBool(AppConfig.keyStartHereSeen) ?? false;
  }

  Future<void> _markSeen() async {
    // Hidden immediately; the write catches up.
    if (mounted) setState(() => _seen = true);
    await Prefs.setBool(AppConfig.keyStartHereSeen, true);
  }

  @override
  Widget build(BuildContext context) {
    if (_seen) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final label = AppLocalizations.of(context)!.startHereCue;

    return Material(
      color: cs.primaryContainer,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await _markSeen();
          widget.onActivate();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: cs.onPrimaryContainer,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: cs.onPrimaryContainer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
