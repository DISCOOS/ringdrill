import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/numbering.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/utils/plan_variables.dart';
import 'package:ringdrill/views/position_form_field.dart';
import 'package:ringdrill/views/widgets/dismiss_keyboard.dart';
import 'package:ringdrill/views/widgets/plan_scope.dart';
import 'package:ringdrill/views/widgets/ringdrill_text_field.dart';
import 'package:ringdrill/views/widgets/section_navigated_form.dart';
import 'package:ringdrill/views/widgets/station_number_badge.dart';
import 'package:ringdrill/views/widgets/token_text_editing_controller.dart';

/// Token-aware markdown sections, addable/removable (DESIGN-008
/// follow-up 07). `signalement` is a short field, not markdown, and lives
/// in the always-visible "Rolle" base section instead.
enum _MdSection { background, behavior, props }

/// Edit form for a single [RolePlay].
///
/// Edits the publishable Role fields only: name, age, signalement,
/// background, behavior, stationIndex, and position. The actorUuid
/// (cast assignment) is intentionally absent — casting is managed
/// from the RolePlays list via the cast picker.
///
/// Pops with the updated [RolePlay] on save, or null on cancel.
/// The caller is responsible for persisting the result (same pattern
/// as [StationFormScreen]).
///
/// [exercise] is optional. When provided, the stationIndex dropdown
/// is populated with the exercise's stations.
class RolePlayFormScreen extends StatefulWidget {
  const RolePlayFormScreen({
    super.key,
    required this.rolePlay,
    this.exercise,
    this.variables = const <DrillVariable>[],
  });

  final RolePlay rolePlay;
  final Exercise? exercise;

  /// The plan's declared variables (ADR-0046), read-only here — a roleplay
  /// declares and overrides nothing (DESIGN-008 follow-up 07's settled
  /// scope: no Variabler section). Every call site passes
  /// `program.variables`.
  final List<DrillVariable> variables;

  @override
  State<RolePlayFormScreen> createState() => _RolePlayFormScreenState();
}

class _RolePlayFormScreenState extends State<RolePlayFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _programService = ProgramService();

  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  // Never token-aware — signalement is a short field in the always-visible
  // "Rolle" base section, not one of the three markdown sections.
  final _signalementController = TextEditingController();

  /// Token-aware so `RingDrillTextArea(tokenAware: true)` can drive its
  /// chips from [PlanScope].
  final TextEditingController _backgroundController =
      TokenTextEditingController();
  final TextEditingController _behaviorController =
      TokenTextEditingController();
  final TextEditingController _propsController = TokenTextEditingController();

  final _signalementFocus = FocusNode();
  final _backgroundFocus = FocusNode();
  final _behaviorFocus = FocusNode();
  final _propsFocus = FocusNode();

  late Set<_MdSection> _activeMdSections;
  int? _stationIndex;
  // Tracks the current position; updated by PositionFormField.onSaved
  late RolePlay _rolePlay;
  // Current marker position, kept in sync with the PositionFormField.
  LatLng? _position;
  // True while [_position] still mirrors the selected station's position (a
  // default we may keep updating). Cleared once the user picks a spot on the
  // map, so we never overwrite a manual fine-tune.
  bool _positionFromStation = false;

  /// The station currently selected in the dropdown, or null. Recomputed on
  /// every access (not cached) so it always follows [_stationIndex] live —
  /// a roleplay's effective scope must track the dropdown, not just the
  /// station it opened with.
  Station? get _parentStation {
    final stations = widget.exercise?.stations;
    final index = _stationIndex;
    if (stations == null ||
        index == null ||
        index < 0 ||
        index >= stations.length) {
      return null;
    }
    return stations[index];
  }

  /// The full effective map at this roleplay's scope (ADR-0046): the
  /// plan's declared defaults overlaid by the enclosing exercise's
  /// overrides, then by [_parentStation]'s overrides. RolePlay has no
  /// override table of its own — it only ever reads this cascade, never
  /// writes to it — mirroring what
  /// `effectivePlanVariables(program, exercise: parentExercise, station: parentStation)`
  /// would return; computed directly since this editor only has the
  /// declared list and its parent objects, not the whole `Program`.
  Map<String, String> get _effectiveVariables {
    final vars = {for (final v in widget.variables) v.name: v.value};
    final exercise = widget.exercise;
    if (exercise != null) {
      for (final entry in exercise.variableOverrides.entries) {
        if (vars.containsKey(entry.key)) vars[entry.key] = entry.value;
      }
    }
    final station = _parentStation;
    if (station != null) {
      for (final entry in station.variableOverrides.entries) {
        if (vars.containsKey(entry.key)) vars[entry.key] = entry.value;
      }
    }
    return vars;
  }

  @override
  void initState() {
    super.initState();
    _rolePlay = widget.rolePlay;
    _nameController.text = _rolePlay.name;
    _ageController.text = _rolePlay.age?.toString() ?? '';
    _signalementController.text = _rolePlay.signalement ?? '';
    _backgroundController.text = _rolePlay.background ?? '';
    _behaviorController.text = _rolePlay.behavior ?? '';
    _propsController.text = _rolePlay.propsMd ?? '';
    _stationIndex = _rolePlay.stationIndex;
    _position = _rolePlay.position;
    // When a markør is added to a post without its own position yet, default
    // to the post's location so the user fine-tunes from there.
    if (_position == null && _stationIndex != null) {
      final stationPos = _stationPosition(_stationIndex!);
      if (stationPos != null) {
        _position = stationPos;
        _positionFromStation = true;
      }
    }
    _activeMdSections = {
      if (_rolePlay.background != null) _MdSection.background,
      if (_rolePlay.behavior != null) _MdSection.behavior,
      if (_rolePlay.propsMd != null) _MdSection.props,
    };
  }

  /// Position of the station at [index] within the current exercise, or null.
  LatLng? _stationPosition(int index) {
    final stations = widget.exercise?.stations ?? const [];
    if (index < 0 || index >= stations.length) return null;
    return stations[index].position;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _signalementController.dispose();
    _backgroundController.dispose();
    _behaviorController.dispose();
    _propsController.dispose();
    _signalementFocus.dispose();
    _backgroundFocus.dispose();
    _behaviorFocus.dispose();
    _propsFocus.dispose();
    super.dispose();
  }

  void _addMdSection(_MdSection section) {
    setState(() => _activeMdSections.add(section));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mdFocusFor(section).requestFocus();
    });
  }

  void _removeMdSection(_MdSection section) {
    setState(() {
      _activeMdSections.remove(section);
      _mdControllerFor(section).clear();
    });
  }

  FocusNode _mdFocusFor(_MdSection section) => switch (section) {
    _MdSection.background => _backgroundFocus,
    _MdSection.behavior => _behaviorFocus,
    _MdSection.props => _propsFocus,
  };

  String _mdLabelFor(_MdSection section, AppLocalizations l) =>
      switch (section) {
        _MdSection.background => l.roleBackground,
        _MdSection.behavior => l.roleBehavior,
        _MdSection.props => l.catalogDiffFieldProps,
      };

  TextEditingController _mdControllerFor(_MdSection section) =>
      switch (section) {
        _MdSection.background => _backgroundController,
        _MdSection.behavior => _behaviorController,
        _MdSection.props => _propsController,
      };

  /// [_MdSection]s whose text contains an undeclared `{{var.x}}` — mirrors
  /// `ExerciseFormScreen._sectionsWithUndeclaredTokens`.
  List<_MdSection> _sectionsWithUndeclaredTokens() {
    final declared = widget.variables.map((v) => v.name).toSet();
    return [
      for (final section in _MdSection.values)
        if (_activeMdSections.contains(section) &&
            planVariableTokenPattern
                .allMatches(_mdControllerFor(section).text)
                .any((m) => !declared.contains(m.group(1))))
          section,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return _buildSectionNavigated(context);
  }

  /// DESIGN-008 follow-up 07. `signalement` sits in the always-visible
  /// "Rolle" base section. No Variabler section — a roleplay declares and
  /// overrides nothing (ADR-0046).
  Widget _buildSectionNavigated(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final titleText = widget.rolePlay.name.trim().isEmpty
        ? l.newRolePlayTitle
        : widget.rolePlay.name;

    final activeMdSections = [
      for (final section in _MdSection.values)
        if (_activeMdSections.contains(section))
          FormSection(
            id: section.name,
            label: _mdLabelFor(section, l),
            icon: Icons.description_outlined,
            removable: true,
            builder: (_) => Padding(
              key: ValueKey(section.name),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Expanded(
                    child: RingDrillTextArea(
                      controller: _mdControllerFor(section),
                      focusNode: _mdFocusFor(section),
                      label: _mdLabelFor(section, l),
                      expands: true,
                      tokenAware: true,
                      overrides: _effectiveVariables,
                      // No onCreateVariable: a roleplay cannot create plan
                      // variables (DESIGN-008 follow-up 07's settled
                      // scope, matching Exercise/Station).
                    ),
                  ),
                ],
              ),
            ),
          ),
    ];
    final addableSections = [
      for (final section in _MdSection.values)
        if (!_activeMdSections.contains(section))
          FormSection(
            id: section.name,
            label: _mdLabelFor(section, l),
            icon: Icons.description_outlined,
            removable: true,
            builder: (_) => const SizedBox.shrink(),
          ),
    ];

    return PlanScope(
      variables: widget.variables,
      child: Form(
        key: _formKey,
        child: SectionNavigatedForm(
          title: titleText,
          initialSectionId: 'roleplay',
          sections: [
            FormSection(
              id: 'roleplay',
              label: l.roleplaySectionRole,
              icon: Icons.theater_comedy,
              builder: (ctx) => _buildRoleplaySectionBody(ctx, l),
            ),
            ...activeMdSections,
          ],
          addable: addableSections,
          onAdd: (id) => _addMdSection(_MdSection.values.byName(id)),
          onRemove: (id) => _removeMdSection(_MdSection.values.byName(id)),
          onSave: _save,
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  /// The DESIGN-008 default section for [RolePlay]: the short structural
  /// fields that never become their own section (name, age, signalement,
  /// station, position).
  Widget _buildRoleplaySectionBody(BuildContext context, AppLocalizations l) {
    final stations = widget.exercise?.stations ?? [];
    final exercises = _programService.loadExercises();
    final exerciseIndex = exercises.indexWhere(
      (e) => e.uuid == widget.rolePlay.exerciseUuid,
    );
    final stationNumberFormat =
        _programService.activeProgram?.stationNumberFormat ??
        StationNumberFormat.dotted;

    return SafeArea(
      child: DismissKeyboard(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      autofocus: true,
                      controller: _nameController,
                      decoration: InputDecoration(labelText: l.roleName),
                      validator: (value) =>
                          value != null && value.trim().isNotEmpty
                          ? null
                          : l.pleaseEnterAName,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 80,
                    child: TextFormField(
                      key: const Key('age-field'),
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(labelText: l.roleAge),
                      validator: (value) {
                        if (value == null || value.isEmpty) return null;
                        final age = int.tryParse(value);
                        if (age == null || age < 0 || age > 120) {
                          return l.ageRange;
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                initialValue: _stationIndex,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l.stationLabel,
                  hintText: l.noStationAssigned,
                ),
                items: [
                  for (var i = 0; i < stations.length; i++)
                    DropdownMenuItem<int?>(
                      value: i,
                      child: Row(
                        children: [
                          StationNumberBadge(
                            label: Numbering.station(
                              stationNumberFormat,
                              exerciseNumber: exerciseIndex < 0
                                  ? 1
                                  : exerciseIndex + 1,
                              stationIndex: i,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(stations[i].name)),
                        ],
                      ),
                    ),
                ],
                validator: (v) => stations.isNotEmpty && v == null
                    ? l.pleaseSelectStation
                    : null,
                onChanged: (v) => setState(() {
                  _stationIndex = v;
                  final canInherit = _position == null || _positionFromStation;
                  if (v != null && canInherit) {
                    final stationPos = _stationPosition(v);
                    if (stationPos != null) {
                      _position = stationPos;
                      _positionFromStation = true;
                    }
                  }
                }),
              ),
              const SizedBox(height: 16),
              PositionFormField(
                key: ValueKey(_position),
                initialValue: _position,
                onChanged: (pos) {
                  _position = pos;
                  _positionFromStation = false;
                },
                onSaved: (pos) {
                  _rolePlay = _rolePlay.copyWith(position: pos);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _signalementController,
                keyboardType: TextInputType.multiline,
                minLines: 1,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: l.roleSignalement,
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final offending = _sectionsWithUndeclaredTokens();
    if (offending.isNotEmpty) {
      final l = AppLocalizations.of(context)!;
      final sections = offending.map((s) => _mdLabelFor(s, l)).join(', ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.programSaveBlockedUndeclaredVariable(sections)),
        ),
      );
      return;
    }
    _formKey.currentState!.save();

    final ageText = _ageController.text.trim();
    final signalementText = _signalementController.text.trim();
    final backgroundText = _backgroundController.text.trim();
    final behaviorText = _behaviorController.text.trim();
    final propsText = _propsController.text.trim();
    final signalement = signalementText.isEmpty ? null : signalementText;
    final backgroundActive = _activeMdSections.contains(_MdSection.background);
    final behaviorActive = _activeMdSections.contains(_MdSection.behavior);
    final propsActive = _activeMdSections.contains(_MdSection.props);

    final updated = _rolePlay.copyWith(
      name: _nameController.text.trim(),
      age: ageText.isEmpty ? null : int.parse(ageText),
      signalement: signalement,
      background: backgroundActive && backgroundText.isNotEmpty
          ? backgroundText
          : null,
      behavior: behaviorActive && behaviorText.isNotEmpty ? behaviorText : null,
      propsMd: propsActive && propsText.isNotEmpty ? propsText : null,
      stationIndex: _stationIndex,
    );

    Navigator.of(context).pop(updated);
  }
}
