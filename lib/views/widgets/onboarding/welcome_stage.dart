import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/widgets/onboarding/onboarding_scaffold.dart';

/// First stage of the first-launch onboarding: the brand mark plus a
/// short welcome line, with a single "Next" button.
///
/// The conceptual ring-rotation figure lives on the final stage —
/// not here. Putting the rotation insight at the start would burn the
/// punchline before the user has even agreed to use the app; the
/// welcome stage is the brand identity ("here is RingDrill"), the
/// final stage is the product concept ("here is what it does"). See
/// [ADR-0038].
class WelcomeStage extends StatelessWidget {
  const WelcomeStage({
    super.key,
    required this.stageIndex,
    required this.totalStages,
    required this.onNext,
  });

  final int stageIndex;
  final int totalStages;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return OnboardingScaffold(
      stageIndex: stageIndex,
      totalStages: totalStages,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: ClipRRect(
                    // iOS app-icon corner radius ratio (~22.37% of side).
                    // Matches what the user just saw on the home screen
                    // when they tapped to launch, so the welcome carries
                    // visual continuity from outside the app.
                    borderRadius: BorderRadius.circular(36),
                    child: Image.asset(
                      'assets/images/ringdrill-v2-512x512.png',
                      width: 160,
                      height: 160,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  l10n.onboardingWelcomeHeading,
                  textAlign: TextAlign.center,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.onboardingWelcomeBody,
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
      ),
      footer: OnboardingFooter(
        primary: OnboardingAction(
          label: l10n.nextLabel,
          onPressed: onNext,
        ),
      ),
    );
  }
}
