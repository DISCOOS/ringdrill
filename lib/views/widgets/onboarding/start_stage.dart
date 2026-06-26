import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/widgets/onboarding/onboarding_scaffold.dart';
import 'package:ringdrill/views/widgets/ring_rotation_figure.dart';

/// Final onboarding stage. Reveals the ring-rotation figure — the
/// conceptual core of RingDrill — and offers the choice between
/// opening the bundled example or starting from an empty plan. See
/// [ADR-0038].
///
/// The figure lands here on purpose: it is the message the user
/// should carry into their first interaction with the real app, not
/// a brand-time-only welcome card. The parent screen persists
/// [AppConfig.keyOnboardingSeen] and navigates away after the user
/// picks one of the two CTAs.
///
/// There used to be a tertiary "Skip" button alongside, but it did
/// exactly what "Start empty" already does — write
/// `keyOnboardingSeen` and land in the app with no plan loaded —
/// so it was redundant and got removed.
class StartStage extends StatelessWidget {
  const StartStage({
    super.key,
    required this.stageIndex,
    required this.totalStages,
    required this.onStartEmpty,
    required this.onOpenExample,
  });

  final int stageIndex;
  final int totalStages;
  final VoidCallback onStartEmpty;
  final VoidCallback onOpenExample;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return OnboardingScaffold(
      stageIndex: stageIndex,
      totalStages: totalStages,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Figure tracks the available column so it never overflows
          // a short window and is capped so it stays legible without
          // dominating the footer area.
          final figureSize = math
              .min(constraints.maxWidth * 0.7, constraints.maxHeight * 0.45)
              .clamp(200.0, 320.0)
              .toDouble();
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: RingRotationFigure(size: figureSize)),
                    const SizedBox(height: 16),
                    Text(
                      l10n.primerHeading,
                      textAlign: TextAlign.center,
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.primerBody,
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        height: 1.55,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: onOpenExample,
            icon: const Icon(Icons.play_arrow),
            label: Text(l10n.primerOpenExample),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: onStartEmpty,
            child: Text(l10n.primerStartEmpty),
          ),
        ],
      ),
    );
  }
}
