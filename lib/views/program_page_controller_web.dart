import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:ringdrill/data/drill_file.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/program_view.dart';

class ProgramPageController extends ProgramPageControllerBase {
  @override
  Future<DrillFile?> open(
    BuildContext context,
    BoxConstraints constraints,
    AppLocalizations localizations,
  ) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      dialogTitle: localizations.openProgram,
      allowedExtensions: [DrillFile.drillExtension],
    );

    if (result == null) return null;

    final content = await result.files.first.xFile.readAsBytes();
    return DrillFile.fromBytes(
      basename(result.files.first.xFile.path),
      content,
    );
  }

  @override
  Future<bool> save(
    BuildContext context,
    BoxConstraints constraints,
    AppLocalizations localizations,
    DrillFile drillFile,
  ) async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: localizations.save,
      type: FileType.custom,
      fileName: drillFile.fileName,
      bytes: Uint8List.fromList(drillFile.content),
      allowedExtensions: [DrillFile.drillExtension],
    );

    return path == null;
  }
}
