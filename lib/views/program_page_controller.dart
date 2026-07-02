import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:ringdrill/data/drill_client.dart';
import 'package:ringdrill/data/drill_file.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/utils/app_config.dart';
import 'package:ringdrill/views/program_view.dart';
import 'package:share_plus/share_plus.dart';
import 'package:universal_io/io.dart';

const String baseUrl = 'https://ringdrill.app';

class ProgramPageController extends ProgramPageControllerBase {
  ProgramPageController({
    required super.stationListController,
    required super.rolePlaysController,
    required super.teamsPageController,
  });

  // Direct-to-disk export via FilePicker.getDirectoryPath + dart:io. Disabled
  // on Android because Storage Access Framework URIs returned there can't be
  // written to with File.writeAsBytesSync — Android users go through
  // [canSendDrillFile] (share intent) instead.
  static bool get canSaveDrillFile => !Platform.isAndroid;

  // OS-level share / "send to another app" — always available on native
  // platforms (Android intents, iOS share sheet, mac share menu, share_plus
  // fallbacks on Windows/Linux).
  static bool get canSendDrillFile => true;

  static Future<DrillFile?> pickOpenFile(
    BuildContext context,
    BoxConstraints constraints,
    AppLocalizations localizations,
  ) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      dialogTitle: localizations.openProgram,
      allowedExtensions: [DrillFile.drillExtension, 'zip'],
    );

    if (result == null) return null;

    final file = File(result.files.first.xFile.path);
    return DrillFile.fromFile(file);
  }

  static Future<bool> saveDrillFile(
    BuildContext context,
    BoxConstraints constraints,
    AppLocalizations localizations,
    DrillFile drillFile,
  ) async {
    final dirPath = await FilePicker.getDirectoryPath(
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

  static Future<bool> sendDrillFileTo(
    BuildContext context,
    BoxConstraints constraints,
    AppLocalizations localizations,
    DrillFile drillFile,
  ) async {
    // Create a temp folder for export.
    final String tempDirPath = path.join(
      (await getTemporaryDirectory()).path,
      'program_send_to',
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

  static Future<bool> shareDrillFile(
    BuildContext context,
    BoxConstraints constraints,
    AppLocalizations localizations,
    DrillFile drillFile,
  ) async {
    final client = DrillClient(
      baseUrl: baseUrl,
      functionsBasePath: AppConfig.functionsBasePathFor(baseUrl),
      deepLinkBasePath: AppConfig.deepLinkBasePathFor(baseUrl),
    );

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
