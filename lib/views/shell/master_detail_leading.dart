import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/shell/master_detail_scope.dart';

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
      return IconButton(
        icon: const Icon(CupertinoIcons.sidebar_left),
        onPressed: onToggleMaster,
        tooltip: localizations.masterPaneToggle,
      );
    }
    return IconButton(
      icon: const Icon(Icons.close),
      onPressed: onClose,
      tooltip: localizations.briefClose,
    );
  }
}
