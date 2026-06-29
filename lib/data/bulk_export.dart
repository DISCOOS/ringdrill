import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:ringdrill/data/drill_file.dart';
import 'package:ringdrill/models/program.dart';

/// Bundles every program into a single outer ZIP for migration export.
///
/// Each program is serialised as a `.drill` archive (ADR-0007) and stored
/// inside the outer ZIP. The outer ZIP is suitable for passing to share_plus
/// on native or triggering a browser `<a download>` on web.
Uint8List exportAllPrograms(List<Program> programs) {
  final outer = Archive();
  final seen = <String>{};

  for (final program in programs) {
    var slug = sanitizeSlug(program.name);
    if (slug.isEmpty) slug = program.uuid;

    var name = slug;
    var counter = 1;
    while (seen.contains(name)) {
      name = '$slug-$counter';
      counter++;
    }
    seen.add(name);

    final drillFile = DrillFile.fromProgram(program, name);
    final bytes = drillFile.content;
    outer.addFile(ArchiveFile(drillFile.fileName, bytes.length, bytes));
  }

  return Uint8List.fromList(ZipEncoder().encode(outer));
}

/// Returns the suggested filename for the outer ZIP, e.g.
/// `ringdrill-eksport-2026-06-29.zip`.
String bulkExportFileName(DateTime date) {
  final y = date.year.toString();
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return 'ringdrill-eksport-$y-$m-$d.zip';
}
