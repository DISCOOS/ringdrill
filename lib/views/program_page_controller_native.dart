import 'dart:async';
import 'dart:math';

import 'package:external_path/external_path.dart';
import 'package:filesystem_picker/filesystem_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:ringdrill/data/drill_file.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/program_view.dart';
import 'package:universal_io/io.dart';

class ProgramPageController extends ProgramPageControllerBase {
  @override
  Future<DrillFile?> open(
    BuildContext context,
    BoxConstraints constraints,
    AppLocalizations localizations,
  ) async {
    String? filePath = await _pickFileOrDir(
      context,
      constraints,
      localizations.selectFile,
      FilesystemType.file,
    );
    if (filePath == null) return null;

    final file = File(filePath);
    return DrillFile.fromFile(file);
  }

  @override
  Future<bool> save(
    BuildContext context,
    BoxConstraints constraints,
    AppLocalizations localizations,
    DrillFile drillFile,
  ) async {
    String? dirPath = await _pickFileOrDir(
      context,
      constraints,
      localizations.selectDirectory,
      FilesystemType.folder,
    );
    if (!context.mounted || dirPath == null) return false;

    // Write content to local file system
    Directory(dirPath).createSync(recursive: true);
    File(
      path.join(dirPath, drillFile.fileName),
    ).writeAsBytesSync(drillFile.content);

    return true;
  }

  static Future<String?> _pickFileOrDir(
    BuildContext context,
    BoxConstraints constraints,
    String title,
    FilesystemType type,
  ) async {
    final localizations = AppLocalizations.of(context)!;
    final docsDirPath = await ExternalPath.getExternalStoragePublicDirectory(
      ExternalPath.DIRECTORY_DOCUMENTS,
    );
    final downloadsDirPath =
        await ExternalPath.getExternalStoragePublicDirectory(
          ExternalPath.DIRECTORY_DOWNLOAD,
        );

    final extDirs = Platform.isAndroid
        ? await getExternalStorageDirectories()
        : [];

    if (!context.mounted) return null;

    int i = 1;
    final result = await FilesystemPicker.openBottomSheet(
      context: context,
      title: title,
      fsType: type,
      showGoUp: true,
      constraints: constraints.copyWith(
        minHeight: 400,
        maxHeight: max(400, constraints.maxHeight * 0.6),
      ),
      pickText: localizations.select,
      rootName: localizations.storage,
      fileTileSelectMode: FileTileSelectMode.wholeTile,
      shortcuts: [
        FilesystemPickerShortcut(
          name: localizations.documents,
          path: Directory(docsDirPath),
          icon: Icons.folder,
          isSelectable: false,
        ),
        FilesystemPickerShortcut(
          name: localizations.downloads,
          path: Directory(downloadsDirPath),
          icon: Icons.folder,
          isSelectable: false,
        ),
        if (extDirs != null)
          ...extDirs.map(
            (dir) => FilesystemPickerShortcut(
              name:
                  '${localizations.sdCard} ${i++} '
                  '(${path.basenameWithoutExtension(dir.path)})',
              path: dir,
              icon: Icons.snippet_folder,
              isSelectable: false,
            ),
          ),
      ],
    );
    return result;
  }
}
