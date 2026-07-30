/// The façade the CLI and the MCP server call: source text in, `.drill` out.
///
/// Keeps command wiring free of the parse/build split, so `bin/ringdrill.dart`
/// reads as argument handling and output formatting rather than as compiler
/// internals.
///
/// Free of `package:flutter/*` (AGENTS.md rule 7).
library;

import 'package:ringdrill/data/drill_file.dart';
import 'package:ringdrill/data/source/plan_builder.dart';
import 'package:ringdrill/data/source/source_diagnostic.dart';
import 'package:ringdrill/data/source/source_parser.dart';
import 'package:ringdrill/models/plan.dart';

/// A successful compile: the plan, the archive, and anything worth saying about
/// the document that did not stop it.
class CompileResult {
  const CompileResult({
    required this.plan,
    required this.drillFile,
    required this.warnings,
  });

  final Plan plan;
  final DrillFile drillFile;
  final List<SourceDiagnostic> warnings;
}

/// Compiles source documents to `.drill` archives.
class SourceCompiler {
  const SourceCompiler._();

  /// Parses and builds [yamlText].
  ///
  /// [fileName] names the archive (without the extension) and so becomes its
  /// slug — normally the source file's basename. Throws
  /// [SourceFormatException] carrying every diagnostic when the document cannot
  /// be built.
  static CompileResult compile(
    String yamlText, {
    required String fileName,
    DateTime? now,
    String Function()? mintUuid,
  }) {
    final diagnostics = DiagnosticSink();
    final document = SourceParser.parse(yamlText, diagnostics: diagnostics);
    final builder = PlanBuilder(
      diagnostics: diagnostics,
      now: now,
      mintUuid: mintUuid,
    );
    final plan = builder.build(document);
    return CompileResult(
      plan: plan,
      drillFile: DrillFile.fromPlan(plan, fileName),
      warnings: diagnostics.items,
    );
  }

  /// Parses and builds without serializing — for `analyze`, and for callers that
  /// want the model rather than the archive.
  static ({Plan plan, List<SourceDiagnostic> diagnostics}) toPlan(
    String yamlText, {
    DateTime? now,
    String Function()? mintUuid,
  }) {
    final diagnostics = DiagnosticSink();
    final document = SourceParser.parse(yamlText, diagnostics: diagnostics);
    final plan = PlanBuilder(
      diagnostics: diagnostics,
      now: now,
      mintUuid: mintUuid,
    ).build(document);
    return (plan: plan, diagnostics: diagnostics.items);
  }
}
