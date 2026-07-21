import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/utils/external_links.dart';

/// Visual + behavioural shell for an inline code chip.
///
/// Renders the code text inside a padded, rounded `Container` and adds a
/// small copy icon to the right of the text. Tapping anywhere on the chip
/// copies the code content to the clipboard and shows a `SnackBar`
/// confirmation. Hovering over the chip on web/desktop shows a click cursor.
class CodeChip extends StatelessWidget {
  const CodeChip({
    super.key,
    required this.text,
    required this.textStyle,
    required this.backgroundColor,
    this.adornmentStyle,
  });

  final String text;
  final TextStyle textStyle;
  final Color backgroundColor;

  /// Style for parentheses folded into the code span (drawn outside the pill
  /// in the surrounding body style). Falls back to [textStyle] when null.
  final TextStyle? adornmentStyle;

  /// A single surrounding paren pair is treated as adornment: rendered just
  /// outside the pill and excluded from the copied text. Only content with
  /// both a leading `(` and trailing `)` qualifies.
  bool get _hasParens =>
      text.length >= 2 && text.startsWith('(') && text.endsWith(')');

  /// The pill's visible content and the copied text — the coordinate without
  /// the adornment parentheses.
  String get _inner => _hasParens ? text.substring(1, text.length - 1) : text;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _inner));
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(l10n.briefCodeCopied),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final iconColor = textStyle.color?.withValues(alpha: 0.7);

    final pill = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _copy(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                // Wraps so long values (addresses) show in full rather than
                // truncating; short values (coordinates) stay on one line.
                child: Text(_inner, style: textStyle, softWrap: true),
              ),
              const SizedBox(width: 6),
              Tooltip(
                message: l10n.briefCodeCopyTooltip,
                child: Icon(Icons.content_copy, size: 16, color: iconColor),
              ),
            ],
          ),
        ),
      ),
    );

    if (!_hasParens) return pill;

    // Flank the pill with the adornment parentheses inside one Row, so the
    // whole "(pill)" group is a single unbreakable placeholder — the "(" can
    // no longer orphan at a line end.
    final parenStyle = adornmentStyle ?? textStyle;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('(', style: parenStyle),
        pill,
        Text(')', style: parenStyle),
      ],
    );
  }
}

/// A single launch target a chip can run — a map open, a phone dial. Actions
/// are modelled as a list (ADR-0050): a chip with exactly one runs it
/// directly on tap; the `TODO` below is the seam for a context menu once a
/// chip has more than one (no chip does today).
class ChipAction {
  const ChipAction(this.run);

  final Future<void> Function() run;
}

/// Parses a `ringdrill://chip` URI's query parameters into its launch
/// target(s). Empty (no action, degrades to a plain tap-does-nothing chip)
/// for an `action` this version doesn't recognize — forward-compatible with
/// a future action kind rather than crashing.
List<ChipAction> chipActions(Uri uri) {
  final params = uri.queryParameters;
  switch (params['action']) {
    case 'map':
      final lat = params['lat'];
      final lng = params['lng'];
      if (lat == null || lng == null) return const [];
      return [
        ChipAction(
          () => launchExternalApp(
            'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
          ),
        ),
      ];
    case 'call':
      final tel = params['tel'];
      if (tel == null) return const [];
      return [ChipAction(() => launchExternalApp('tel:$tel'))];
    default:
      return const [];
  }
}

/// Renders a `ringdrill://chip` link as a pill matching [_CodeChip]'s look:
/// an [InkWell] over everything *except* the copy icon runs the chip's
/// action(s); the copy icon always copies [text] (never the URI — that
/// scheme must never reach the clipboard). The parens-adornment handling
/// (`(pill)` kept unbreakable, parens excluded from both the action and the
/// copied value) mirrors [_CodeChip].
class CodeActionChip extends StatelessWidget {
  const CodeActionChip({
    super.key,
    required this.text,
    required this.textStyle,
    required this.backgroundColor,
    required this.actions,
    this.adornmentStyle,
  });

  final String text;
  final TextStyle textStyle;
  final Color backgroundColor;
  final List<ChipAction> actions;
  final TextStyle? adornmentStyle;

  bool get _hasParens =>
      text.length >= 2 && text.startsWith('(') && text.endsWith(')');

  String get _inner => _hasParens ? text.substring(1, text.length - 1) : text;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _inner));
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(l10n.briefCodeCopied),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// A single action runs directly on tap (every actionable chip today).
  // TODO(ADR-0050): once a chip carries more than one action, open a context
  // menu here instead of always running the first.
  Future<void> _runAction() async {
    if (actions.isEmpty) return;
    await actions.first.run();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final iconColor = textStyle.color?.withValues(alpha: 0.7);

    final pill = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _runAction,
                child: Text(_inner, style: textStyle, softWrap: true),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _copy(context),
              child: Tooltip(
                message: l10n.briefCodeCopyTooltip,
                child: Icon(Icons.content_copy, size: 16, color: iconColor),
              ),
            ),
          ],
        ),
      ),
    );

    if (!_hasParens) return pill;

    final parenStyle = adornmentStyle ?? textStyle;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('(', style: parenStyle),
        pill,
        Text(')', style: parenStyle),
      ],
    );
  }
}
