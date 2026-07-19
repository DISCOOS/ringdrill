import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/person.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/utils/plan_variables.dart';
import 'package:ringdrill/utils/slug.dart';
import 'package:ringdrill/utils/station_scenario_tokens.dart';
import 'package:ringdrill/views/location_form_screen.dart';
import 'package:ringdrill/views/plan_additions.dart';
import 'package:ringdrill/views/shell/open_form_surface.dart';
import 'package:ringdrill/views/widgets/dismiss_keyboard.dart';
import 'package:ringdrill/views/widgets/editor_token.dart';
import 'package:ringdrill/views/widgets/gender_segmented_control.dart';
import 'package:ringdrill/views/widgets/plan_field_tokens.dart';
import 'package:ringdrill/views/widgets/plan_scope.dart';
import 'package:ringdrill/views/widgets/ringdrill_text_field.dart';
import 'package:ringdrill/views/widgets/station_scope.dart';
import 'package:ringdrill/views/widgets/token_text_editing_controller.dart';

/// Marker item value for the location picker's inline "+ Ny lokasjon" entry
/// — distinct from every real [Location.slug] (which never contains a colon).
const _createLocationValue = ':create-location:';

/// A declared plan variable name (ADR-0046) -- mirrors
/// `StationFormScreen`'s/`RolePlayFormScreen`'s own copy of this pattern.
final _variableSlugPattern = RegExp(r'^[a-z][a-z0-9_]*$');

/// [PersonFormScreen]'s result: the saved [Person] plus any [PlanAdditions]
/// created inline this session (ADR-0047, DESIGN-009 "Inline creation and
/// write-back") -- a new `var.*` (-> `Program`), a location from the home
/// picker's "Ny lokasjon" entry, or a sibling `station.loc.*`/
/// `station.person.*` created from the `name`/`signalement`/`notes` fields'
/// own insertion menu (-> the station this [Person] itself joins, which this
/// form does not own and never writes to directly).
typedef PersonFormResult = ({Person person, PlanAdditions additions});

/// Self-sufficient full-screen/dialog form for creating or editing a
/// station-owned [Person] (ADR-0047, DESIGN-009 follow-up 3b). Opened via
/// `openFormSurface` by the caller (`PersonsSection`) — full-screen route
/// on narrow, dialog on wide (ADR-0030). Pops with a [PersonFormResult], or
/// null on cancel.
///
/// The reference (`slug`) is never shown: it is a random id generated at
/// creation via [randomSlug] against [existingSlugs] (DESIGN-009 follow-up
/// 4h — derived from no field) and carries through unchanged when [initial]
/// is edited (there is no rename, ADR-0047).
class PersonFormScreen extends StatefulWidget {
  const PersonFormScreen({
    super.key,
    required this.existingSlugs,
    required this.locations,
    this.initial,
  });

  /// Slugs already used by other persons on the station, so a new
  /// reference never collides. Excludes [initial]'s own slug when editing.
  final Set<String> existingSlugs;

  /// The station's own locations, offered in the location picker.
  final List<Location> locations;

  final Person? initial;

  @override
  State<PersonFormScreen> createState() => _PersonFormScreenState();
}

class _PersonFormScreenState extends State<PersonFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TokenTextEditingController(
    text: widget.initial?.name ?? '',
  );
  late final _ageController = TextEditingController(
    text: widget.initial?.age?.toString() ?? '',
  );
  late final _signalementController = TokenTextEditingController(
    text: widget.initial?.signalement ?? '',
  );
  late final _notesController = TokenTextEditingController(
    text: widget.initial?.notes ?? '',
  );
  String? _gender;
  String? _locSlug;

  /// Working copy of [PersonFormScreen.locations] -- both the home picker's
  /// own dropdown options and (ADR-0047, DESIGN-009 "Inline creation and
  /// write-back") the sibling `station.loc.*` candidates a
  /// `name`/`signalement`/`notes` field can reference or create. Seeded
  /// from what this form was given, so a new entry from either mechanism
  /// shows up immediately without waiting for the caller to rebuild
  /// (DESIGN-009's "editor resolves newly created entities against a
  /// working copy it holds"); diffed against [_originalLocationSlugs] at
  /// save time to carry only the new ones up as a write-back.
  late List<Location> _workingLocations;
  late Set<String> _originalLocationSlugs;

  /// [_workingLocations]'s `station.person.*` counterpart -- this form has
  /// no `persons:` constructor prop (only its own [initial] and sibling
  /// [_workingLocations]), so it is seeded from the ambient `StationScope`
  /// instead, in [didChangeDependencies].
  late List<Person> _workingPersons;
  late Set<String> _originalPersonSlugs;

  /// The ambient `PlanScope`'s declared variables as of open time -- this
  /// form does not own `Program.variables` either, so a `var.*` created
  /// inline is tracked in [_pendingVariables] instead and carried up the
  /// same way.
  late List<DrillVariable> _declaredVariables;
  final List<DrillVariable> _pendingVariables = [];

  bool _ambientScopesSeeded = false;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    _gender = widget.initial?.gender;
    _locSlug = widget.initial?.locSlug;
    _workingLocations = List<Location>.of(widget.locations);
    _originalLocationSlugs = _workingLocations.map((l) => l.slug).toSet();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ambientScopesSeeded) return;
    _ambientScopesSeeded = true;
    final stationScope = StationScope.maybeOf(context);
    _workingPersons = List<Person>.of(stationScope?.persons ?? const []);
    _originalPersonSlugs = _workingPersons.map((p) => p.slug).toSet();
    _declaredVariables = List<DrillVariable>.of(
      PlanScope.of(context).variables,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _signalementController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String? _validateAge(String? value, AppLocalizations l10n) {
    if (value == null || value.isEmpty) return null;
    final age = int.tryParse(value);
    if (age == null || age < 0 || age > 120) return l10n.ageRange;
    return null;
  }

  Future<void> _createLocationInline() async {
    final created = await openFormSurface<LocationFormResult>(
      context,
      // Folded into this form's own working copies below, not persisted
      // directly — this form's own caller owns the eventual save.
      commitsToParent: true,
      builder: (_) => LocationFormScreen(
        existingSlugs: _workingLocations.map((l) => l.slug).toSet(),
      ),
    );
    if (created == null || !mounted) return;
    setState(() {
      _workingLocations = [..._workingLocations, created.location];
      _locSlug = created.location.slug;
      _mergeAdditions(created.additions);
    });
  }

  /// Merges a nested editor's own `PlanAdditions` write-back into this
  /// form's working copies (ADR-0047, DESIGN-009 "Inline creation and
  /// write-back") — mirrors `StationFormScreen._openRolePlayEditor`'s merge
  /// block. Call inside a `setState`.
  void _mergeAdditions(PlanAdditions additions) {
    final existingLocSlugs = _workingLocations.map((l) => l.slug).toSet();
    _workingLocations = [
      ..._workingLocations,
      ...additions.stationLocations.where(
        (l) => !existingLocSlugs.contains(l.slug),
      ),
    ];
    final existingPersonSlugs = _workingPersons.map((p) => p.slug).toSet();
    _workingPersons = [
      ..._workingPersons,
      ...additions.stationPersons.where(
        (p) => !existingPersonSlugs.contains(p.slug),
      ),
    ];
    final declaredNames = {
      for (final v in _declaredVariables) v.name,
      for (final v in _pendingVariables) v.name,
    };
    _pendingVariables.addAll(
      additions.variables.where((v) => !declaredNames.contains(v.name)),
    );
  }

  /// Wired to a token-aware field's `onCreateLocation` hook (ADR-0047,
  /// DESIGN-009 follow-up 4/4e): the insertion menu needs the generated
  /// slug synchronously to embed in the token it is about to insert. The
  /// new [Location] joins the same station this [Person] itself joins,
  /// which this form does not own -- [_save] diffs [_workingLocations]
  /// against [_originalLocationSlugs] to carry it up as a write-back.
  String _createStationLocation(String label) {
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

  /// [_createStationLocation]'s [_workingPersons] counterpart.
  String _createStationPerson(String label) {
    final slug = randomSlug(
      (candidate) => _workingPersons.any((p) => p.slug == candidate),
    );
    setState(() {
      _workingPersons = [..._workingPersons, Person(slug: slug, name: label)];
    });
    return slug;
  }

  /// Wired to every token-aware field's `onCreateVariable` hook: the menu
  /// already inserted `{{var.<name>}}`; this only needs to declare it,
  /// empty, in [_pendingVariables] so the chip resolves live (amber) via the
  /// merged [PlanScope] this form provides in [build].
  void _createVariableInline(String name) {
    if (!_variableSlugPattern.hasMatch(name)) return;
    final alreadyDeclared = _declaredVariables.any((v) => v.name == name);
    final alreadyPending = _pendingVariables.any((v) => v.name == name);
    if (alreadyDeclared || alreadyPending) return;
    setState(() {
      _pendingVariables.add(DrillVariable(name: name, value: ''));
    });
  }

  /// This form's own token-aware fields, paired with their display label
  /// (DESIGN-009 follow-up 4e) — mirrors `StationFormScreen`'s own
  /// base-field scan, scoped down to `name`/`signalement`/`notes`.
  Iterable<(String label, String text)> _tokenAwareFields(
    AppLocalizations l10n,
  ) sync* {
    yield (l10n.roleName, _nameController.text);
    yield (l10n.roleSignalement, _signalementController.text);
    yield (l10n.personsSectionNotesLabel, _notesController.text);
  }

  /// Field labels with an undeclared `{{var.x}}` token — checked against
  /// [_declaredVariables]/[_pendingVariables] (this session's working set,
  /// including anything just created inline), not the ambient `PlanScope`
  /// directly: a variable created inline from one of these fields must not
  /// immediately block save as "undeclared" — mirrors
  /// `StationFormScreen._baseFieldLabelsWithUndeclaredTokens`.
  List<String> _fieldLabelsWithUndeclaredVariable(AppLocalizations l10n) {
    final declared = {
      for (final v in _declaredVariables) v.name,
      for (final v in _pendingVariables) v.name,
    };
    bool hasUndeclared(String text) => planVariableTokenPattern
        .allMatches(text)
        .any((m) => !declared.contains(m.group(1)));
    return [
      for (final (label, text) in _tokenAwareFields(l10n))
        if (hasUndeclared(text)) label,
    ];
  }

  /// The `station.loc.<slug>`/`station.person.<slug>` references in [text]
  /// whose slug is absent from [_workingLocations]/[_workingPersons] (this
  /// session's working set — a sibling entity created inline from one of
  /// these fields must not immediately block save as "unresolved") —
  /// mirrors `StationFormScreen._unresolvedReferencesIn`.
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

  List<String> _fieldLabelsWithUnresolvedReference(AppLocalizations l10n) {
    return [
      for (final (label, text) in _tokenAwareFields(l10n))
        if (_unresolvedReferencesIn(text).isNotEmpty) label,
    ];
  }

  Set<String> _unresolvedReferences(AppLocalizations l10n) {
    final refs = <String>{};
    for (final (_, text) in _tokenAwareFields(l10n)) {
      refs.addAll(_unresolvedReferencesIn(text));
    }
    return refs;
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l10n = AppLocalizations.of(context)!;

    final undeclared = _fieldLabelsWithUndeclaredVariable(l10n);
    if (undeclared.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.programSaveBlockedUndeclaredVariable(undeclared.join(', ')),
          ),
        ),
      );
      return;
    }

    final unresolved = _fieldLabelsWithUnresolvedReference(l10n);
    if (unresolved.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.saveBlockedUnresolvedReference(
              unresolved.join(', '),
              _unresolvedReferences(l10n).join(', '),
            ),
          ),
        ),
      );
      return;
    }

    final signalement = _signalementController.text.trim();
    final notes = _notesController.text.trim();
    final slug =
        widget.initial?.slug ?? randomSlug(widget.existingSlugs.contains);
    final person = Person(
      slug: slug,
      name: _nameController.text.trim(),
      age: _ageController.text.isEmpty
          ? null
          : int.tryParse(_ageController.text),
      gender: _gender,
      signalement: signalement.isEmpty ? null : signalement,
      locSlug: _locSlug,
      notes: notes.isEmpty ? null : notes,
    );
    // Write-back (ADR-0047, DESIGN-009 "Inline creation and write-back"):
    // only entries created this session -- beyond what this form was given/
    // the ambient StationScope already had when it opened -- need to be
    // carried up; the rest already live on the station this form itself
    // does not own.
    final newLocations = [
      for (final location in _workingLocations)
        if (!_originalLocationSlugs.contains(location.slug)) location,
    ];
    final newPersons = [
      for (final p in _workingPersons)
        if (!_originalPersonSlugs.contains(p.slug)) p,
    ];
    Navigator.of(context).pop((
      person: person,
      additions: (
        variables: _pendingVariables,
        stationLocations: newLocations,
        stationPersons: newPersons,
        rolePlays: const <RolePlay>[],
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = _isEdit
        ? l10n.personsSectionEditAction
        : l10n.personsSectionAddAction;
    // Resolvable at station scope and below (DESIGN-009 follow-up 4e) —
    // never `PlanFieldTokens.roleplay`, which only resolves inside a
    // roleplay's own scope, not a station-owned Person's.
    final planFields = [
      ...PlanFieldTokens.program(l10n),
      ...PlanFieldTokens.exercise(l10n),
      ...PlanFieldTokens.station(l10n),
    ];
    // Null for a new person (not yet part of the ambient StationScope, so
    // it cannot appear as a self-reference candidate anyway) — see
    // SelfTokenExclusion.
    final selfSlug = widget.initial?.slug;
    // Captured before this form re-wraps PlanScope/StationScope below (for
    // its own inline-created working copies, ADR-0047) -- `context` here is
    // this State's own, an ancestor of what this build() returns, so it
    // always resolves to the *ambient* scope from `openFormSurface`, never
    // this form's own re-provided one (same reasoning `RolePlayFormScreen`'s
    // own `build` documents).
    final ambientPlan = PlanScope.of(context);
    final ambientStation = StationScope.maybeOf(context);
    return PlanScope(
      variables: [..._declaredVariables, ..._pendingVariables],
      programName: ambientPlan.programName,
      programDescription: ambientPlan.programDescription,
      child: StationScope(
        locations: _workingLocations,
        persons: _workingPersons,
        portrayerOf: ambientStation?.portrayerOf,
        name: ambientStation?.name,
        stationCode: ambientStation?.stationCode,
        description: ambientStation?.description,
        variantSuffix: ambientStation?.variantSuffix,
        position: ambientStation?.position,
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.close),
              tooltip: l10n.cancel,
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(title),
            actions: [
              // "Ferdig"/"Done" when this form only folds its result into a
              // parent's own unsaved working copy (DESIGN-010's
              // FormSurfaceScope) — this form has its own AppBar rather than
              // `SectionNavigatedForm`'s, so it reads the scope directly.
              FilledButton(
                onPressed: _save,
                child: Text(
                  FormSurfaceScope.of(context)
                      ? l10n.formDoneAction
                      : l10n.save,
                ),
              ),
              const SizedBox(width: 16),
            ],
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
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: RingDrillTextField(
                              controller: _nameController,
                              label: l10n.roleName,
                              autofocus: !_isEdit,
                              tokenAware: true,
                              planFields: planFields,
                              selfPerson: selfSlug == null
                                  ? null
                                  : SelfTokenExclusion(
                                      slug: selfSlug,
                                      excludeBare: true,
                                      excludedFacet: 'name',
                                    ),
                              onCreateVariable: _createVariableInline,
                              onCreateLocation: _createStationLocation,
                              onCreatePerson: _createStationPerson,
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 84,
                            child: TextFormField(
                              controller: _ageController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: InputDecoration(
                                labelText: l10n.roleAge,
                              ),
                              validator: (value) => _validateAge(value, l10n),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.roleGender,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 6),
                          GenderSegmentedControl(
                            value: _gender,
                            onChanged: (value) =>
                                setState(() => _gender = value),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      RingDrillTextArea(
                        controller: _signalementController,
                        label: l10n.roleSignalement,
                        minLines: 1,
                        maxLines: 3,
                        tokenAware: true,
                        planFields: planFields,
                        selfPerson: selfSlug == null
                            ? null
                            : SelfTokenExclusion(
                                slug: selfSlug,
                                excludedFacet: 'signalement',
                              ),
                        onCreateVariable: _createVariableInline,
                        onCreateLocation: _createStationLocation,
                        onCreatePerson: _createStationPerson,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        key: const Key('loc-field'),
                        initialValue: _locSlug ?? '',
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: l10n.personsSectionLocationLabel,
                        ),
                        items: [
                          DropdownMenuItem(
                            value: '',
                            child: Text(l10n.personsSectionLocationNone),
                          ),
                          for (final location in _workingLocations)
                            DropdownMenuItem(
                              value: location.slug,
                              child: Text(
                                location.label.isEmpty
                                    ? location.slug
                                    : location.label,
                              ),
                            ),
                          DropdownMenuItem(
                            value: _createLocationValue,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.add, size: 16),
                                const SizedBox(width: 6),
                                Text(l10n.locationsSectionAddAction),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == _createLocationValue) {
                            _createLocationInline();
                            return;
                          }
                          setState(
                            () => _locSlug = (value == null || value.isEmpty)
                                ? null
                                : value,
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      RingDrillTextArea(
                        controller: _notesController,
                        label: l10n.personsSectionNotesLabel,
                        minLines: 1,
                        maxLines: 3,
                        tokenAware: true,
                        planFields: planFields,
                        onCreateVariable: _createVariableInline,
                        onCreateLocation: _createStationLocation,
                        onCreatePerson: _createStationPerson,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
