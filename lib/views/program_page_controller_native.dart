import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:ringdrill/data/drill_file.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/program_view.dart';
import 'package:share_plus/share_plus.dart';
import 'package:universal_io/io.dart';

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
      allowedExtensions: ['drill'],
    );

    if (result == null) return null;

    final file = File(result.files.first.xFile.path);
    return DrillFile.fromFile(file);
  }

  @override
  Future<bool> save(
    BuildContext context,
    BoxConstraints constraints,
    AppLocalizations localizations,
    DrillFile drillFile,
  ) async {
    final dirPath = await FilePicker.platform.getDirectoryPath(
      dialogTitle: localizations.selectAction,
    );

    if (dirPath == null) return false;

    // Write content to local file system
    final dir = Directory(dirPath);
    if (!dir.existsSync()) Directory(dirPath).createSync(recursive: true);
    File(
      path.join(dirPath, drillFile.fileName),
    ).writeAsBytesSync(drillFile.content);

    return true;
  }

  @override
  Future<bool> share(
    BuildContext context,
    BoxConstraints constraints,
    AppLocalizations localizations,
    DrillFile drillFile,
  ) async {
    // Create a temp folder for export.
    final String tempDirPath = path.join(
      (await getTemporaryDirectory()).path,
      'program_share',
    );
    if (!context.mounted) return false;

    final tempDir = Directory(tempDirPath);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    tempDir.createSync(recursive: true);

    final filePath = path.join(tempDirPath, drillFile.fileName);
    File(filePath).writeAsBytesSync(drillFile.content);

    final params = ShareParams(
      text: path.basenameWithoutExtension(drillFile.fileName),
      files: [XFile(filePath, mimeType: drillFile.mimeType)],
    );

    final result = await SharePlus.instance.share(params);
    if (!context.mounted) {
      return false;
    }

    return result.status == ShareResultStatus.success;
  }
}
