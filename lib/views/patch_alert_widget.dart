import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

class PatchAlertWidget extends StatefulWidget {
  const PatchAlertWidget({super.key, required this.child});

  final Widget child;

  @override
  State<PatchAlertWidget> createState() => _PatchAlertWidgetState();
}

class _PatchAlertWidgetState extends State<PatchAlertWidget> {
  /// Null on web, where there is nothing to poll for.
  ///
  /// Shorebird patches a Flutter *engine*, and the web build has none — the
  /// package says so itself, at length, on the first call. Polling it every
  /// ten seconds from the PWA printed that essay into the console of a browser
  /// that was never going to receive a patch, and asked the question 8 640
  /// times a day to be told no.
  Timer? _timer;

  final updater = ShorebirdUpdater();
  UpdateStatus status = UpdateStatus.unavailable;

  @override
  void initState() {
    if (!kIsWeb) {
      _timer = Timer.periodic(const Duration(seconds: 10), _check);
    }
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
            showAdaptiveDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
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
                      Navigator.pop(context, true);
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
    _timer?.cancel();
    super.dispose();
  }
}
