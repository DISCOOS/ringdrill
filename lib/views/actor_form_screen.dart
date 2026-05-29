import 'package:flutter/material.dart';
import 'package:nanoid/nanoid.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/actor.dart';

/// Form for creating or editing an [Actor] record.
///
/// Accepts an existing [actor] (edit mode) or null (create mode).
/// Pops with [ActorFormSave] on save, [ActorFormDelete] on delete, or null on
/// cancel.
///
/// When [modal] is true the caller provided a bottom-sheet context and the
/// save button text is "Add" rather than "Save". The widget is stateless
/// with respect to persistence — the caller persists via [ProgramService].
class ActorFormScreen extends StatefulWidget {
  const ActorFormScreen({super.key, this.actor, this.modal = false});

  /// Existing actor to edit; null to create a new one.
  final Actor? actor;

  /// When true, the form is shown inside a bottom sheet (cast roster FAB /
  /// cast picker inline). Changes button label from "Save" to the locale's
  /// "Add" / "Done" equivalent.
  final bool modal;

  @override
  State<ActorFormScreen> createState() => _ActorFormScreenState();
}

sealed class ActorFormResult {
  const ActorFormResult();
}

final class ActorFormSave extends ActorFormResult {
  const ActorFormSave(this.actor);

  final Actor actor;
}

final class ActorFormDelete extends ActorFormResult {
  const ActorFormDelete(this.actor);

  final Actor actor;
}

class _ActorFormScreenState extends State<ActorFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final actor = widget.actor;
    if (actor != null) {
      _nameController.text = actor.realName;
      _phoneController.text = actor.phone ?? '';
      _notesController.text = actor.notes ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final isNew = widget.actor == null;
    final title = isNew ? localizations.newActor : widget.actor!.realName;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: localizations.cancel,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(title),
        actions: [
          if (!isNew)
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: localizations.deleteActor,
              onPressed: _confirmDelete,
            ),
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
                // Real name (required)
                TextFormField(
                  autofocus: true,
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: localizations.actorRealName,
                  ),
                  validator: (value) => value != null && value.trim().isNotEmpty
                      ? null
                      : localizations.pleaseEnterAName,
                ),
                const SizedBox(height: 12),

                // Phone (optional)
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: localizations.actorPhone,
                    hintText: localizations.optional,
                  ),
                ),
                const SizedBox(height: 12),

                // Notes (optional, multiline)
                TextFormField(
                  controller: _notesController,
                  keyboardType: TextInputType.multiline,
                  minLines: 2,
                  maxLines: 6,
                  decoration: InputDecoration(
                    labelText: localizations.actorNotes,
                    hintText: localizations.optional,
                    alignLabelWithHint: true,
                  ),
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

    final existing = widget.actor;
    final saved = existing == null
        ? Actor(
            uuid: nanoid(10),
            realName: _nameController.text.trim(),
            phone: _phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text.trim(),
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
          )
        : existing.copyWith(
            realName: _nameController.text.trim(),
            phone: _phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text.trim(),
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
          );

    Navigator.of(context).pop(ActorFormSave(saved));
  }

  Future<void> _confirmDelete() async {
    final actor = widget.actor;
    if (actor == null) return;

    final localizations = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.deleteActor),
        content: Text(localizations.confirmDeleteActor(actor.realName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(localizations.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(localizations.delete),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      Navigator.of(context).pop(ActorFormDelete(actor));
    }
  }
}
