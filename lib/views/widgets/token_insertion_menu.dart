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
_Trigger? _detectTrigger(String text, int caret) {
  if (caret < 0 || caret > text.length) return null;
  final before = text.substring(0, caret);

  final brace = RegExp(r'\{\{(\w*)$').firstMatch(before);
  if (brace != null) {
    return _Trigger(start: brace.start, filter: brace.group(1)!);
  }

  final slash = RegExp(r'(?:^|\s)/(\w*)$').firstMatch(before);
  if (slash != null) {
    return _Trigger(start: before.lastIndexOf('/'), filter: slash.group(1)!);
  }

  return null;
}

/// Wraps a token-aware field with the DESIGN-008 `/`/`{{` insertion menu:
/// an [OverlayEntry] anchored just below the field (via
/// [CompositedTransformTarget]/[CompositedTransformFollower], per the "no
/// `position: fixed` hacks" ground rule), shown while the caret sits right
/// after an unclosed `{{` or a `/` command, and dismissed on Escape, on a
/// tap outside, or once the caret moves away from the trigger.
///
/// This does not track the exact caret pixel inside a (possibly multi-line)
/// field — it anchors at the field's own bounding box, a deliberate
/// simplification given the cost of reaching into `RenderEditable` through
/// an opaque child. The menu still opens/closes/filters/inserts correctly;
/// only its exact on-screen position is approximate.
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
  final _link = LayerLink();
  OverlayEntry? _entry;
  _Trigger? _trigger;

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
    if (_entry == null) {
      _showMenu();
    } else {
      _entry!.markNeedsBuild();
    }
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
  }

  List<TokenMenuEntry> _filteredEntries(String filter) {
    final lower = filter.toLowerCase();
    final entries = <TokenMenuEntry>[
      for (final v in widget.variables)
        if (filter.isEmpty || v.name.toLowerCase().contains(lower))
          VariableMenuEntry(v),
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
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _hideMenu,
          ),
        ),
        CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 4),
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
      child: CompositedTransformTarget(link: _link, child: widget.child),
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
