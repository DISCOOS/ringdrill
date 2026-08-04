/// Diagnostics shared by the source-format commands.
///
/// `build` fails on errors and prints warnings; `analyze` prints both and exits
/// non-zero only on errors. One type for both so a message written once reads
/// the same wherever it surfaces, and `--json` output has one shape.
///
/// Free of `package:flutter/*` (AGENTS.md rule 7).
library;

enum DiagnosticSeverity {
  /// The document cannot be built as written.
  error,

  /// Buildable, but probably not what the author meant.
  warning,

  /// Correct as written, but a shortcut past something the format models
  /// (ADR-0071) — a coordinate typed into prose, a talegruppe repeated in eleven
  /// fields, a role play that invents the person it portrays.
  ///
  /// Its own level rather than a warning because `build --strict` refuses a
  /// document with warnings, and every rule that produces one of these is a
  /// heuristic. A heuristic that can fail a build is a heuristic someone turns
  /// off, so a suggestion never blocks and never changes an exit code. It is
  /// also why [isError] is not the negation of "warning" anywhere: see
  /// [isWarning].
  suggestion,
}

/// One finding about a source document.
class SourceDiagnostic {
  const SourceDiagnostic({
    required this.severity,
    required this.path,
    required this.message,
    this.hint,
  });

  SourceDiagnostic.error(String path, String message, {String? hint})
    : this(
        severity: DiagnosticSeverity.error,
        path: path,
        message: message,
        hint: hint,
      );

  SourceDiagnostic.warning(String path, String message, {String? hint})
    : this(
        severity: DiagnosticSeverity.warning,
        path: path,
        message: message,
        hint: hint,
      );

  SourceDiagnostic.suggestion(String path, String message, {String? hint})
    : this(
        severity: DiagnosticSeverity.suggestion,
        path: path,
        message: message,
        hint: hint,
      );

  final DiagnosticSeverity severity;

  /// Where in the document, as a dotted path with list indices —
  /// `exercises[1].stations[4].situation`. Not a line number: the parse is
  /// normalized before validation, and a path survives reformatting.
  final String path;

  final String message;

  /// What to do about it, when that is not obvious from [message].
  final String? hint;

  bool get isError => severity == DiagnosticSeverity.error;

  /// True only for [DiagnosticSeverity.warning].
  ///
  /// Exists because `!isError` used to mean "warning" in six places, and adding
  /// [DiagnosticSeverity.suggestion] silently made every one of them wrong — most
  /// damagingly `build --strict`, which would have started refusing a document over
  /// a naming suggestion. Ask for what you mean.
  bool get isWarning => severity == DiagnosticSeverity.warning;

  /// True only for [DiagnosticSeverity.suggestion]. Never blocks a build.
  bool get isSuggestion => severity == DiagnosticSeverity.suggestion;

  /// Whether this is something `--strict` may refuse a build over — an error or a
  /// warning, never a suggestion.
  bool get isBlockingUnderStrict => !isSuggestion;

  Map<String, dynamic> toJson() => {
    'severity': severity.name,
    'path': path,
    'message': message,
    if (hint != null) 'hint': hint,
  };

  @override
  String toString() =>
      '${severity.name}: $path: $message${hint == null ? '' : ' — $hint'}';
}

/// Thrown when a document cannot be built. Carries every diagnostic found, not
/// just the first, so one run tells an author (or an agent) everything to fix.
class SourceFormatException implements Exception {
  SourceFormatException(this.diagnostics);

  final List<SourceDiagnostic> diagnostics;

  Iterable<SourceDiagnostic> get errors => diagnostics.where((d) => d.isError);

  @override
  String toString() =>
      'SourceFormatException:\n${diagnostics.map((d) => '  $d').join('\n')}';
}

/// Collects diagnostics while walking a document.
class DiagnosticSink {
  final List<SourceDiagnostic> _items = [];

  List<SourceDiagnostic> get items => List.unmodifiable(_items);

  bool get hasErrors => _items.any((d) => d.isError);

  void error(String path, String message, {String? hint}) =>
      _items.add(SourceDiagnostic.error(path, message, hint: hint));

  void warn(String path, String message, {String? hint}) =>
      _items.add(SourceDiagnostic.warning(path, message, hint: hint));

  void suggest(String path, String message, {String? hint}) =>
      _items.add(SourceDiagnostic.suggestion(path, message, hint: hint));

  void addAll(Iterable<SourceDiagnostic> other) => _items.addAll(other);

  /// Throws if anything is an error; otherwise returns the warnings.
  List<SourceDiagnostic> throwIfErrors() {
    if (hasErrors) throw SourceFormatException(items);
    return items;
  }
}
