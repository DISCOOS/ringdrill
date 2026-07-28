import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/staff.dart';
import 'package:ringdrill/views/widgets/app_user_role_selector.dart';

/// Material's default segment padding, and the chrome it costs per segment: the
/// padding on both sides plus the 1px divider.
const _kRoomyPadding = EdgeInsets.symmetric(horizontal: 12);
const _kRoomyChrome = 26.0;

/// The tightened padding used once the label needs the room, and its chrome.
const _kTightPadding = EdgeInsets.symmetric(horizontal: 4);
const _kTightChrome = 10.0;

/// Icon box plus the gap to the label.
const _kIconWidth = 16.0 + 8.0;

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
/// **Always one row.** `SegmentedButton` neither ellipsizes nor shrinks, so at
/// phone width it wrapped the labels mid-word ("Veilede / r"). Two earlier attempts
/// were worse: an icon-only control fits but cannot be read, and wrapping chips left
/// an orphan on a second row. So the control keeps its labels on one line and gives
/// up other things in order, measuring at each step rather than guessing a
/// breakpoint — which also means it holds for a longer translation and for a user who
/// has scaled their text up:
///
/// 1. **Icons** go first. They are the cheapest thing to lose; the labels say the
///    same thing.
/// 2. **Padding** tightens next, which buys about 16px per segment.
/// 3. **The label shrinks**, down to a floor of [_kMinLabelSize]. Four Norwegian
///    role names fit a 420px phone at roughly 13px, so this is usually the step that
///    settles it.
/// 4. **Ellipsis** as the last resort, below the floor. "Øvelsesled…" on one line
///    beats a legible word broken across two.
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
    final labels = {
      for (final role in StaffRole.values) role: staffRoleLabel(role, l10n),
    };
    final baseStyle =
        theme.textTheme.labelLarge ?? const TextStyle(fontSize: 14);
    final baseSize = baseStyle.fontSize ?? 14;
    final scaler = MediaQuery.textScalerOf(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final perSegment = constraints.maxWidth / StaffRole.values.length;
          double widestAt(double size) => labels.values
              .map(
                (label) => _textWidth(
                  label,
                  baseStyle.copyWith(fontSize: size),
                  scaler,
                ),
              )
              .fold<double>(0, (a, b) => a > b ? a : b);

          // Step 1: icons, at the full label size and the roomy padding.
          final withIcons =
              widestAt(baseSize) + _kRoomyChrome + _kIconWidth <= perSegment;
          if (withIcons) {
            return _segmented(labels, baseStyle, _kRoomyPadding, icons: true);
          }
          // Step 2: no icons, still roomy.
          if (widestAt(baseSize) + _kRoomyChrome <= perSegment) {
            return _segmented(labels, baseStyle, _kRoomyPadding, icons: false);
          }
          // Step 3: tighten, then shrink toward the floor.
          var size = baseSize;
          while (size > _kMinLabelSize &&
              widestAt(size) + _kTightChrome > perSegment) {
            size -= 0.5;
          }
          return _segmented(
            labels,
            baseStyle.copyWith(fontSize: size),
            _kTightPadding,
            icons: false,
            // Step 4: below the floor nothing fits, so clip rather than wrap.
            ellipsize: widestAt(size) + _kTightChrome > perSegment,
          );
        },
      ),
    );
  }

  Widget _segmented(
    Map<StaffRole, String> labels,
    TextStyle style,
    EdgeInsets padding, {
    required bool icons,
    bool ellipsize = false,
  }) {
    return SegmentedButton<StaffRole>(
      multiSelectionEnabled: true,
      emptySelectionAllowed: true,
      showSelectedIcon: false,
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: WidgetStatePropertyAll(padding),
        // copyWith off the theme style, never a bare TextStyle: a bare one drops
        // the font family, which silently changes the metrics this widget just
        // measured against.
        textStyle: WidgetStatePropertyAll(style),
      ),
      segments: [
        for (final role in StaffRole.values)
          ButtonSegment<StaffRole>(
            value: role,
            icon: icons ? Icon(staffRoleIcon(role), size: 16) : null,
            label: Text(
              labels[role]!,
              maxLines: 1,
              softWrap: false,
              overflow: ellipsize ? TextOverflow.ellipsis : TextOverflow.clip,
            ),
            tooltip: ellipsize ? labels[role] : null,
          ),
      ],
      selected: selected,
      onSelectionChanged: onChanged,
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
