import 'package:flutter/material.dart';
import 'package:ringdrill/utils/plan_variables.dart';
import 'package:ringdrill/utils/station_scenario_tokens.dart';
import 'package:ringdrill/views/widgets/editor_token.dart';

/// Resolves a `{{station.(loc|person).<slug>(.facet)*}}` match to its
/// effective displayed value, or `null` when `slug` is unknown in scope —
/// fed in by the wrapping widget from `StationScope.resolve` (ADR-0047,
/// DESIGN-009 follow-up 4). The controller only ever calls this closure; it
/// never reads `StationScope` itself, matching the DESIGN-008 "widget reads
/// context, controller doesn't" rule [VariableToken]/`variables` already
/// follows.
typedef StationTokenResolver =
    String? Function(String kind, String slug, List<String> facets);

/// A [TextEditingController] that renders `{{var.<name>}}` and (DESIGN-009
/// follow-up 4) `{{station.loc.<slug>}}` / `{{station.person.<slug>}}`
/// tokens as colored, boxed text instead of plain text — DESIGN-008 Stage
/// 4's chosen representation after the prototype gate rejected an inline
/// `WidgetSpan` chip for caret/backspace correctness (see
/// `docs/notes/design-008-token-field-spike.md`).
///
/// [buildTextSpan] is a pure render-time projection: [text] itself is
/// always left as the raw markdown with literal `{{var.name}}` /
/// `{{station...}}`, so `BriefRenderer` keeps seeing plain mustache (the
/// DESIGN-004 constraint).
class TokenTextEditingController extends TextEditingController {
  TokenTextEditingController({super.text, List<VariableToken> variables = const []})
    : _variables = variables;

  List<VariableToken> _variables;
  StationTokenResolver? _stationTokenResolver;

  List<VariableToken> get variables => _variables;

  /// Updates the resolved variable list (e.g. the registry or the scope
  /// changed) without recreating the controller, so callers do not lose
  /// the current selection/focus.
  set variables(List<VariableToken> value) {
    _variables = value;
    notifyListeners();
  }

  /// Updates the station-token resolver (e.g. the enclosing `StationScope`
  /// changed, or there is none). Null when no station is in scope for this
  /// field — every `{{station...}}` match then renders unstyled, plain
  /// text, since [buildTextSpan] never scans for it without a resolver.
  set stationTokenResolver(StationTokenResolver? value) {
    _stationTokenResolver = value;
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
    final resolver = _stationTokenResolver;
    final varMatches = planVariableTokenPattern.allMatches(text);
    final stationMatches = resolver == null
        ? const <RegExpMatch>[]
        : stationScenarioTokenPattern.allMatches(text);
    if (varMatches.isEmpty && stationMatches.isEmpty) {
      return TextSpan(text: text, style: style);
    }

    // `{{var.x}}` and `{{station.(loc|person).x}}` can never overlap (their
    // prefixes diverge right after `{{`), so a plain start-order merge is
    // enough — no interval-tree needed for two small, non-overlapping match
    // sets.
    final matches = <_TokenMatch>[
      for (final m in varMatches) _TokenMatch(m, isVariable: true),
      for (final m in stationMatches) _TokenMatch(m, isVariable: false),
    ]..sort((a, b) => a.match.start.compareTo(b.match.start));

    final children = <InlineSpan>[];
    var cursor = 0;
    for (final entry in matches) {
      final match = entry.match;
      if (match.start > cursor) {
        children.add(
          TextSpan(text: text.substring(cursor, match.start), style: style),
        );
      }
      final chipStyle = entry.isVariable
          ? _variableChipStyle(style, _lookup(match.group(1)!))
          : _stationChipStyle(style, resolver!, match);
      children.add(TextSpan(text: match.group(0), style: chipStyle));
      cursor = match.end;
    }
    if (cursor < text.length) {
      children.add(TextSpan(text: text.substring(cursor), style: style));
    }
    return TextSpan(style: style, children: children);
  }

  static TextStyle _variableChipStyle(TextStyle? base, VariableToken? token) {
    if (token == null) return _chipStyle(base, known: false, empty: false);
    return _chipStyle(base, known: true, empty: token.isEmpty);
  }

  static TextStyle _stationChipStyle(
    TextStyle? base,
    StationTokenResolver resolver,
    RegExpMatch match,
  ) {
    final kind = match.group(1)!;
    final slug = match.group(2)!;
    final facets = stationScenarioTokenFacets(match);
    final value = resolver(kind, slug, facets);
    return _chipStyle(base, known: value != null, empty: value != null && value.isEmpty);
  }

  /// Shared red/amber/blue chip styling: red for an unknown reference
  /// ([known] false), amber for a known reference that currently resolves
  /// empty, blue otherwise.
  static TextStyle _chipStyle(
    TextStyle? base, {
    required bool known,
    required bool empty,
  }) {
    final b = base ?? const TextStyle();
    if (!known) {
      return b.copyWith(
        color: Colors.red.shade800,
        backgroundColor: Colors.red.withValues(alpha: 0.12),
        decoration: TextDecoration.underline,
        decorationColor: Colors.red.shade800,
        decorationStyle: TextDecorationStyle.dashed,
      );
    }
    if (empty) {
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

class _TokenMatch {
  const _TokenMatch(this.match, {required this.isVariable});
  final RegExpMatch match;
  final bool isVariable;
}
