import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ringdrill/data/drill_client.dart';
import 'package:ringdrill/data/drill_file.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Modes the publish dialog adapts to. The dialog itself behaves the same in
/// both cases (slug + tags input). The mode picks the title and body copy.
enum PublishDialogMode {
  /// First-time publish of a local or imported plan.
  firstTime,

  /// "Publish as…" — explicit dialog flow, may produce a fork on an already
  /// published plan if the user changes the slug.
  publishAs,
}

/// Result returned by [showPublishPlanDialog].
class PublishPlanInput {
  const PublishPlanInput({required this.slug, required this.tags});

  final String slug;
  final List<String> tags;
}

/// Shows the publish-to-catalog dialog and returns the user's input.
///
/// Returns `null` if the user cancels. The slug field is always editable; the
/// initial value is derived from [program]'s current catalog slug if it has
/// one, otherwise from its name.
Future<PublishPlanInput?> showPublishPlanDialog(
  BuildContext context, {
  required Program program,
  required PublishDialogMode mode,
}) {
  final initialSlug = program.source.whenOrNull(
        catalog: (slug, latestEtag, installedAt) => slug,
      ) ??
      sanitizeSlug(program.name);

  return showDialog<PublishPlanInput>(
    context: context,
    builder: (context) => _PublishPlanDialog(
      mode: mode,
      initialSlug: initialSlug,
    ),
  );
}

class _PublishPlanDialog extends StatefulWidget {
  const _PublishPlanDialog({required this.mode, required this.initialSlug});

  final PublishDialogMode mode;
  final String initialSlug;

  @override
  State<_PublishPlanDialog> createState() => _PublishPlanDialogState();
}

class _PublishPlanDialogState extends State<_PublishPlanDialog> {
  late final TextEditingController _slugController;
  final TextEditingController _tagsController = TextEditingController();
  String _sanitizedSlug = '';

  @override
  void initState() {
    super.initState();
    _slugController = TextEditingController(text: widget.initialSlug);
    _sanitizedSlug = sanitizeSlug(widget.initialSlug);
    _slugController.addListener(_onSlugChanged);
  }

  void _onSlugChanged() {
    final next = sanitizeSlug(_slugController.text);
    if (next != _sanitizedSlug) {
      setState(() => _sanitizedSlug = next);
    }
  }

  @override
  void dispose() {
    _slugController.removeListener(_onSlugChanged);
    _slugController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final title = switch (widget.mode) {
      PublishDialogMode.firstTime => localizations.libraryPublishTitle,
      PublishDialogMode.publishAs => localizations.libraryPublishAsTitle,
    };
    final body = switch (widget.mode) {
      PublishDialogMode.firstTime => localizations.libraryPublishBody,
      PublishDialogMode.publishAs => localizations.libraryPublishAsBody,
    };
    final canSubmit = _sanitizedSlug.isNotEmpty;
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(body),
            const SizedBox(height: 16),
            TextField(
              controller: _slugController,
              decoration: InputDecoration(
                labelText: localizations.libraryPublishSlugLabel,
                helperText: localizations.libraryPublishSlugHelper,
                border: const OutlineInputBorder(),
              ),
              autocorrect: false,
              enableSuggestions: false,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tagsController,
              decoration: InputDecoration(
                labelText: localizations.libraryPublishTagsLabel,
                border: const OutlineInputBorder(),
              ),
              autocorrect: false,
              enableSuggestions: false,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(localizations.cancel),
        ),
        FilledButton(
          onPressed: canSubmit
              ? () {
                  final tags = _tagsController.text
                      .split(',')
                      .map((s) => s.trim())
                      .where((s) => s.isNotEmpty)
                      .toSet()
                      .toList();
                  Navigator.pop(
                    context,
                    PublishPlanInput(slug: _sanitizedSlug, tags: tags),
                  );
                }
              : null,
          child: Text(localizations.libraryPublishSubmit),
        ),
      ],
    );
  }
}

/// Publish [programUuid] under its current slug (or [slug] for first-time
/// publish) and show a snackbar describing the outcome.
Future<Program?> runPublishProgram(
  BuildContext context, {
  required String programUuid,
  required String slug,
  required List<String> tags,
  required DrillClient client,
}) {
  return _runUpload(
    context,
    slug: slug,
    upload: () => ProgramService().publishProgram(
      programUuid,
      slug: slug,
      tags: tags,
      client: client,
    ),
  );
}

/// Publish [programUuid] at [slug], forking the local plan if the slug differs
/// from the plan's current catalog slug. Shows a snackbar describing the
/// outcome.
Future<Program?> runPublishProgramAs(
  BuildContext context, {
  required String programUuid,
  required String slug,
  required List<String> tags,
  required DrillClient client,
}) {
  return _runUpload(
    context,
    slug: slug,
    upload: () => ProgramService().publishProgramAs(
      programUuid,
      slug: slug,
      tags: tags,
      client: client,
    ),
  );
}

Future<Program?> _runUpload(
  BuildContext context, {
  required Future<Program> Function() upload,
  required String slug,
}) async {
  final localizations = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  try {
    final published = await upload();
    messenger.showSnackBar(
      SnackBar(
        showCloseIcon: true,
        dismissDirection: DismissDirection.endToStart,
        content: Text(localizations.libraryPublishSuccess(published.name)),
      ),
    );
    return published;
  } on DrillApiException catch (e, stackTrace) {
    final message = switch (e.status) {
      409 => localizations.libraryPublishSlugTaken(slug),
      412 => localizations.libraryPublishConflict,
      _ => localizations.libraryPublishFailed,
    };
    messenger.showSnackBar(
      SnackBar(
        showCloseIcon: true,
        dismissDirection: DismissDirection.endToStart,
        content: Text(message),
      ),
    );
    if (e.status == null || e.status! >= 500) {
      unawaited(Sentry.captureException(e, stackTrace: stackTrace));
    }
    return null;
  } catch (e, stackTrace) {
    messenger.showSnackBar(
      SnackBar(
        showCloseIcon: true,
        dismissDirection: DismissDirection.endToStart,
        content: Text(localizations.libraryPublishFailed),
      ),
    );
    unawaited(Sentry.captureException(e, stackTrace: stackTrace));
    return null;
  }
}
