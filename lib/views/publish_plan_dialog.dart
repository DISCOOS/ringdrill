import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ringdrill/data/drill_client.dart';
import 'package:ringdrill/data/drill_file.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/views/catalog_conflict_dialog.dart';
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
  const PublishPlanInput({required this.slug});

  final String slug;
}

/// Shows the publish-to-catalog dialog and returns the user's input.
///
/// Returns `null` if the user cancels. The slug field is always editable; the
/// initial value is derived from [plan]'s current catalog slug if it has
/// one, otherwise from its name.
Future<PublishPlanInput?> showPublishPlanDialog(
  BuildContext context, {
  required Plan plan,
  required PublishDialogMode mode,
}) {
  final initialSlug =
      plan.source.whenOrNull(
        catalog: (slug, latestEtag, installedAt, latestVersion) => slug,
      ) ??
      sanitizeSlug(plan.name);

  return showAdaptiveDialog<PublishPlanInput>(
    context: context,
    builder: (context) =>
        _PublishPlanDialog(mode: mode, initialSlug: initialSlug),
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
              ? () => Navigator.pop(
                  context,
                  PublishPlanInput(slug: _sanitizedSlug),
                )
              : null,
          child: Text(localizations.libraryPublishSubmit),
        ),
      ],
    );
  }
}

/// Publish [planUuid] under its current slug (or [slug] for first-time
/// publish) and show a snackbar describing the outcome.
///
/// On 412 (stale view) the function triggers a catalog refresh, shows the
/// conflict dialog so the user can see the diff between their local edits
/// and the new remote state, and acts on their choice (publish anyway,
/// overwrite local, fork, or cancel). The caller therefore never has to
/// handle 412 itself.
Future<Plan?> runPublishPlan(
  BuildContext context, {
  required String planUuid,
  required String slug,
  required DrillClient client,
}) {
  return _runUpload(
    context,
    slug: slug,
    planUuid: planUuid,
    client: client,
    upload: () =>
        PlanService().publishPlan(planUuid, slug: slug, client: client),
  );
}

/// Publish [planUuid] at [slug], forking the local plan if the slug differs
/// from the plan's current catalog slug. Shows a snackbar describing the
/// outcome.
Future<Plan?> runPublishPlanAs(
  BuildContext context, {
  required String planUuid,
  required String slug,
  required DrillClient client,
}) {
  return _runUpload(
    context,
    slug: slug,
    planUuid: planUuid,
    client: client,
    upload: () =>
        PlanService().publishPlanAs(planUuid, slug: slug, client: client),
  );
}

Future<Plan?> _runUpload(
  BuildContext context, {
  required Future<({Plan plan, bool notModified})> Function() upload,
  required String slug,
  required String planUuid,
  required DrillClient client,
}) async {
  final localizations = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  try {
    final result = await upload();
    final message = result.notModified
        ? localizations.libraryPublishNoChange
        : localizations.libraryPublishSuccess(result.plan.name);
    messenger.showSnackBar(
      SnackBar(
        showCloseIcon: true,
        dismissDirection: DismissDirection.endToStart,
        content: Text(message),
      ),
    );
    return result.plan;
  } on DrillApiException catch (e, stackTrace) {
    if (e.status == 412 && context.mounted) {
      // Stale view — hand off to the catalog-conflict flow so the user can
      // see the diff between their edits and the new remote state and pick
      // overwrite / fork / publish-anyway / cancel.
      return await _resolvePublishConflict(
        context,
        planUuid: planUuid,
        client: client,
      );
    }
    final message = switch ((e.status, e.conflictKind)) {
      (409, 'version') => localizations.libraryPublishConflict,
      (409, _) => localizations.libraryPublishSlugTaken(slug),
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

/// Triggered after the upload returned 412. Refreshes the catalog state,
/// shows the conflict dialog with a diff against the fresh remote, and acts
/// on the user's choice. The refresh flow is the same one used by
/// "Refresh from catalog" — the only difference is that we got here because
/// the user already attempted to publish, so [CatalogConflictChoice
/// .publishMyChanges] re-runs the upload with the fresh etag.
Future<Plan?> _resolvePublishConflict(
  BuildContext context, {
  required String planUuid,
  required DrillClient client,
}) async {
  final localizations = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  try {
    final outcome = await PlanService().refreshCatalogItem(
      planUuid,
      client,
      onConflict:
          (
            diff, {
            required ownedSlug,
            required remoteUnchanged,
            required localVersion,
            required catalogVersion,
          }) => showCatalogConflictDialog(
            context,
            diff: diff,
            ownedSlug: ownedSlug,
            remoteUnchanged: remoteUnchanged,
            localVersion: localVersion,
            catalogVersion: catalogVersion,
          ),
    );
    if (outcome.kind == CatalogRefreshKind.published) {
      final published = PlanService().loadPlan(outcome.planUuid);
      if (published != null) {
        messenger.showSnackBar(
          SnackBar(
            showCloseIcon: true,
            dismissDirection: DismissDirection.endToStart,
            content: Text(localizations.libraryPublishSuccess(published.name)),
          ),
        );
      }
      return published;
    }
    // cancelled, overwriteLocal, fork, upToDate, failed — the dialog (or
    // silent refresh) is the user-visible feedback; we don't add a snackbar
    // on top.
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
