import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/numbering.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/position_form_field.dart';
import 'package:ringdrill/views/widgets/optional_field_sections.dart';
import 'package:ringdrill/views/widgets/role_number_badge.dart';
import 'package:ringdrill/views/widgets/station_number_badge.dart';
import 'package:ringdrill/views/widgets/dismiss_keyboard.dart';

/// Optional long-form sections that can be added to a [RolePlay].
enum _Section { signalement, background, behavior }

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
  const RolePlayFormScreen({super.key, required this.rolePlay, this.exercise});

  final RolePlay rolePlay;
  final Exercise? exercise;

  @override
  State<RolePlayFormScreen> createState() => _RolePlayFormScreenState();
}

class _RolePlayFormScreenState extends State<RolePlayFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _programService = ProgramService();

  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _signalementController = TextEditingController();
  final _backgroundController = TextEditingController();
  final _behaviorController = TextEditingController();

  final _signalementFocus = FocusNode();
  final _backgroundFocus = FocusNode();
  final _behaviorFocus = FocusNode();

  late Set<_Section> _activeSections;
  int? _stationIndex;
  // Tracks the current position; updated by PositionFormField.onSaved
  late RolePlay _rolePlay;
  // Current marker position, kept in sync with the PositionFormField.
  LatLng? _position;
  // True while [_position] still mirrors the selected station's position (a
  // default we may keep updating). Cleared once the user picks a spot on the
  // map, so we never overwrite a manual fine-tune.
  bool _positionFromStation = false;

  @override
  void initState() {
    super.initState();
    _rolePlay = widget.rolePlay;
    _nameController.text = _rolePlay.name;
    _ageController.text = _rolePlay.age?.toString() ?? '';
    _signalementController.text = _rolePlay.signalement ?? '';
    _backgroundController.text = _rolePlay.background ?? '';
    _behaviorController.text = _rolePlay.behavior ?? '';
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
    _signalementFocus.dispose();
    _backgroundFocus.dispose();
    _behaviorFocus.dispose();
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
    _formKey.currentState!.save();

    final ageText = _ageController.text.trim();
    final updated = _rolePlay.copyWith(
      name: _nameController.text.trim(),
      age: ageText.isEmpty ? null : int.parse(ageText),
      signalement:
          _activeSections.contains(_Section.signalement) &&
              _signalementController.text.trim().isNotEmpty
          ? _signalementController.text.trim()
          : null,
      background:
          _activeSections.contains(_Section.background) &&
              _backgroundController.text.trim().isNotEmpty
          ? _backgroundController.text.trim()
          : null,
      behavior:
          _activeSections.contains(_Section.behavior) &&
              _behaviorController.text.trim().isNotEmpty
          ? _behaviorController.text.trim()
          : null,
      stationIndex: _stationIndex,
    );

    Navigator.of(context).pop(updated);
  }
}
