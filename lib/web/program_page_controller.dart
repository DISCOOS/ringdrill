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
  ProgramPageController()
    : super([
        ProgramPageAction.open,
        ProgramPageAction.import,
        ProgramPageAction.sendTo,
        ProgramPageAction.share,
        ProgramPageAction.feedback,
        if (WebEnv.isAndroid)
          // On Android 10+ export (save as) does not make that much sense.
          // Access to the file system is highly limited, in practice
          // only “scoped storage” is available to this application for
          // write operations, which is hard to find again. Most modern apps
          // use SEND actions (share) instead, allowing the user decide which
          // app on the mobile os that should receive it (could be Dropbox, SMS etc).
          ProgramPageAction.export,
      ]);

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
      basename(result.files.first.xFile.name),
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

  @override
  Future<bool> sendTo(
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

  @override
  Future<bool> share(
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
