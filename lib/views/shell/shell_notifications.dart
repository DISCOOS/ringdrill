// Snackbar helpers that the shell raises in response to background
// events (an exercise auto-stopping, the library schema having just
// migrated). Kept stateless and context-driven so the host shell can
// hand off the work without taking on more code itself.

import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/program_service.dart';

/// Shows a passive notice that the auto-stop fired. The persistent
/// notification from `NotificationService` is what the user actually
/// has to acknowledge; this snackbar is the in-app equivalent for
/// whoever is staring at the running app when the timer expires.
void showAutoStoppedSnackBar(BuildContext context, ExerciseEvent event) {
  final localizations = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        showCloseIcon: true,
        // endToStart swipe matches the migration snackbar and mirrors
        // the swipe gesture the notification supports, so the
        // dismissal idiom is consistent.
        dismissDirection: DismissDirection.endToStart,
        content: Text(
          localizations.exerciseAutoStoppedSnack(event.exercise.name),
        ),
      ),
    );
}

/// One-shot snackbar shown the first time the shell rebuilds after a
/// `ProgramService` library-schema migration. Schedules itself on the
/// post-frame callback so it doesn't collide with the build that
/// triggered the check, and clears the service-side flag when the
/// snackbar is dismissed so it isn't re-raised on the next rebuild.
///
/// Caller owns the "have I checked already?" boolean via [hasChecked]
/// and [onChecked] — the helper does not maintain its own latch so the
/// behaviour mirrors the original inline implementation exactly.
void maybeShowLibraryMigrationSnackBar(
  BuildContext context, {
  required bool hasChecked,
  required VoidCallback onChecked,
  required bool Function() isStillMounted,
}) {
  if (hasChecked) return;
  onChecked();
  if (!ProgramService().librarySchemaJustMigrated) return;
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    if (!isStillMounted()) return;
    final localizations = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    messenger
        .showSnackBar(
          SnackBar(
            showCloseIcon: true,
            content: Text(localizations.libraryMigrationNotice),
            dismissDirection: DismissDirection.endToStart,
          ),
        )
        .closed
        .then((_) => ProgramService().clearLibrarySchemaJustMigrated());
  });
}
