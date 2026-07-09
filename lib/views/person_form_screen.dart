import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/person.dart';
import 'package:ringdrill/utils/slug.dart';
import 'package:ringdrill/views/location_form_screen.dart';
import 'package:ringdrill/views/shell/open_form_surface.dart';
import 'package:ringdrill/views/widgets/dismiss_keyboard.dart';
import 'package:ringdrill/views/widgets/gender_segmented_control.dart';

/// Marker item value for the home picker's inline "+ Ny lokasjon" entry —
/// distinct from every real [Location.slug] (which never contains a colon).
const _createLocationValue = ':create-location:';

/// [PersonFormScreen]'s result: the saved [Person] plus, when the home
/// picker's inline "Ny lokasjon" created one, that new [Location] — a
/// write-back the caller (`PersonsSection`) applies to the station's own
/// working list alongside the person (DESIGN-009's inline-creation
/// mechanism, scoped down to this one hop: the caller already owns both
/// lists, so no `PlanAdditions`-style payload is needed here).
typedef PersonFormResult = ({Person person, Location? newLocation});

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

  /// The station's own locations, offered in the home picker.
  final List<Location> locations;

  final Person? initial;

  @override
  State<PersonFormScreen> createState() => _PersonFormScreenState();
}

class _PersonFormScreenState extends State<PersonFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.initial?.name ?? '',
  );
  late final _ageController = TextEditingController(
    text: widget.initial?.age?.toString() ?? '',
  );
  late final _signalementController = TextEditingController(
    text: widget.initial?.signalement ?? '',
  );
  late final _notesController = TextEditingController(
    text: widget.initial?.notes ?? '',
  );
  String? _gender;
  String? _homeSlug;

  /// Working copy of [PersonFormScreen.locations], seeded from what this
  /// form was given, so the home picker's own inline "Ny lokasjon" chip
  /// shows up immediately without waiting for the caller to rebuild
  /// (DESIGN-009's "editor resolves newly created entities against a
  /// working copy it holds").
  late List<Location> _workingLocations;

  /// The location created inline via the home picker this session, if any
  /// — carried out in the popped [PersonFormResult] for the caller to add
  /// to the station's own list.
  Location? _newLocation;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    _gender = widget.initial?.gender;
    _homeSlug = widget.initial?.homeSlug;
    _workingLocations = List<Location>.of(widget.locations);
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
    final created = await openFormSurface<Location>(
      context,
      builder: (_) => LocationFormScreen(
        existingSlugs: _workingLocations.map((l) => l.slug).toSet(),
      ),
    );
    if (created == null || !mounted) return;
    setState(() {
      _workingLocations = [..._workingLocations, created];
      _newLocation = created;
      _homeSlug = created.slug;
    });
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final signalement = _signalementController.text.trim();
    final notes = _notesController.text.trim();
    final slug = widget.initial?.slug ?? randomSlug(widget.existingSlugs.contains);
    final person = Person(
      slug: slug,
      name: _nameController.text.trim(),
      age: _ageController.text.isEmpty
          ? null
          : int.tryParse(_ageController.text),
      gender: _gender,
      signalement: signalement.isEmpty ? null : signalement,
      homeSlug: _homeSlug,
      notes: notes.isEmpty ? null : notes,
    );
    Navigator.of(
      context,
    ).pop((person: person, newLocation: _newLocation));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = _isEdit
        ? l10n.personsSectionEditAction
        : l10n.personsSectionAddAction;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: l10n.cancel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(title),
        actions: [
          FilledButton(onPressed: _save, child: Text(l10n.save)),
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
                        child: TextFormField(
                          controller: _nameController,
                          autofocus: !_isEdit,
                          decoration: InputDecoration(
                            labelText: l10n.roleName,
                          ),
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
                          decoration: InputDecoration(labelText: l10n.roleAge),
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
                        onChanged: (value) => setState(() => _gender = value),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _signalementController,
                    minLines: 1,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: l10n.roleSignalement,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: const Key('home-field'),
                    initialValue: _homeSlug ?? '',
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l10n.personsSectionHomeLabel,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: '',
                        child: Text(l10n.personsSectionHomeNone),
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
                        () => _homeSlug = (value == null || value.isEmpty)
                            ? null
                            : value,
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _notesController,
                    minLines: 1,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: l10n.personsSectionNotesLabel,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
