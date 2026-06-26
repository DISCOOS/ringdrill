import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/widgets/onboarding/onboarding_scaffold.dart';

/// Onboarding stage for opt-in analytics consent (ADR-0006, presented
/// as part of the four-stage flow in ADR-0038).
///
/// Renders an icon, heading, rationale, and two equal-weight footer
/// buttons. The parent screen handles persistence and Sentry init.
class AnalyticsConsentStage extends StatelessWidget {
  const AnalyticsConsentStage({
    super.key,
    required this.stageIndex,
    required this.totalStages,
    required this.onChoice,
  });

  final int stageIndex;
  final int totalStages;

  /// Invoked with `true` when the user taps Allow and `false` when
  /// the user taps Skip for now. The parent persists the choice and
  /// advances the [PageView] in both cases.
  final void Function(bool consented) onChoice;

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
                Icon(
                  Icons.insights_outlined,
                  size: 56,
                  color: scheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.appAnalyticsConsent,
                  textAlign: TextAlign.center,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  // Two ARB keys rendered as a single bodyMedium
                  // paragraph: a double newline gives a clear
                  // section break without introducing a third font
                  // size on the page. Keeping them as separate
                  // strings preserves translator flexibility — if a
                  // language needs different framing for the "you
                  // can change later" hint, only one key has to
                  // move.
                  '${l10n.appAnalyticsConsentMessage}\n\n${l10n.appAnalyticsConsentOptIn}',
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
          label: l10n.allow,
          onPressed: () => onChoice(true),
        ),
        secondary: OnboardingAction(
          label: l10n.skipForNow,
          onPressed: () => onChoice(false),
        ),
      ),
    );
  }
}
