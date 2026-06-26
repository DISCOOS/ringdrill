import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/shell/window_size_class.dart';
import 'package:ringdrill/views/widgets/ring_rotation_figure.dart';

/// The conceptual primer content: a ring-rotation figure with heading
/// and body copy. Reused by the welcome stage of the first-launch
/// onboarding (see [ADR-0038]) and intended to be reusable from the
/// Help/FAQ surface in stage 5 of DESIGN-007.
///
/// Owns the figure size adaptation across form factors but nothing
/// else — no header, no Skip button, no CTAs. The surrounding chrome
/// is the caller's responsibility. For the first-launch flow that
/// chrome is `OnboardingScaffold`.
class ConceptPrimerContent extends StatelessWidget {
  const ConceptPrimerContent({super.key});

  @override
  Widget build(BuildContext context) {
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

        final figure = Center(child: RingRotationFigure(size: figureSize));
        const copy = _Copy();

        if (isWide) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxContentWidth),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [figure, const SizedBox(height: 16), copy],
                ),
              ),
            ),
          );
        }

        // Compact: figure near the top, copy under it. The Spacer below the
        // copy lets the surrounding scaffold's footer settle at the bottom
        // of the screen without overlapping the copy on tall windows.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: figure,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: copy,
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
