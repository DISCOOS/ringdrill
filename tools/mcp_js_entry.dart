// The source compiler as a JavaScript module — the ADR-0060 hosted backend.
//
// `dart compile js` this file and the result runs the whole pipeline in-process,
// with no `ringdrill` subprocess: which is what makes the hosted MCP server a
// function rather than a container. Crucially it is *this* Dart source, the same
// one the app and the CLI use, so the field table stays the single description of
// the format (ADR-0058). Cross-compiled, not rewritten.
//
// Regenerate with `make mcp-bundle`. The output is committed, because a Netlify
// build has no Dart SDK — the same reason `headless_labels.g.dart` and
// `brief_templates.g.dart` are committed.
//
// ## The interop surface is one function
//
// `globalThis.ringdrillInvoke(jsonRequest) -> Promise<jsonResponse>`, both plain
// JSON strings. One function with a JSON contract rather than a dozen typed
// bindings: the surface stays small, it mirrors the CLI's own `--json` shape, and
// adding an operation costs a `switch` arm here instead of another interop
// declaration on both sides.
//
// Free of `package:flutter/*` — necessarily, since dart2js cannot compile it
// (AGENTS.md rule 7 is what makes this file possible at all).
library;

import 'dart:convert';
import 'dart:js_interop';

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

/// The one exported entry point, assigned onto `globalThis` by [main].
///
/// Declared as an external setter rather than built with `setProperty`, so the
/// signature is checked at compile time on both sides of the boundary.
@JS('ringdrillInvoke')
external set _ringdrillInvoke(JSFunction value);

void main() {
  _ringdrillInvoke = ((JSString request) => _invokeJs(request.toDart)).toJS;
}

/// Bridges [_invoke] to a promise that resolves to a JavaScript string.
///
/// The `JSString` return type is load-bearing: `Future<String>.toJS` compiles
/// happily and produces a promise that resolves to `undefined`, because a Dart
/// `String` is not a JS value. The failure is silent on both sides — the call
/// succeeds and the caller gets nothing — so it is worth the extra hop to keep the
/// conversion explicit.
JSPromise<JSString> _invokeJs(String request) =>
    _invoke(request).then((json) => json.toJS).toJS;

/// Dispatches one request. Never throws across the interop boundary: a thrown
/// Dart error surfaces in JavaScript as an opaque object, so every failure comes
/// back as `{ok: false, error: …}` instead — the same shape the CLI's callers
/// already handle.
Future<String> _invoke(String request) async {
  try {
    final json = jsonDecode(request) as Map<String, dynamic>;
    final op = json['op'] as String?;
    return jsonEncode(switch (op) {
      'schema' => {'ok': true, 'schema': SourceSchema.generate()},
      'create' => _create(json),
      'analyze' => _analyze(json),
      'build' => _build(json),
      'render' => await _render(json),
      'decompile' => _decompile(json),
      _ => {'ok': false, 'error': 'unknown op "$op"'},
    });
  } catch (e) {
    return jsonEncode({'ok': false, 'error': '$e'});
  }
}

Map<String, dynamic> _create(Map<String, dynamic> json) => {
  'ok': true,
  'document': SourceScaffold.generate(
    name: json['name'] as String? ?? 'Untitled',
    exercises: (json['exercises'] as num?)?.toInt() ?? 1,
    teams: (json['teams'] as num?)?.toInt() ?? 4,
    stationsPerExercise: (json['stations'] as num?)?.toInt(),
    rounds: (json['rounds'] as num?)?.toInt() ?? 0,
    languageCode: json['lang'] as String? ?? 'en',
    withExample: json['bare'] != true,
  ),
};

Map<String, dynamic> _analyze(Map<String, dynamic> json) {
  final strict = json['strict'] == true;
  final List<SourceDiagnostic> items;
  final Plan? plan;
  try {
    final result = SourceCompiler.toPlan(json['document'] as String);
    items = SourceAnalyzer.review(result.plan, seed: result.diagnostics);
    plan = result.plan;
  } on SourceFormatException catch (e) {
    return _diagnosticsOnly(e.diagnostics);
  }
  final errors = items.where((d) => d.isError).length;
  final warnings = items.where((d) => d.isWarning).length;
  return {
    // A suggestion (ADR-0071) never makes a document not-ok, under strict or
    // otherwise: the rules that produce one are heuristics.
    'ok': errors == 0 && !(strict && warnings > 0),
    'errors': errors,
    'warnings': warnings,
    'suggestions': items.where((d) => d.isSuggestion).length,
    'name': plan.name,
    'exercises': plan.exercises.length,
    'diagnostics': items.map((d) => d.toJson()).toList(),
  };
}

Map<String, dynamic> _build(Map<String, dynamic> json) {
  final strict = json['strict'] == true;
  final CompileResult result;
  try {
    result = SourceCompiler.compile(
      json['document'] as String,
      fileName: json['fileName'] as String? ?? 'plan',
    );
  } on SourceFormatException catch (e) {
    return _diagnosticsOnly(e.diagnostics);
  }
  // `strict` asks the full question, reference checks included — otherwise it
  // refuses on compile warnings while ignoring the `{{var.typo}}` that renders
  // "‹missing variable›" to a reader.
  final reviewed = SourceAnalyzer.review(result.plan, seed: result.warnings);
  // An error will visibly fail in the brief, so the archive is known-broken
  // before it is written; `strict` adds warnings on top.
  final blocking = reviewed.where((d) => d.isError).length;
  final strictly = reviewed.where((d) => d.isBlockingUnderStrict).length;
  if (blocking > 0 || (strict && strictly > 0)) {
    return {
      ..._diagnosticsOnly(reviewed),
      'error': blocking > 0
          ? 'refused: $blocking error(s) that will not render'
          : 'refused: strict and warnings present',
    };
  }
  final plan = result.plan;
  return {
    'ok': true,
    'planId': plan.uuid,
    'name': plan.name,
    'exercises': plan.exercises.length,
    'stations': plan.exercises.fold<int>(0, (a, e) => a + e.stations.length),
    'teams': plan.teams.length,
    'rolePlays': plan.rolePlays.length,
    'contentHash': plan.contentHash,
    'size': result.drillFile.content.length,
    // Counts under `errors`/`warnings`, diagnostics under `diagnostics` — the
    // shape `_analyze` and `_diagnosticsOnly` already use. A caller must not
    // have to check the outcome to know a key's type.
    'errors': reviewed.where((d) => d.isError).length,
    'warnings': reviewed.where((d) => d.isWarning).length,
    'suggestions': reviewed.where((d) => d.isSuggestion).length,
    'diagnostics': reviewed.map((d) => d.toJson()).toList(),
    'drillBase64': base64Encode(result.drillFile.content),
  };
}

Future<Map<String, dynamic>> _render(Map<String, dynamic> json) async {
  final Plan plan;
  final document = json['document'] as String?;
  if (document != null) {
    try {
      plan = SourceCompiler.toPlan(document).plan;
    } on SourceFormatException catch (e) {
      return _diagnosticsOnly(e.diagnostics);
    }
  } else {
    // A built archive, for rendering something already published.
    plan = DrillFile.fromBytes(
      'plan.drill',
      base64Decode(json['drillBase64'] as String),
    ).plan();
  }

  final audienceName = json['audience'] as String? ?? 'participant';
  final audience = BriefAudience.values.where((a) => a.name == audienceName);
  if (audience.isEmpty) {
    return {'ok': false, 'error': 'unknown audience "$audienceName"'};
  }

  final lang = (json['lang'] as String?)?.trim();
  final labels = HeadlessBriefLabels(
    languageCode: (lang == null || lang.isEmpty)
        ? plan.metadata.languageCode
        : lang,
  );

  Exercise? exercise;
  final number = (json['exercise'] as num?)?.toInt();
  if (number != null) {
    if (number < 1 || number > plan.exercises.length) {
      return {
        'ok': false,
        'error':
            'invalid exercise $number; the plan has ${plan.exercises.length}',
      };
    }
    final ordered = plan.exercises.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    exercise = ordered[number - 1];
  }

  // Station scoping keeps each station's own index, so the surviving station still
  // renders with the code it has in the whole plan (ADR-0064).
  final stationNumber = (json['station'] as num?)?.toInt();
  if (stationNumber != null) {
    if (exercise == null) {
      return {
        'ok': false,
        'error':
            'station needs exercise: a station number is within an exercise',
      };
    }
    final ordered = exercise.stations.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    if (stationNumber < 1 || stationNumber > ordered.length) {
      return {
        'ok': false,
        'error':
            'invalid station $stationNumber; that exercise has ${ordered.length}',
      };
    }
    exercise = exercise.copyWith(stations: [ordered[stationNumber - 1]]);
  }

  final format = (json['format'] as String?)?.trim() ?? 'full';
  if (format != 'full' && format != 'summary') {
    return {'ok': false, 'error': 'unknown format "$format"'};
  }

  final markdown = format == 'summary'
      ? renderBriefSummary(
          plan: plan,
          audience: audience.first,
          exercise: exercise,
        )
      : await BriefRenderer().render(
          plan: plan,
          exercise: exercise,
          audience: audience.first,
          l10n: labels,
        );
  return {
    'ok': true,
    'audience': audience.first.name,
    'lang': labels.localeName,
    if (exercise != null) 'exercise': exercise.name,
    'format': format,
    'bytes': markdown.length,
    'markdown': markdown,
  };
}

Map<String, dynamic> _decompile(Map<String, dynamic> json) {
  final notes = <MigrationNote>[];
  final Plan plan;
  try {
    plan = DrillFile.fromBytes(
      'plan.drill',
      base64Decode(json['drillBase64'] as String),
    ).plan(migrationNotes: notes);
  } on DrillFormatException catch (e) {
    return {'ok': false, 'error': e.message, 'reason': e.reason.name};
  }
  final result = PlanDecompiler.decompile(
    plan,
    header: json['header'] as String?,
  );
  return {
    'ok': true,
    'planId': plan.uuid,
    'name': plan.name,
    'exercises': result.exercises.length,
    'teams': result.teams.length,
    'contentHash': plan.computeContentHash(),
    'migrations': notes.map((n) => n.toJson()).toList(),
    'document': result.yaml,
  };
}

Map<String, dynamic> _diagnosticsOnly(List<SourceDiagnostic> diagnostics) {
  final errors = diagnostics.where((d) => d.isError).length;
  return {
    'ok': false,
    'errors': errors,
    'warnings': diagnostics.where((d) => d.isWarning).length,
    'suggestions': diagnostics.where((d) => d.isSuggestion).length,
    'diagnostics': diagnostics.map((d) => d.toJson()).toList(),
  };
}
