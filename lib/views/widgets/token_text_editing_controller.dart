import 'package:flutter/material.dart';
import 'package:ringdrill/views/widgets/editor_token.dart';

/// Matches `{{var.<name>}}` (whitespace-tolerant). Kept in sync by hand with
/// the server-side pattern in `lib/services/brief/brief_renderer.dart`
/// (`_varTokenPattern`) — duplicated deliberately, since the renderer is a
/// pure model/services concern and this controller is a view concern
/// (DESIGN-008 Stage 2 vs Stage 4). Only `var.*` participates in chip
/// validation (ADR-0046); every other `{{...}}` expression is left as
/// ordinary text.
final tokenPattern = RegExp(r'\{\{\s*var\.([a-z][a-z0-9_]*)\s*\}\}');

/// A [TextEditingController] that renders `{{var.<name>}}` tokens as
/// colored, boxed text instead of plain text — DESIGN-008 Stage 4's chosen
/// representation after the prototype gate rejected an inline `WidgetSpan`
/// chip for caret/backspace correctness (see
/// `docs/notes/design-008-token-field-spike.md`).
///
/// [buildTextSpan] is a pure render-time projection: [text] itself is
/// always left as the raw markdown with literal `{{var.name}}`, so
/// `BriefRenderer` keeps seeing plain mustache (the DESIGN-004 constraint).
class TokenTextEditingController extends TextEditingController {
  TokenTextEditingController({super.text, List<VariableToken> variables = const []})
    : _variables = variables;

  List<VariableToken> _variables;

  List<VariableToken> get variables => _variables;

  /// Updates the resolved variable list (e.g. the registry or the scope
  /// changed) without recreating the controller, so callers do not lose
  /// the current selection/focus.
  set variables(List<VariableToken> value) {
    _variables = value;
    notifyListeners();
  }

  VariableToken? _lookup(String name) {
    for (final v in _variables) {
      if (v.name == name) return v;
    }
    return null;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final matches = tokenPattern.allMatches(text);
    if (matches.isEmpty) {
      return TextSpan(text: text, style: style);
    }

    final children = <InlineSpan>[];
    var cursor = 0;
    for (final match in matches) {
      if (match.start > cursor) {
        children.add(
          TextSpan(text: text.substring(cursor, match.start), style: style),
        );
      }
      children.add(
        TextSpan(
          text: match.group(0),
          style: _chipStyle(style, _lookup(match.group(1)!)),
        ),
      );
      cursor = match.end;
    }
    if (cursor < text.length) {
      children.add(TextSpan(text: text.substring(cursor), style: style));
    }
    return TextSpan(style: style, children: children);
  }

  static TextStyle _chipStyle(TextStyle? base, VariableToken? token) {
    final b = base ?? const TextStyle();
    if (token == null) {
      return b.copyWith(
        color: Colors.red.shade800,
        backgroundColor: Colors.red.withValues(alpha: 0.12),
        decoration: TextDecoration.underline,
        decorationColor: Colors.red.shade800,
        decorationStyle: TextDecorationStyle.dashed,
      );
    }
    if (token.isEmpty) {
      return b.copyWith(
        color: Colors.amber.shade900,
        backgroundColor: Colors.amber.withValues(alpha: 0.2),
      );
    }
    return b.copyWith(
      color: Colors.blue.shade800,
      backgroundColor: Colors.blue.withValues(alpha: 0.15),
    );
  }
}
