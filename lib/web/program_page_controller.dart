import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path/path.dart';
import 'package:ringdrill/data/drill_client.dart';
import 'package:ringdrill/data/drill_file.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/program_view.dart';
import 'package:ringdrill/web/web_env.dart';
import 'package:share_plus/share_plus.dart';

class ProgramPageController extends ProgramPageControllerBase {
  ProgramPageController();

  static bool get canSaveDrillFile => WebEnv.isAndroid;

  static Future<DrillFile?> pickOpenFile(
    BuildContext context,
    BoxConstraints constraints,
    AppLocalizations localizations,
  ) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      dialogTitle: localizations.openProgram,
      allowedExtensions: [DrillFile.drillExtension],
    );

    if (result == null) return null;

    final content = await result.files.first.xFile.readAsBytes();
    return DrillFile.fromBytes(
      basename(result.files.first.xFile.name),
      content,
    );
  }

  static Future<bool> saveDrillFile(
    BuildContext context,
    BoxConstraints constraints,
    AppLocalizations localizations,
    DrillFile drillFile,
  ) async {
    final path = await FilePicker.saveFile(
      dialogTitle: localizations.save,
      type: FileType.custom,
      fileName: drillFile.fileName,
      bytes: Uint8List.fromList(drillFile.content),
      allowedExtensions: [DrillFile.drillExtension],
    );

    return path == null;
  }

  static Future<bool> sendDrillFileTo(
    BuildContext context,
    BoxConstraints constraints,
    AppLocalizations localizations,
    DrillFile drillFile,
  ) async {
    final xf = XFile.fromData(
      Uint8List.fromList(drillFile.content),
      name: drillFile.fileName,
      mimeType: DrillFile.drillMimeType,
    );

    final params = ShareParams(
      text: path.basenameWithoutExtension(drillFile.fileName),
      files: [xf],
    );

    final result = await SharePlus.instance.share(params);
    if (!context.mounted) {
      return false;
    }

    return result.status == ShareResultStatus.success;
  }

  static Future<bool> shareDrillFile(
    BuildContext context,
    BoxConstraints constraints,
    AppLocalizations localizations,
    DrillFile drillFile,
  ) async {
    // Empty url use same-origin in web builds
    final client = DrillClient(baseUrl: '');

    final result = await client.upload(drillFile);

    // TODO: Store upload metadata for later use
    debugPrint(
      {
        "slug": result.slug,
        "etag": result.etag,
        "version": result.version,
        "versionedUrl": result.versionedUrl,
      }.toString(),
    );

    return true;
  }
}
