import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/utils/variable_values.dart';
import 'package:ringdrill/views/widgets/editor_token.dart';
import 'package:ringdrill/views/widgets/plan_scope.dart';
import 'package:ringdrill/views/widgets/station_scope.dart';
import 'package:ringdrill/views/widgets/token_insertion_menu.dart';
import 'package:ringdrill/views/widgets/token_text_editing_controller.dart';
import 'package:ringdrill/views/widgets/variable_type_labels.dart';

/// Effective [VariableToken] list for a token-aware field: [PlanScope]'s
/// declared variables, each value shadowed by [overrides] when present —
/// the same "declared value, then override wins" rule
/// `BriefRenderer._effectiveVariables` applies server-side (ADR-0046). A
/// field only ever has one `overrides` map (its own entity's
/// `variableOverrides`, or none at program scope), so there is no
/// exercise/station cascade to apply here — the caller already resolved
/// which single map (if any) applies to this field's scope.
///
/// The effective value is the *display* rendering, formatted for the
/// variable's declared type (DESIGN-008 follow-up 11) — it feeds the
/// slash-menu preview and the chip's empty/amber state, both of which
/// should read like the brief renders (canonical → formatted).
List<VariableToken> _effectiveTokens(
  BuildContext context,
  Map<String, String> overrides,
) {
  final declared = PlanScope.of(context).variables;
  final format = variableFormatOf(AppLocalizations.of(context)!);
  return [
    for (final v in declared)
      VariableToken(
        name: v.name,
        effectiveValue: formatVariableValue(
          applyVariableOverride(v, overrides[v.name]),
          format,
        ),
      ),
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
  required String Function(String label)? onCreateLocation,
  required String Function(String label)? onCreatePerson,
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
  // Optional: only a caller editing under a StationScope (station and
  // roleplay editors) gets `station.loc`/`station.person` chip coloring
  // (ADR-0047, DESIGN-009 follow-up 4). Program/Exercise fields have no
  // station in scope, so this stays null there and the tokens render as
  // plain text, same as before this field existed.
  final stationScope = StationScope.maybeOf(context);
  tokenController.stationTokenResolver = stationScope?.resolve;
  return TokenInsertionMenu(
    controller: tokenController,
    focusNode: focusNode,
    variables: variables,
    planFields: planFields,
    stationLocations: stationScope?.locationTokens ?? const [],
    stationPersons: stationScope?.personTokens ?? const [],
    onCreateVariable: onCreateVariable,
    onCreateLocation: stationScope == null ? null : onCreateLocation,
    onCreatePerson: stationScope == null ? null : onCreatePerson,
    child: field,
  );
}

/// Single-line counterpart to [RingDrillTextArea] — same token-aware
/// behavior, shared with it via [_wrapTokenAware], for name/description-like
/// fields. First wired to a call site in DESIGN-008 follow-up 09: every
/// editor's name field.
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
    this.onCreateLocation,
    this.onCreatePerson,
    this.validator,
    this.autofocus = false,
    this.hintText,
    this.onChanged,
    this.showLabel = true,
  });

  /// Owned by the caller, as with any Flutter form field. When
  /// [tokenAware] is true, this must be a [TokenTextEditingController]
  /// (asserted in debug mode) — see [_wrapTokenAware].
  final TextEditingController controller;
  final String label;
  final FocusNode? focusNode;

  /// Whether [label] renders as the field's own floating `labelText`.
  /// Default `true` — the normal case, where this field is its own only
  /// label. Set `false` when a caller already shows [label] itself right
  /// above the field (e.g. `RolePlayFormScreen`'s identity override panel,
  /// which labels every facet the same way) — [label] is still required
  /// so callers keep the value for that outer label, but this field no
  /// longer duplicates it inside its own decoration.
  final bool showLabel;

  /// Notified on every keystroke. Optional — a caller only needs this when
  /// something *outside* this field's own [controller] must react live
  /// (e.g. a sibling effective-identity preview in `RolePlayFormScreen`);
  /// the field's own chip rendering already reacts to the controller's own
  /// `notifyListeners()` regardless of whether this is set.
  final ValueChanged<String>? onChanged;

  /// Opts this field into chip rendering and the insertion menu, reading
  /// [PlanScope]. Only a caller that has provided a [PlanScope] ancestor
  /// should set this true.
  final bool tokenAware;

  /// This field's own scope override map (e.g. an `Exercise`'s
  /// `variableOverrides`), or empty at a scope with none (e.g. program).
  final Map<String, String> overrides;
  final List<PlanFieldToken> planFields;
  final ValueChanged<String>? onCreateVariable;

  /// Inline-create hooks for the picker's "Create location/person «x»"
  /// entries (ADR-0047, DESIGN-009 follow-up 4) — see
  /// [TokenInsertionMenu.onCreateLocation]/`onCreatePerson`. Only take
  /// effect when this field also has a `StationScope` ancestor; ignored (as
  /// if null) otherwise, same as [tokenAware]'s own `station.loc`/
  /// `station.person` entries being empty without one.
  final String Function(String label)? onCreateLocation;
  final String Function(String label)? onCreatePerson;
  final FormFieldValidator<String>? validator;
  final bool autofocus;

  /// Placeholder shown while the field is empty, e.g. a name's example text.
  final String? hintText;

  @override
  State<RingDrillTextField> createState() => _RingDrillTextFieldState();
}

class _RingDrillTextFieldState extends State<RingDrillTextField> {
  FocusNode? _ownedFocusNode;

  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownedFocusNode ??= FocusNode());

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
      decoration: InputDecoration(
        labelText: widget.showLabel ? widget.label : null,
        hintText: widget.hintText,
      ),
      validator: widget.validator,
      autofocus: widget.autofocus,
      onChanged: widget.onChanged,
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
      onCreateLocation: widget.onCreateLocation,
      onCreatePerson: widget.onCreatePerson,
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
    this.onCreateLocation,
    this.onCreatePerson,
    this.hintText,
    this.hintMaxLines,
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

  /// Placeholder shown while the field is empty, e.g. a description's
  /// example text.
  final String? hintText;
  final int? hintMaxLines;

  /// Opts this field into chip rendering and the insertion menu, reading
  /// [PlanScope]. Only a caller that has provided a [PlanScope] ancestor
  /// should set this true.
  final bool tokenAware;

  /// This field's own scope override map (e.g. a `Station`'s
  /// `variableOverrides`), or empty at a scope with none (e.g. program).
  final Map<String, String> overrides;
  final List<PlanFieldToken> planFields;
  final ValueChanged<String>? onCreateVariable;

  /// Inline-create hooks for the picker's "Create location/person «x»"
  /// entries (ADR-0047, DESIGN-009 follow-up 4) — see
  /// [RingDrillTextField.onCreateLocation]/`onCreatePerson`.
  final String Function(String label)? onCreateLocation;
  final String Function(String label)? onCreatePerson;

  @override
  State<RingDrillTextArea> createState() => _RingDrillTextAreaState();
}

class _RingDrillTextAreaState extends State<RingDrillTextArea> {
  FocusNode? _ownedFocusNode;

  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownedFocusNode ??= FocusNode());

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
        hintText: widget.hintText,
        hintMaxLines: widget.hintMaxLines,
        alignLabelWithHint: true,
        suffixIcon: widget.onRemove == null
            ? null
            : IconButton(
                icon: const Icon(Icons.close),
                onPressed: widget.onRemove,
              ),
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
      onCreateLocation: widget.onCreateLocation,
      onCreatePerson: widget.onCreatePerson,
    );
  }
}
