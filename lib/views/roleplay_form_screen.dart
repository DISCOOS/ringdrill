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
import 'package:ringdrill/services/brief/field_resolver.dart' show formatUtm;
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/utils/plan_variables.dart';
import 'package:ringdrill/utils/slug.dart';
import 'package:ringdrill/utils/station_scenario_tokens.dart'
    show EffectivePersonIdentity, stationScenarioTokenPattern;
import 'package:ringdrill/views/plan_additions.dart';
import 'package:ringdrill/views/position_form_field.dart';
import 'package:ringdrill/views/position_widget.dart';
import 'package:ringdrill/views/widgets/dismiss_keyboard.dart';
import 'package:ringdrill/views/widgets/editor_token.dart';
import 'package:ringdrill/views/widgets/gender_segmented_control.dart';
import 'package:ringdrill/views/widgets/plan_field_tokens.dart';
import 'package:ringdrill/views/widgets/plan_scope.dart';
import 'package:ringdrill/views/widgets/ringdrill_text_field.dart';
import 'package:ringdrill/views/widgets/section_navigated_form.dart';
import 'package:ringdrill/views/widgets/section_rollup.dart';
import 'package:ringdrill/views/widgets/station_number_badge.dart';
import 'package:ringdrill/views/widgets/station_scope.dart';
import 'package:ringdrill/views/widgets/token_text_editing_controller.dart';

/// Token-aware markdown sections, addable/removable (DESIGN-008
/// follow-up 07). `signalement` is a short field, not markdown, and lives
/// in the always-visible "Rolle" base section instead.
enum _MdSection { background, behavior, props }

/// [RolePlayFormScreen]'s result: the saved [RolePlay] plus any
/// [PlanAdditions] created inline this session (ADR-0047, DESIGN-009
/// follow-up 4) — new plan variables (→ `Program`) and any new station
/// locations/persons beyond what [RolePlayFormScreen.rolePlay]'s linked
/// station already had (→ that station; a roleplay does not own it).
typedef RolePlayFormResult = ({RolePlay rolePlay, PlanAdditions additions});

/// ADR-0046's declared-variable-name rule — see `ExerciseFormScreen`'s own
/// copy of this same one-line RegExp for why it is duplicated per editor.
final _variableSlugPattern = RegExp(r'^[a-z][a-z0-9_]*$');

/// Edit form for a single [RolePlay].
///
/// Edits the publishable Role fields only: name, age, signalement,
/// background, behavior, stationIndex, and position. The actorUuid
/// (cast assignment) is intentionally absent — casting is managed
/// from the RolePlays list via the cast picker.
///
/// Pops with a [RolePlayFormResult] on save, or null on cancel. The caller
/// is responsible for persisting both the [RolePlay] and applying the
/// write-back [PlanAdditions] (same pattern as [StationFormScreen]).
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

  /// Section ids currently showing their resolved-markdown preview
  /// (DESIGN-010) rather than the editable chip field — remembered for the
  /// session, per section, not editor-wide (DESIGN-010's settled decisions).
  final Set<String> _previewSections = {};

  void _togglePreview(String sectionId, bool preview) => setState(() {
    if (preview) {
      _previewSections.add(sectionId);
    } else {
      _previewSections.remove(sectionId);
    }
  });

  /// Whether the default section's read-only rollup is shown (DESIGN-010).
  /// Default off, to keep the default section compact.
  bool _showRollup = false;

  int? _stationIndex;
  // Tracks the current position; updated by PositionFormField.onSaved
  late RolePlay _rolePlay;
  // Current marker position, kept in sync with the PositionFormField.
  LatLng? _position;
  // True while [_position] still mirrors the selected station's position (a
  // default we may keep updating). Cleared once the user picks a spot on the
  // map, so we never overwrite a manual fine-tune.
  bool _positionFromStation = false;

  /// Whether the position section shows the raw [PositionFormField] picker
  /// rather than the collapsed location card (DESIGN-009 prompt 4i/4j).
  /// Set once in [initState] from whether there is a person
  /// location to collapse behind at all; toggled true afterward by the
  /// "Sett egen" action, and back to false by "Tilbakestill".
  bool _positionExpanded = false;

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

  /// Whether the identity card's "Tilpass" override panel is open
  /// (DESIGN-009 prompt 4i). Set once in [initState] — auto-expanded when
  /// the roleplay already has at least one facet overridden, otherwise
  /// collapsed, so an untouched marker reads as one clean summary line.
  /// Toggled afterward by the disclosure row, independent of override
  /// count.
  bool _identityExpanded = false;

  /// Working copies of [_parentStation]'s `locations`/`persons` — a
  /// roleplay does not own a station's collections, so anything created
  /// here this session ([_autoCreatePersonFromIdentity]'s bootstrap Person,
  /// or a "Create location/person «x»" picked from a markdown field's
  /// insertion menu) is a pending write-back the caller applies to the
  /// station via the returned [RolePlayFormResult.additions] (ADR-0047,
  /// DESIGN-009 follow-up 4). Also feeds [StationScope] so
  /// `station.loc`/`station.person` chips and the picker see it live, the
  /// same "editor resolves against a working copy" pattern
  /// `LocationFormScreen`/`PersonFormScreen` already use.
  late List<Location> _workingLocations;
  late List<Person> _workingPersons;

  /// [_workingLocations]'/[_workingPersons]' slugs as of the currently
  /// selected station (reset in [_onStationChanged] alongside them) — the
  /// baseline [_save] diffs against to compute which entries are new this
  /// session (the write-back) versus already on the station.
  late Set<String> _originalLocationSlugs;
  late Set<String> _originalPersonSlugs;

  /// New plan variables created inline from a token field this session
  /// (ADR-0047, DESIGN-009 follow-up 4 — un-defers DESIGN-008's parked
  /// "create a variable from a sub-editor"). A `RolePlay` cannot declare
  /// variables itself; these are returned as [PlanAdditions] for the caller
  /// to apply to `Program` alongside this roleplay's own save.
  final List<DrillVariable> _pendingVariables = [];

  /// [widget.exercise]'s own stations, or empty when opened without one.
  List<Station> get _stations => widget.exercise?.stations ?? const [];

  /// The station currently selected in the Post card, or null. Recomputed
  /// on every access (not cached) so it always follows [_stationIndex] live
  /// — a roleplay's effective scope must track the selection, not just the
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

  /// This roleplay's own `roleplay.*` cross-reference facets (DESIGN-010),
  /// read live from the same controllers the "Rolle" default section edits
  /// — so a `{{roleplay.name}}` reference in e.g. `background` previews the
  /// identity as it is currently being typed, not just the last save.
  /// Folded directly into `resolveScopedField`'s context (via
  /// `RingDrillTextArea.roleplayFacets`) rather than a scope — small enough,
  /// and only this roleplay's own fields ever need it (DESIGN-010's "The
  /// resolve-context cascade").
  Map<String, dynamic> get _roleplayFacets => {
    'name': _nameController.text,
    'age': int.tryParse(_ageController.text.trim()),
    'signalement': _signalementController.text,
    'position': {'utm': _position == null ? '' : formatUtm(_position)},
  };

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
    _originalLocationSlugs = _workingLocations.map((l) => l.slug).toSet();
    _originalPersonSlugs = _workingPersons.map((p) => p.slug).toSet();
    if (_personRef == null) {
      _autoCreatePersonFromIdentity();
    }
    final selectedPerson = _personBySlug(_personRef);
    _identityExpanded =
        selectedPerson != null && _identityOverrideCount(selectedPerson) > 0;

    _position = _rolePlay.position;
    // When a markør has no position of its own yet, default it — preferring
    // the selected person's own location (DESIGN-009 prompt 4i) over the
    // post's location (the pre-existing fallback) so the user fine-tunes
    // from the most specific default available.
    if (_position == null && _stationIndex != null) {
      final personCoord = _personLocationCoordinate;
      if (personCoord != null) {
        _position = personCoord;
      } else {
        final stationPos = _stationPosition(_stationIndex!);
        if (stationPos != null) {
          _position = stationPos;
          _positionFromStation = true;
        }
      }
    }
    // Show the raw picker right away unless there is a person location to
    // collapse behind (DESIGN-009 prompt 4i) — no inheritable coordinate
    // means no card, no regression from the pre-existing behavior above.
    _positionExpanded = _personLocationCoordinate == null;
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
      slug: randomSlug(existingSlugs.contains),
      name: name,
      age: ageText.isEmpty ? null : int.tryParse(ageText),
      gender: _gender,
      signalement: signalement.isEmpty ? null : signalement,
    );
    _workingPersons = [..._workingPersons, created];
    _personRef = created.slug;
  }

  /// Wired to a markdown field's `onCreateLocation` hook (ADR-0047,
  /// DESIGN-009 follow-up 4): the insertion menu needs the generated slug
  /// synchronously to embed in the token it is about to insert. Unlike the
  /// station editor, this new [Location] belongs to the linked station,
  /// which this editor does not own — [_save] diffs [_workingLocations]
  /// against [_originalLocationSlugs] to carry it up as a write-back.
  String _createLocationInline(String label) {
    final slug = randomSlug(
      (candidate) => _workingLocations.any((l) => l.slug == candidate),
    );
    setState(() {
      _workingLocations = [
        ..._workingLocations,
        Location(slug: slug, label: label),
      ];
    });
    return slug;
  }

  /// [_createLocationInline]'s [_workingPersons] counterpart.
  String _createPersonInline(String label) {
    final slug = randomSlug(
      (candidate) => _workingPersons.any((p) => p.slug == candidate),
    );
    setState(() {
      _workingPersons = [..._workingPersons, Person(slug: slug, name: label)];
    });
    return slug;
  }

  /// Wired to every token-aware field's `onCreateVariable` hook (ADR-0047,
  /// DESIGN-009 follow-up 4 — mirrors `ExerciseFormScreen`'s own copy): the
  /// menu already inserted `{{var.<name>}}`; this only needs to declare it,
  /// empty, in [_pendingVariables] so the chip resolves live (amber) via the
  /// merged [PlanScope] below.
  void _createVariableInline(String name) {
    if (!_variableSlugPattern.hasMatch(name)) return;
    final alreadyDeclared = widget.variables.any((v) => v.name == name);
    final alreadyPending = _pendingVariables.any((v) => v.name == name);
    if (alreadyDeclared || alreadyPending) return;
    setState(() {
      _pendingVariables.add(DrillVariable(name: name, value: ''));
    });
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
    // Position follows the same inherit-or-override rule (DESIGN-009
    // prompt 4i): a position that is null, or that matched the *old*
    // person's location, was following rather than a deliberate choice,
    // so it re-follows onto the *new* person's location too; any other
    // non-null position (including one set while the old person had no
    // location at all) is a manual choice and is left untouched.
    final oldPersonCoord = _personLocationCoordinate;
    final wasPositionFollowing =
        _position == null || _position == oldPersonCoord;

    _personRef = slug;
    final person = _personBySlug(slug);
    if (person == null) return;
    if (wasNameInherited) _nameController.text = person.name;
    if (wasAgeInherited) _ageController.text = person.age?.toString() ?? '';
    if (wasGenderInherited) _gender = person.gender;
    if (wasSignalementInherited) {
      _signalementController.text = person.signalement ?? '';
    }
    if (wasPositionFollowing) {
      final newCoord = _personLocationCoordinate;
      if (newCoord != null) {
        _position = newCoord;
        _positionExpanded = false;
      }
    }
  }

  void _onPersonChanged(String? slug) {
    setState(() => _applyPersonSelection(slug));
  }

  /// The identity card header's tap target (DESIGN-009 prompt 4i): a
  /// plain pick-one dialog over [_workingPersons], since
  /// `DropdownButtonFormField`'s own menu can't host the header's
  /// multi-line summary in its closed state (see [_buildIdentityCard]).
  Future<void> _showPersonPicker(
    BuildContext context,
    AppLocalizations l,
  ) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l.rolePlayPersonLabel),
        children: [
          for (final person in _workingPersons)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(person.slug),
              child: Text(person.name.isEmpty ? person.slug : person.name),
            ),
        ],
      ),
    );
    if (selected != null) _onPersonChanged(selected);
  }

  /// True when [fieldValue] currently equals [personValue] — i.e. the field
  /// is inherited from the selected Person rather than overridden
  /// (ADR-0047). Shown as a small per-field caption; a field with no
  /// selected person at all shows neither state.
  bool _isInherited(String fieldValue, String? personValue) =>
      fieldValue == (personValue ?? '');

  /// [_isInherited]'s age counterpart — age is an `int?`, not a `String`,
  /// so it compares parsed values rather than raw text.
  bool _isAgeInherited(Person person) {
    final ageText = _ageController.text.trim();
    final age = ageText.isEmpty ? null : int.tryParse(ageText);
    return age == person.age;
  }

  /// The [Person] currently selected via [_personRef], or null.
  Person? get _selectedPerson => _personBySlug(_personRef);

  /// The [Location] [_selectedPerson]'s `locSlug` references on this
  /// station, or null when there is no selected person, no `locSlug`, or
  /// the slug is dangling (DESIGN-009 prompt 4i).
  Location? get _selectedPersonLocation {
    final locSlug = _selectedPerson?.locSlug;
    if (locSlug == null) return null;
    for (final location in _workingLocations) {
      if (location.slug == locSlug) return location;
    }
    return null;
  }

  /// [_selectedPersonLocation]'s own coordinate, or null when there is no
  /// such location or it has no coordinate set — the "no inheritable
  /// coordinate" case that keeps the position section as the plain
  /// picker, unchanged (DESIGN-009 prompt 4i).
  LatLng? get _personLocationCoordinate => _selectedPersonLocation?.position;

  /// Whether [_position] currently matches [_personLocationCoordinate] —
  /// the ADR-0047 inherit/override equality rule applied to position
  /// (DESIGN-009 prompt 4i). Recomputed live, so a later edit to the
  /// person's own location is picked up automatically, same as re-opening
  /// this editor would. False when there is nothing to follow.
  bool get _positionFollowsPerson {
    final personCoord = _personLocationCoordinate;
    return personCoord != null &&
        (_position == null || _position == personCoord);
  }

  /// How many of the four identity facets (name/age/gender/signalement)
  /// currently differ from [person]'s own value (DESIGN-009 prompt 4i) —
  /// drives the identity card's collapsed summary ("N felt tilpasset") and
  /// whether the override panel auto-expands on open.
  int _identityOverrideCount(Person person) {
    var count = 0;
    if (!_isInherited(_nameController.text, person.name)) count++;
    if (!_isAgeInherited(person)) count++;
    if (!_isInherited(_gender ?? '', person.gender)) count++;
    if (!_isInherited(_signalementController.text, person.signalement)) {
      count++;
    }
    return count;
  }

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

  /// Names declared for this editor's save-time undeclared-token check: the
  /// plan's own registry plus anything created inline this session
  /// (ADR-0047, DESIGN-009 follow-up 4) — a variable the author just
  /// declared via the picker must not immediately block save as
  /// "undeclared".
  Set<String> get _declaredVariableNames => {
    for (final v in widget.variables) v.name,
    for (final v in _pendingVariables) v.name,
  };

  /// [_MdSection]s whose text contains an undeclared `{{var.x}}` — mirrors
  /// `ExerciseFormScreen._sectionsWithUndeclaredTokens`.
  List<_MdSection> _sectionsWithUndeclaredTokens() {
    final declared = _declaredVariableNames;
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
  /// `{{var.<name>}}` token not declared in [_declaredVariableNames]. Name
  /// is unconditionally present, unlike [_MdSection], so this is a short
  /// parallel check rather than another enum member.
  bool _nameHasUndeclaredTokens() {
    final declared = _declaredVariableNames;
    return planVariableTokenPattern
        .allMatches(_nameController.text)
        .any((m) => !declared.contains(m.group(1)));
  }

  /// The `station.loc.<slug>`/`station.person.<slug>` references in [text]
  /// (DESIGN-009 prompt 5) whose slug is absent from the linked station's
  /// `locations`/`persons` — [_workingLocations]/[_workingPersons] are that
  /// station's own working copy (ADR-0047), the same source `StationScope`
  /// below reads. Mirrors `StationFormScreen`'s own copy of this check.
  /// Facet paths are not validated, only the slug.
  Iterable<String> _unresolvedReferencesIn(String text) {
    return stationScenarioTokenPattern
        .allMatches(text)
        .where((m) {
          final slug = m.group(2)!;
          return m.group(1) == 'loc'
              ? !_workingLocations.any((loc) => loc.slug == slug)
              : !_workingPersons.any((p) => p.slug == slug);
        })
        .map((m) => 'station.${m.group(1)}.${m.group(2)}');
  }

  /// Whether the name field has an unresolved scenario reference — mirrors
  /// [_nameHasUndeclaredTokens].
  bool _nameHasUnresolvedReference() =>
      _unresolvedReferencesIn(_nameController.text).isNotEmpty;

  /// [_MdSection]s whose text has an unresolved scenario reference —
  /// mirrors [_sectionsWithUndeclaredTokens].
  List<_MdSection> _sectionsWithUnresolvedReferences() {
    return [
      for (final section in _MdSection.values)
        if (_activeMdSections.contains(section) &&
            _unresolvedReferencesIn(_mdControllerFor(section).text).isNotEmpty)
          section,
    ];
  }

  /// The distinct broken references across the name field and every active
  /// markdown section, named in the save-blocked snackbar.
  Set<String> _unresolvedReferences() {
    final refs = <String>{..._unresolvedReferencesIn(_nameController.text)};
    for (final section in _MdSection.values) {
      if (_activeMdSections.contains(section)) {
        refs.addAll(_unresolvedReferencesIn(_mdControllerFor(section).text));
      }
    }
    return refs;
  }

  /// Field labels with an unresolved scenario reference, right now, against
  /// the currently linked station's `locations`/`persons` — shared by the
  /// live inline warning (below) and the save-block (DESIGN-009 prompt 5,
  /// commit 3). Re-pointing the station (and so, necessarily, `personRef`)
  /// to a different station's person changes [_workingLocations]/
  /// [_workingPersons] out from under any `station.*` token already typed
  /// in these fields — this re-evaluates on every rebuild, so it reflects
  /// that change immediately, not just at save time.
  List<String> _unresolvedReferenceFieldLabels(AppLocalizations l) {
    return [
      if (_nameHasUnresolvedReference()) l.roleName,
      ..._sectionsWithUnresolvedReferences().map((s) => _mdLabelFor(s, l)),
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
    // Static type title (DESIGN-009 prompt 4j) — the marker's own name
    // already sits in the identity card's header, so the AppBar just names
    // what kind of screen this is, new vs. existing.
    final titleText = widget.rolePlay.name.trim().isEmpty
        ? l.newRolePlayTitle
        : l.editRolePlayTitle;
    // Additive to the station.loc/person entries StationScope already
    // supplies below (DESIGN-009 follow-up 4) — those come through
    // StationScope, not planFields, so both coexist (follow-up 4b). The full
    // set including roleplay.name: these fields (behavior/background/props)
    // are not the roleplay's own name field, so no self-reference concern
    // (DESIGN-009 follow-up 4c) — see the name field's own planFields below.
    final planFields = [
      ...PlanFieldTokens.program(l),
      ...PlanFieldTokens.exercise(l),
      ...PlanFieldTokens.station(l),
      ...PlanFieldTokens.roleplay(l),
    ];

    final activeMdSections = [
      for (final section in _MdSection.values)
        if (_activeMdSections.contains(section))
          FormSection(
            id: section.name,
            label: _mdLabelFor(section, l),
            icon: Icons.description_outlined,
            removable: true,
            preview: _previewSections.contains(section.name),
            onPreviewChanged: (value) => _togglePreview(section.name, value),
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
                      preview: _previewSections.contains(section.name),
                      roleplayFacets: _roleplayFacets,
                      tokenAware: true,
                      overrides: _effectiveVariables,
                      planFields: planFields,
                      // A RolePlay cannot declare a plan variable itself
                      // (DESIGN-008 follow-up 07's settled scope, matching
                      // Exercise/Station), but can now create one inline
                      // for the write-back PlanAdditions carries up to
                      // Program (ADR-0047, DESIGN-009 follow-up 4). A new
                      // location/person belongs to the linked station,
                      // which this editor also does not own — both are
                      // likewise carried up as write-back.
                      onCreateVariable: _createVariableInline,
                      onCreateLocation: _createLocationInline,
                      onCreatePerson: _createPersonInline,
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

    // Forwards the ambient PlanScope's program facets (DESIGN-010) — this
    // editor shadows PlanScope with its own (for the live variables list),
    // which would otherwise strand {{program.name}} at null below here.
    final ambientPlan = PlanScope.maybeOf(context);
    final parentStation = _parentStation;

    return PlanScope(
      // Declared variables plus anything created inline this session, so a
      // just-created {{var.x}} chip resolves live (amber) instead of red
      // (ADR-0047, DESIGN-009 follow-up 4).
      variables: [...widget.variables, ..._pendingVariables],
      programName: ambientPlan?.programName,
      programDescription: ambientPlan?.programDescription,
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
        // The parent station's own facets (DESIGN-010) — the last-saved
        // Station this roleplay is linked to, not live (this editor does
        // not own the station's own fields; see ExerciseScope's own
        // "reflects the last save" note in DESIGN-010 stage 1).
        name: parentStation?.name,
        description: parentStation?.description,
        variantSuffix: parentStation?.variantSuffix,
        positionUtm: parentStation?.position == null
            ? null
            : formatUtm(parentStation!.position),
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

  /// Live inline warning shown right under the Post selector when
  /// switching stations (and so [_workingLocations]/[_workingPersons], and
  /// necessarily `personRef`) has left a `station.*` token in one of this
  /// roleplay's own fields unresolved (DESIGN-009 prompt 5, commit 3). Null
  /// when nothing is broken. Save already stays blocked by
  /// [_unresolvedReferenceFieldLabels] regardless — this only surfaces the
  /// problem without waiting for a Save attempt. Never rewrites or clears
  /// the author's text.
  Widget? _buildUnresolvedReferenceWarning(AppLocalizations l) {
    final offending = _unresolvedReferenceFieldLabels(l);
    if (offending.isEmpty) return null;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 18, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l.rolePlayBrokenReferenceWarning(offending.join(', ')),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The DESIGN-008 default section for [RolePlay]: the short structural
  /// fields that never become their own section (name, age, signalement,
  /// station, position).
  Widget _buildRoleplaySectionBody(BuildContext context, AppLocalizations l) {
    // Excludes roleplay.name (DESIGN-009 follow-up 4c): this is the
    // roleplay's own name field, and the renderer only substitutes
    // {{var.*}} there, never the cross-reference pass — so {{roleplay.name}}
    // would never resolve in this one field, unlike in behavior/background/
    // propsMd (see the full list in _buildSectionNavigated above).
    final planFields = [
      ...PlanFieldTokens.program(l),
      ...PlanFieldTokens.exercise(l),
      ...PlanFieldTokens.station(l),
      ...PlanFieldTokens.roleplay(l).where((t) => t.name != 'roleplay.name'),
    ];
    final stations = _stations;
    final exercises = _programService.loadExercises();
    final exerciseIndex = exercises.indexWhere(
      (e) => e.uuid == widget.rolePlay.exerciseUuid,
    );
    final stationNumberFormat =
        _programService.activeProgram?.stationNumberFormat ??
        StationNumberFormat.dotted;

    final fields = SafeArea(
      child: DismissKeyboard(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Post — the most structural choice (which post the
              // marker is on), so it leads (DESIGN-009 prompt 4g). A
              // compact card, not a full-width dropdown (DESIGN-009 prompt
              // 4j): re-pointing a marker's post after creation is rare, so
              // it reads as context with a discreet "Endre" action, not a
              // prominent control.
              _buildPostCard(
                context,
                l,
                stations,
                exerciseIndex: exerciseIndex,
                stationNumberFormat: stationNumberFormat,
              ),
              ?_buildUnresolvedReferenceWarning(l),
              const SizedBox(height: 16),
              // 2. Identity card (DESIGN-009 prompt 4i) — the effective
              // name/age/gender/signalement packed into one inherit/
              // override card, replacing the interleaved fields and 4g's
              // Person + Kjønn row.
              _buildIdentityCard(context, l, planFields),
              const SizedBox(height: 16),
              // 3. Posisjon — follows the person's location by default
              // (DESIGN-009 prompt 4i).
              _buildPositionSection(context, l),
            ],
          ),
        ),
      ),
    );

    return withSectionRollup(
      context: context,
      fields: fields,
      rollupSections: [
        for (final section in _MdSection.values)
          if (_activeMdSections.contains(section))
            RollupSection(
              id: section.name,
              label: _mdLabelFor(section, l),
              controller: _mdControllerFor(section),
              overrides: _effectiveVariables,
              roleplayFacets: _roleplayFacets,
            ),
      ],
      showRollup: _showRollup,
      onShowRollupChanged: (value) => setState(() => _showRollup = value),
    );
  }

  /// Applies [index] as the new [_stationIndex] (DESIGN-009 prompt 4j) —
  /// extracted from the old Post dropdown's own `onChanged` so
  /// [_showStationPicker] can call the same logic.
  void _onStationChanged(int index) {
    if (index == _stationIndex) return;
    setState(() {
      _stationIndex = index;
      final canInherit = _position == null || _positionFromStation;
      if (canInherit) {
        final stationPos = _stationPosition(index);
        if (stationPos != null) {
          _position = stationPos;
          _positionFromStation = true;
        }
      }
      // Persons/locations are station-owned (ADR-0047): a new station
      // means a new person/location list, so the working copies and
      // personRef follow the selection, same as [_parentStation] does.
      // Deliberately does NOT re-run [_autoCreatePersonFromIdentity] —
      // that bootstrap is an [initState]-only nicety for a fresh/legacy
      // roleplay's *first* load; once the author is interactively
      // switching stations, the mandatory-personRef validator should make
      // them pick from the new station's own list, not silently
      // manufacture a duplicate from whatever is currently typed.
      _workingLocations = List<Location>.of(
        _parentStation?.locations ?? const [],
      );
      _workingPersons = List<Person>.of(_parentStation?.persons ?? const []);
      _originalLocationSlugs = _workingLocations.map((l) => l.slug).toSet();
      _originalPersonSlugs = _workingPersons.map((p) => p.slug).toSet();
      _personRef = null;
    });
  }

  /// The Post picker (DESIGN-009 prompt 4j): a plain pick-one dialog over
  /// [stations], mirroring [_showPersonPicker] — re-pointing a marker's
  /// post after creation is rare, so this sits behind the compact card's
  /// discreet "Endre" action rather than a full-width dropdown always on
  /// screen.
  Future<void> _showStationPicker(
    BuildContext context,
    AppLocalizations l,
    List<Station> stations, {
    required int exerciseIndex,
    required StationNumberFormat stationNumberFormat,
  }) async {
    final selected = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l.stationLabel),
        children: [
          for (var i = 0; i < stations.length; i++)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(i),
              child: Row(
                children: [
                  StationNumberBadge(
                    label: Numbering.station(
                      stationNumberFormat,
                      exerciseNumber: exerciseIndex < 0 ? 1 : exerciseIndex + 1,
                      stationIndex: i,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(stations[i].name)),
                ],
              ),
            ),
        ],
      ),
    );
    if (selected != null) _onStationChanged(selected);
  }

  /// The Post selector as a compact card (DESIGN-009 prompt 4j): the
  /// station-code badge, the post name (or [AppLocalizations.noStationAssigned]
  /// when none is picked yet), and a discreet "Endre" action opening
  /// [_showStationPicker] — replacing the old full-width dropdown.
  Widget _buildPostCard(
    BuildContext context,
    AppLocalizations l,
    List<Station> stations, {
    required int exerciseIndex,
    required StationNumberFormat stationNumberFormat,
  }) {
    final theme = Theme.of(context);
    final stationIndex = _stationIndex;
    final station = stationIndex != null && stationIndex < stations.length
        ? stations[stationIndex]
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.stationLabel,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            child: InkWell(
              key: const Key('station-field'),
              onTap: () => _showStationPicker(
                context,
                l,
                stations,
                exerciseIndex: exerciseIndex,
                stationNumberFormat: stationNumberFormat,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                child: Row(
                  children: [
                    if (station != null && stationIndex != null) ...[
                      StationNumberBadge(
                        label: Numbering.station(
                          stationNumberFormat,
                          exerciseNumber: exerciseIndex < 0
                              ? 1
                              : exerciseIndex + 1,
                          stationIndex: stationIndex,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Text(
                        station?.name ?? l.noStationAssigned,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Flexible (not a bare Text): at narrow widths the
                    // station name above already yields to ellipsis first,
                    // but this label's own fixed width could still overflow
                    // the row on its own — shrink-with-ellipsis instead.
                    // A visible gap can appear here at very narrow widths
                    // when the station name is short enough to leave its
                    // Expanded box mostly empty — a known, minor cosmetic
                    // trade-off for overflow safety, distinct from (and much
                    // less visible than) the identity card's "Tilpass" row,
                    // which this same pattern used to cause a much more
                    // prominent version of before that row was rebuilt
                    // (single Expanded, right-aligned, see below).
                    Flexible(
                      child: Text(
                        l.rolePlayPostEditAction,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// The effective-identity card (DESIGN-009 prompt 4i): the Person
  /// selector as its own header — same [DropdownButtonFormField] and
  /// `person-field` key as before, now rendered richly via
  /// [DropdownButtonFormField.selectedItemBuilder] instead of a plain
  /// name — a disclosure footer, and the "Tilpass" override panel with
  /// Navn+Alder, Kjønn and Signalement.
  Widget _buildIdentityCard(
    BuildContext context,
    AppLocalizations l,
    List<PlanFieldToken> planFields,
  ) {
    final theme = Theme.of(context);
    final person = _selectedPerson;
    final overrideCount = person == null ? 0 : _identityOverrideCount(person);
    final panelSurfaceColor = theme.colorScheme.surfaceContainerHighest
        .withValues(alpha: 0.5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.rolePlayIdentitySectionLabel,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The Person selector, as the card's own header. A plain
              // tap-to-pick dialog rather than DropdownButtonFormField:
              // that widget's `selectedItemBuilder` closed-state area is
              // capped to a single-line height regardless of `itemHeight`,
              // too short for this three-line (name/meta/signalement)
              // summary. `pleaseSelectPerson` is enforced manually in
              // [_save] instead of via a FormField validator.
              InkWell(
                key: const Key('person-field'),
                onTap: () => _showPersonPicker(context, l),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildIdentityHeaderSummary(context, l, person),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 6, left: 4),
                        child: Icon(
                          Icons.unfold_more,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // "Tilpass" is the only toggle here (DESIGN-009 prompt 4j) —
              // no inherit-state or override-count label of any kind, since
              // a field the author does not touch simply reads as it is.
              // The chevron alone signals open/closed state.
              InkWell(
                onTap: () =>
                    setState(() => _identityExpanded = !_identityExpanded),
                child: Container(
                  key: const Key('identity-disclosure'),
                  color: panelSurfaceColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        overrideCount == 0
                            ? Icons.tune
                            : Icons.fact_check_outlined,
                        size: 16,
                        color: overrideCount == 0
                            ? theme.colorScheme.onSurfaceVariant
                            : theme.colorScheme.primary,
                      ),
                      // The *sole* flex participant, absorbing all
                      // remaining space, with its own child right-aligned
                      // inside it: a sibling Flexible on the label below
                      // (as this used to be) would instead split that
                      // space evenly between this box and the label
                      // regardless of what the label actually needs,
                      // leaving it short of the row's edge with dead space
                      // after it. Nesting the label in an end-aligned Row
                      // *inside* the sole Expanded keeps it flush right
                      // whenever there's room, while its own Flexible still
                      // ellipsis-shrinks it if the row is ever too narrow.
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Flexible(
                              child: Text(
                                l.rolePlayIdentityCustomizeAction,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              _identityExpanded
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_identityExpanded)
                Container(
                  key: const Key('identity-panel'),
                  color: panelSurfaceColor,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _identityFacetColumn(
                              label: l.roleName,
                              field: RingDrillTextField(
                                controller: _nameController,
                                label: l.roleName,
                                // The panel already labels this facet via
                                // _identityFacetColumn above — this field's
                                // own floating label would just duplicate
                                // "Navn" a second time.
                                showLabel: false,
                                tokenAware: true,
                                overrides: _effectiveVariables,
                                planFields: planFields,
                                // Rebuilds this screen so the card's
                                // summary/override dot stays live as the
                                // author types — the controller's own
                                // notifyListeners() only repaints the
                                // field itself (DESIGN-009 follow-up 4).
                                onChanged: (_) => setState(() {}),
                                onCreateVariable: _createVariableInline,
                                onCreateLocation: _createLocationInline,
                                onCreatePerson: _createPersonInline,
                                validator: (value) =>
                                    value != null && value.trim().isNotEmpty
                                    ? null
                                    : l.pleaseEnterAName,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 84,
                            child: _identityFacetColumn(
                              label: l.roleAge,
                              field: TextFormField(
                                key: const Key('age-field'),
                                controller: _ageController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                onChanged: (_) => setState(() {}),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return null;
                                  }
                                  final age = int.tryParse(value);
                                  if (age == null || age < 0 || age > 120) {
                                    return l.ageRange;
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _identityFacetColumn(
                        label: l.roleGender,
                        field: GenderSegmentedControl(
                          value: _gender,
                          onChanged: (value) => setState(() => _gender = value),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _identityFacetColumn(
                        label: l.roleSignalement,
                        field: TextFormField(
                          key: const Key('signalement-field'),
                          controller: _signalementController,
                          onChanged: (_) => setState(() {}),
                          keyboardType: TextInputType.multiline,
                          minLines: 1,
                          maxLines: 4,
                          decoration: const InputDecoration(isDense: true),
                        ),
                      ),
                      // Single collective reset (DESIGN-009 prompt 4j),
                      // superseding 4i's per-field one — clears every
                      // overridden facet at once, including age (which had
                      // no per-field reset at all under the old layout).
                      if (person != null && overrideCount > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: InkWell(
                              onTap: () => setState(() {
                                _nameController.text = person.name;
                                _ageController.text =
                                    person.age?.toString() ?? '';
                                _gender = person.gender;
                                _signalementController.text =
                                    person.signalement ?? '';
                              }),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.replay,
                                    size: 13,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    l.rolePlayIdentityResetAction,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// The position section (DESIGN-009 prompt 4i): follows the selected
  /// person's own location by default, mirroring the identity card's
  /// inherit/override pattern but with a single facet (the coordinate)
  /// instead of four. Falls through to the plain, unchanged
  /// [PositionFormField] when there is no inheritable coordinate — no
  /// card, no regression from the pre-existing "defaults to the post's
  /// position" behavior.
  Widget _buildPositionSection(BuildContext context, AppLocalizations l) {
    final personCoord = _personLocationCoordinate;
    if (personCoord == null) {
      return PositionFormField(
        key: ValueKey(_position),
        variant: PositionFieldVariant.card,
        initialValue: _position,
        onChanged: (pos) => setState(() {
          _position = pos;
          _positionFromStation = false;
        }),
        onSaved: (pos) => _rolePlay = _rolePlay.copyWith(position: pos),
      );
    }

    final theme = Theme.of(context);
    final location = _selectedPersonLocation!;
    final locationLabel = location.label.isEmpty
        ? location.slug
        : location.label;
    final following = _positionFollowsPerson;

    if (!_positionExpanded && following) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.position,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              locationLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            PositionWidget(
                              format: PositionFormat.utm,
                              position: personCoord,
                              wrapped: false,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  key: const Key('position-disclosure'),
                  onTap: () => setState(() => _positionExpanded = true),
                  child: Container(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.map_outlined,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        // No inherit-state label here (DESIGN-009 prompt
                        // 4j) — the location name above already reads
                        // as the source.
                        const Expanded(child: SizedBox.shrink()),
                        Text(
                          l.rolePlayPositionSetOwnAction,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PositionFormField(
          key: ValueKey(_position),
          variant: PositionFieldVariant.card,
          initialValue: _position,
          onChanged: (pos) => setState(() {
            _position = pos;
            _positionFromStation = false;
          }),
          onSaved: (pos) => _rolePlay = _rolePlay.copyWith(position: pos),
        ),
        if (!following)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: InkWell(
              onTap: () => setState(() {
                _position = personCoord;
                _positionExpanded = false;
              }),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.replay,
                    size: 13,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    l.rolePlayIdentityResetAction,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// The identity card's collapsed-header content: this roleplay's own
  /// live effective identity, not [person]'s raw fields — a bold name
  /// (with a small accent dot when any facet is overridden), an "age ·
  /// gender" meta line, and either the signalement or, when the *name*
  /// itself is overridden, "Tilpasset fra {person.name}" (DESIGN-009
  /// prompt 4j) so the reader still knows who is actually being portrayed.
  Widget _buildIdentityHeaderSummary(
    BuildContext context,
    AppLocalizations l,
    Person? person,
  ) {
    final theme = Theme.of(context);
    final overrideCount = person == null ? 0 : _identityOverrideCount(person);
    final nameOverridden =
        person != null && !_isInherited(_nameController.text, person.name);
    final age = int.tryParse(_ageController.text.trim());
    final genderLabel = genderLabelFor(_gender, l);
    final metaParts = [if (age != null) l.rolePlayAgeYears(age), ?genderLabel];
    final signalementText = _signalementController.text.trim();
    final displayName = _nameController.text.trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 17,
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(
            Icons.person,
            size: 18,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      displayName.isEmpty ? l.newRolePlayTitle : displayName,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (overrideCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                ],
              ),
              if (metaParts.isNotEmpty)
                Text(
                  metaParts.join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              if (nameOverridden)
                Text(
                  l.rolePlayCustomizedFrom(person.name),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                )
              else if (signalementText.isNotEmpty)
                Text(
                  signalementText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// One override-panel row: [label] above [field] itself. No per-facet
  /// inherit chip and no per-field reset action (DESIGN-009 prompt 4j) —
  /// a field the author does not touch simply reads as it is;
  /// the panel foot's single collective reset covers all of them at once.
  Widget _identityFacetColumn({required String label, required Widget field}) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        field,
      ],
    );
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l = AppLocalizations.of(context)!;

    // The Post card is a plain tap target opening a picker dialog, not a
    // DropdownButtonFormField (DESIGN-009 prompt 4j), so this is no longer
    // covered by the Form's own validate() above — enforced manually here
    // instead, same pattern as the personRef/name/age checks below.
    if (_stations.isNotEmpty && _stationIndex == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.pleaseSelectStation)));
      return;
    }

    // Mandatory personRef is scoped to "a station is selected" (ADR-0047):
    // persons are station-owned, so there is nothing to require a
    // selection *from* without one. Enforced manually (not a FormField
    // validator) since the identity card's header is a plain tap target,
    // not a DropdownButtonFormField (DESIGN-009 prompt 4i).
    if (_parentStation != null && _personRef == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.pleaseSelectPerson)));
      return;
    }

    // The identity card's Navn/Alder fields only exist in the widget tree
    // (and so only get their own FormField validation) while the "Tilpass"
    // panel is expanded (DESIGN-009 prompt 4i). Check both manually too, so
    // an empty name or an out-of-range age typed while the panel was open
    // still blocks save after the author collapses it again.
    if (_nameController.text.trim().isEmpty) {
      setState(() => _identityExpanded = true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.pleaseEnterAName)));
      return;
    }
    final typedAgeText = _ageController.text.trim();
    if (typedAgeText.isNotEmpty) {
      final typedAge = int.tryParse(typedAgeText);
      if (typedAge == null || typedAge < 0 || typedAge > 120) {
        setState(() => _identityExpanded = true);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.ageRange)));
        return;
      }
    }

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

    final unresolvedOffending = _unresolvedReferenceFieldLabels(l);
    if (unresolvedOffending.isNotEmpty) {
      final sections = unresolvedOffending.join(', ');
      final references = _unresolvedReferences().join(', ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.saveBlockedUnresolvedReference(sections, references)),
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
      // Explicit rather than relying on PositionFormField's own `onSaved`
      // (DESIGN-009 prompt 4i): that FormField isn't even mounted while
      // the position card shows its collapsed location summary instead of
      // the picker, so its onSaved would never fire. [_position] is the
      // single source of truth regardless.
      position: _position,
    );

    // Write-back (ADR-0047, DESIGN-009 follow-up 4): only entries created
    // this session — those beyond what the (currently selected) station
    // already had when this editor opened/last switched stations — need to
    // be carried up; the rest already live on the station this editor
    // itself does not own.
    final newLocations = [
      for (final location in _workingLocations)
        if (!_originalLocationSlugs.contains(location.slug)) location,
    ];
    final newPersons = [
      for (final person in _workingPersons)
        if (!_originalPersonSlugs.contains(person.slug)) person,
    ];

    Navigator.of(context).pop((
      rolePlay: updated,
      additions: (
        variables: _pendingVariables,
        stationLocations: newLocations,
        stationPersons: newPersons,
        rolePlays: const <RolePlay>[],
      ),
    ));
  }
}
