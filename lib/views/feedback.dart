import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

Future<void> showFeedbackSheet(
  BuildContext context, {
  Map<String, dynamic>? appState, // exerciseId, phase, station, etc.
}) async {
  await showModalBottomSheet(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
    ),
    builder: (_) => _FeedbackSheet(appContext: appState ?? const {}),
  );
}

final _feedbackRepaintKey = GlobalKey();

class FeedbackBoundary extends StatelessWidget {
  const FeedbackBoundary({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(key: _feedbackRepaintKey, child: child);
  }
}

class FeedbackLog {
  static final List<String> _buf = <String>[];
  static const int maxLines = 200;

  static void add(String line) {
    final ts = DateTime.now().toIso8601String();
    _buf.add("[$ts] $line");
    if (_buf.length > maxLines) {
      _buf.removeRange(0, _buf.length - maxLines);
    }
    // Also add a breadcrumb to Sentry so it correlates
    Sentry.addBreadcrumb(Breadcrumb(message: line, level: SentryLevel.info));
  }

  static List<String> last(int n) =>
      _buf.sublist(max(0, _buf.length - n), _buf.length);
}

class _FeedbackSheet extends StatefulWidget {
  const _FeedbackSheet({required this.appContext});
  final Map<String, dynamic> appContext;

  @override
  State<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<_FeedbackSheet> {
  final _form = GlobalKey<FormState>();
  final _messageCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _withScreenshot = false;
  final _withLastLogs = false;
  bool _includeScreenshot = true;

  bool _includeLogs = true;
  bool _sending = false;

  @override
  void dispose() {
    _messageCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<Uint8List?> _capturePng() async {
    final obj = _feedbackRepaintKey.currentContext?.findRenderObject();
    if (obj is! RenderRepaintBoundary) return null;
    final image = await obj.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<Map<String, dynamic>> _collectAppContext() async {
    final updater = ShorebirdUpdater();
    final status = await updater.checkForUpdate();
    final patch = await updater.readCurrentPatch();

    if (!mounted) return {};

    return {
      'shorebird': {
        'patchStatus': status.name,
        'patchNumber': patch?.number ?? 0,
      },
      'route': ModalRoute.of(context)?.settings.name,
      'context': widget.appContext,
    };
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _sending = true);

    try {
      final contextMap = await _collectAppContext();
      if (contextMap.isEmpty) {
        // TODO: Handle this, probably not a thing.
        return;
      }
      final logs = _includeLogs ? FeedbackLog.last(100) : [];
      final screenshot = _includeScreenshot ? await _capturePng() : null;

      // Create a synthetic event that carries all diagnostics.
      final eventId = await Sentry.captureMessage(
        'user_feedback',
        withScope: (scope) async {
          scope.setContexts('shorebird', contextMap['shorebird'] ?? {});
          scope.setContexts('app_state', contextMap['context'] ?? {});
          scope.setContexts('logs', logs);

          if (screenshot != null) {
            scope.addAttachment(
              SentryAttachment.fromUint8List(
                screenshot,
                'screenshot.png',
                contentType: 'image/png',
              ),
            );
          }
        },
      );

      // Send feedback linked to that event.
      final feedback = SentryFeedback(
        message: _messageCtrl.text.trim(),
        name: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
        contactEmail: _emailCtrl.text.trim().isEmpty
            ? null
            : _emailCtrl.text.trim(),
        associatedEventId: eventId,
      );
      await Sentry.captureFeedback(feedback);

      if (mounted) {
        Navigator.of(context).maybePop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Thanks! Feedback sent.')));
      }
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Couldn’t send feedback: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets;
    final localizations = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: SafeArea(
        child: AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Send feedback',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _messageCtrl,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'What happened or what’s your idea?',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Please add a note'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Name (optional)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _emailCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Email (optional)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (_withScreenshot) ...[
                        Checkbox(
                          value: _includeScreenshot,
                          onChanged: (v) =>
                              setState(() => _includeScreenshot = v ?? true),
                        ),
                        const Text('Include screenshot'),
                        const SizedBox(width: 16),
                      ],
                      if (_withLastLogs) ...[
                        Checkbox(
                          value: _includeLogs,
                          onChanged: (v) =>
                              setState(() => _includeLogs = v ?? true),
                        ),
                        const Text('Include last logs'),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _sending
                            ? null
                            : () => Navigator.of(context).maybePop(),
                        child: Text(localizations.cancel),
                      ),
                      SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: _sending ? null : _submit,
                        icon: _sending
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send),
                        label: Text(_sending ? 'Sending…' : 'SEND'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
