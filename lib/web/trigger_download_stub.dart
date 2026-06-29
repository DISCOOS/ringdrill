import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

/// Shares [bytes] via the native share sheet on iOS/Android.
///
/// On native platforms there is no browser download concept; share_plus
/// opens the OS file-share picker instead.
Future<void> triggerDownload(String filename, Uint8List bytes) async {
  final xf = XFile.fromData(bytes, name: filename, mimeType: 'application/zip');
  await SharePlus.instance.share(ShareParams(files: [xf]));
}
