// ignore_for_file: public_member_api_docs
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:meta/meta.dart';
import 'package:ringdrill/data/drill_file.dart';

/// MIME used by download endpoints (deep-link/head).
/// TODO: Replace with DrillFile
const drillMime = 'application/vnd.ringdrill+zip';

/// Thin error type that preserves HTTP context.
class DrillApiException implements Exception {
  final String message;
  final int? status;
  final String? body;

  /// Optional discriminator returned by the upload backend so the caller can
  /// tell apart a slug-ownership 409 ("slug") from a version-collision 409
  /// ("version"). Read from the `X-Conflict-Kind` response header. Null when
  /// the server did not set it (older backends or non-conflict errors).
  final String? conflictKind;

  DrillApiException(this.message, {this.status, this.body, this.conflictKind});

  @override
  String toString() =>
      'DrillApiException($message, status=$status, body=$body, '
      'conflictKind=$conflictKind)';
}

/// Upload response from drills-upload.
@immutable
class DrillUploadResponse {
  final String slug;
  final String programId;
  final String version;
  final String etag;
  final Uri latestUrl;
  final Uri versionedUrl;
  final String? note;

  /// True when the server returned 304 Not Modified — i.e. the uploaded
  /// bytes were byte-identical to the current latest version and no new
  /// version was created. The other fields point at the existing latest.
  final bool notModified;

  const DrillUploadResponse({
    required this.slug,
    required this.programId,
    required this.version,
    required this.etag,
    required this.latestUrl,
    required this.versionedUrl,
    this.note,
    this.notModified = false,
  });

  factory DrillUploadResponse.fromJson(Map<String, dynamic> j) =>
      DrillUploadResponse(
        slug: j['slug'] as String,
        programId: j['programId'] as String,
        version: j['version'] as String,
        etag: j['etag'] as String,
        latestUrl: Uri.parse(j['latest'] as String),
        versionedUrl: Uri.parse(j['versioned'] as String),
        note: j['note'] as String?,
      );
}

/// HEAD metadata for a drill blob/version.
@immutable
class DrillHeadResponse {
  final bool exists;
  final bool notModified; // true if 304
  final String? etag;
  final int? contentLength;
  final DateTime? lastModified;
  final String? cacheControl;
  const DrillHeadResponse({
    required this.exists,
    required this.notModified,
    this.etag,
    this.contentLength,
    this.lastModified,
    this.cacheControl,
  });
}

/// Downloaded drill object.
@immutable
class DrillDownloadResponse {
  final String slug;
  final Uint8List bytes;
  final String? etag;
  final String? contentType;
  final String? contentDisposition;
  final DateTime? lastModified;
  final bool notModified;

  const DrillDownloadResponse({
    required this.slug,
    required this.bytes,
    this.etag,
    this.contentType,
    this.contentDisposition,
    this.lastModified,
    this.notModified = false,
  });

  factory DrillDownloadResponse.notModified(String slug) {
    return DrillDownloadResponse(
      slug: slug,
      bytes: Uint8List(0),
      notModified: true,
    );
  }

  DrillFile get file =>
      DrillFile.fromBytes('$slug.${DrillFile.drillExtension}', bytes);
}

/// Market feed item (published drills only).
@immutable
class MarketFeedItem {
  final String programId;
  final String slug;
  final String name;
  final List<String> tags;
  final Uri latestUrl;
  final DateTime? updatedAt;
  const MarketFeedItem({
    required this.programId,
    required this.slug,
    required this.name,
    required this.tags,
    required this.latestUrl,
    this.updatedAt,
  });

  factory MarketFeedItem.fromJson(Map<String, dynamic> j) => MarketFeedItem(
    programId: j['programId'] as String,
    slug: j['slug'] as String,
    name: j['name'] as String,
    tags: (j['tags'] as List<dynamic>? ?? const <dynamic>[])
        .map((e) => e.toString())
        .toList(),
    latestUrl: Uri.parse(j['latestUrl'] as String),
    updatedAt: j['updatedAt'] == null || (j['updatedAt'] as String).isEmpty
        ? null
        : DateTime.tryParse(j['updatedAt'] as String),
  );
}

@immutable
class MarketFeedPageResponse {
  final List<MarketFeedItem> items;
  final String? nextCursor;
  const MarketFeedPageResponse({required this.items, this.nextCursor});

  factory MarketFeedPageResponse.fromJson(Map<String, dynamic> j) =>
      MarketFeedPageResponse(
        items: ((j['items'] as List<dynamic>? ?? const <dynamic>[]))
            .map((e) => MarketFeedItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        nextCursor: j['nextCursor'] as String?,
      );
}

@immutable
@immutable
class AdminListItem {
  final String slug;
  final String? ownerId;
  final String? programId;
  final bool? published;
  final int? versionCount;
  final DateTime? updatedAt;
  final Map<String, dynamic>? latest; // { v, etag, size, updatedAt }
  final List<Map<String, dynamic>>?
  versions; // only present on `list` (per-slug)

  const AdminListItem({
    required this.slug,
    this.ownerId,
    this.programId,
    this.published,
    this.versionCount,
    this.latest,
    this.versions,
    this.updatedAt,
  });

  factory AdminListItem.fromJson(Map<String, dynamic> j) => AdminListItem(
    slug: j['slug'] as String,
    ownerId: j['ownerId'] as String?,
    programId: j['programId'] as String?,
    published: j['published'] as bool?,
    versionCount: (j['versionCount'] as num?)?.toInt(),
    latest: j['latest'] == null
        ? null
        : Map<String, dynamic>.from(j['latest'] as Map),
    versions: (j['versions'] as List?)
        ?.map((e) => Map<String, dynamic>.from(e as Map))
        .toList(),
    updatedAt: j['updatedAt'] == null
        ? null
        : DateTime.tryParse(j['updatedAt'] as String),
  );
}

@immutable
class AdminListPageResponse {
  final List<AdminListItem> items;
  final String? nextCursor;

  const AdminListPageResponse({required this.items, this.nextCursor});

  factory AdminListPageResponse.fromJson(Map<String, dynamic> j) =>
      AdminListPageResponse(
        items: (j['items'] as List<dynamic>? ?? const [])
            .map((e) => AdminListItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        nextCursor: j['nextCursor'] as String?,
      );
}

/// Admin operation result (publish/unpublish/deleteVersion/deleteAll).
@immutable
class AdminResult {
  final bool ok;
  final String slug;
  final bool? published;
  final String? deletedVersion;
  final String? newLatest;
  final List<String>? remainingVersions;
  final int? deletedKeys;
  final bool? cleaned;
  const AdminResult({
    required this.ok,
    required this.slug,
    this.published,
    this.deletedVersion,
    this.newLatest,
    this.remainingVersions,
    this.deletedKeys,
    this.cleaned,
  });

  factory AdminResult.fromJson(Map<String, dynamic> j) => AdminResult(
    ok: (j['ok'] as bool?) ?? false,
    slug: (j['slug'] as String?) ?? '',
    published: j['published'] as bool?,
    deletedVersion: j['deletedVersion'] as String?,
    newLatest: j['newLatest'] as String?,
    remainingVersions: (j['remainingVersions'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .toList(),
    deletedKeys: j['deletedKeys'] as int?,
    cleaned: j['cleaned'] as bool?,
  );
}

/// Client that speaks the exact Netlify Function contracts.
class DrillClient {
  /// Base origin or prefix (e.g. "https://ringdrill.netlify.app").
  /// Can be empty ("") to use same-origin in web builds.
  final String baseUrl;

  /// Public path prefix for the catalog API (default: "/api"). Aliased in
  /// `netlify.toml` to the `/.netlify/functions/*` implementation paths so
  /// old cached PWAs that still call the implementation paths keep working
  /// on the Netlify side.
  final String functionsBasePath;

  /// Path prefix for deep links (default: "/d").
  final String deepLinkBasePath;

  final http.Client _http;

  DrillClient({
    required this.baseUrl,
    this.functionsBasePath = '/api',
    this.deepLinkBasePath = '/d',
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  Future<bool> exists(String slug, {int? version}) async {
    final h = await head(slug, version: version);
    return h.exists;
  }

  // -------------------------------
  // Upload (drills-upload) — POST
  // -------------------------------
  /// Upload a [DrillFile] to the catalog.
  ///
  /// 412 (Precondition Failed) is propagated to the caller — we do NOT
  /// silently HEAD + retry with a refreshed etag. That would defeat the
  /// optimistic-concurrency contract: a 412 means the server has moved on
  /// since the client last looked, and the local edits the caller is about
  /// to publish are based on a stale view. The UI is the right place to
  /// surface that, refresh, and let the user decide (overwrite, fork,
  /// cancel) — not the transport layer.
  Future<DrillUploadResponse> upload(
    DrillFile file, {
    String? ifMatchEtag,
    String ownerId = 'anon',
    bool published = false,
    List<String> tags = const [],
  }) =>
      _uploadOnce(
        file,
        tags: tags,
        ownerId: ownerId,
        published: published,
        ifMatchEtag: ifMatchEtag,
      );

  Future<DrillUploadResponse> _uploadOnce(
    DrillFile file, {
    String? ifMatchEtag,
    String ownerId = 'anon',
    bool published = false,
    List<String> tags = const [],
  }) async {
    final program = file.program();
    final qs = <String, String>{
      'ownerId': ownerId,
      'programId': program.uuid,
      // Send an explicit version only when the caller has actually set one on
      // the DrillFile (file.version > 0 means "I uploaded version N before, so
      // tag this one N+1"). When unset, let the backend auto-bump to the next
      // free integer based on the meta's existing versions.
      if (file.version > 0) 'version': (file.version + 1).toString(),
      'slug': file.slug,
      // TODO: Add name to Drill Program
      'name': file.fileName,
      'published': published.toString(),
      if (tags.isNotEmpty) 'tags': tags.join(','),
    };

    final uri = _buildFnUri('drills/upload', query: qs);
    final res = await _http.post(
      uri,
      headers: {
        // Server accepts raw binary or base64. We send raw.
        'content-type': 'application/octet-stream',
        'if-match': ?ifMatchEtag,
      },
      body: file.content,
    );

    if (res.statusCode == 304) {
      // Server tells us "your bytes match the current latest — no new
      // version was created". Build a synthetic response from the headers
      // so the caller can update its source.latestEtag (it's a no-op for
      // them but keeps the field non-stale) without special-casing the
      // upload return type.
      final etag = res.headers['etag'] ?? '';
      final version = res.headers['x-version'] ?? '';
      final latestUrl = res.headers['x-latest'];
      final versionedUrl = res.headers['x-versioned'];
      final programId = res.headers['x-program-id'] ?? '';
      return DrillUploadResponse(
        slug: file.slug,
        programId: programId,
        version: version,
        etag: etag,
        latestUrl: latestUrl != null ? Uri.parse(latestUrl) : uri,
        versionedUrl: versionedUrl != null ? Uri.parse(versionedUrl) : uri,
        notModified: true,
      );
    }

    if (res.statusCode == 409) {
      final kind = res.headers['x-conflict-kind'];
      throw DrillApiException(
        kind == 'version'
            ? 'Version collision for slug=${file.slug}'
            : 'Slug already in use: ${file.slug}',
        status: 409,
        body: res.body,
        conflictKind: kind,
      );
    }

    if (res.statusCode == 412) {
      throw DrillApiException(
        'Precondition failed (If-Match did not match current ETag).',
        status: 412,
        body: res.body,
      );
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw DrillApiException(
        'Upload failed',
        status: res.statusCode,
        body: res.body,
      );
    }

    final j = jsonDecode(res.body) as Map<String, dynamic>;
    return DrillUploadResponse.fromJson(j);
  }

  // ----------------------------------------
  // Head (drills-head) — HEAD + If-None-Match
  // ----------------------------------------
  Future<DrillHeadResponse> head(
    String slug, {
    int? version,
    String? ifNoneMatch,
  }) async {
    final path = _slugVerPath(slug, version);
    final uri = _buildFnUri('drills/head/$path');
    final res = await _http.head(uri, headers: {'if-none-match': ?ifNoneMatch});

    if (res.statusCode == 304) {
      return const DrillHeadResponse(exists: true, notModified: true);
    }
    if (res.statusCode == 404) {
      return const DrillHeadResponse(exists: false, notModified: false);
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw DrillApiException(
        'HEAD failed',
        status: res.statusCode,
        body: res.body,
      );
    }

    return DrillHeadResponse(
      exists: true,
      notModified: false,
      etag: res.headers['etag'],
      contentLength: int.tryParse(res.headers['content-length'] ?? ''),
      lastModified: _parseHttpDate(res.headers['last-modified']),
      cacheControl: res.headers['cache-control'],
    );
  }

  // -------------------------------
  // Download (deep-link) — GET/HEAD
  // -------------------------------
  /// Download bytes. Returns [DrillDownloadResponse.notModified]
  /// with `true` when `If-None-Match` hit (304).
  Future<DrillDownloadResponse> download(
    String slug, {
    int? version,
    String? ifNoneMatch,
  }) async {
    final path = _slugVerPath(slug, version);
    final uri = _buildDeepUri(path);
    final res = await _http.get(
      uri,
      headers: {'if-none-match': ?ifNoneMatch, 'accept': drillMime},
    );

    if (res.statusCode == 304) {
      return DrillDownloadResponse.notModified(slug);
    }
    if (res.statusCode == 404) {
      throw DrillApiException('Not found', status: 404, body: res.body);
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw DrillApiException(
        'Download failed',
        status: res.statusCode,
        body: res.body,
      );
    }

    return DrillDownloadResponse(
      slug: slug,
      bytes: res.bodyBytes,
      etag: res.headers['etag'],
      contentType: res.headers['content-type'],
      contentDisposition: res.headers['content-disposition'],
      lastModified: _parseHttpDate(res.headers['last-modified']),
    );
  }

  // ---------------------------------
  // Market feed (market-feed) — GET
  // ---------------------------------
  Future<MarketFeedPageResponse> marketFeed({
    int limit = 50,
    String? cursor,
  }) async {
    final uri = _buildFnUri(
      'market/feed',
      query: {'limit': limit.toString(), 'cursor': ?cursor},
    );
    final res = await _http.get(uri);

    final contentType = res.headers['content-type'] ?? '';
    if (res.statusCode != 200) {
      throw DrillApiException(
        'Feed failed',
        status: res.statusCode,
        body: res.body,
      );
    }
    if (!contentType.contains('application/json')) {
      throw DrillApiException(
        'Feed returned non-JSON content',
        status: res.statusCode,
        body: res.body,
      );
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(res.body);
    } on FormatException catch (e) {
      throw DrillApiException(
        'Feed returned invalid JSON: ${e.message}',
        status: res.statusCode,
        body: res.body,
      );
    }
    return switch (decoded) {
      final Map<String, dynamic> j => MarketFeedPageResponse.fromJson(j),
      final List<dynamic> items => MarketFeedPageResponse(
        items: items
            .map((e) => MarketFeedItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      ),
      _ => throw DrillApiException(
        'Feed returned an unexpected JSON shape',
        status: res.statusCode,
        body: res.body,
      ),
    };
  }

  // --------------------------------------------
  // Admin (drills-admin) — GET + Authorization
  // --------------------------------------------
  // list versions for a given slug (admin action=list)
  Future<AdminListItem> versions({
    required String adminToken,
    required String slug,
  }) async {
    final uri = _buildFnUri(
      'admin',
      query: {'action': 'versions', 'slug': slug},
    );
    final res = await _http.get(
      uri,
      headers: {
        'authorization': 'Bearer $adminToken',
        'accept': 'application/json',
      },
    );
    if (res.statusCode != 200) {
      throw DrillApiException(
        'List versions failed',
        status: res.statusCode,
        body: res.body,
      );
    }
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    return AdminListItem.fromJson(j);
  }

  // list all slugs (admin action=listall)
  Future<AdminListPageResponse> listAll({
    required String adminToken,
    int limit = 50,
    String? cursor,
  }) async {
    final uri = _buildFnUri(
      'admin',
      query: {
        'action': 'listall',
        'limit': limit.toString(),
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      },
    );
    final res = await _http.get(
      uri,
      headers: {
        'authorization': 'Bearer $adminToken',
        'accept': 'application/json',
      },
    );
    if (res.statusCode != 200) {
      throw DrillApiException(
        'List All failed',
        status: res.statusCode,
        body: res.body,
      );
    }
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    return AdminListPageResponse.fromJson(j);
  }

  Future<AdminResult> publish(String slug, {required String adminToken}) =>
      _adminAction('publish', slug: slug, adminToken: adminToken);

  Future<AdminResult> unpublish(String slug, {required String adminToken}) =>
      _adminAction('unpublish', slug: slug, adminToken: adminToken);

  Future<AdminResult> deleteVersion(
    String slug,
    String version, {
    required String adminToken,
  }) => _adminAction(
    'deleteversion',
    slug: slug,
    version: version,
    adminToken: adminToken,
  );

  Future<AdminResult> deleteAll(String slug, {required String adminToken}) =>
      _adminAction('deleteall', slug: slug, adminToken: adminToken);

  // -------------------------------
  // Helpers
  // -------------------------------
  Future<AdminResult> _adminAction(
    String action, {
    required String slug,
    String? version,
    required String adminToken,
  }) async {
    final uri = _buildFnUri(
      'admin',
      query: {'action': action, 'slug': slug, 'version': ?version},
    );
    final res = await _http.get(
      uri,
      headers: {
        'authorization': 'Bearer $adminToken',
        'accept': 'application/json',
      },
    );

    // Contract returns JSON bodies for both success & errors.
    final bodyText = res.body;
    Map<String, dynamic>? j;
    try {
      j = bodyText.isNotEmpty
          ? jsonDecode(bodyText) as Map<String, dynamic>
          : null;
    } catch (_) {
      j = null;
    }

    if (res.statusCode != 200) {
      final msg = j?['error'] as String? ?? 'Admin action failed';
      throw DrillApiException(msg, status: res.statusCode, body: bodyText);
    }
    return AdminResult.fromJson(j ?? const {});
  }

  Uri _buildFnUri(String tail, {Map<String, String>? query}) {
    final base = _join(baseUrl, _ensureLeadingSlash(functionsBasePath));
    final path = _join(base, _ensureNoLeadingSlash(tail));
    return Uri.parse(path).replace(queryParameters: query);
  }

  Uri _buildDeepUri(String tail) {
    final base = _join(baseUrl, _ensureLeadingSlash(deepLinkBasePath));
    final path = _join(base, _ensureNoLeadingSlash(tail));
    return Uri.parse(path);
  }

  String _slugVerPath(String slug, int? version) =>
      version == null ? slug : '$slug@$version';

  static DateTime? _parseHttpDate(String? v) {
    if (v == null || v.isEmpty) return null;
    try {
      return parseHttpDate(v);
    } catch (_) {
      return null;
    }
  }

  static String _join(String a, String b) {
    if (a.isEmpty) return b;
    if (a.endsWith('/') && b.startsWith('/')) return a + b.substring(1);
    if (!a.endsWith('/') && !b.startsWith('/')) return '$a/$b';
    return a + b;
  }

  static String _ensureLeadingSlash(String p) => p.startsWith('/') ? p : '/$p';
  static String _ensureNoLeadingSlash(String p) =>
      p.startsWith('/') ? p.substring(1) : p;

  void close() => _http.close();
}
