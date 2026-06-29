import 'package:flutter/material.dart';

/// Shared chrome for every onboarding stage in [ConceptPrimerScreen].
///
/// Renders a progress-dot header at the top, the [body] in the centre,
/// and the [footer] (typically one or two action buttons) pinned at
/// the bottom. The current stage is highlighted by a wider primary
/// dot, matching the bar-style indicator used elsewhere in the app.
///
/// Stages stay forward-only — no Skip button in the header, no swipe
/// physics on the surrounding [PageView]. The only way out is via
/// the [footer] actions. See [ADR-0038].
class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.stageIndex,
    required this.totalStages,
    required this.body,
    required this.footer,
  });

  /// Zero-based index of this stage within the onboarding flow.
  final int stageIndex;

  /// Total number of stages mounted by [ConceptPrimerScreen] in the
  /// current flow (4 on first launch, 2 when consent has already been
  /// captured).
  final int totalStages;

  /// Page content. Sits between the progress header and the footer.
  /// Constrained to a readable 520 px column on wide windows.
  final Widget body;

  /// Action area pinned to the bottom. Use [OnboardingFooter] for the
  /// default single/double-button layout.
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: _ProgressDots(
            current: stageIndex,
            total: totalStages,
          ),
        ),
        Expanded(child: body),
        // Footer is centred and capped to the same readable column as
        // the body (see the 480 px ConstrainedBox each stage uses).
        // Without this, on wide windows (web on desktop, tablet
        // landscape) the action buttons stretched edge-to-edge while
        // the body sat in a narrow column, which read as visually
        // unbalanced and oversized.
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: footer,
            ),
          ),
        ),
      ],
    );
  }
}

/// Convenience footer with a primary action and an optional
/// secondary action. Buttons stretch full-width and are stacked
/// vertically so both choices read as equal weight on a phone.
class OnboardingFooter extends StatelessWidget {
  const OnboardingFooter({
    super.key,
    required this.primary,
    this.secondary,
  });

  /// Primary affirmative action (Allow, Next, Open example). Rendered
  /// as a [FilledButton] across the top of the footer.
  final OnboardingAction primary;

  /// Optional secondary action (Skip for now, Start empty).
  /// Rendered as an [OutlinedButton] below [primary], matching the
  /// established stage typography. Null hides the row.
  final OnboardingAction? secondary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          onPressed: primary.onPressed,
          child: Text(primary.label),
        ),
        if (secondary != null) ...[
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: secondary!.onPressed,
            child: Text(secondary!.label),
          ),
        ],
      ],
    );
  }
}

/// Label + callback for a single button in [OnboardingFooter].
class OnboardingAction {
  const OnboardingAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;
}

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dots = <Widget>[];
    for (var i = 0; i < total; i++) {
      if (i > 0) dots.add(const SizedBox(width: 6));
      final isActive = i == current;
      dots.add(
        Container(
          width: isActive ? 18 : 8,
          height: 4,
          decoration: BoxDecoration(
            color: isActive ? scheme.primary : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      );
    }
    return Row(mainAxisSize: MainAxisSize.min, children: dots);
  }
}
