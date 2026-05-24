import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/views/position_form_field.dart';

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
  });

  final RolePlay rolePlay;
  final Exercise? exercise;

  @override
  State<RolePlayFormScreen> createState() => _RolePlayFormScreenState();
}

class _RolePlayFormScreenState extends State<RolePlayFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _signalementController = TextEditingController();
  final _backgroundController = TextEditingController();
  final _behaviorController = TextEditingController();

  int? _stationIndex;
  // Tracks the current position; updated by PositionFormField.onSaved
  late RolePlay _rolePlay;

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
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _signalementController.dispose();
    _backgroundController.dispose();
    _behaviorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final stations = widget.exercise?.stations ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.rolePlay.name.trim().isEmpty
              ? localizations.newRolePlayTitle
              : widget.rolePlay.name,
        ),
        actions: [
          ElevatedButton(
            onPressed: _save,
            child: Text(localizations.save),
          ),
        ],
        actionsPadding: const EdgeInsets.only(right: 16),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name
                TextFormField(
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
                const SizedBox(height: 12),

                // Age (optional, 0–120)
                TextFormField(
                  key: const Key('age-field'),
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: localizations.roleAge,
                    hintText: localizations.optional,
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
                const SizedBox(height: 12),

                // Station dropdown
                DropdownButtonFormField<int?>(
                  initialValue: _stationIndex,
                  decoration: InputDecoration(
                    labelText: localizations.stationLabel,
                  ),
                  items: [
                    DropdownMenuItem<int?>(
                      value: null,
                      child: Text(localizations.noStationAssigned),
                    ),
                    for (var i = 0; i < stations.length; i++)
                      DropdownMenuItem<int?>(
                        value: i,
                        child: Text(stations[i].name),
                      ),
                  ],
                  onChanged: (v) => setState(() => _stationIndex = v),
                ),
                const SizedBox(height: 16),

                // Signalement
                TextFormField(
                  controller: _signalementController,
                  keyboardType: TextInputType.multiline,
                  minLines: 2,
                  maxLines: 8,
                  decoration: InputDecoration(
                    labelText: localizations.roleSignalement,
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),

                // Background
                TextFormField(
                  controller: _backgroundController,
                  keyboardType: TextInputType.multiline,
                  minLines: 2,
                  maxLines: 8,
                  decoration: InputDecoration(
                    labelText: localizations.roleBackground,
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),

                // Behavior
                TextFormField(
                  controller: _behaviorController,
                  keyboardType: TextInputType.multiline,
                  minLines: 2,
                  maxLines: 8,
                  decoration: InputDecoration(
                    labelText: localizations.roleBehavior,
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),

                // Position
                PositionFormField(
                  initialValue: _rolePlay.position,
                  onSaved: (pos) {
                    _rolePlay = _rolePlay.copyWith(position: pos);
                  },
                ),
              ],
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
      signalement: _signalementController.text.trim().isEmpty
          ? null
          : _signalementController.text.trim(),
      background: _backgroundController.text.trim().isEmpty
          ? null
          : _backgroundController.text.trim(),
      behavior: _behaviorController.text.trim().isEmpty
          ? null
          : _behaviorController.text.trim(),
      stationIndex: _stationIndex,
    );

    Navigator.of(context).pop(updated);
  }
}
