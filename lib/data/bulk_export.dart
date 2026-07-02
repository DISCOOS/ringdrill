import 'dart:typed_data';

import 'package:ringdrill/data/drill_library.dart';
import 'package:ringdrill/models/program.dart';

/// Bundles every program into a single outer ZIP for migration export.
///
/// Thin delegate: the encoder lives in [DrillLibrary.fromPrograms]
/// (ADR-0045) so encode and decode live together. Kept here so
/// `MigrationPage` and the migration banner do not need to change.
Uint8List exportAllPrograms(List<Program> programs) =>
    DrillLibrary.fromPrograms(programs);

/// Returns the suggested filename for the outer ZIP, e.g.
/// `ringdrill-eksport-2026-06-29.zip`.
String bulkExportFileName(DateTime date) {
  final y = date.year.toString();
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return 'ringdrill-eksport-$y-$m-$d.zip';
}
