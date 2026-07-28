import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/staff.dart';
import 'package:ringdrill/views/widgets/app_user_role_selector.dart';

/// Horizontal padding inside each segment, on each side.
const _kSegmentPadding = 12.0;

/// `ToggleButtons`' own per-segment chrome — borders and internal insets — on top of
/// [_kSegmentPadding]. Measured rather than derived: the widget's layout is not
/// documented in a way that lets this be computed, so it is a calibration constant.
/// The scroll wrapper below means an underestimate degrades to a scrollable row
/// rather than an overflow, which is why an approximate figure is safe here.
const _kToggleChrome = 12.0;

/// Icon box plus the gap to the label.
const _kIconWidth = 16.0 + 6.0;

/// The smallest the label is allowed to get. Material's `labelSmall` is 11, so this
/// is the bottom of the sanctioned range rather than an arbitrary floor.
const _kMinLabelSize = 11.0;

/// Segmented role filter above a staff list.
///
/// Multi-select rather than single: "show me the øvelsesledere *and* veiledere" is
/// a real question, and a single-select would answer it only by making the user
/// look twice. Nothing selected means **no filter** — every member shows — which is
/// also why this is not a `SegmentedButton` with `emptySelectionAllowed: false`.
///
/// Filters on [StaffRoles.effectiveRoles], not the stored set, so a member who is
/// cast to a roleplay but was never ticked as an actor still appears under the actor
/// filter. Filtering on the stored set would hide exactly the people the cast
/// picker exists to find.
///
/// **Each segment is as wide as its own label, and the row is centred.**
///
/// `SegmentedButton` cannot do that: it equalises every segment to the widest one
/// internally, whatever constraints it is given. With four Norwegian role names that
/// makes every segment as wide as "Øvelsesleder" — the row then overflows a phone,
/// and the earlier attempt to rescue it by shrinking clipped the leading "Ø" against
/// the rounded end. Sizing to the text instead removes the problem rather than
/// mitigating it: the four labels total roughly 341px with comfortable padding, which
/// fits a 430px phone at full size with no shrinking and nothing clipped.
///
/// So this is a [ToggleButtons] — the Material control that *does* size children to
/// their content — themed to read as the segmented buttons elsewhere in the app, and
/// wrapped in a [Center].
///
/// The icon still drops when the row would not otherwise fit, measured against the
/// **total** width now rather than a per-segment share, and the label still shrinks
/// toward [_kMinLabelSize] after that. Both are rarely reached now that the segments
/// are not padded out to the widest. Below the floor the row scrolls horizontally,
/// so it can never overflow however long a translation or how large a text scale it
/// is handed.
class StaffRoleFilter extends StatelessWidget {
  const StaffRoleFilter({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  /// Empty means "no filter", not "match nothing".
  final Set<StaffRole> selected;
  final ValueChanged<Set<StaffRole>> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final labels = [
      for (final role in StaffRole.values) staffRoleLabel(role, l10n),
    ];
    final baseStyle =
        theme.textTheme.labelLarge ?? const TextStyle(fontSize: 14);
    final baseSize = baseStyle.fontSize ?? 14;
    final scaler = MediaQuery.textScalerOf(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final available = constraints.maxWidth;
          double totalAt(double size, {required bool icons}) {
            final chrome =
                _kSegmentPadding * 2 +
                _kToggleChrome +
                (icons ? _kIconWidth : 0);
            return labels.fold<double>(
              0,
              (sum, label) =>
                  sum +
                  _textWidth(
                    label,
                    baseStyle.copyWith(fontSize: size),
                    scaler,
                  ) +
                  chrome,
            );
          }

          // Icons first, then the label size — the same order of concessions as
          // before, just measured against the whole row.
          if (totalAt(baseSize, icons: true) <= available) {
            return _scrollable(
              available,
              _buttons(context, labels, baseStyle, icons: true),
            );
          }
          var size = baseSize;
          while (size > _kMinLabelSize &&
              totalAt(size, icons: false) > available) {
            size -= 0.5;
          }
          return _scrollable(
            available,
            _buttons(
              context,
              labels,
              baseStyle.copyWith(fontSize: size),
              icons: false,
            ),
          );
        },
      ),
    );
  }

  /// Centres [row] when it fits and scrolls it when it does not.
  ///
  /// The `minWidth` is what makes both true at once: the child is at least as wide as
  /// the viewport, so [Center] has something to centre within, and free to be wider,
  /// so a row that cannot fit scrolls instead of overflowing.
  ///
  /// This is deliberately structural rather than conditional on the measurement
  /// above. `ToggleButtons`' chrome is a calibration constant, and a measurement that
  /// is a few pixels optimistic would otherwise produce the exact
  /// "RenderFlex overflowed" this widget exists to avoid — at a text scale or in a
  /// translation nobody tested.
  Widget _scrollable(double available, Widget row) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: ConstrainedBox(
      constraints: BoxConstraints(minWidth: available),
      child: Center(child: row),
    ),
  );

  Widget _buttons(
    BuildContext context,
    List<String> labels,
    TextStyle style, {
    required bool icons,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ToggleButtons(
      isSelected: [
        for (final role in StaffRole.values) selected.contains(role),
      ],
      // Multi-select: toggling one leaves the others alone, and an empty set
      // means "no filter".
      onPressed: (index) {
        final role = StaffRole.values[index];
        onChanged({
          for (final r in StaffRole.values)
            if (r == role ? !selected.contains(r) : selected.contains(r)) r,
        });
      },
      borderRadius: BorderRadius.circular(20),
      constraints: const BoxConstraints(minHeight: 32),
      // Themed to read as the SegmentedButtons elsewhere rather than taking
      // ToggleButtons' Material 2 defaults.
      borderColor: scheme.outline,
      selectedBorderColor: scheme.outline,
      color: scheme.onSurface,
      selectedColor: scheme.onSecondaryContainer,
      fillColor: scheme.secondaryContainer,
      textStyle: style,
      children: [
        for (var i = 0; i < labels.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: _kSegmentPadding),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icons) ...[
                  Icon(staffRoleIcon(StaffRole.values[i]), size: 16),
                  const SizedBox(width: 6),
                ],
                // The style goes on the Text, not only on ToggleButtons:
                // `ToggleButtons.textStyle` did not reach the children, so the
                // row rendered at the full size while this widget had measured
                // the shrunken one and concluded it fit. Same trap as passing a
                // bare TextStyle and losing the font family — measure and render
                // must use the identical style.
                Text(labels[i], style: style, maxLines: 1, softWrap: false),
              ],
            ),
          ),
      ],
    );
  }
}

/// Laid-out width of [text] in [style], honouring the user's text scaling.
double _textWidth(String text, TextStyle style, TextScaler scaler) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textScaler: scaler,
    maxLines: 1,
  )..layout();
  return painter.width;
}

/// Applies a [StaffRoleFilter]'s selection to [staff].
///
/// [isCast] answers "is this member cast to any roleplay", which the actor filter
/// needs so an untagged-but-cast member is not hidden. An empty [selected] returns
/// the list unchanged.
List<Staff> filterStaffByRole(
  List<Staff> staff,
  Set<StaffRole> selected, {
  required bool Function(Staff) isCast,
}) {
  if (selected.isEmpty) return staff;
  return staff
      .where(
        (member) => member
            .effectiveRoles(isCast: isCast(member))
            .any(selected.contains),
      )
      .toList();
}
