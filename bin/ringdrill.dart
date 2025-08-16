import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:ringdrill/data/drill_client.dart';

const _defaultBaseUrl = 'https://ringdrill.netlify.app';

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
      help: 'Admin bearer token (env: RINGDRILL_ADMIN_TOKEN).',
      defaultsTo: Platform.environment['RINGDRILL_ADMIN_TOKEN'],
    )
    ..addFlag(
      'json',
      abbr: 'j',
      help: 'Print raw JSON only.',
      defaultsTo: false,
    )
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage.');

  final res = parser.parse(argv);
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

  if (token.isEmpty) {
    _fail('Missing admin token. Use --token or set RINGDRILL_ADMIN_TOKEN.');
  }

  final client = DrillClient(baseUrl: baseUrl);

  try {
    Map<String, dynamic> out = {};
    switch (cmd) {
      case 'publish':
        if (args.length != 1) _fail('Usage: publish <slug>');
        out = _toJson(await client.publish(args[0], adminToken: token));
        break;

      case 'unpublish':
        if (args.length != 1) _fail('Usage: unpublish <slug>');
        out = _toJson(await client.unpublish(args[0], adminToken: token));
        break;

      case 'delete-version':
        if (args.length != 2) _fail('Usage: delete-version <slug> <version>');
        out = _toJson(
          await client.deleteVersion(args[0], args[1], adminToken: token),
        );
        break;

      case 'delete-all':
        if (args.length != 1) _fail('Usage: delete-all <slug>');
        out = _toJson(await client.deleteAll(args[0], adminToken: token));
        break;

      case 'list-versions':
        {
          // list <slug>
          if (args.length != 1) _fail('Usage: list <slug>');
          final item = await client.versions(adminToken: token, slug: args[0]);
          _printListOne(item, jsonOut);
          break;
        }

      case 'list-all':
        {
          // listall [limit] [cursor]
          final limit = args.isNotEmpty ? int.tryParse(args[0]) ?? 50 : 50;
          final cursor = args.length > 1 ? args[1] : null;
          final page = await client.listAll(
            adminToken: token,
            limit: limit,
            cursor: cursor,
          );
          _printListPage(page, jsonOut);
          break;
        }

      default:
        _printUsage(parser);
        exit(64); // EX_USAGE
    }

    _printResult(out, jsonOut);
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
  } catch (e) {
    stderr.writeln('Unexpected error: $e');
    exitCode = 2;
  } finally {
    client.close();
  }
}

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

void _printUsage(ArgParser parser) {
  stdout.writeln('''
ringdrill — CLI using DrillClient for RingDrill admin API

USAGE:
  ringdrill [global options] <command> [args]

COMMANDS:
  list-versions <slug>            List versions for a slug (admin action=list)
  list-all [limit] [cursor]       List all slugs (admin action=listall)
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
