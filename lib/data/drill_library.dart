import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:ringdrill/data/drill_file.dart';
import 'package:ringdrill/models/program.dart';

/// How a byte buffer is classified before import.
///
/// `single` = top-level `program.json` present (a `.drill`, ADR-0007).
/// `library` = one or more top-level `*.drill` entries and no top-level
/// `program.json` (a drill library, ADR-0045). `invalid` otherwise.
enum DrillArchiveKind { single, library, invalid }

/// Why a drill-library bundle could not be parsed at the container level.
///
/// Per-entry parse failures are NOT represented here — those are handled
/// by skipping the entry during install (see [ProgramService.installBundle]
/// in `lib/services/program_service.dart`).
enum DrillLibraryReason {
  /// Bytes are empty, or the file does not exist on disk by the time we
  /// try to read it.
  empty,

  /// Bytes are not a valid ZIP container at all.
  notArchive,

  /// Valid ZIP, but no top-level `*.drill` entries (and no top-level
  /// `program.json` either, otherwise this would be a single `.drill`).
  noDrillEntries,
}

/// Thrown by [DrillLibrary.entries] when a bundle cannot be parsed for
/// reasons that are user-visible rather than a programming error.
///
/// Mirrors [DrillFormatException]: implements [FormatException] for
/// backwards compatibility, but adds a typed [reason] so the import path
/// can pick a useful message instead of a generic failure snackbar.
class DrillLibraryException implements FormatException {
  DrillLibraryException(this.reason, this.message, {this.cause});

  /// What category of container-level problem this is.
  final DrillLibraryReason reason;

  /// Human-readable, English diagnostic. Used in logs and as a fallback;
  /// the UI maps [reason] to a localized message.
  @override
  final String message;

  /// Original exception that triggered this wrap (ZIP decode error, …).
  /// Never logged to Sentry.
  final Object? cause;

  @override
  dynamic get source => null;

  @override
  int get offset => -1;

  @override
  String toString() => cause == null
      ? 'DrillLibraryException(${reason.name}): $message'
      : 'DrillLibraryException(${reason.name}): $message (cause: $cause)';
}

/// A drill library: a ZIP of `.drill` entries, one per program (ADR-0045).
///
/// A thin container — it carries no schema of its own, each inner `.drill`
/// carries its own schema per ADR-0007. Detection is content-based, so the
/// file extension does not matter for import.
class DrillLibrary {
  /// Classify [content] without fully parsing it. Cheap magic-byte + top-
  /// level entry-name inspection. Nested paths are ignored when deciding —
  /// only top-level entry names matter, matching what [fromPrograms] writes.
  static DrillArchiveKind sniff(List<int> content) {
    if (content.length < 2 || content[0] != 0x50 || content[1] != 0x4B) {
      return DrillArchiveKind.invalid;
    }

    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(content);
    } catch (_) {
      return DrillArchiveKind.invalid;
    }
    if (archive.files.isEmpty) return DrillArchiveKind.invalid;

    var hasTopLevelProgramJson = false;
    var hasTopLevelDrillEntry = false;
    for (final file in archive.files) {
      if (!file.isFile || file.name.contains('/')) continue;
      if (file.name == 'program.json') hasTopLevelProgramJson = true;
      if (file.name.endsWith('.${DrillFile.drillExtension}')) {
        hasTopLevelDrillEntry = true;
      }
    }

    if (hasTopLevelProgramJson) return DrillArchiveKind.single;
    if (hasTopLevelDrillEntry) return DrillArchiveKind.library;
    return DrillArchiveKind.invalid;
  }

  /// Decode a bundle into one [DrillFile] per inner `.drill`. Throws
  /// [DrillLibraryException] for container-level problems. Does NOT parse
  /// the inner programs — callers use [DrillFile.program] per entry so a
  /// single bad entry can be skipped instead of sinking the whole import.
  static List<DrillFile> entries(List<int> content, {String? sourceName}) {
    final label = sourceName == null ? '' : ' ($sourceName)';

    if (content.isEmpty) {
      throw DrillLibraryException(
        DrillLibraryReason.empty,
        'Invalid drill library$label: file is empty.',
      );
    }

    // Same cheap magic-byte guard as DrillFile.program(): ZipDecoder is
    // lenient enough to return a zero-entry Archive for ASCII garbage
    // instead of throwing.
    if (content.length < 2 || content[0] != 0x50 || content[1] != 0x4B) {
      throw DrillLibraryException(
        DrillLibraryReason.notArchive,
        'Invalid drill library$label: bytes are not a ZIP container '
        '(missing PK signature).',
      );
    }

    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(content);
    } catch (e) {
      throw DrillLibraryException(
        DrillLibraryReason.notArchive,
        'Invalid drill library$label: bytes are not a valid ZIP container.',
        cause: e,
      );
    }

    if (archive.files.isEmpty) {
      throw DrillLibraryException(
        DrillLibraryReason.empty,
        'Invalid drill library$label: ZIP container has no entries.',
      );
    }

    final drillEntries = archive.files.where(
      (file) =>
          file.isFile &&
          !file.name.contains('/') &&
          file.name.endsWith('.${DrillFile.drillExtension}'),
    );
    if (drillEntries.isEmpty) {
      throw DrillLibraryException(
        DrillLibraryReason.noDrillEntries,
        'Invalid drill library$label: no top-level '
        '.${DrillFile.drillExtension} entries found.',
      );
    }

    return drillEntries
        .map((file) => DrillFile.fromBytes(file.name, file.content as List<int>))
        .toList();
  }

  /// Encode a library: one `.drill` per program inside an outer ZIP, slug
  /// collisions disambiguated with a counter. This is the mechanism
  /// `bulk_export.exportAllPrograms` uses today.
  static Uint8List fromPrograms(List<Program> programs) {
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
}
