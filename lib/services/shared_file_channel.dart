import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:universal_io/io.dart';

class SharedFileChannel {
  final _platform = MethodChannel('ringdrill/shared_file');

  static final SharedFileChannel _instance = SharedFileChannel._internal();

  factory SharedFileChannel() => _instance;

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

          _controller.add(file);

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

  Stream<File> get files => _controller.stream;
}
