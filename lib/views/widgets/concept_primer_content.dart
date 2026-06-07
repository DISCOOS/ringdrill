import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/shell/window_size_class.dart';
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
    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final sizeClass = WindowSizeClass.of(context);
        final isWide = sizeClass != WindowSizeClass.compact;

        // The figure is the lesson, so it scales with the form factor instead
        // of being pinned to the 270 px from the phone mockup. It tracks the
        // smaller of the width and height budget so it never overflows a short
        // landscape window, and is capped so it does not dominate a large
        // tablet. Wide screens read the figure off a constrained column, so
        // the budget is that column's width, not the whole window.
        final widthBudget = isWide
            ? math.min(constraints.maxWidth, _maxContentWidth)
            : constraints.maxWidth;
        final figureSize = math
            .min(
              widthBudget * (isWide ? 0.62 : 0.72),
              constraints.maxHeight * 0.42,
            )
            .clamp(220.0, isWide ? 420.0 : 300.0)
            .toDouble();

        final header = Padding(
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
                child: Text(AppLocalizations.of(context)!.primerSkip),
              ),
            ],
          ),
        );

        final figure = Center(child: RingRotationFigure(size: figureSize));
        const copy = _Copy();
        final ctas = _Ctas(
          onOpenExample: onOpenExample,
          onStartEmpty: onStartEmpty,
        );

        if (isWide) {
          // Group figure, copy and CTAs and centre them vertically in a
          // readable column, so a wide window does not leave the card adrift
          // at the top with a large empty band below.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          figure,
                          const SizedBox(height: 16),
                          copy,
                          const SizedBox(height: 28),
                          ctas,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        // Compact: keep the phone mockup — figure near the top, copy under it,
        // CTAs pinned to the bottom.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: figure,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: copy,
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: ctas,
            ),
          ],
        );
      },
    );
  }
}

/// Max width of the primer's content column on medium/expanded windows.
const double _maxContentWidth = 520;

class _Copy extends StatelessWidget {
  const _Copy();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        Text(
          l10n.primerHeading,
          textAlign: TextAlign.center,
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w500),
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
    );
  }
}

class _Ctas extends StatelessWidget {
  const _Ctas({required this.onOpenExample, required this.onStartEmpty});

  final VoidCallback onOpenExample;
  final VoidCallback onStartEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
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
