import 'dart:convert';

import 'package:args/args.dart';
import 'package:http/http.dart' as http;
import 'package:ringdrill/data/drill_client.dart';
import 'package:ringdrill/data/drill_file.dart';
import 'package:universal_io/io.dart';

const _defaultBaseUrl = 'https://ringdrill.netlify.app';

const _adminCommands = <String>{
  'publish',
  'unpublish',
  'delete-version',
  'delete-all',
  'list-versions',
  'list-all',
};

Future<void> main(List<String> argv) async {
  final parser = ArgParser()
    ..addOption(
      'base-url',
      abbr: 'b',
      help: 'Base URL for the site (env: RINGDRILL_BASE_URL).',
      defaultsTo: Platform.environment['RINGDRILL_BASE_URL'] ?? _defaultBaseUrl,
    )
    ..addOption(
      'token',
      abbr: 't',
      help: 'Admin bearer token (env: RINGDRILL_ADMIN_TOKEN). '
          'Only required for admin commands.',
      defaultsTo: Platform.environment['RINGDRILL_ADMIN_TOKEN'],
    )
    ..addFlag(
      'json',
      abbr: 'j',
      help: 'Print raw JSON only.',
      defaultsTo: false,
    )
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage.')
    // upload
    ..addFlag(
      'published',
      negatable: false,
      help: 'Upload as published (upload command).',
    )
    ..addOption(
      'owner',
      help: 'Owner id (upload command). Default: anon.',
      defaultsTo: 'anon',
    )
    // feed
    ..addOption(
      'limit',
      help: 'Page size (feed/list-all command). Default: 50.',
      defaultsTo: '50',
    )
    ..addOption(
      'cursor',
      help: 'Pagination cursor (feed/list-all command).',
    )
    // download
    ..addOption(
      'out',
      help: 'Output path (download command). Default: <slug>.drill.',
    )
    ..addOption(
      'version',
      help: 'Specific version (download command). Default: latest.',
    );

  late final ArgResults res;
  try {
    res = parser.parse(argv);
  } on FormatException catch (e) {
    stderr.writeln('Error: ${e.message}');
    _printUsage(parser);
    exit(64); // EX_USAGE
  }

  if (res['help'] == true || res.rest.isEmpty) {
    _printUsage(parser);
    exit(0);
  }

  final baseUrl = (res['base-url'] as String).trim().replaceAll(
    RegExp(r'/$'),
    '',
  );
  final token = (res['token'] as String?)?.trim() ?? '';
  final jsonOut = res['json'] == true;

  final cmd = res.rest.first;
  final args = res.rest.skip(1).toList();

  if (_adminCommands.contains(cmd) && token.isEmpty) {
    _fail(
      'Missing admin token for "$cmd". Use --token or set RINGDRILL_ADMIN_TOKEN.',
    );
  }

  final client = DrillClient(baseUrl: baseUrl);

  try {
    switch (cmd) {
      case 'upload':
        await _runUpload(client, args, res, jsonOut);
        break;

      case 'feed':
        await _runFeed(client, res, jsonOut);
        break;

      case 'download':
        await _runDownload(client, args, res, jsonOut);
        break;

      case 'publish':
        if (args.length != 1) _fail('Usage: publish <slug>');
        _printResult(
          _toJson(await client.publish(args[0], adminToken: token)),
          jsonOut,
        );
        break;

      case 'unpublish':
        if (args.length != 1) _fail('Usage: unpublish <slug>');
        _printResult(
          _toJson(await client.unpublish(args[0], adminToken: token)),
          jsonOut,
        );
        break;

      case 'delete-version':
        if (args.length != 2) _fail('Usage: delete-version <slug> <version>');
        _printResult(
          _toJson(
            await client.deleteVersion(args[0], args[1], adminToken: token),
          ),
          jsonOut,
        );
        break;

      case 'delete-all':
        if (args.length != 1) _fail('Usage: delete-all <slug>');
        _printResult(
          _toJson(await client.deleteAll(args[0], adminToken: token)),
          jsonOut,
        );
        break;

      case 'list-versions':
        if (args.length != 1) _fail('Usage: list-versions <slug>');
        final item = await client.versions(adminToken: token, slug: args[0]);
        _printListOne(item, jsonOut);
        break;

      case 'list-all':
        final limit = int.tryParse(res['limit'] as String) ?? 50;
        final cursor = res['cursor'] as String?;
        final page = await client.listAll(
          adminToken: token,
          limit: limit,
          cursor: cursor,
        );
        _printListPage(page, jsonOut);
        break;

      default:
        _printUsage(parser);
        exit(64); // EX_USAGE
    }
  } on DrillApiException catch (e) {
    if (jsonOut && e.body != null && e.body!.isNotEmpty) {
      try {
        json.decode(e.body!);
        stdout.writeln(e.body);
      } catch (_) {
        stderr.writeln(jsonEncode({'error': e.message, 'status': e.status}));
      }
    } else {
      stderr.writeln(
        'Error${e.status != null ? ' (${e.status})' : ''}: ${e.message}',
      );
      if (e.body != null && e.body!.isNotEmpty) {
        stderr.writeln(e.body);
      }
    }
    exitCode = 1;
  } on http.ClientException catch (e) {
    _printNetworkError(baseUrl, e.message, jsonOut);
    exitCode = 3;
  } on SocketException catch (e) {
    _printNetworkError(baseUrl, e.message, jsonOut);
    exitCode = 3;
  } catch (e) {
    stderr.writeln('Unexpected error: $e');
    exitCode = 2;
  } finally {
    client.close();
  }
}

void _printNetworkError(String baseUrl, String detail, bool jsonOut) {
  final isLocal =
      baseUrl.contains('localhost') || baseUrl.contains('127.0.0.1');
  if (jsonOut) {
    stderr.writeln(
      jsonEncode({
        'error': 'network',
        'baseUrl': baseUrl,
        'detail': detail,
        if (isLocal) 'hint': 'Start the local backend with: make netlify-dev',
      }),
    );
    return;
  }
  stderr.writeln('Network error talking to $baseUrl: $detail');
  if (isLocal) {
    stderr.writeln(
      'The local backend does not appear to be running. '
      'Start it in another terminal with:',
    );
    stderr.writeln('  make netlify-dev');
  }
}

// ---------------------------------------------------------------------------
// Command implementations
// ---------------------------------------------------------------------------

Future<void> _runUpload(
  DrillClient client,
  List<String> args,
  ArgResults res,
  bool jsonOut,
) async {
  if (args.length != 1) {
    _fail(
      'Usage: upload <file.drill> '
      '[--published] [--owner=<id>]',
    );
  }
  final path = args[0];
  final file = File(path);
  if (!file.existsSync()) {
    _fail('File not found: $path');
  }
  final drillFile = DrillFile.fromFile(file);
  final response = await client.upload(
    drillFile,
    published: res['published'] as bool,
    ownerId: res['owner'] as String,
  );
  _printUpload(response, jsonOut);
}

Future<void> _runFeed(
  DrillClient client,
  ArgResults res,
  bool jsonOut,
) async {
  final limit = int.tryParse(res['limit'] as String) ?? 50;
  final cursor = res['cursor'] as String?;
  final page = await client.marketFeed(limit: limit, cursor: cursor);
  _printFeed(page, jsonOut);
}

Future<void> _runDownload(
  DrillClient client,
  List<String> args,
  ArgResults res,
  bool jsonOut,
) async {
  if (args.length != 1) {
    _fail('Usage: download <slug> [--out=<file>] [--version=N]');
  }
  final slug = args[0];
  final versionStr = res['version'] as String?;
  final version = versionStr == null ? null : int.tryParse(versionStr);
  if (versionStr != null && version == null) {
    _fail('Invalid --version: $versionStr');
  }
  final outPath = (res['out'] as String?) ?? '$slug.${DrillFile.drillExtension}';
  final response = await client.download(slug, version: version);
  File(outPath).writeAsBytesSync(response.bytes);
  _printDownload(slug, outPath, response, jsonOut);
}

// ---------------------------------------------------------------------------
// Printers
// ---------------------------------------------------------------------------

Map<String, dynamic> _toJson(AdminResult res) => {
  'ok': res.ok,
  'slug': res.slug,
  if (res.published != null) 'published': res.published,
  if (res.deletedVersion != null) 'deletedVersion': res.deletedVersion,
  if (res.newLatest != null) 'newLatest': res.newLatest,
  if (res.remainingVersions != null) 'remainingVersions': res.remainingVersions,
  if (res.deletedKeys != null) 'deletedKeys': res.deletedKeys,
  if (res.cleaned != null) 'cleaned': res.cleaned,
};

void _printUpload(DrillUploadResponse r, bool jsonOut) {
  if (jsonOut) {
    stdout.writeln(
      jsonEncode({
        'slug': r.slug,
        'programId': r.programId,
        'version': r.version,
        'etag': r.etag,
        'latest': r.latestUrl.toString(),
        'versioned': r.versionedUrl.toString(),
        if (r.note != null) 'note': r.note,
      }),
    );
    return;
  }
  stdout.writeln('✔ uploaded ${r.slug}');
  stdout.writeln('  programId : ${r.programId}');
  stdout.writeln('  version   : ${r.version}');
  stdout.writeln('  etag      : ${r.etag}');
  stdout.writeln('  latest    : ${r.latestUrl}');
  stdout.writeln('  versioned : ${r.versionedUrl}');
  if (r.note != null && r.note!.isNotEmpty) {
    stdout.writeln('  note      : ${r.note}');
  }
}

void _printFeed(MarketFeedPageResponse page, bool jsonOut) {
  if (jsonOut) {
    stdout.writeln(
      jsonEncode({
        'items': page.items
            .map(
              (i) => {
                'programId': i.programId,
                'slug': i.slug,
                'name': i.name,
                'tags': i.tags,
                'latestUrl': i.latestUrl.toString(),
                if (i.updatedAt != null)
                  'updatedAt': i.updatedAt!.toIso8601String(),
              },
            )
            .toList(),
        if (page.nextCursor != null) 'nextCursor': page.nextCursor,
      }),
    );
    return;
  }
  stdout.writeln('✔ ${page.items.length} items');
  for (final i in page.items) {
    final tags = i.tags.isEmpty ? '' : ' [${i.tags.join(', ')}]';
    final updated = i.updatedAt == null
        ? ''
        : ' updated=${i.updatedAt!.toIso8601String()}';
    stdout.writeln('  ${i.slug}  ${i.name}$tags$updated');
  }
  if (page.nextCursor != null) {
    stdout.writeln('nextCursor: ${page.nextCursor}');
  }
}

void _printDownload(
  String slug,
  String outPath,
  DrillDownloadResponse r,
  bool jsonOut,
) {
  if (jsonOut) {
    stdout.writeln(
      jsonEncode({
        'slug': slug,
        'out': outPath,
        'size': r.bytes.length,
        if (r.etag != null) 'etag': r.etag,
        if (r.contentType != null) 'contentType': r.contentType,
        if (r.lastModified != null)
          'lastModified': r.lastModified!.toIso8601String(),
      }),
    );
    return;
  }
  stdout.writeln('✔ downloaded $slug → $outPath (${r.bytes.length} bytes)');
  if (r.etag != null) stdout.writeln('  etag         : ${r.etag}');
  if (r.contentType != null) {
    stdout.writeln('  contentType  : ${r.contentType}');
  }
  if (r.lastModified != null) {
    stdout.writeln('  lastModified : ${r.lastModified}');
  }
}

void _printUsage(ArgParser parser) {
  stdout.writeln('''
ringdrill — CLI for the RingDrill Netlify backend

USAGE:
  ringdrill [global options] <command> [args]

PUBLIC COMMANDS (no admin token required):
  upload <file.drill>             Upload a .drill file
                                    [--published] [--owner=<id>]
  feed                            Show the public market feed
                                    [--limit=N] [--cursor=C]
  download <slug>                 Download a .drill to disk
                                    [--out=<file>] [--version=N]

ADMIN COMMANDS (RINGDRILL_ADMIN_TOKEN or --token required):
  list-versions <slug>            List versions for a slug
  list-all                        List all slugs [--limit=N] [--cursor=C]
  publish <slug>                  Publish a drill
  unpublish <slug>                Unpublish a drill
  delete-version <slug> <ver>     Delete a version
  delete-all <slug>               Delete all versions for a slug

GLOBAL OPTIONS:
${parser.usage}

ENV:
  RINGDRILL_BASE_URL     Base URL (default: $_defaultBaseUrl)
  RINGDRILL_ADMIN_TOKEN  Bearer token for admin API
''');
}

Never _fail(String msg) {
  stderr.writeln(msg);
  exit(64); // EX_USAGE
}

void _printListOne(AdminListItem i, bool jsonOut) {
  if (jsonOut) {
    stdout.writeln(
      jsonEncode({
        'slug': i.slug,
        'ownerId': i.ownerId,
        'programId': i.programId,
        'published': i.published,
        'versionCount': i.versionCount,
        if (i.latest != null) 'latest': i.latest,
        if (i.versions != null) 'versions': i.versions,
      }),
    );
    return;
  }
  final pub = i.published == true
      ? ' (published)'
      : i.published == false
      ? ' (unpublished)'
      : '';
  stdout.writeln('✔ ${i.slug}$pub');
  stdout.writeln('  programId: ${i.programId}');
  stdout.writeln('  versions : ${i.versionCount ?? 0}');
  if (i.latest != null) {
    stdout.writeln(
      '  latest   : v=${i.latest!['v']} etag=${i.latest!['etag']} size=${i.latest!['size']} updatedAt=${i.latest!['updatedAt']}',
    );
  }
  if (i.versions != null && i.versions!.isNotEmpty) {
    for (final v in i.versions!) {
      stdout.writeln(
        '    - v=${v['v']} etag=${v['etag']} size=${v['size']} updatedAt=${v['updatedAt']}',
      );
    }
  }
}

void _printListPage(AdminListPageResponse page, bool jsonOut) {
  if (jsonOut) {
    stdout.writeln(
      jsonEncode({
        'items': page.items
            .map(
              (i) => {
                'slug': i.slug,
                'ownerId': i.ownerId,
                'programId': i.programId,
                'published': i.published,
                'versionCount': i.versionCount,
                if (i.latest != null) 'latest': i.latest,
              },
            )
            .toList(),
        if (page.nextCursor != null) 'nextCursor': page.nextCursor,
      }),
    );
    return;
  }
  stdout.writeln('✔ ${page.items.length} items');
  for (final i in page.items) {
    final pub = i.published == true
        ? ' (published)'
        : i.published == false
        ? ' (unpublished)'
        : '';
    final latest = i.latest != null ? ' v=${i.latest!['v']}' : '';
    stdout.writeln('  ${i.slug}$pub  versions=${i.versionCount ?? 0}$latest');
  }
  if (page.nextCursor != null) {
    stdout.writeln('nextCursor: ${page.nextCursor}');
  }
}

void _printResult(Map<String, dynamic> jsonMap, bool jsonOut) {
  if (jsonOut) {
    stdout.writeln(jsonEncode(jsonMap));
    return;
  }
  final ok = jsonMap['ok'] == true;
  final slug = jsonMap['slug'] ?? '(unknown)';
  stdout.writeln('${ok ? '✔' : '✖'} ok=$ok slug=$slug');

  if (jsonMap.containsKey('published')) {
    stdout.writeln('  published: ${jsonMap['published']}');
  }
  if (jsonMap.containsKey('deletedVersion')) {
    stdout.writeln('  deletedVersion: ${jsonMap['deletedVersion']}');
  }
  if (jsonMap.containsKey('newLatest')) {
    stdout.writeln('  newLatest: ${jsonMap['newLatest']}');
  }
  if (jsonMap.containsKey('remainingVersions')) {
    stdout.writeln('  remainingVersions: ${jsonMap['remainingVersions']}');
  }
  if (jsonMap.containsKey('deletedKeys')) {
    stdout.writeln('  deletedKeys: ${jsonMap['deletedKeys']}');
  }
  if (jsonMap.containsKey('cleaned')) {
    stdout.writeln('  cleaned: ${jsonMap['cleaned']}');
  }
}
