import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/team.dart';
import 'package:ringdrill/views/position_form_field.dart';

class TeamFormScreen extends StatefulWidget {
  const TeamFormScreen({super.key, required this.team});

  final Team team;

  @override
  State<TeamFormScreen> createState() => _TeamFormScreenState();
}

class _TeamFormScreenState extends State<TeamFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _numberOfMembersController = TextEditingController();

  late Team _team;

  @override
  void initState() {
    super.initState();
    _team = widget.team;
    _nameController.text = _team.name;
    _numberOfMembersController.text = _team.numberOfMembers?.toString() ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _numberOfMembersController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: localizations.cancel,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(localizations.editTeam),
        actions: [
          ElevatedButton(onPressed: _save, child: Text(localizations.save)),
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
                TextFormField(
                  autofocus: true,
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: localizations.teamName,
                  ),
                  validator: (value) => value != null && value.trim().isNotEmpty
                      ? null
                      : localizations.pleaseEnterAName,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('number-of-members-field'),
                  controller: _numberOfMembersController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: localizations.numberOfMembers,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return null;
                    final numberOfMembers = int.tryParse(value);
                    if (numberOfMembers == null || numberOfMembers < 0) {
                      return localizations.pleaseEnterAValidNumber;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                PositionFormField(
                  initialValue: _team.position,
                  onSaved: (position) {
                    _team = _team.copyWith(position: position);
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
    final numberOfMembers = _numberOfMembersController.text;
    Navigator.pop(
      context,
      _team.copyWith(
        name: _nameController.text.trim(),
        numberOfMembers: numberOfMembers.isEmpty
            ? null
            : int.parse(numberOfMembers),
      ),
    );
  }
}
