import 'dart:convert';

import 'package:args/args.dart';
import 'package:http/http.dart' as http;
import 'package:ringdrill/data/drill_client.dart';
import 'package:ringdrill/data/drill_file.dart';
import 'package:ringdrill/data/drill_migrations.dart';
import 'package:ringdrill/data/source/plan_decompiler.dart';
import 'package:ringdrill/data/source/source_analyzer.dart';
import 'package:ringdrill/data/source/source_compiler.dart';
import 'package:ringdrill/data/source/source_diagnostic.dart';
import 'package:ringdrill/data/source/source_scaffold.dart';
import 'package:ringdrill/data/source/source_schema.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/services/brief/brief_audience.dart';
import 'package:ringdrill/services/brief/brief_labels.dart';
import 'package:ringdrill/services/brief/brief_renderer.dart';
import 'package:ringdrill/services/brief/brief_summary.dart';
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
      'functions-base-path',
      help:
          'Path prefix for Netlify function calls '
          '(env: RINGDRILL_FUNCTIONS_BASE_PATH). Default "/api" relies on '
          'netlify.toml redirects, which "netlify functions:serve" (ADR-0013) '
          'does not apply — pass "/.netlify/functions" against that local mode.',
      defaultsTo:
          Platform.environment['RINGDRILL_FUNCTIONS_BASE_PATH'] ?? '/api',
    )
    ..addOption(
      'token',
      abbr: 't',
      help:
          'Admin bearer token (env: RINGDRILL_ADMIN_TOKEN). '
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
    ..addOption('cursor', help: 'Pagination cursor (feed/list-all command).')
    // download
    ..addOption(
      'out',
      help: 'Output path (download command). Default: <slug>.drill.',
    )
    ..addOption(
      'version',
      help: 'Specific version (download command). Default: latest.',
    )
    // source format (DESIGN-014)
    ..addOption('name', help: 'Plan name (create command).')
    ..addOption(
      'exercises',
      help: 'How many exercises to scaffold (create command). Default: 1.',
      defaultsTo: '1',
    )
    ..addOption(
      'teams',
      help: 'How many teams rotate (create command). Default: 4.',
      defaultsTo: '4',
    )
    ..addOption(
      'stations',
      help:
          'Stations per exercise (create command). Default: the team count, '
          'which is the fewest a rotation can have.',
    )
    ..addOption(
      'rounds',
      help:
          'Rounds per exercise (create command). Default: the station count — '
          'one round per station is a full rotation.',
    )
    ..addFlag(
      'bare',
      negatable: false,
      help:
          'Scaffold without the worked scenario example (create command): no '
          'locations, persons, role plays or variables.',
    )
    ..addOption(
      'audience',
      help:
          'Brief audience (render command): one per staff role — actor, '
          'instructor, director, other — plus participant, the printed '
          'handout. Every audience but participant is a staff view; the ones '
          'that include the cast\'s contact details only have them in a '
          'locally held archive, since staff is stripped at publish '
          '(ADR-0063).',
      defaultsTo: 'participant',
    )
    ..addOption(
      'lang',
      help:
          'Language for the rendered brief (render command). Default: the '
          "plan's own content language.",
    )
    ..addOption(
      'exercise',
      help:
          '1-based exercise number to scope the brief to (render command). '
          'Default: the whole plan.',
    )
    ..addOption(
      'station',
      help:
          '1-based station number within the scoped exercise (render command). '
          'Requires --exercise. Default: every station.',
    )
    ..addOption(
      'format',
      help:
          'Brief output (render command): "full" (default) or "summary" — '
          'headings and which sections each scope carries, without the prose. '
          'Summary is the cheap way to check that a plan reads, when the brief '
          'itself is tens of kilobytes (ADR-0064).',
      defaultsTo: 'full',
    )
    ..addFlag(
      'strict',
      negatable: false,
      help:
          'Treat warnings as errors (build/analyze commands). Useful in a '
          'pipeline where a generated document should be clean, not just '
          'buildable.',
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

  final functionsBasePath = (res['functions-base-path'] as String).trim();
  final client = DrillClient(
    baseUrl: baseUrl,
    functionsBasePath: functionsBasePath,
  );

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

      case 'create':
        _runCreate(args, res, jsonOut);
        break;

      case 'build':
        _runBuild(args, res, jsonOut);
        break;

      case 'decompile':
        _runDecompile(args, res, jsonOut);
        break;

      case 'analyze':
        _runAnalyze(args, res, jsonOut);
        break;

      case 'render':
        await _runRender(args, res, jsonOut);
        break;

      case 'schema':
        _runSchema(res);
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

Future<void> _runFeed(DrillClient client, ArgResults res, bool jsonOut) async {
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
  final outPath =
      (res['out'] as String?) ?? '$slug.${DrillFile.drillExtension}';
  final response = await client.download(slug, version: version);
  File(outPath).writeAsBytesSync(response.bytes);
  _printDownload(slug, outPath, response, jsonOut);
}

// ---------------------------------------------------------------------------
// Source format (DESIGN-014)
// ---------------------------------------------------------------------------

/// `create --name=<plan> [--exercises=N] [--teams=N] …`
///
/// Writes a source document to start from. Everything is a flag rather than a
/// prompt so the command works the same interactively, in a Makefile and from an
/// MCP tool call; a scaffold nobody can script is only half useful.
void _runCreate(List<String> args, ArgResults res, bool jsonOut) {
  if (args.isNotEmpty) {
    _fail('Usage: create --name=<plan> [options]  (no positional arguments)');
  }
  final name = (res['name'] as String?)?.trim();
  if (name == null || name.isEmpty) {
    _fail('Usage: create --name=<plan> [--exercises=N] [--teams=N] …');
  }

  final exercises = _positive(res['exercises'] as String?, 'exercises', 1);
  final teams = _positive(res['teams'] as String?, 'teams', 4);
  final stations = res['stations'] == null
      ? null
      : _positive(res['stations'] as String?, 'stations', teams);
  final rounds = res['rounds'] == null
      ? 0
      : _positive(res['rounds'] as String?, 'rounds', 0);

  if (stations != null && stations < teams) {
    // The same rule `build` enforces, caught here so the scaffold cannot produce
    // a document that immediately fails to compile.
    _fail(
      'Cannot scaffold $stations station(s) for $teams team(s): a rotation '
      'needs at least one station per team.',
    );
  }

  final document = SourceScaffold.generate(
    name: name,
    exercises: exercises,
    teams: teams,
    stationsPerExercise: stations,
    rounds: rounds,
    languageCode: ((res['lang'] as String?)?.trim().isEmpty ?? true)
        ? 'en'
        : (res['lang'] as String).trim(),
    withExample: res['bare'] != true,
  );

  // Default the file name from the plan name, the same slug rule the catalog
  // uses — so `create` then `build` then `upload` lands on a predictable slug
  // rather than one that changes at the last step.
  final outPath = (res['out'] as String?) ?? '${sanitizeSlug(name)}.yaml';
  if (outPath == '-') {
    stdout.write(document);
    return;
  }
  if (File(outPath).existsSync()) {
    _fail('Refusing to overwrite $outPath. Pass --out=<file> or remove it.');
  }
  File(outPath).writeAsStringSync(document);

  if (jsonOut) {
    stdout.writeln(
      jsonEncode({
        'out': outPath,
        'name': name,
        'exercises': exercises,
        'teams': teams,
        'stations': stations ?? teams,
        'bytes': document.length,
      }),
    );
    return;
  }
  stdout.writeln('✔ created $outPath');
  stdout.writeln('  name      : $name');
  stdout.writeln('  exercises : $exercises');
  stdout.writeln('  teams     : $teams');
  stdout.writeln('  stations  : ${stations ?? teams} per exercise');
  stdout.writeln();
  stdout.writeln('Next:');
  stdout.writeln('  ringdrill analyze $outPath');
  stdout.writeln('  ringdrill build $outPath');
  stdout.writeln('  ringdrill render $outPath --audience=director');
}

int _positive(String? raw, String flag, int fallback) {
  if (raw == null || raw.trim().isEmpty) return fallback;
  final value = int.tryParse(raw.trim());
  if (value == null || value < 1) {
    _fail('Invalid --$flag "$raw". Expected a whole number of 1 or more.');
  }
  return value;
}

/// `build <source.yaml> [--out=<file>] [--strict]`
///
/// Compiles a source document to a `.drill`. Synchronous and offline — nothing
/// here touches the network, which is why it does not take the client.
void _runBuild(List<String> args, ArgResults res, bool jsonOut) {
  if (args.length != 1) {
    _fail('Usage: build <source.yaml> [--out=<file>] [--strict]');
  }
  final path = args[0];
  final file = File(path);
  if (!file.existsSync()) {
    _fail('File not found: $path');
  }

  // The archive's slug comes from its file name, so default the output to the
  // source's basename: `lsor-eidene-2026.yaml` builds `lsor-eidene-2026.drill`,
  // and the slug the catalog sees matches the file the author edits.
  final baseName = _baseName(path);
  final outPath =
      (res['out'] as String?) ?? '$baseName.${DrillFile.drillExtension}';
  final strict = res['strict'] == true;

  final CompileResult result;
  try {
    result = SourceCompiler.compile(
      file.readAsStringSync(),
      fileName: _baseName(outPath),
    );
  } on SourceFormatException catch (e) {
    _printDiagnostics(path, e.diagnostics, jsonOut);
    exitCode = 65; // EX_DATAERR
    return;
  }

  // `--strict` asks the full question, reference checks included — otherwise it
  // refuses on compile warnings while ignoring the `{{var.typo}}` that renders
  // "‹missing variable›" to a reader.
  final reviewed = SourceAnalyzer.review(result.plan, seed: result.warnings);

  // An analyzer *error* is not advisory: the renderer substitutes
  // "‹missing variable: x›" into the brief, so the archive is known-broken before
  // it is written. Refusing is not a widening of `build`'s question ("can I make
  // an archive") — it is answering it honestly. `--strict` adds warnings on top.
  final blocking = reviewed.where((d) => d.isError).toList();
  if (blocking.isNotEmpty || (strict && reviewed.isNotEmpty)) {
    _printDiagnostics(path, reviewed, jsonOut);
    stderr.writeln(
      blocking.isEmpty
          ? 'Refusing to write $outPath: --strict and warnings present.'
          : 'Refusing to write $outPath: ${blocking.length} error(s) that will '
                'not render.',
    );
    exitCode = 65;
    return;
  }

  File(outPath).writeAsBytesSync(result.drillFile.content);

  if (jsonOut) {
    stdout.writeln(
      jsonEncode({
        'source': path,
        'out': outPath,
        'planId': result.plan.uuid,
        'name': result.plan.name,
        'exercises': result.plan.exercises.length,
        'stations': result.plan.exercises.fold<int>(
          0,
          (acc, e) => acc + e.stations.length,
        ),
        'teams': result.plan.teams.length,
        'rolePlays': result.plan.rolePlays.length,
        'contentHash': result.plan.contentHash,
        'size': result.drillFile.content.length,
        // Same vocabulary as `analyze` and as the refusal path: counts under
        // `errors`/`warnings`, the diagnostics themselves under `diagnostics`.
        // One tool must not change a key's *type* with its outcome.
        'errors': reviewed.where((d) => d.isError).length,
        'warnings': reviewed.where((d) => !d.isError).length,
        'diagnostics': reviewed.map((d) => d.toJson()).toList(),
      }),
    );
    return;
  }

  stdout.writeln('✔ built $path → $outPath');
  stdout.writeln('  name        : ${result.plan.name}');
  stdout.writeln('  planId      : ${result.plan.uuid}');
  stdout.writeln(
    '  exercises   : ${result.plan.exercises.length} '
    '(${result.plan.exercises.fold<int>(0, (a, e) => a + e.stations.length)} '
    'stations)',
  );
  stdout.writeln('  teams       : ${result.plan.teams.length}');
  stdout.writeln('  roles       : ${result.plan.rolePlays.length}');
  stdout.writeln('  contentHash : ${result.plan.contentHash}');
  stdout.writeln('  size        : ${result.drillFile.content.length} bytes');
  if (reviewed.isNotEmpty) {
    stdout.writeln();
    _printDiagnostics(path, reviewed, false);
  }
}

/// `decompile <file.drill> [--out=<file>]`
///
/// Emits the source document for an existing archive. Writes to stdout when
/// `--out` is absent, so it composes in a pipeline — `decompile x.drill | less`
/// is the fastest way to read a published plan.
void _runDecompile(List<String> args, ArgResults res, bool jsonOut) {
  if (args.length != 1) {
    _fail('Usage: decompile <file.drill> [--out=<file>]');
  }
  final path = args[0];
  final file = File(path);
  if (!file.existsSync()) {
    _fail('File not found: $path');
  }

  final drillFile = DrillFile.fromFile(file);
  // Collect what the ADR-0059 ladder normalized on the way in. The app has
  // nowhere useful to say this, but here it is worth knowing: it is how someone
  // finds out that the archive a colleague sent them predates a rename, and that
  // the document they are about to edit is not a byte-for-byte view of it.
  final migrations = <MigrationNote>[];
  final Plan plan;
  try {
    plan = drillFile.plan(migrationNotes: migrations);
  } on DrillFormatException catch (e) {
    stderr.writeln('Cannot read $path: ${e.message}');
    exitCode = 65; // EX_DATAERR
    return;
  }

  final result = PlanDecompiler.decompile(
    plan,
    // A decompiled document is a derived artefact; say so in the file itself, or
    // it gets mistaken for hand-written source and edited in the wrong place.
    header:
        'Decompiled from $path by `ringdrill decompile`.\n'
        'Edit freely, then rebuild with `ringdrill build`.\n'
        'Derived fields (schedule, indices, contentHash) are omitted — the\n'
        'compiler fills them. uuids are kept so a rebuild lands on the same\n'
        'plan rather than a copy.',
  );

  final outPath = res['out'] as String?;
  if (outPath != null) {
    File(outPath).writeAsStringSync(result.yaml);
  }

  if (jsonOut) {
    stdout.writeln(
      jsonEncode({
        'source': path,
        'out': ?outPath,
        'planId': plan.uuid,
        'name': plan.name,
        'exercises': result.exercises.length,
        'teams': result.teams.length,
        'contentHash': plan.computeContentHash(),
        'migrations': migrations.map((n) => n.toJson()).toList(),
        if (outPath == null) 'document': result.yaml,
      }),
    );
    return;
  }

  if (outPath == null) {
    // Migration notes go to stderr, so `decompile x.drill > y.yaml` still
    // produces a clean document while the reader still sees them.
    _printMigrations(migrations);
    stdout.write(result.yaml);
    return;
  }
  stdout.writeln('✔ decompiled $path → $outPath');
  stdout.writeln('  name        : ${plan.name}');
  stdout.writeln('  planId      : ${plan.uuid}');
  stdout.writeln('  exercises   : ${result.exercises.length}');
  stdout.writeln('  teams       : ${result.teams.length}');
  stdout.writeln('  contentHash : ${plan.computeContentHash()}');
  _printMigrations(migrations);
}

/// Reports what the migration ladder changed, if anything.
void _printMigrations(List<MigrationNote> notes) {
  if (notes.isEmpty) return;
  stderr.writeln();
  stderr.writeln(
    'Normalized ${notes.length} legacy item(s) while reading the archive '
    '(ADR-0059):',
  );
  for (final note in notes) {
    stderr.writeln('  ${note.path}: ${note.message} [${note.rung}]');
  }
}

/// `analyze <source.yaml> [--strict]`
///
/// Checks a document without writing anything. Exit 0 when clean, 65 when
/// something will not resolve — or when `--strict` and there are warnings.
///
/// Separate from `build --strict` because the questions differ: `build` asks "can
/// I make an archive from this", `analyze` asks "will this render". A document
/// with a `{{var.typo}}` builds perfectly and then shows "‹missing variable›" to
/// a reader.
void _runAnalyze(List<String> args, ArgResults res, bool jsonOut) {
  if (args.length != 1) {
    _fail('Usage: analyze <source.yaml> [--strict]');
  }
  final path = args[0];
  final file = File(path);
  if (!file.existsSync()) {
    _fail('File not found: $path');
  }

  final strict = res['strict'] == true;
  final diagnostics = DiagnosticSink();
  final Plan plan;
  try {
    // Build in memory: reference checks need the assembled plan, since a token's
    // scope and the station that owns a slug are structural.
    final result = SourceCompiler.toPlan(file.readAsStringSync());
    plan = result.plan;
    diagnostics.addAll(result.diagnostics);
  } on SourceFormatException catch (e) {
    _printDiagnostics(path, e.diagnostics, jsonOut);
    exitCode = 65; // EX_DATAERR
    return;
  }

  SourceAnalyzer.analyze(plan, diagnostics);
  final items = diagnostics.items;
  final errors = items.where((d) => d.isError).length;
  final warnings = items.length - errors;

  if (jsonOut) {
    stdout.writeln(
      jsonEncode({
        'source': path,
        'ok': errors == 0 && !(strict && warnings > 0),
        'errors': errors,
        'warnings': warnings,
        'name': plan.name,
        'exercises': plan.exercises.length,
        'diagnostics': items.map((d) => d.toJson()).toList(),
      }),
    );
  } else if (items.isEmpty) {
    stdout.writeln('✔ $path is clean');
    stdout.writeln('  name      : ${plan.name}');
    stdout.writeln('  exercises : ${plan.exercises.length}');
    stdout.writeln('  variables : ${plan.variables.length}');
  } else {
    _printDiagnostics(path, items, false);
  }

  if (errors > 0 || (strict && warnings > 0)) exitCode = 65;
}

/// `render <source.yaml|file.drill> [--audience=…] [--lang=…] [--exercise=N]`
///
/// Renders the markdown brief. Accepts either side of the compiler — a source
/// document or a built archive — because both are things you have in hand and
/// want to read.
///
/// This is what the ADR-0048 amendment bought: the resolver and the renderer used
/// to take an `AppLocalizations` and load their template through the Flutter asset
/// bundle, so none of it could run here.
Future<void> _runRender(List<String> args, ArgResults res, bool jsonOut) async {
  if (args.length != 1) {
    _fail(
      'Usage: render <source.yaml|file.drill> '
      '[--audience=participant|actor|instructor|director|other] '
      '[--lang=<code>] [--exercise=N] [--station=N] '
      '[--format=full|summary] [--out=<file>]',
    );
  }
  final path = args[0];
  final file = File(path);
  if (!file.existsSync()) {
    _fail('File not found: $path');
  }

  final audienceName = (res['audience'] as String).trim();
  final audience = BriefAudience.values.where((a) => a.name == audienceName);
  if (audience.isEmpty) {
    _fail(
      'Unknown audience "$audienceName". '
      'Expected one of ${BriefAudience.values.map((a) => a.name).join(', ')}.',
    );
  }

  final Plan plan;
  if (path.endsWith('.${DrillFile.drillExtension}')) {
    try {
      plan = DrillFile.fromFile(file).plan();
    } on DrillFormatException catch (e) {
      stderr.writeln('Cannot read $path: ${e.message}');
      exitCode = 65;
      return;
    }
  } else {
    try {
      plan = SourceCompiler.toPlan(file.readAsStringSync()).plan;
    } on SourceFormatException catch (e) {
      _printDiagnostics(path, e.diagnostics, jsonOut);
      exitCode = 65;
      return;
    }
  }

  // The plan's own content language, not the host's locale (ADR-0007 addendum) —
  // a brief must not read differently depending on which machine rendered it.
  // --lang overrides, for rendering a Norwegian plan's brief in English.
  final languageCode = (res['lang'] as String?)?.trim();
  final labels = HeadlessBriefLabels(
    languageCode: (languageCode == null || languageCode.isEmpty)
        ? plan.metadata.languageCode
        : languageCode,
  );

  Exercise? exercise;
  final exerciseArg = (res['exercise'] as String?)?.trim();
  if (exerciseArg != null && exerciseArg.isNotEmpty) {
    final number = int.tryParse(exerciseArg);
    if (number == null || number < 1 || number > plan.exercises.length) {
      _fail(
        'Invalid --exercise "$exerciseArg". '
        'The plan has ${plan.exercises.length} exercise(s), numbered from 1.',
      );
    }
    final ordered = plan.exercises.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    exercise = ordered[number - 1];
  }

  // Station scoping filters the station list and keeps each station's own `index`
  // (ADR-0064). Codes come from that index, not from list position, so the one
  // station that survives still renders as "1c" rather than being renumbered to
  // "1a" — which would make a scoped brief disagree with the plan it came from.
  final stationArg = (res['station'] as String?)?.trim();
  if (stationArg != null && stationArg.isNotEmpty) {
    if (exercise == null) {
      _fail(
        '--station needs --exercise: a station number is within an exercise.',
      );
    }
    final ordered = exercise.stations.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    final number = int.tryParse(stationArg);
    if (number == null || number < 1 || number > ordered.length) {
      _fail(
        'Invalid --station "$stationArg". '
        'That exercise has ${ordered.length} station(s), numbered from 1.',
      );
    }
    exercise = exercise.copyWith(stations: [ordered[number - 1]]);
  }

  final format = (res['format'] as String).trim();
  if (format != 'full' && format != 'summary') {
    _fail('Unknown --format "$format". Expected "full" or "summary".');
  }
  if (format == 'summary') {
    final summary = renderBriefSummary(
      plan: plan,
      audience: audience.first,
      exercise: exercise,
    );
    _emitBrief(
      summary,
      source: path,
      res: res,
      jsonOut: jsonOut,
      audience: audience.first,
      labels: labels,
      exercise: exercise,
    );
    return;
  }

  final markdown = await BriefRenderer().render(
    plan: plan,
    exercise: exercise,
    audience: audience.first,
    l10n: labels,
  );

  _emitBrief(
    markdown,
    source: path,
    res: res,
    jsonOut: jsonOut,
    audience: audience.first,
    labels: labels,
    exercise: exercise,
  );
}

/// Writes or prints a rendered brief, whichever shape it is.
///
/// Shared by the full render and the `--format=summary` one so the two agree on
/// where output goes and what the JSON envelope looks like — a summary is a brief
/// with less in it, not a different command.
void _emitBrief(
  String markdown, {
  required String source,
  required ArgResults res,
  required bool jsonOut,
  required BriefAudience audience,
  required HeadlessBriefLabels labels,
  Exercise? exercise,
}) {
  final outPath = res['out'] as String?;
  if (outPath != null) File(outPath).writeAsStringSync(markdown);

  if (jsonOut) {
    stdout.writeln(
      jsonEncode({
        'source': source,
        'out': ?outPath,
        'audience': audience.name,
        'lang': labels.localeName,
        'exercise': ?exercise?.name,
        'format': res['format'],
        'bytes': markdown.length,
        if (outPath == null) 'markdown': markdown,
      }),
    );
    return;
  }
  if (outPath == null) {
    stdout.write(markdown);
    return;
  }
  stdout.writeln('✔ rendered $source → $outPath');
  stdout.writeln('  audience : ${audience.name}');
  stdout.writeln('  language : ${labels.localeName}');
  if (exercise != null) stdout.writeln('  exercise : ${exercise.name}');
  stdout.writeln('  format   : ${res['format']}');
  stdout.writeln('  size     : ${markdown.length} bytes');
}

/// `schema`
///
/// Prints the source format's JSON Schema. Pretty-printed by default because a
/// human reads it as reference; `--json` keeps it compact for a tool.
void _runSchema(ArgResults res) {
  final schema = SourceSchema.generate();
  if (res['json'] == true) {
    stdout.writeln(jsonEncode(schema));
    return;
  }
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(schema));
}

/// Prints diagnostics grouped by severity, errors first.
///
/// The non-JSON form is deliberately `path: severity: message` rather than a
/// table: it is what an editor's error parser and a human skim both handle, and
/// the paths are long enough that columns would wrap.
void _printDiagnostics(
  String file,
  List<SourceDiagnostic> diagnostics,
  bool jsonOut,
) {
  if (jsonOut) {
    stderr.writeln(
      jsonEncode({
        'source': file,
        'diagnostics': diagnostics.map((d) => d.toJson()).toList(),
      }),
    );
    return;
  }
  final errors = diagnostics.where((d) => d.isError).toList();
  final warnings = diagnostics.where((d) => !d.isError).toList();
  for (final d in [...errors, ...warnings]) {
    final where = d.path.isEmpty ? file : '$file:${d.path}';
    final label = d.isError ? 'error' : 'warning';
    stderr.writeln('$where: $label: ${d.message}');
    if (d.hint != null) stderr.writeln('    $where: hint: ${d.hint}');
  }
  stderr.writeln('${errors.length} error(s), ${warnings.length} warning(s).');
}

/// File name without directory or extension.
String _baseName(String path) {
  final name = path.split(Platform.pathSeparator).last.split('/').last;
  final dot = name.lastIndexOf('.');
  return dot <= 0 ? name : name.substring(0, dot);
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
        'planId': r.planId,
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
  stdout.writeln('  planId : ${r.planId}');
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
                'planId': i.planId,
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

SOURCE FORMAT COMMANDS (offline; DESIGN-014):
  create                          Scaffold a source document to start from
                                    --name=<plan> [--exercises=N] [--teams=N]
                                    [--stations=N] [--rounds=N] [--lang=<code>]
                                    [--bare] [--out=<file>]
  build <source.yaml>             Compile a source document to a .drill
                                    [--out=<file>] [--strict]
  decompile <file.drill>          Emit the source document for an archive
                                    [--out=<file>]  (stdout when omitted)
  analyze <source.yaml>           Check a source document without building
                                    [--strict]
  render <source.yaml|.drill>     Render the markdown brief
                                    [--audience=<a>] [--lang=<code>]
                                    [--exercise=N] [--out=<file>]
  schema                          Print the source format's JSON Schema

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
  RINGDRILL_FUNCTIONS_BASE_PATH  Function-call path prefix (default: /api)
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
        'planId': i.planId,
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
  stdout.writeln('  planId: ${i.planId}');
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
                'planId': i.planId,
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
