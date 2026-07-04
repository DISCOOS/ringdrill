import 'package:flutter/material.dart';
import 'package:ringdrill/views/widgets/editor_token.dart';
import 'package:ringdrill/views/widgets/plan_scope.dart';
import 'package:ringdrill/views/widgets/token_insertion_menu.dart';
import 'package:ringdrill/views/widgets/token_text_editing_controller.dart';

/// Effective [VariableToken] list for a token-aware field: [PlanScope]'s
/// declared variables, each value shadowed by [overrides] when present —
/// the same "declared value, then override wins" rule
/// `BriefRenderer._effectiveVariables` applies server-side (ADR-0046). A
/// field only ever has one `overrides` map (its own entity's
/// `variableOverrides`, or none at program scope), so there is no
/// exercise/station cascade to apply here — the caller already resolved
/// which single map (if any) applies to this field's scope.
List<VariableToken> _effectiveTokens(
  BuildContext context,
  Map<String, String> overrides,
) {
  final declared = PlanScope.of(context).variables;
  return [
    for (final v in declared)
      VariableToken(name: v.name, effectiveValue: overrides[v.name] ?? v.value),
  ];
}

/// Wraps [field] with the DESIGN-008 token-aware chrome when [tokenAware]
/// is true: computes the effective variable list (see [_effectiveTokens])
/// and pushes it into [controller] on every build — the `PlanScope`-driven
/// replacement for the manual per-controller refresh earlier DESIGN-008
/// stages did by hand — then wraps in [TokenInsertionMenu]. Returns [field]
/// unchanged, performing no [PlanScope] lookup at all, when [tokenAware] is
/// false, so the flag-off legacy path gains zero new dependencies.
Widget _wrapTokenAware({
  required BuildContext context,
  required Widget field,
  required bool tokenAware,
  required TextEditingController controller,
  required FocusNode focusNode,
  required Map<String, String> overrides,
  required List<PlanFieldToken> planFields,
  required ValueChanged<String>? onCreateVariable,
}) {
  if (!tokenAware) return field;
  assert(
    controller is TokenTextEditingController,
    'A tokenAware RingDrillTextField/RingDrillTextArea requires its '
    'controller to be a TokenTextEditingController, got '
    '${controller.runtimeType}.',
  );
  final tokenController = controller as TokenTextEditingController;
  final variables = _effectiveTokens(context, overrides);
  tokenController.variables = variables;
  return TokenInsertionMenu(
    controller: tokenController,
    focusNode: focusNode,
    variables: variables,
    planFields: planFields,
    onCreateVariable: onCreateVariable,
    child: field,
  );
}

/// Single-line counterpart to [RingDrillTextArea] — same token-aware
/// behavior, shared with it via [_wrapTokenAware], for name/description-like
/// fields. Not yet wired to any call site: DESIGN-008 follow-up 03 lays
/// this foundation without resolving variables in names/descriptions on a
/// live display surface — that is a later follow-up.
class RingDrillTextField extends StatefulWidget {
  const RingDrillTextField({
    super.key,
    required this.controller,
    required this.label,
    this.focusNode,
    this.tokenAware = false,
    this.overrides = const {},
    this.planFields = const [],
    this.onCreateVariable,
  });

  /// Owned by the caller, as with any Flutter form field. When
  /// [tokenAware] is true, this must be a [TokenTextEditingController]
  /// (asserted in debug mode) — see [_wrapTokenAware].
  final TextEditingController controller;
  final String label;
  final FocusNode? focusNode;

  /// Opts this field into chip rendering and the insertion menu, reading
  /// [PlanScope]. Only a caller that has provided a [PlanScope] ancestor
  /// should set this true.
  final bool tokenAware;

  /// This field's own scope override map (e.g. an `Exercise`'s
  /// `variableOverrides`), or empty at a scope with none (e.g. program).
  final Map<String, String> overrides;
  final List<PlanFieldToken> planFields;
  final ValueChanged<String>? onCreateVariable;

  @override
  State<RingDrillTextField> createState() => _RingDrillTextFieldState();
}

class _RingDrillTextFieldState extends State<RingDrillTextField> {
  FocusNode? _ownedFocusNode;

  FocusNode get _focusNode => widget.focusNode ?? (_ownedFocusNode ??= FocusNode());

  @override
  void dispose() {
    _ownedFocusNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final field = TextFormField(
      controller: widget.controller,
      focusNode: widget.tokenAware ? _focusNode : widget.focusNode,
      decoration: InputDecoration(labelText: widget.label),
    );
    return _wrapTokenAware(
      context: context,
      field: field,
      tokenAware: widget.tokenAware,
      controller: widget.controller,
      focusNode: _focusNode,
      overrides: widget.overrides,
      planFields: widget.planFields,
      onCreateVariable: widget.onCreateVariable,
    );
  }
}

/// Multi-line markdown field shared by [OptionalFieldSections] and the
/// DESIGN-008 section-navigated editor bodies, so both paths build the
/// same field the same way. Subsumes the earlier `MarkdownSectionField`
/// (DESIGN-008 Stage 3/4) — same shape, now driven by [PlanScope] instead
/// of an explicit `variables:` list.
///
/// A plain [TextFormField] by default. [tokenAware] (DESIGN-008 Stage 4,
/// now [PlanScope]-driven per follow-up 03) opts a field into rendering
/// `{{var.<name>}}` as a colored/boxed chip (see
/// `docs/notes/design-008-token-field-spike.md` for why not an inline
/// widget) and attaching the `/`/`{{` insertion menu — every param
/// defaults off, so [OptionalFieldSections] (the flag-off path) and any
/// caller that omits them renders exactly the plain field it always has,
/// with no [PlanScope] lookup at all.
///
/// [expands] makes the field fill its parent's height instead of sizing to
/// [minLines]/[maxLines] — used by a section body that gets the whole
/// screen, so it must sit inside a bounded-height ancestor (e.g.
/// `Expanded` in a `Column`).
class RingDrillTextArea extends StatefulWidget {
  const RingDrillTextArea({
    super.key,
    required this.controller,
    required this.label,
    this.focusNode,
    this.minLines = 2,
    this.maxLines = 8,
    this.expands = false,
    this.onRemove,
    this.tokenAware = false,
    this.overrides = const {},
    this.planFields = const [],
    this.onCreateVariable,
  });

  /// Owned by the caller, as with any Flutter form field. When
  /// [tokenAware] is true, this must be a [TokenTextEditingController]
  /// (asserted in debug mode) — see [_wrapTokenAware].
  final TextEditingController controller;
  final String label;
  final FocusNode? focusNode;
  final int minLines;
  final int maxLines;
  final bool expands;

  /// Shows a trailing close button that calls this when pressed. Omitted
  /// (null) where removal is handled elsewhere, e.g. a section's overflow
  /// menu (ADR-0031).
  final VoidCallback? onRemove;

  /// Opts this field into chip rendering and the insertion menu, reading
  /// [PlanScope]. Only a caller that has provided a [PlanScope] ancestor
  /// should set this true.
  final bool tokenAware;

  /// This field's own scope override map (e.g. a `Station`'s
  /// `variableOverrides`), or empty at a scope with none (e.g. program).
  final Map<String, String> overrides;
  final List<PlanFieldToken> planFields;
  final ValueChanged<String>? onCreateVariable;

  @override
  State<RingDrillTextArea> createState() => _RingDrillTextAreaState();
}

class _RingDrillTextAreaState extends State<RingDrillTextArea> {
  FocusNode? _ownedFocusNode;

  FocusNode get _focusNode => widget.focusNode ?? (_ownedFocusNode ??= FocusNode());

  @override
  void dispose() {
    _ownedFocusNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final field = TextFormField(
      controller: widget.controller,
      focusNode: widget.tokenAware ? _focusNode : widget.focusNode,
      keyboardType: TextInputType.multiline,
      minLines: widget.expands ? null : widget.minLines,
      maxLines: widget.expands ? null : widget.maxLines,
      expands: widget.expands,
      textAlignVertical: widget.expands ? TextAlignVertical.top : null,
      decoration: InputDecoration(
        labelText: widget.label,
        alignLabelWithHint: true,
        suffixIcon: widget.onRemove == null
            ? null
            : IconButton(icon: const Icon(Icons.close), onPressed: widget.onRemove),
      ),
    );
    return _wrapTokenAware(
      context: context,
      field: field,
      tokenAware: widget.tokenAware,
      controller: widget.controller,
      focusNode: _focusNode,
      overrides: widget.overrides,
      planFields: widget.planFields,
      onCreateVariable: widget.onCreateVariable,
    );
  }
}
