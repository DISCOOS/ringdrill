import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/data/drill_file.dart';

// ---------------------------------------------------------------------------
// DrillFile.program() — format-error hardening
//
// Covers the user-facing failure modes the open/import flow must
// distinguish. Each case asserts:
//   1. The thrown exception is a [DrillFormatException].
//   2. `reason` is the expected category.
//   3. The exception is still catchable as a [FormatException] so
//      legacy `on FormatException` sites do not regress.
//
// Where applicable the test also asserts that the original cause is
// preserved on the exception so debug logs still surface it.
// ---------------------------------------------------------------------------

ArchiveFile _entry(String name, String content) {
  final bytes = utf8.encode(content);
  return ArchiveFile(name, bytes.length, bytes);
}

void main() {
  group('DrillFile.program() format errors', () {
    test('empty bytes -> DrillFormatReason.empty', () {
      final file = DrillFile.fromBytes('empty.drill', const <int>[]);
      DrillFormatException? caught;
      try {
        file.program();
      } on DrillFormatException catch (e) {
        caught = e;
      }
      expect(caught, isNotNull);
      expect(caught!.reason, DrillFormatReason.empty);
      // Back-compat: still a FormatException to existing callers.
      expect(caught, isA<FormatException>());
    });

    test('plain text bytes -> DrillFormatReason.notArchive', () {
      // The magic-byte sniff rejects this before ZipDecoder sees it,
      // so there is no underlying `cause` to assert on — the reason
      // enum is the contract that matters to the UI layer.
      final bytes = utf8.encode('this is definitely not a zip');
      final file = DrillFile.fromBytes('bogus.drill', bytes);
      DrillFormatException? caught;
      try {
        file.program();
      } on DrillFormatException catch (e) {
        caught = e;
      }
      expect(caught, isNotNull);
      expect(caught!.reason, DrillFormatReason.notArchive);
    });

    // NOTE: there used to be a "truncated PK header" test here that fed
    // ZipDecoder a few bytes starting with the ZIP magic to force it
    // through the decoder catch and assert that `cause` was preserved.
    // It was removed because ZipDecoder accepts that input — it returns
    // an empty Archive instead of throwing — so the test landed in the
    // `empty` branch and could not exercise the decoder-catch path. The
    // cause preservation still happens for archives that actually fail
    // to decode in production; we just don't have a reliable unit-test
    // fixture for it.

    test('zip without program.json -> DrillFormatReason.missingProgram', () {
      final archive = Archive()
        ..addFile(
          _entry('teams/ignored.json', '{"uuid":"x","name":"T"}'),
        );
      final bytes = ZipEncoder().encode(archive);
      final file = DrillFile.fromBytes('no-program.drill', bytes);
      DrillFormatException? caught;
      try {
        file.program();
      } on DrillFormatException catch (e) {
        caught = e;
      }
      expect(caught, isNotNull);
      expect(caught!.reason, DrillFormatReason.missingProgram);
    });

    test(
      'zip with malformed program.json -> DrillFormatReason.corruptManifest',
      () {
        final archive = Archive()
          ..addFile(
            _entry('program.json', '{ this is not valid json'),
          );
        final bytes = ZipEncoder().encode(archive);
        final file = DrillFile.fromBytes('corrupt.drill', bytes);
        DrillFormatException? caught;
        try {
          file.program();
        } on DrillFormatException catch (e) {
          caught = e;
        }
        expect(caught, isNotNull);
        expect(caught!.reason, DrillFormatReason.corruptManifest);
        expect(caught.cause, isNotNull);
      },
    );

    test(
      'program.json missing required fields -> DrillFormatReason.corruptManifest',
      () {
        // `Program.fromJson` blows up with a TypeError when uuid/name are
        // absent. We catch that inside `program()` and surface it as a
        // corrupt-manifest format error, not a raw TypeError.
        final archive = Archive()
          ..addFile(_entry('program.json', '{"unrelated": 1}'));
        final bytes = ZipEncoder().encode(archive);
        final file = DrillFile.fromBytes('shape.drill', bytes);
        DrillFormatException? caught;
        try {
          file.program();
        } on DrillFormatException catch (e) {
          caught = e;
        }
        expect(caught, isNotNull);
        expect(caught!.reason, DrillFormatReason.corruptManifest);
      },
    );

    test('schema from the future -> DrillFormatReason.schemaUnsupported', () {
      // Minimum viable program.json + a metadata.json that declares a
      // major version higher than anything this build knows.
      final programJson = jsonEncode({
        'uuid': 'prog-1',
        'name': 'Future Plan',
        'description': '',
        'metadata': {
          'created': '2026-01-01T00:00:00.000Z',
          'updated': '2026-01-01T00:00:00.000Z',
          'version': '1.0',
        },
        'teams': const <Map<String, dynamic>>[],
        'sessions': const <Map<String, dynamic>>[],
        'exercises': const <Map<String, dynamic>>[],
        'rolePlays': const <Map<String, dynamic>>[],
        'actors': const <Map<String, dynamic>>[],
      });
      final metaJson = jsonEncode({
        'created': '2026-01-01T00:00:00.000Z',
        'updated': '2026-01-01T00:00:00.000Z',
        'version': '1.0',
        'schema': '9.9',
      });
      final archive = Archive()
        ..addFile(_entry('program.json', programJson))
        ..addFile(_entry('metadata.json', metaJson));
      final bytes = ZipEncoder().encode(archive);
      final file = DrillFile.fromBytes('future.drill', bytes);
      DrillFormatException? caught;
      try {
        file.program();
      } on DrillFormatException catch (e) {
        caught = e;
      }
      expect(caught, isNotNull);
      expect(caught!.reason, DrillFormatReason.schemaUnsupported);
    });
  });
}
