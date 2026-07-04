import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/widgets/editor_token.dart';

/// One entry in the flat DESIGN-008 insertion-menu list. A single list, no
/// group headers: variable entries show their effective value, plan-field
/// entries show a muted "planfelt" hint instead, and — when
/// [TokenInsertionMenu.onCreateVariable] is supplied and nothing else
/// matches — a trailing "Opprett variabel «x»" entry.
sealed class TokenMenuEntry {
  const TokenMenuEntry();
}

class VariableMenuEntry extends TokenMenuEntry {
  const VariableMenuEntry(this.token);
  final VariableToken token;
}

class PlanFieldMenuEntry extends TokenMenuEntry {
  const PlanFieldMenuEntry(this.token);
  final PlanFieldToken token;
}

class CreateVariableMenuEntry extends TokenMenuEntry {
  const CreateVariableMenuEntry(this.name);
  final String name;
}

class _Trigger {
  const _Trigger({required this.start, required this.filter});

  /// Index of the trigger's first character (the `/` or the first `{`).
  final int start;
  final String filter;
}

/// `/` opens the command menu; an unclosed `{{` opens the same picker
/// directly. Both are detected by looking backward from the caret, so
/// typing continues to work as ordinary text until one of these patterns
/// appears right before the caret.
///
/// The `{{` filter allows a `.` (in addition to word characters) so that
/// manually typing the actual token syntax — `{{var.` or `{{exercise.` —
/// keeps the menu open and filtering instead of closing the instant the
/// dot is typed; it only closes once the token itself closes (typing `}`
/// is not a filter character, so a completed `{{var.frekvens}}` no longer
/// matches). The `/` trigger deliberately does not allow `.`: variable
/// names are plain slugs (ADR-0046) with no dotted path to type out.
_Trigger? _detectTrigger(String text, int caret) {
  if (caret < 0 || caret > text.length) return null;
  final before = text.substring(0, caret);

  final brace = RegExp(r'\{\{([\w.]*)$').firstMatch(before);
  if (brace != null) {
    return _Trigger(start: brace.start, filter: brace.group(1)!);
  }

  final slash = RegExp(r'(?:^|\s)/(\w*)$').firstMatch(before);
  if (slash != null) {
    return _Trigger(start: before.lastIndexOf('/'), filter: slash.group(1)!);
  }

  return null;
}

/// A `{{var.` prefix on the filter names the registry namespace explicitly
/// (ADR-0046) rather than being part of any entry's own name — matching it
/// literally against variable names would never succeed. Stripped so
/// `{{var.frek` filters variables by `frek`, the same as typing `/frek`
/// would, instead of showing "no matches" for as long as the prefix is
/// present.
final _varPrefixPattern = RegExp(r'^var\.(.*)$', caseSensitive: false);

/// Wraps a token-aware field with the DESIGN-008 `/`/`{{` insertion menu: an
/// [OverlayEntry] anchored at the caret (via [RenderEditable] found through
/// [FocusNode.context], not a `position: fixed` hack), shown while the
/// caret sits right after an unclosed `{{` or a `/` command, and dismissed
/// on Escape, on a tap outside, or once the caret moves away from the
/// trigger.
///
/// A markdown section body fills the whole screen ([MarkdownSectionField]'s
/// `expands: true`), so anchoring at the *field's* bounding box (an earlier
/// version of this widget did, via [CompositedTransformFollower]) puts the
/// menu at the bottom of the screen for a caret near the top of a long
/// field — anchoring at the caret itself is not optional here.
class TokenInsertionMenu extends StatefulWidget {
  const TokenInsertionMenu({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.child,
    this.variables = const [],
    this.planFields = const [],
    this.onCreateVariable,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Widget child;
  final List<VariableToken> variables;
  final List<PlanFieldToken> planFields;

  /// Wired by the caller once a scope owns a variable registry to mutate
  /// (DESIGN-008 Stage 5). Null keeps the "Opprett variabel" entry hidden.
  final ValueChanged<String>? onCreateVariable;

  @override
  State<TokenInsertionMenu> createState() => TokenInsertionMenuState();
}

/// Public (not the usual `_State` convention) so a widget test can inspect
/// [isMenuOpen] via `tester.state<TokenInsertionMenuState>(...)`.
class TokenInsertionMenuState extends State<TokenInsertionMenu> {
  static const _menuWidth = 280.0;
  static const _menuMaxHeight = 240.0;
  static const _gap = 4.0;

  OverlayEntry? _entry;
  _Trigger? _trigger;
  Rect? _caretRect;

  @visibleForTesting
  bool get isMenuOpen => _entry != null;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(TokenInsertionMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
    _entry?.markNeedsBuild();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _entry?.remove();
    super.dispose();
  }

  void _onChanged() {
    final selection = widget.controller.selection;
    if (!widget.focusNode.hasFocus ||
        !selection.isValid ||
        !selection.isCollapsed) {
      _hideMenu();
      return;
    }
    final trigger = _detectTrigger(widget.controller.text, selection.baseOffset);
    if (trigger == null) {
      _hideMenu();
      return;
    }
    _trigger = trigger;
    // The controller notifies listeners synchronously as soon as its value
    // changes, before EditableText's own listener (registered later, since
    // this widget wraps it) has relaid-out RenderEditable for that change —
    // reading the caret rect right now would be one keystroke stale. Defer
    // to a post-frame callback, once layout has caught up.
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshMenuPosition());
  }

  void _refreshMenuPosition() {
    if (!mounted || _trigger == null) return;
    final rect = _caretGlobalRect();
    if (rect == null) {
      _hideMenu();
      return;
    }
    _caretRect = rect;
    if (_entry == null) {
      _showMenu();
    } else {
      _entry!.markNeedsBuild();
    }
  }

  /// Finds the wrapped field's [RenderEditable] through its own
  /// [FocusNode]: [FocusNode.context] is the `Focus` widget `EditableText`
  /// builds around itself, which is a descendant of [EditableTextState] —
  /// reachable by an ancestor search from there, even though
  /// [TokenInsertionMenu]'s own `context` is on the *other* side (an
  /// ancestor of the field, not a descendant of it).
  Rect? _caretGlobalRect() {
    final focusContext = widget.focusNode.context;
    final editableState = focusContext
        ?.findAncestorStateOfType<EditableTextState>();
    final renderEditable = editableState?.renderEditable;
    if (renderEditable == null || !renderEditable.attached) return null;
    final selection = widget.controller.selection;
    if (!selection.isValid) return null;

    final local = renderEditable.getLocalRectForCaret(
      TextPosition(offset: selection.baseOffset),
    );
    return Rect.fromPoints(
      renderEditable.localToGlobal(local.topLeft),
      renderEditable.localToGlobal(local.bottomLeft),
    );
  }

  void _showMenu() {
    final entry = OverlayEntry(builder: _buildOverlay);
    _entry = entry;
    Overlay.of(context, rootOverlay: true).insert(entry);
  }

  void _hideMenu() {
    if (_entry == null) return;
    _entry!.remove();
    _entry = null;
    _trigger = null;
    _caretRect = null;
  }

  List<TokenMenuEntry> _filteredEntries(String rawFilter) {
    // "var." names the registry namespace, not part of any variable's own
    // name — once typed, narrow to variables only and match the remainder
    // against their names, the same as the bare `/` picker would.
    final varMatch = _varPrefixPattern.firstMatch(rawFilter);
    final filter = varMatch?.group(1) ?? rawFilter;
    final lower = filter.toLowerCase();

    final entries = <TokenMenuEntry>[
      for (final v in widget.variables)
        if (filter.isEmpty || v.name.toLowerCase().contains(lower))
          VariableMenuEntry(v),
      if (varMatch == null)
        for (final f in widget.planFields)
          if (filter.isEmpty ||
              f.name.toLowerCase().contains(lower) ||
              f.label.toLowerCase().contains(lower))
            PlanFieldMenuEntry(f),
    ];
    if (widget.onCreateVariable != null &&
        filter.trim().isNotEmpty &&
        entries.isEmpty) {
      entries.add(CreateVariableMenuEntry(filter.trim()));
    }
    return entries;
  }

  void _select(TokenMenuEntry entry) {
    final trigger = _trigger;
    if (trigger == null) return;
    final caret = widget.controller.selection.baseOffset;
    final text = widget.controller.text;
    final token = switch (entry) {
      VariableMenuEntry(token: final v) => '{{var.${v.name}}}',
      PlanFieldMenuEntry(token: final f) => '{{${f.name}}}',
      CreateVariableMenuEntry(name: final name) => '{{var.$name}}',
    };
    final newText = text.replaceRange(trigger.start, caret, token);
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: trigger.start + token.length),
    );
    if (entry is CreateVariableMenuEntry) {
      widget.onCreateVariable?.call(entry.name);
    }
    _hideMenu();
  }

  Widget _buildOverlay(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final entries = _filteredEntries(_trigger?.filter ?? '');
    final screenSize = MediaQuery.sizeOf(context);
    final caretRect = _caretRect ?? Rect.zero;
    final estimatedHeight = entries.isEmpty ? 48.0 : _menuMaxHeight;

    var left = caretRect.left;
    if (left + _menuWidth > screenSize.width) {
      left = screenSize.width - _menuWidth;
    }
    left = left.clamp(0.0, screenSize.width);

    // Prefer just below the caret line; flip above it if there is not
    // enough room below (e.g. typing on the last visible line of a
    // full-screen markdown section).
    var top = caretRect.bottom + _gap;
    if (top + estimatedHeight > screenSize.height) {
      top = caretRect.top - estimatedHeight - _gap;
    }
    top = top.clamp(0.0, screenSize.height);

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _hideMenu,
          ),
        ),
        Positioned(
          left: left,
          top: top,
          width: _menuWidth,
          child: _TokenMenuCard(
            entries: entries,
            emptyLabel: l10n.tokenMenuEmpty,
            onSelect: _select,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) {
        if (_entry != null &&
            event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          _hideMenu();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: widget.child,
    );
  }
}

class _TokenMenuCard extends StatelessWidget {
  const _TokenMenuCard({
    required this.entries,
    required this.emptyLabel,
    required this.onSelect,
  });

  final List<TokenMenuEntry> entries;
  final String emptyLabel;
  final ValueChanged<TokenMenuEntry> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280, maxHeight: 240),
        child: entries.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(12),
                child: Text(emptyLabel, style: Theme.of(context).textTheme.bodySmall),
              )
            : ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [for (final entry in entries) _tile(context, l10n, entry)],
              ),
      ),
    );
  }

  Widget _tile(BuildContext context, AppLocalizations l10n, TokenMenuEntry entry) {
    final mutedStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      fontStyle: FontStyle.italic,
    );
    return switch (entry) {
      VariableMenuEntry(token: final v) => ListTile(
        dense: true,
        leading: const Icon(Icons.data_object, size: 18),
        title: Text(v.name),
        trailing: Text(v.effectiveValue, style: Theme.of(context).textTheme.bodySmall),
        onTap: () => onSelect(entry),
      ),
      PlanFieldMenuEntry(token: final f) => ListTile(
        dense: true,
        leading: const Icon(Icons.article_outlined, size: 18),
        title: Text(f.label),
        trailing: Text(l10n.tokenMenuPlanFieldHint, style: mutedStyle),
        onTap: () => onSelect(entry),
      ),
      CreateVariableMenuEntry(name: final name) => ListTile(
        dense: true,
        leading: const Icon(Icons.add, size: 18),
        title: Text(l10n.tokenMenuCreateVariable(name)),
        onTap: () => onSelect(entry),
      ),
    };
  }
}
