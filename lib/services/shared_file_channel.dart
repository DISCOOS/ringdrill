import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:universal_io/io.dart';

class SharedFileChannel {
  final _platform = MethodChannel('ringdrill/shared_file');

  static final SharedFileChannel _instance = SharedFileChannel._internal();

  factory SharedFileChannel() => _instance;

  bool receivedFileIntent = false;

  SharedFileChannel._internal() {
    _platform.setMethodCallHandler((call) async {
      debugPrint(
        'SharedFileChannel._internal::setMethodCallHandler(${call.method})',
      );
      switch (call.method) {
        case 'onSharedFilePath':
          final String path = call.arguments;
          final file = File(path);
          if (!file.existsSync()) {
            Sentry.captureMessage(
              '[shared_file] Receiving file does not exist: ${call.arguments}',
            );
            return;
          }
          receivedFileIntent = true;

          _controller.add(file);

          break;
        case 'onSharedLink':
          final String raw = call.arguments;
          final uri = Uri.tryParse(raw);
          if (uri == null) {
            Sentry.captureMessage('[shared_file] Invalid shared link: $raw');
            return;
          }
          _linkController.add(uri);
          break;
        case 'onSharedFileError':
          Sentry.captureMessage(
            '[shared_file] Error receiving file: ${call.arguments}',
          );
          break;
      }
    });
  }

  final StreamController<File> _controller = StreamController<File>.broadcast();
  final StreamController<Uri> _linkController =
      StreamController<Uri>.broadcast();

  Stream<File> get files => _controller.stream;

  /// Shared `ringdrill.app/i/…` or `/o/…` links (e.g. a "Share" on a chat
  /// link, or the Web Share API on the catalog page) that arrived via the
  /// OS share sheet rather than as a real `.drill` file.
  Stream<Uri> get links => _linkController.stream;
}
