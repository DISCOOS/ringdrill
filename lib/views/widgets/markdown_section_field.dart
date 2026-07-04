import 'package:flutter/material.dart';
import 'package:ringdrill/views/widgets/editor_token.dart';
import 'package:ringdrill/views/widgets/token_insertion_menu.dart';
import 'package:ringdrill/views/widgets/token_text_editing_controller.dart';

/// Labelled multi-line markdown field shared by [OptionalFieldSections] and
/// the DESIGN-008 section-navigated editor bodies, so both paths build the
/// same field the same way.
///
/// A plain [TextFormField] by default. [tokenAware] (DESIGN-008 Stage 4)
/// opts a field into rendering `{{var.<name>}}` as a colored/boxed chip
/// (see `docs/notes/design-008-token-field-spike.md` for why not an inline
/// widget) and attaching the `/`/`{{` insertion menu — every param defaults
/// off, so `OptionalFieldSections` (the flag-off path) and any caller that
/// omits them renders exactly the plain field it always has.
///
/// [expands] makes the field fill its parent's height instead of sizing to
/// [minLines]/[maxLines] — used by a section body that gets the whole
/// screen, so it must sit inside a bounded-height ancestor (e.g. `Expanded`
/// in a `Column`).
class MarkdownSectionField extends StatefulWidget {
  const MarkdownSectionField({
    super.key,
    required this.controller,
    required this.label,
    this.focusNode,
    this.minLines = 2,
    this.maxLines = 8,
    this.expands = false,
    this.onRemove,
    this.tokenAware = false,
    this.variables = const [],
    this.planFields = const [],
    this.onCreateVariable,
  });

  /// Owned by the caller (the form), read at save time. When [tokenAware]
  /// is true this field mirrors user edits into it via an internal
  /// [TokenTextEditingController] rather than handing it directly to the
  /// [TextFormField] — see [_MarkdownSectionFieldState].
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

  /// Opts this field into chip rendering and the insertion menu. Only the
  /// flag-on Program editor sets this — `AppFlags.planVariables` is never
  /// checked inside this widget; the caller supplying token data *is* the
  /// gate.
  final bool tokenAware;
  final List<VariableToken> variables;
  final List<PlanFieldToken> planFields;
  final ValueChanged<String>? onCreateVariable;

  @override
  State<MarkdownSectionField> createState() => _MarkdownSectionFieldState();
}

class _MarkdownSectionFieldState extends State<MarkdownSectionField> {
  TokenTextEditingController? _tokenController;
  FocusNode? _ownedFocusNode;

  FocusNode get _focusNode => widget.focusNode ?? (_ownedFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    if (widget.tokenAware) _attachTokenController();
  }

  @override
  void didUpdateWidget(MarkdownSectionField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A changed owned-controller identity means this State was reused for
    // a logically different field (e.g. two sections without a
    // distinguishing key landing in the same tree slot) — reseed rather
    // than keep editing the previous field's text under the new one's
    // controller.
    final controllerChanged = oldWidget.controller != widget.controller;
    if (widget.tokenAware && (_tokenController == null || controllerChanged)) {
      _detachTokenController();
      _attachTokenController();
    } else if (!widget.tokenAware && _tokenController != null) {
      _detachTokenController();
    } else if (_tokenController != null) {
      _tokenController!.variables = widget.variables;
    }
  }

  @override
  void dispose() {
    _detachTokenController();
    _ownedFocusNode?.dispose();
    super.dispose();
  }

  void _attachTokenController() {
    final controller = TokenTextEditingController(
      text: widget.controller.text,
      variables: widget.variables,
    );
    controller.addListener(_syncToOwnedController);
    _tokenController = controller;
  }

  void _detachTokenController() {
    _tokenController?.removeListener(_syncToOwnedController);
    _tokenController?.dispose();
    _tokenController = null;
  }

  /// The field edits [_tokenController] (so chips render); this mirrors
  /// every change back into [MarkdownSectionField.controller], the plain
  /// controller the form owns and reads at save time.
  void _syncToOwnedController() {
    final tokenController = _tokenController!;
    if (widget.controller.text != tokenController.text) {
      widget.controller.value = widget.controller.value.copyWith(
        text: tokenController.text,
        selection: tokenController.selection,
        composing: tokenController.value.composing,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveController = _tokenController ?? widget.controller;
    final field = TextFormField(
      controller: effectiveController,
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

    if (!widget.tokenAware) return field;
    return TokenInsertionMenu(
      controller: effectiveController,
      focusNode: _focusNode,
      variables: widget.variables,
      planFields: widget.planFields,
      onCreateVariable: widget.onCreateVariable,
      child: field,
    );
  }
}
