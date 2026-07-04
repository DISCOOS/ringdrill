import 'package:flutter/material.dart';
import 'package:ringdrill/views/widgets/ringdrill_text.dart';

/// Two-line title for an [AppBar] inside a bottom-sheet body.
///
/// The first line names the entity the sheet is about (e.g. station code +
/// name, team N, role name). The optional second line carries parent
/// context (e.g. the exercise name). The secondary line uses the AppBar's
/// foreground colour at 0.75 alpha so it reads as subordinate without
/// breaking the dark `AppBarTheme.brandDeep` tint.
///
/// Both lines resolve `{{var.name}}` tokens (ADR-0046) via [RingDrillText],
/// degrading to plain text where there is no `PlanScope` ancestor.
/// [primaryOverrides]/[secondaryOverrides] are each line's entity's
/// effective override map (`effectivePlanVariables`) where the cascade
/// matters — omit where the entity has none.
///
/// Designed to be dropped into `AppBar.title` together with
/// `toolbarHeight: 72`. Used by `StationExerciseScreen`,
/// `TeamExerciseScreen`, `RolePlayScreen` and the station mini-map sheet
/// header so every viewer-context AppBar reads the same way.
class SheetTitle extends StatelessWidget {
  const SheetTitle({
    super.key,
    required this.primary,
    this.secondary,
    this.primaryOverrides = const {},
    this.secondaryOverrides = const {},
  });

  final String primary;
  final String? secondary;
  final Map<String, String> primaryOverrides;
  final Map<String, String> secondaryOverrides;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = theme.appBarTheme.foregroundColor ?? theme.colorScheme.onPrimary;
    final hasSecondary = secondary != null && secondary!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        RingDrillText(
          primary,
          overrides: primaryOverrides,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (hasSecondary) ...[
          const SizedBox(height: 2),
          RingDrillText(
            secondary!,
            overrides: secondaryOverrides,
            style: theme.textTheme.bodySmall?.copyWith(
              color: fg.withValues(alpha: 0.75),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}
