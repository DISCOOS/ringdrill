import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:ringdrill/data/drill_file.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/services/program_service.dart';
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening program: $name'),
        dismissDirection: DismissDirection.endToStart,
        showCloseIcon: true,
      ),
    );
    try {
      final program = await ProgramService().openProgram(
        localizations,
        DrillFile.fromFile(file),
      );
      if (context.mounted && program != null) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.openSuccess(name)),
            dismissDirection: DismissDirection.endToStart,
            showCloseIcon: true,
          ),
        );
      }
    } on Exception catch (e, stackTrace) {
      unawaited(Sentry.captureException(e, stackTrace: stackTrace));
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.openFailure(name)),
            dismissDirection: DismissDirection.endToStart,
            showCloseIcon: true,
            duration: const Duration(seconds: 15),
          ),
        );
      }
    }
    if (context.mounted) Navigator.pop(context);
  }

  void _handleImportFile(
    BuildContext context,
    AppLocalizations localizations,
    File file,
  ) async {
    final name = basename(file.path);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Importing program: $name'),
        dismissDirection: DismissDirection.endToStart,
        showCloseIcon: true,
      ),
    );
    try {
      final program = await ProgramService().importProgram(
        localizations,
        DrillFile.fromFile(file),
        onSelect: (items) async {
          final selected = await ProgramPageControllerBase.selectExercises(
            context,
            localizations.importProgram,
            items.toList(),
            BoxConstraints.expand(),
            localizations,
            true,
          );
          return selected.isEmpty
              ? null
              : items.where((e) => selected.contains(e.uuid));
        },
      );
      if (context.mounted && program != null) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.importSuccess(name)),
            dismissDirection: DismissDirection.endToStart,
            showCloseIcon: true,
          ),
        );
      }
    } on Exception catch (e, stackTrace) {
      unawaited(Sentry.captureException(e, stackTrace: stackTrace));
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.importFailure(name)),
            dismissDirection: DismissDirection.endToStart,
            showCloseIcon: true,
            duration: const Duration(seconds: 15),
          ),
        );
      }
    }
    if (context.mounted) Navigator.pop(context);
  }
}
