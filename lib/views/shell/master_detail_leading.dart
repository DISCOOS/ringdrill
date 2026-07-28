import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/shell/master_detail_scope.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';

/// Shared `leading` control for every detail screen's AppBar (and the wide
/// empty-pane placeholder).
///
/// In the wide master/detail layout there is no reason to "close" the
/// selected item back to an empty pane — you switch items or collapse the
/// master list instead. So whenever a [MasterDetailScope] with a collapse
/// toggle wired up is in scope, this renders that toggle
/// (`CupertinoIcons.sidebar_left`) in place of the close-X. Otherwise (no
/// scope, or a scope with no toggle) it falls back to the ordinary close-X,
/// which is what narrow (full-screen sheet) layout sees.
class MasterDetailLeading extends StatelessWidget {
  const MasterDetailLeading({super.key, required this.onClose});

  /// Closes the detail — pops the route or dismisses the context sheet.
  /// Ignored while the sidebar toggle is shown instead.
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final onToggleMaster = MasterDetailScope.maybeOf(context)?.onToggleMaster;
    if (onToggleMaster != null) {
      // Left-only padding: unlike the close-X (which sits flush against
      // the AppBar's usual leading inset), this toggle sits right at the
      // seam between the master and detail panes and reads as cramped
      // against it without extra breathing room on that side only.
      return Padding(
        padding: const EdgeInsets.only(left: 8),
        child: IconButton(
          icon: const Icon(CupertinoIcons.sidebar_left),
          onPressed: onToggleMaster,
          tooltip: localizations.masterPaneToggle,
        ),
      );
    }
    // Inside the fullscreen player the affordance is a chevron-down, not an X:
    // it dismisses back to the mini bar without stopping anything, which is what
    // a downward chevron says and what an X does not — DESIGN-001 specified the
    // chevron from the start, and the X was drift.
    //
    // `isInline` is the test because that is exactly what it means: a host
    // rendering the target itself, which today is only the player. No extra
    // plumbing, and it cannot get out of step with which surface is the player.
    final inPlayer = ContextSheet.maybeOf(context)?.isInline ?? false;
    return IconButton(
      icon: Icon(inPlayer ? Icons.keyboard_arrow_down : Icons.close),
      onPressed: onClose,
      tooltip: localizations.briefClose,
    );
  }
}
