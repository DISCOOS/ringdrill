import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ringdrill/data/drill_file.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/views/add_exercises_dialog.dart';
import 'package:ringdrill/views/app_routes.dart';
import 'package:ringdrill/views/drill_format_messages.dart';
import 'package:ringdrill/views/widgets/ringdrill_sheet.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Shows [OpenFileWidget] in the app's standard action-sheet chrome. Shared
/// by the `/o/<path>` (local file) and `/i/<slug>` (catalog link) redirect
/// handlers so both offer the same Open/Import choice.
void showOpenFileBottomSheet(BuildContext context, OpenFileWidget sheet) {
  showRingdrillActionSheet<void>(context: context, builder: (_) => sheet);
}

class OpenFileWidget extends StatefulWidget {
  const OpenFileWidget({
    super.key,
    required this.fileName,
    required this.loadFile,
    required this.openPlan,
    required this.isOnline,
    required this.location,
  });

  /// Display name shown in the sheet title as a fallback (e.g. `foo.drill`
  /// or `<slug>.drill`) while the real plan name isn't known yet, or if it
  /// can't be determined at all — does not need to be an on-disk path.
  final String fileName;

  /// Produces the [DrillFile] to open/import. Kicked off once, eagerly, in
  /// [State.initState] rather than per-button-tap: for a `/i/<slug>`
  /// catalog link this is a network download, and starting it as soon as
  /// the sheet appears both lets the title update to the plan's real name
  /// once parsed, and means the download is often already underway (or
  /// done) by the time the user taps a button.
  final Future<DrillFile> Function() loadFile;

  /// Installs [file] as the active plan. Local `/o/` files use plain
  /// `installFromFile`; catalog `/i/` links use `installFromCatalogFile` so
  /// the result keeps its catalog-source tag (slug/etag) for later refresh.
  final Future<Plan> Function(DrillFile file) openPlan;

  final bool isOnline;
  final String location;

  @override
  State<OpenFileWidget> createState() => _OpenFileWidgetState();
}

/// Which action, if any, is mid-flight. Disables the sheet and shows a
/// spinner in the tapped button so a second tap (or Cancel) can't race the
/// first one while `loadFile()`/install/merge are still running.
enum _Busy { none, opening, importing }

class _OpenFileWidgetState extends State<OpenFileWidget> {
  _Busy _busy = _Busy.none;

  /// Display name for the sheet title: the plan's real name once parsed,
  /// falling back to [OpenFileWidget.fileName] while loading or on parse
  /// failure (the real error still surfaces once the user taps a button).
  String? _planName;

  late final Future<DrillFile> _fileFuture = widget.loadFile();
  late final Future<Plan> _planFuture = _fileFuture.then((file) => file.plan());

  @override
  void initState() {
    super.initState();
    _planFuture.then((plan) {
      if (mounted && plan.name.isNotEmpty) {
        setState(() => _planName = plan.name);
      }
    }, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        // To ensure the bottom widget avoids keyboard or system navigation bar
        bottom: 24.0,
      ),
      child: Column(
        // Makes the bottom sheet height adaptive
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Center(
            child: Text(
              _planName ?? '${localizations.planFile} ${widget.fileName}',
              style: Theme.of(context).textTheme.headlineSmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Content
          const SizedBox(height: 16.0),
          Text(
            localizations.openPlanHint,
            style: Theme.of(context).textTheme.bodyMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          // Content
          const SizedBox(height: 16.0),

          // Action Buttons
          Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.end,
            spacing: 8.0,
            children: [
              TextButton(
                onPressed: _busy == _Busy.none
                    ? () => Navigator.pop(context)
                    : null,
                child: Text(localizations.cancel),
              ),
              ElevatedButton(
                onPressed: _busy == _Busy.none
                    ? () => _handleOpenFile(context, localizations)
                    : null,
                child: _busy == _Busy.opening
                    ? _buttonSpinner(context)
                    : Text(localizations.open),
              ),
              ElevatedButton(
                onPressed: _busy == _Busy.none
                    ? () => _handleImportFile(context, localizations)
                    : null,
                // "LEGG TIL" (addAction), not a separate "import" label —
                // this is the exact same merge-into-active-plan action as
                // "Legg til øvelser fra...", just with the source already
                // picked (this shared plan), so it should read the same.
                child: _busy == _Busy.importing
                    ? _buttonSpinner(context)
                    : Text(localizations.addAction),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buttonSpinner(BuildContext context) => SizedBox(
    height: 16,
    width: 16,
    child: CircularProgressIndicator(
      strokeWidth: 2,
      valueColor: AlwaysStoppedAnimation(
        Theme.of(context).colorScheme.onPrimary,
      ),
    ),
  );

  void _handleOpenFile(
    BuildContext context,
    AppLocalizations localizations,
  ) async {
    final name = widget.fileName;
    // Snapshot the messenger and router BEFORE the sheet is popped. The
    // sheet's BuildContext becomes deactivated on pop, and any snackbar
    // we'd then post via `ScaffoldMessenger.of(context)` would either
    // throw or — worse — render under the bottom sheet that is still
    // animating out. Holding a long-lived handle lets us close the
    // sheet first and then post the result on the underlying screen.
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final navigator = Navigator.of(context);

    // The sheet stays open (with a spinner) until the result is known
    // instead of popping immediately on tap — `loadFile` can be a network
    // download for a catalog link, and popping right away made it look
    // like the tap had already finished when nothing had happened yet.
    setState(() => _busy = _Busy.opening);

    try {
      final plan = await widget.openPlan(await _fileFuture);
      if (navigator.canPop()) navigator.pop();
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(localizations.openedAndActivated(plan.name)),
          dismissDirection: DismissDirection.endToStart,
          showCloseIcon: true,
        ),
      );
      // ADR-0032 *Activation contract*: move the URL to the newly
      // active plan; installFromFile already wrote `activePlanUuid`,
      // so the redirect gate short-circuits and only the URL catches up.
      router.go(planPath(plan.uuid));
    } on DrillFormatException catch (e) {
      // User picked the wrong file (or a half-downloaded one). Show the
      // specific reason and skip Sentry — this is bad input, not a bug.
      if (navigator.canPop()) navigator.pop();
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(drillFormatMessage(localizations, name, e.reason)),
          dismissDirection: DismissDirection.endToStart,
          showCloseIcon: true,
          duration: const Duration(seconds: 15),
        ),
      );
    } on Exception catch (e, stackTrace) {
      unawaited(Sentry.captureException(e, stackTrace: stackTrace));
      if (navigator.canPop()) navigator.pop();
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(localizations.openFailure(name)),
          dismissDirection: DismissDirection.endToStart,
          showCloseIcon: true,
          duration: const Duration(seconds: 15),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = _Busy.none);
    }
  }

  void _handleImportFile(
    BuildContext context,
    AppLocalizations localizations,
  ) async {
    final name = widget.fileName;
    // See _handleOpenFile for why the messenger is snapshotted up front.
    // The sheet stays open under mergePlanIntoActivePlan's own selection
    // screen and diff-confirmation dialog (same as "Legg til øvelser
    // fra...") and only closes once that whole flow resolves.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _busy = _Busy.importing);

    try {
      final source = await _planFuture;
      if (!context.mounted) return;
      final merged = await mergePlanIntoActivePlan(context, source);
      if (navigator.canPop()) navigator.pop();
      if (merged != null) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(localizations.importSuccess(name)),
            dismissDirection: DismissDirection.endToStart,
            showCloseIcon: true,
          ),
        );
      }
    } on DrillFormatException catch (e) {
      // Same split as the open path: typed format errors are user input,
      // not a defect, so they get a specific message and skip Sentry.
      if (navigator.canPop()) navigator.pop();
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(drillFormatMessage(localizations, name, e.reason)),
          dismissDirection: DismissDirection.endToStart,
          showCloseIcon: true,
          duration: const Duration(seconds: 15),
        ),
      );
    } on Exception catch (e, stackTrace) {
      unawaited(Sentry.captureException(e, stackTrace: stackTrace));
      if (navigator.canPop()) navigator.pop();
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(localizations.importFailure(name)),
          dismissDirection: DismissDirection.endToStart,
          showCloseIcon: true,
          duration: const Duration(seconds: 15),
        ),
      );
    } finally {
      // The sheet has already popped by this point in every path above
      // (success, cancel, and error alike), so this is almost always a
      // no-op — guard with mounted rather than assume that.
      if (mounted) setState(() => _busy = _Busy.none);
    }
  }
}
