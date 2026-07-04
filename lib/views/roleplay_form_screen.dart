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
import 'package:ringdrill/utils/app_flags.dart';
import 'package:ringdrill/utils/plan_variables.dart';
import 'package:ringdrill/views/position_form_field.dart';
import 'package:ringdrill/views/widgets/dismiss_keyboard.dart';
import 'package:ringdrill/views/widgets/optional_field_sections.dart';
import 'package:ringdrill/views/widgets/plan_scope.dart';
import 'package:ringdrill/views/widgets/ringdrill_text_field.dart';
import 'package:ringdrill/views/widgets/role_number_badge.dart';
import 'package:ringdrill/views/widgets/section_navigated_form.dart';
import 'package:ringdrill/views/widgets/station_number_badge.dart';
import 'package:ringdrill/views/widgets/token_text_editing_controller.dart';

/// Optional long-form sections that can be added to a [RolePlay] in the
/// legacy flag-off body.
enum _Section { signalement, background, behavior }

/// Token-aware markdown sections shown only in the flag-on
/// section-navigated body (DESIGN-008 follow-up 07). Deliberately a
/// separate enum from [_Section], not a shared one like
/// Program/Exercise/Station use for their single markdown-section catalog:
/// the two bodies' section shapes genuinely differ here. `signalement` is
/// a short field, not markdown, and is promoted into the always-visible
/// "Rolle" base section; `propsMd` — not editable anywhere in the legacy
/// body at all — becomes a third addable section alongside background and
/// behavior.
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
    @visibleForTesting this.debugPlanVariablesOverride,
  });

  final RolePlay rolePlay;
  final Exercise? exercise;

  /// The plan's declared variables (ADR-0046), read-only here — a roleplay
  /// declares and overrides nothing (DESIGN-008 follow-up 07's settled
  /// scope: no Variabler section). Every call site passes
  /// `program.variables`. Only consulted in the flag-on section-navigated
  /// body.
  final List<DrillVariable> variables;

  /// Overrides [AppFlags.planVariables] for a test. `bool.fromEnvironment`
  /// is a compile-time const, so a widget test cannot flip it at runtime —
  /// this lets a test render the flag-on section-navigated body without a
  /// `--dart-define`. Production code never sets this; the real flag is
  /// read when it is null.
  @visibleForTesting
  final bool? debugPlanVariablesOverride;

  @override
  State<RolePlayFormScreen> createState() => _RolePlayFormScreenState();
}

class _RolePlayFormScreenState extends State<RolePlayFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _programService = ProgramService();

  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  // Never token-aware — signalement is a short field promoted into the
  // always-visible "Rolle" base section in the flag-on body, not one of
  // the three markdown sections.
  final _signalementController = TextEditingController();

  /// A [TokenTextEditingController] in the flag-on path, a plain controller
  /// in the legacy path — same reasoning as `ExerciseFormScreen`'s markdown
  /// controllers. `_planVariablesOn` is constant for the screen's lifetime.
  late final TextEditingController _backgroundController = _planVariablesOn
      ? TokenTextEditingController()
      : TextEditingController();
  late final TextEditingController _behaviorController = _planVariablesOn
      ? TokenTextEditingController()
      : TextEditingController();

  /// Only ever populated/read in the flag-on body — the legacy body has no
  /// UI for `RolePlay.propsMd` at all (a pre-existing gap this migration
  /// does not fix outside the flag).
  late final TextEditingController _propsController = _planVariablesOn
      ? TokenTextEditingController()
      : TextEditingController();

  final _signalementFocus = FocusNode();
  final _backgroundFocus = FocusNode();
  final _behaviorFocus = FocusNode();
  final _propsFocus = FocusNode();

  late Set<_Section> _activeSections;

  /// Flag-on-only active markdown sections — see [_MdSection]'s doc comment
  /// for why this is not shared with [_activeSections].
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

  bool get _planVariablesOn =>
      widget.debugPlanVariablesOverride ?? AppFlags.planVariables;

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
    _activeSections = {
      if (_rolePlay.signalement != null) _Section.signalement,
      if (_rolePlay.background != null) _Section.background,
      if (_rolePlay.behavior != null) _Section.behavior,
    };
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

  void _addSection(_Section section) {
    setState(() => _activeSections.add(section));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusFor(section).requestFocus();
    });
  }

  void _removeSection(_Section section) {
    setState(() {
      _activeSections.remove(section);
      _controllerFor(section).clear();
    });
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

  FocusNode _focusFor(_Section section) => switch (section) {
    _Section.signalement => _signalementFocus,
    _Section.background => _backgroundFocus,
    _Section.behavior => _behaviorFocus,
  };

  String _labelFor(_Section section, AppLocalizations l) => switch (section) {
    _Section.signalement => l.roleSignalement,
    _Section.background => l.roleBackground,
    _Section.behavior => l.roleBehavior,
  };

  TextEditingController _controllerFor(_Section section) => switch (section) {
    _Section.signalement => _signalementController,
    _Section.background => _backgroundController,
    _Section.behavior => _behaviorController,
  };

  @override
  Widget build(BuildContext context) {
    if (_planVariablesOn) {
      return _buildSectionNavigated(context);
    }
    return _buildLegacy(context);
  }

  /// DESIGN-008 follow-up 07, behind `RINGDRILL_PLAN_VARIABLES`. Same
  /// controllers and save path as the legacy body below — [_MdSection]
  /// replaces [_Section] for the addable markdown sections (see its doc
  /// comment for why), and `signalement` moves into the always-visible
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

  Widget _buildLegacy(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final stations = widget.exercise?.stations ?? [];

    // Compute the role badge label.
    final exercises = _programService.loadExercises();
    final exerciseIndex = exercises.indexWhere(
      (e) => e.uuid == widget.rolePlay.exerciseUuid,
    );
    final stationNumberFormat =
        _programService.activeProgram?.stationNumberFormat ??
        StationNumberFormat.dotted;
    // Badge reflects the *selected* post and the markør's number at that
    // post, so it updates live as the post dropdown changes. Until a post
    // is picked the post/markør parts show as `?`.
    final exerciseNumber = exerciseIndex < 0 ? null : exerciseIndex + 1;
    final String code;
    if (exerciseNumber == null) {
      code = stationNumberFormat == StationNumberFormat.alpha ? '?' : '?.?';
    } else if (_stationIndex == null) {
      code = stationNumberFormat == StationNumberFormat.alpha
          ? '$exerciseNumber?'
          : '$exerciseNumber.?';
    } else {
      code = Numbering.role(
        stationNumberFormat,
        exerciseNumber: exerciseNumber,
        stationIndex: _stationIndex!,
        roleNumber: _programService.roleNumberAtStation(
          widget.rolePlay,
          _stationIndex!,
        ),
      );
    }

    final titleText = widget.rolePlay.name.trim().isEmpty
        ? localizations.newRolePlayTitle
        : widget.rolePlay.name;

    final sectionSpecs = [
      for (final section in _Section.values)
        OptionalFieldSection<_Section>(
          id: section,
          label: _labelFor(section, localizations),
          controller: _controllerFor(section),
          focusNode: _focusFor(section),
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: localizations.cancel,
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            RoleNumberBadge(label: code),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                titleText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(onPressed: _save, child: Text(localizations.save)),
        ],
        actionsPadding: const EdgeInsets.only(right: 16),
      ),
      body: DismissKeyboard(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + age on one line
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          autofocus: true,
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: localizations.roleName,
                          ),
                          validator: (value) =>
                              value != null && value.trim().isNotEmpty
                              ? null
                              : localizations.pleaseEnterAName,
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 80,
                        child: TextFormField(
                          key: const Key('age-field'),
                          controller: _ageController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            labelText: localizations.roleAge,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return null;
                            final age = int.tryParse(value);
                            if (age == null || age < 0 || age > 120) {
                              return localizations.ageRange;
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Station dropdown
                  DropdownButtonFormField<int?>(
                    initialValue: _stationIndex,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: localizations.stationLabel,
                      hintText: localizations.noStationAssigned,
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
                    // A station is required whenever the exercise has any.
                    // When it has none there is nothing to pick, so skip.
                    validator: (v) => stations.isNotEmpty && v == null
                        ? localizations.pleaseSelectStation
                        : null,
                    onChanged: (v) => setState(() {
                      _stationIndex = v;
                      // Inherit the post's position as a default while the
                      // current position is empty or still a post default.
                      // A manual map pick clears _positionFromStation, so we
                      // never clobber a fine-tuned location.
                      final canInherit =
                          _position == null || _positionFromStation;
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

                  // Position. Keyed on the value so a programmatic default
                  // (station inheritance) re-creates the field with the new
                  // initialValue instead of keeping stale FormField state.
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
                  const Divider(height: 24),

                  // Optional sections — only shown when added
                  OptionalFieldSections<_Section>(
                    sections: sectionSpecs,
                    activeIds: _activeSections,
                    onAdd: _addSection,
                    onRemove: _removeSection,
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    // Flag off has no way to reference an undeclared token in the first
    // place — only the flag-on path's token-aware fields can produce one
    // to block on (matches Exercise/Station's rule).
    if (_planVariablesOn) {
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
    }
    _formKey.currentState!.save();

    final ageText = _ageController.text.trim();
    final signalementText = _signalementController.text.trim();
    final backgroundText = _backgroundController.text.trim();
    final behaviorText = _behaviorController.text.trim();
    // signalement is always visible (not addable/removable) in the flag-on
    // "Rolle" base section, so it saves on trim-empty-to-null alone there;
    // the legacy body still gates it on _activeSections, matching its
    // addable/removable behavior (DESIGN-008 follow-up 07 settled scope).
    final signalement = _planVariablesOn
        ? (signalementText.isEmpty ? null : signalementText)
        : (_activeSections.contains(_Section.signalement) &&
                  signalementText.isNotEmpty
              ? signalementText
              : null);
    final backgroundActive = _planVariablesOn
        ? _activeMdSections.contains(_MdSection.background)
        : _activeSections.contains(_Section.background);
    final behaviorActive = _planVariablesOn
        ? _activeMdSections.contains(_MdSection.behavior)
        : _activeSections.contains(_Section.behavior);

    var updated = _rolePlay.copyWith(
      name: _nameController.text.trim(),
      age: ageText.isEmpty ? null : int.parse(ageText),
      signalement: signalement,
      background: backgroundActive && backgroundText.isNotEmpty
          ? backgroundText
          : null,
      behavior: behaviorActive && behaviorText.isNotEmpty ? behaviorText : null,
      stationIndex: _stationIndex,
    );
    // propsMd has no legacy-body UI at all (a pre-existing gap this
    // migration does not fix outside the flag) — omitted entirely from
    // copyWith in the flag-off path, which freezed's copyWith sentinel
    // treats as "keep the existing value", not "clear it".
    if (_planVariablesOn) {
      final propsText = _propsController.text.trim();
      updated = updated.copyWith(
        propsMd:
            _activeMdSections.contains(_MdSection.props) && propsText.isNotEmpty
            ? propsText
            : null,
      );
    }

    Navigator.of(context).pop(updated);
  }
}
