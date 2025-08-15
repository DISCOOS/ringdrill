import 'dart:convert';

import 'package:universal_io/io.dart' as io;

/// MIME for full files; if you later post deltas, change the MIME at call site.
const drillMime = 'application/vnd.ringdrill+json';

String slugify(String input) {
  final s = input
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'\s+'), '-') // spaces -> dash
      .replaceAll(RegExp(r'[^a-z0-9\-]'), '-') // non-url chars
      .replaceAll(RegExp(r'-+'), '-') // collapse --
      .replaceAll(RegExp(r'^-+|-+$'), ''); // trim dashes
  return s.isEmpty ? 'program' : s;
}

String fileNameWithoutExt(String name) {
  final i = name.lastIndexOf('.');
  return i > 0 ? name.substring(0, i) : name;
}

class DrillUploadResult {
  final String slug;
  final String programId;
  final String version;
  final String etag;
  final Uri latest; // deep link (always-up-to-date alias)
  final Uri versioned; // immutable version link

  const DrillUploadResult({
    required this.slug,
    required this.programId,
    required this.version,
    required this.etag,
    required this.latest,
    required this.versioned,
  });

  factory DrillUploadResult.fromJson(Map<String, dynamic> j) =>
      DrillUploadResult(
        slug: j['slug'] as String,
        programId: j['programId'] as String,
        version: j['version'] as String,
        etag: j['etag'] as String,
        latest: Uri.parse(j['latest'] as String),
        versioned: Uri.parse(j['versioned'] as String),
      );
}

/// Uploads a .drill file as raw bytes to your Netlify function.
/// - [base] is like `https://ringdrill.app` (or your preview URL).
/// - [fileName] is used to derive a slug and display name if not provided.
/// - [version] can come from your schema (e.g., "1.0.0").
/// - [published] controls marketplace visibility (server stores it in meta).
/// Returns canonical deep links + etag.
Future<DrillUploadResult> uploadDrillFile({
  required Uri base,
  required List<int> bytes,
  required String fileName,
  String? slug,
  String? displayName,
  String? version,
  bool published = true,
  List<String> tags = const [],
  Duration timeout = const Duration(seconds: 30),
  String contentType = drillMime,
}) async {
  final derivedName = fileNameWithoutExt(fileName);
  final qs = <String, String>{
    'slug': slug ?? slugify(derivedName),
    'name': displayName ?? derivedName,
    if (version != null && version.isNotEmpty) 'version': version,
    'published': published.toString(),
    if (tags.isNotEmpty) 'tags': tags.join(','),
  };

  final uri = base.replace(path: '/api/drills/upload', queryParameters: qs);

  final client = io.HttpClient()..connectionTimeout = timeout;
  try {
    final req = await client.postUrl(uri);
    req.headers.set(io.HttpHeaders.contentTypeHeader, contentType);
    // Allow CORS preflights to be cached longer by browsers if needed:
    req.headers.set('Cache-Control', 'no-cache');

    req.add(bytes);
    final res = await req.close();

    final text = await utf8.decodeStream(res);
    if (res.statusCode != 200) {
      throw io.HttpException(
        'Upload failed (${res.statusCode}): $text',
        uri: uri,
      );
    }
    final json = jsonDecode(text) as Map<String, dynamic>;
    return DrillUploadResult.fromJson(json);
  } finally {
    client.close(force: true);
  }
}

class DrillHeadInfo {
  final String? etag;
  final int? contentLength;
  final DateTime? lastModified;

  DrillHeadInfo({this.etag, this.contentLength, this.lastModified});
}

Future<DrillHeadInfo?> headDrill({
  required Uri base,
  required String
  slugOrVersioned, // e.g. 'rope-rescue-basics' or 'rope-rescue-basics@1.2.3'
  Duration timeout = const Duration(seconds: 15),
}) async {
  // We hit the dedicated HEAD endpoint so we don’t download the body.
  final uri = base.replace(path: '/api/drills/head/$slugOrVersioned');

  final client = io.HttpClient()..connectionTimeout = timeout;
  try {
    final req = await client.openUrl('HEAD', uri);
    final res = await req.close();
    if (res.statusCode != 200) return null;

    String? etag;
    int? len;
    DateTime? lm;

    res.headers.forEach((name, values) {
      final v = values.isNotEmpty ? values.first : null;
      if (v == null) return;
      switch (name.toLowerCase()) {
        case 'etag':
          etag = v;
          break;
        case 'content-length':
          len = int.tryParse(v);
          break;
        case 'last-modified':
          lm = DateTime.tryParse(v) ?? lm;
          break;
      }
    });

    // Drain to complete connection cleanly
    await res.drain<void>();
    return DrillHeadInfo(etag: etag, contentLength: len, lastModified: lm);
  } finally {
    client.close(force: true);
  }
}
