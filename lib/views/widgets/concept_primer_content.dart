import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/widgets/ring_rotation_figure.dart';

/// The reusable content of the concept primer card.
///
/// Mounted by [ConceptPrimerScreen] on first launch, and reusable from
/// the Help/FAQ surface in stage 5 (DESIGN-007).
class ConceptPrimerContent extends StatelessWidget {
  const ConceptPrimerContent({
    super.key,
    required this.onSkip,
    required this.onOpenExample,
    required this.onStartEmpty,
  });

  final VoidCallback onSkip;
  final VoidCallback onOpenExample;
  final VoidCallback onStartEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Progress dots + skip
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Row(
            children: [
              _ProgressDots(scheme: scheme),
              const Spacer(),
              TextButton(
                onPressed: onSkip,
                style: TextButton.styleFrom(
                  foregroundColor: scheme.onSurfaceVariant,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(l10n.primerSkip),
              ),
            ],
          ),
        ),
        // Ring illustration
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 270),
              child: const RingRotationFigure(size: 270),
            ),
          ),
        ),
        // Heading + body copy
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
          child: Column(
            children: [
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
                  height: 1.6,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        // CTAs
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
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
        ),
      ],
    );
  }
}

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Active dot (current card)
        Container(
          width: 18,
          height: 4,
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 6),
        // Inactive dots (future cards — decorative in v1)
        _InactiveDot(scheme: scheme),
        const SizedBox(width: 6),
        _InactiveDot(scheme: scheme),
      ],
    );
  }
}

class _InactiveDot extends StatelessWidget {
  const _InactiveDot({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 4,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}
