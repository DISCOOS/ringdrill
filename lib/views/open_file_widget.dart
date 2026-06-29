import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart';
import 'package:ringdrill/data/drill_file.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/app_routes.dart';
import 'package:ringdrill/views/drill_format_messages.dart';
import 'package:ringdrill/views/program_view.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:universal_io/io.dart';

class OpenFileWidget extends StatelessWidget {
  const OpenFileWidget({
    super.key,
    required this.file,
    required this.isOnline,
    required this.location,
  });

  final File file;
  final bool isOnline;
  final String location;

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
              '${localizations.programFile} ${basename(file.path)}',
              style: Theme.of(context).textTheme.headlineSmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Content
          const SizedBox(height: 16.0),
          Text(
            localizations.openProgramHint,
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
                child: Text(localizations.cancel),
                onPressed: () => Navigator.pop(context),
              ),
              ElevatedButton(
                child: Text(localizations.open),
                onPressed: () {
                  _handleOpenFile(context, localizations, file);
                },
              ),
              ElevatedButton(
                child: Text(localizations.import),
                onPressed: () {
                  _handleImportFile(context, localizations, file);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleOpenFile(
    BuildContext context,
    AppLocalizations localizations,
    File file,
  ) async {
    final name = basename(file.path);
    // Snapshot the messenger and router BEFORE the sheet is popped. The
    // sheet's BuildContext becomes deactivated on pop, and any snackbar
    // we'd then post via `ScaffoldMessenger.of(context)` would either
    // throw or — worse — render under the bottom sheet that is still
    // animating out. Holding a long-lived handle lets us close the
    // sheet first and then post the result on the underlying screen.
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final navigator = Navigator.of(context);

    // The "Opening program: …" pre-flight snack used to be posted on
    // the sheet messenger and immediately covered by the sheet itself.
    // Removed: by the time the user has tapped Open they already know
    // we are opening, and the success/failure snack below carries the
    // outcome.
    if (navigator.canPop()) navigator.pop();

    try {
      final program = await ProgramService().installFromFile(
        DrillFile.fromFile(file),
        activate: true,
      );
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(localizations.openedAndActivated(program.name)),
          dismissDirection: DismissDirection.endToStart,
          showCloseIcon: true,
        ),
      );
      // ADR-0032 *Activation contract*: move the URL to the newly
      // active plan; installFromFile already wrote `activeProgramUuid`,
      // so the redirect gate short-circuits and only the URL catches up.
      router.go(programPath(program.uuid));
    } on DrillFormatException catch (e) {
      // User picked the wrong file (or a half-downloaded one). Show the
      // specific reason and skip Sentry — this is bad input, not a bug.
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(drillFormatMessage(localizations, name, e)),
          dismissDirection: DismissDirection.endToStart,
          showCloseIcon: true,
          duration: const Duration(seconds: 15),
        ),
      );
    } on Exception catch (e, stackTrace) {
      unawaited(Sentry.captureException(e, stackTrace: stackTrace));
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(localizations.openFailure(name)),
          dismissDirection: DismissDirection.endToStart,
          showCloseIcon: true,
          duration: const Duration(seconds: 15),
        ),
      );
    }
  }

  void _handleImportFile(
    BuildContext context,
    AppLocalizations localizations,
    File file,
  ) async {
    final name = basename(file.path);
    // See _handleOpenFile for why the messenger and navigator are
    // snapshotted before any pop. Import has the added wrinkle of
    // selectExercises, which itself wants a live context — so we keep
    // the sheet open while we read the file and let the user choose,
    // and only close it before posting the result snack.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final program = await ProgramService().importProgram(
        localizations,
        DrillFile.fromFile(file),
        onSelect: (items) async {
          final selected = await ProgramPageControllerBase.selectExercises(
            context,
            localizations.importProgram,
            items.toList(),
            localizations,
            confirmLabel: localizations.importAction,
            preselectAll: true,
            showSelectAllControls: true,
          );
          return selected.isEmpty
              ? null
              : items.where((e) => selected.contains(e.uuid));
        },
      );
      if (navigator.canPop()) navigator.pop();
      if (program != null) {
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
          content: Text(drillFormatMessage(localizations, name, e)),
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
    }
  }
}
