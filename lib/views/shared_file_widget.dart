import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/services/shared_file_channel.dart';
import 'package:universal_io/io.dart';

class SharedFileWidget extends StatefulWidget {
  const SharedFileWidget({super.key, required this.child});

  final Widget child;

  @override
  State<SharedFileWidget> createState() => _SharedFileWidgetState();
}

class _SharedFileWidgetState extends State<SharedFileWidget> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: SharedFileChannel().files,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          _handleDrillFile(snapshot.data!);
        }
        return widget.child;
      },
    );
  }

  Future<void> _handleDrillFile(File file) async {
    if (file.path.endsWith('.drill')) {
      if (mounted) {
        final localizations = AppLocalizations.of(context)!;
        scheduleMicrotask(() async {
          final action = await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: Text('Drill File'),
              content: Text(localizations.sharedFileReceived),
              actions: [
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                  },
                  child: Text(localizations.cancel),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context, 'import');
                  },
                  child: Text(localizations.import),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context, 'open');
                  },
                  child: Text(localizations.open),
                ),
              ],
            ),
          );
          switch (action) {
            case 'open':
              unawaited(ProgramService().openFromLocalFile(file));
              break;
            case 'import':
              unawaited(ProgramService().importFromLocalFile(file));
              break;
          }
        });
      }
    }
  }
}
