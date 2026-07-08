import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/numbering.dart';
import 'package:ringdrill/models/person.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/utils/plan_variables.dart';
import 'package:ringdrill/utils/slug.dart';
import 'package:ringdrill/utils/station_scenario_tokens.dart';
import 'package:ringdrill/views/position_form_field.dart';
import 'package:ringdrill/views/widgets/dismiss_keyboard.dart';
import 'package:ringdrill/views/widgets/gender_segmented_control.dart';
import 'package:ringdrill/views/widgets/plan_scope.dart';
import 'package:ringdrill/views/widgets/ringdrill_text_field.dart';
import 'package:ringdrill/views/widgets/section_navigated_form.dart';
import 'package:ringdrill/views/widgets/station_number_badge.dart';
import 'package:ringdrill/views/widgets/station_scope.dart';
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

  /// Token-aware so `RingDrillTextField(tokenAware: true)` can drive its
  /// chips from [PlanScope] (DESIGN-008 follow-up 09).
  final TextEditingController _nameController = TokenTextEditingController();
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

  /// New on `RolePlay` (ADR-0047, DESIGN-009 follow-up 4) — the
  /// `roleGender`-labeled counterpart of `Person.gender`, reusing
  /// [GenderSegmentedControl]. Not token-aware, like `signalement`.
  String? _gender;

  /// Slug of the [Person] this roleplay portrays. Required for a new or
  /// edited roleplay (an editor-level invariant, not a wire constraint —
  /// ADR-0047); a legacy roleplay opened with `personRef == null` gets one
  /// auto-created from its current identity in [initState] (see
  /// [_autoCreatePersonFromIdentity]), so mandatory `personRef` adds no
  /// extra authoring step.
  String? _personRef;

  /// Working copies of [_parentStation]'s `locations`/`persons` — a
  /// roleplay does not own a station's collections, so anything created
  /// here this session (currently only [_autoCreatePersonFromIdentity]'s
  /// bootstrap Person) is a pending write-back, not yet persisted to the
  /// station (wired in DESIGN-009 follow-up 4 commit 4's `PlanAdditions`).
  /// Also feeds [StationScope] so `station.loc`/`station.person` chips and
  /// the picker see it live, the same "editor resolves against a working
  /// copy" pattern `LocationFormScreen`/`PersonFormScreen` already use.
  late List<Location> _workingLocations;
  late List<Person> _workingPersons;

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
    _gender = _rolePlay.gender;
    _personRef = _rolePlay.personRef;
    _workingLocations = List<Location>.of(
      _parentStation?.locations ?? const [],
    );
    _workingPersons = List<Person>.of(_parentStation?.persons ?? const []);
    if (_personRef == null) {
      _autoCreatePersonFromIdentity();
    }
  }

  /// A new roleplay, or a legacy one opened with `personRef == null`, gets a
  /// [Person] auto-created on its station from whatever identity fields it
  /// currently carries (ADR-0047): "creating a roleplay auto-creates its
  /// Person... so mandatory `personRef` adds no authoring step". A no-op
  /// without a station selected yet — retried from the station dropdown's
  /// `onChanged` once one is picked.
  void _autoCreatePersonFromIdentity() {
    if (_parentStation == null) return;
    final existingSlugs = _workingPersons.map((p) => p.slug).toSet();
    final name = _nameController.text.trim();
    final ageText = _ageController.text.trim();
    final signalement = _signalementController.text.trim();
    final created = Person(
      slug: generateSlug(
        name.isEmpty ? 'person' : name,
        existingSlugs.contains,
      ),
      name: name,
      age: ageText.isEmpty ? null : int.tryParse(ageText),
      gender: _gender,
      signalement: signalement.isEmpty ? null : signalement,
    );
    _workingPersons = [..._workingPersons, created];
    _personRef = created.slug;
  }

  Person? _personBySlug(String? slug) {
    if (slug == null) return null;
    for (final p in _workingPersons) {
      if (p.slug == slug) return p;
    }
    return null;
  }

  /// Applies [slug] as the new [_personRef]: an identity field that was
  /// still tracking the *previous* selection's value (inherited, ADR-0047 —
  /// "a field tracking the Person shows its value and stays in sync")
  /// updates to the new person's value; a field the author already
  /// overrode (differs from the old person) is left untouched. Must be
  /// called from inside a `setState`.
  void _applyPersonSelection(String? slug) {
    final oldPerson = _personBySlug(_personRef);
    final currentAge = _ageController.text.trim().isEmpty
        ? null
        : int.tryParse(_ageController.text.trim());
    final wasNameInherited =
        oldPerson == null || _nameController.text == oldPerson.name;
    final wasAgeInherited = oldPerson == null || currentAge == oldPerson.age;
    final wasGenderInherited = oldPerson == null || _gender == oldPerson.gender;
    final wasSignalementInherited =
        oldPerson == null ||
        _signalementController.text == (oldPerson.signalement ?? '');

    _personRef = slug;
    final person = _personBySlug(slug);
    if (person == null) return;
    if (wasNameInherited) _nameController.text = person.name;
    if (wasAgeInherited) _ageController.text = person.age?.toString() ?? '';
    if (wasGenderInherited) _gender = person.gender;
    if (wasSignalementInherited) {
      _signalementController.text = person.signalement ?? '';
    }
  }

  void _onPersonChanged(String? slug) {
    setState(() => _applyPersonSelection(slug));
  }

  /// True when [fieldValue] currently equals [personValue] — i.e. the field
  /// is inherited from the selected Person rather than overridden
  /// (ADR-0047). Shown as a small per-field caption; a field with no
  /// selected person at all shows neither state.
  bool _isInherited(String fieldValue, String? personValue) =>
      fieldValue == (personValue ?? '');

  /// [StationScope.portrayerOf]: for this roleplay's own [_personRef], the
  /// effective identity is whatever the author is typing *right now* —
  /// more current than the last-saved [_rolePlay] — so a `station.person`
  /// chip elsewhere in this same editor reflects live edits. Null for any
  /// other person slug: this editor only ever portrays the one it is
  /// editing.
  EffectivePersonIdentity? _portrayerOf(String personSlug) {
    if (personSlug != _personRef) return null;
    final ageText = _ageController.text.trim();
    final signalement = _signalementController.text.trim();
    return EffectivePersonIdentity(
      name: _nameController.text.trim(),
      age: ageText.isEmpty ? null : int.tryParse(ageText),
      gender: _gender,
      signalement: signalement.isEmpty ? null : signalement,
    );
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

  /// Whether the base section's name field (DESIGN-008 follow-up 09) has a
  /// `{{var.<name>}}` token not declared in [widget.variables]. Name is
  /// unconditionally present, unlike [_MdSection], so this is a short
  /// parallel check rather than another enum member.
  bool _nameHasUndeclaredTokens() {
    final declared = widget.variables.map((v) => v.name).toSet();
    return planVariableTokenPattern
        .allMatches(_nameController.text)
        .any((m) => !declared.contains(m.group(1)));
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
      // The linked station's own locations/persons, plus anything created
      // inline this session (ADR-0047, DESIGN-009 follow-up 4) — a
      // roleplay does not own a station's collections, so it always reads
      // a working copy of someone else's, unlike StationFormScreen's own.
      // [_portrayerOf] feeds this roleplay's own *live* (in-progress, not
      // yet saved) identity fields for its own personRef, so a
      // station.person chip resolving that person reflects what the
      // author is typing right now.
      child: StationScope(
        locations: _workingLocations,
        persons: _workingPersons,
        portrayerOf: _portrayerOf,
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
                    child: RingDrillTextField(
                      controller: _nameController,
                      label: l.roleName,
                      autofocus: true,
                      tokenAware: true,
                      overrides: _effectiveVariables,
                      // Rebuilds this screen so the effective-identity
                      // preview and the field's own inherited/override
                      // caption stay live as the author types — the
                      // controller's own notifyListeners() only repaints
                      // the field itself (DESIGN-009 follow-up 4).
                      onChanged: (_) => setState(() {}),
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
                      onChanged: (_) => setState(() {}),
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
              if (_personRef != null)
                _identityCaption(
                  context,
                  l,
                  inherited: _isInherited(
                    _nameController.text,
                    _personBySlug(_personRef)?.name,
                  ),
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
                onChanged: (v) {
                  if (v == _stationIndex) return;
                  setState(() {
                    _stationIndex = v;
                    final canInherit =
                        _position == null || _positionFromStation;
                    if (v != null && canInherit) {
                      final stationPos = _stationPosition(v);
                      if (stationPos != null) {
                        _position = stationPos;
                        _positionFromStation = true;
                      }
                    }
                    // Persons/locations are station-owned (ADR-0047): a new
                    // station means a new person/location list, so the
                    // working copies and personRef follow the selection,
                    // same as [_parentStation] does. Deliberately does NOT
                    // re-run [_autoCreatePersonFromIdentity] — that bootstrap
                    // is an [initState]-only nicety for a fresh/legacy
                    // roleplay's *first* load; once the author is
                    // interactively switching stations, the mandatory-
                    // personRef validator should make them pick from the
                    // new station's own list, not silently manufacture a
                    // duplicate from whatever is currently typed.
                    _workingLocations = List<Location>.of(
                      _parentStation?.locations ?? const [],
                    );
                    _workingPersons = List<Person>.of(
                      _parentStation?.persons ?? const [],
                    );
                    _personRef = null;
                  });
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: const Key('person-field'),
                initialValue: _personRef,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.rolePlayPersonLabel),
                items: [
                  for (final person in _workingPersons)
                    DropdownMenuItem(
                      value: person.slug,
                      child: Text(
                        person.name.isEmpty ? person.slug : person.name,
                      ),
                    ),
                ],
                // Mandatory personRef is scoped to "a station is selected"
                // (ADR-0047): persons are station-owned, so there is
                // nothing to require a selection *from* without one —
                // mirrors the station dropdown's own
                // `stations.isNotEmpty && v == null` conditioning above.
                validator: (_) => _parentStation != null && _personRef == null
                    ? l.pleaseSelectPerson
                    : null,
                onChanged: _onPersonChanged,
              ),
              if (_personRef != null) ...[
                const SizedBox(height: 4),
                Text(
                  l.rolePlayEffectiveIdentityPreview(
                    _effectiveIdentitySummary(),
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.roleGender,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  GenderSegmentedControl(
                    value: _gender,
                    onChanged: (value) => setState(() {
                      _gender = value;
                    }),
                  ),
                  if (_personRef != null)
                    _identityCaption(
                      context,
                      l,
                      inherited: _isInherited(
                        _gender ?? '',
                        _personBySlug(_personRef)?.gender,
                      ),
                    ),
                ],
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
                onChanged: (_) => setState(() {}),
                keyboardType: TextInputType.multiline,
                minLines: 1,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: l.roleSignalement,
                  alignLabelWithHint: true,
                ),
              ),
              if (_personRef != null)
                _identityCaption(
                  context,
                  l,
                  inherited: _isInherited(
                    _signalementController.text,
                    _personBySlug(_personRef)?.signalement,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Small "Arvet fra person"/"Overstyrt" tag under an identity field
  /// (ADR-0047) — see [_isInherited].
  Widget _identityCaption(
    BuildContext context,
    AppLocalizations l, {
    required bool inherited,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 4),
      child: Text(
        inherited ? l.rolePlayIdentityInherited : l.rolePlayIdentityOverride,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  /// "Anne Glemsk, 47, kvinne, ..." — the current effective identity, for
  /// the small preview line under the person selector (ADR-0047). Always
  /// reflects the fields as they stand right now, the same effective
  /// values [_save] persists.
  String _effectiveIdentitySummary() {
    final l = AppLocalizations.of(context)!;
    final ageText = _ageController.text.trim();
    final genderLabel = genderLabelFor(_gender, l);
    final signalement = _signalementController.text.trim();
    final parts = [
      _nameController.text.trim(),
      if (ageText.isNotEmpty) ageText,
      ?genderLabel,
      if (signalement.isNotEmpty) signalement,
    ];
    return parts.where((p) => p.isNotEmpty).join(', ');
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l = AppLocalizations.of(context)!;
    final offending = [
      if (_nameHasUndeclaredTokens()) l.roleName,
      ..._sectionsWithUndeclaredTokens().map((s) => _mdLabelFor(s, l)),
    ];
    if (offending.isNotEmpty) {
      final sections = offending.join(', ');
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
      gender: _gender,
      signalement: signalement,
      background: backgroundActive && backgroundText.isNotEmpty
          ? backgroundText
          : null,
      behavior: behaviorActive && behaviorText.isNotEmpty ? behaviorText : null,
      propsMd: propsActive && propsText.isNotEmpty ? propsText : null,
      stationIndex: _stationIndex,
      // On disk each identity field holds the *effective* value, not a
      // separate override flag (ADR-0047) — `updated` above already is
      // that effective value, computed live by the inherit/override sync
      // in `_applyPersonSelection`/the fields' own `onChanged`.
      personRef: _personRef,
    );

    Navigator.of(context).pop(updated);
  }
}
