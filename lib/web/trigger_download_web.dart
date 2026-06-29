import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Triggers a browser file download for [bytes] under [filename].
///
/// Creates a temporary object URL from a Blob, attaches it to a hidden
/// `<a download>` element, clicks it, then revokes the URL.
Future<void> triggerDownload(String filename, Uint8List bytes) async {
  final blob = web.Blob(
    [bytes.buffer.toJS].toJS,
    web.BlobPropertyBag(type: 'application/zip'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement();
  anchor.href = url;
  anchor.setAttribute('download', filename);
  web.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}
