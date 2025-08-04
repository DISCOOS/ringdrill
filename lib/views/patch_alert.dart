import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

class PatchAlert extends StatefulWidget {
  const PatchAlert({super.key, required this.child});

  final Widget child;

  @override
  State<PatchAlert> createState() => _PatchAlertState();
}

class _PatchAlertState extends State<PatchAlert> {
  late Timer _timer;

  final updater = ShorebirdUpdater();
  UpdateStatus status = UpdateStatus.unavailable;

  @override
  void initState() {
    _timer = Timer.periodic(const Duration(seconds: 10), _check);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  void _check(Timer timer) async {
    // Checks for an available patch on [track] (or [UpdateTrack.stable] if no
    // track is specified) and returns the [UpdateStatus].
    final next = await updater.checkForUpdate();
    if (mounted) {
      if (status != next) {
        final localizations = AppLocalizations.of(context)!;
        status = next;
        switch (status) {
          case UpdateStatus.restartRequired:
            showDialog(
              context: context,
              barrierDismissible: false,
              builder:
                  (context) => AlertDialog(
                    title: Text(localizations.updateRequired),
                    content: Text(localizations.restartAppToApplyNewPatch),
                    actions: [
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(context, false);
                        },
                        child: Text(localizations.no),
                      ),
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(context, false);
                        },
                        child: Text(localizations.yes),
                      ),
                    ],
                  ),
            );
          default:
          // NOP
        }
      }
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
}
