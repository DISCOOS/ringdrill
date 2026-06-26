import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/widgets/onboarding/onboarding_scaffold.dart';

/// Onboarding stage for the OS notification permission rationale
/// (ADR-0038).
///
/// Renders the same chrome as [AnalyticsConsentStage] with a
/// notification-flavoured icon and copy. The parent handles the
/// `keyNotificationConsentAsked` write and the
/// `NotificationService.initFromPrefs` call that triggers the iOS
/// system dialog when the user taps Allow.
class NotificationConsentStage extends StatelessWidget {
  const NotificationConsentStage({
    super.key,
    required this.stageIndex,
    required this.totalStages,
    required this.onChoice,
  });

  final int stageIndex;
  final int totalStages;

  /// Invoked with `true` when the user taps Allow and `false` when
  /// the user taps Skip for now. The parent persists the ask-flag
  /// and advances the [PageView] in both cases.
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
                  Icons.notifications_active_outlined,
                  size: 56,
                  color: scheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.appNotificationConsent,
                  textAlign: TextAlign.center,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  // Two ARB keys rendered as a single bodyMedium
                  // paragraph. See the analytics stage for why
                  // they stay separate keys.
                  '${l10n.appNotificationConsentMessage}\n\n${l10n.appNotificationConsentOptIn}',
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
