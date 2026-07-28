import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/data/drill_file.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/staff.dart';

/// DESIGN-011's wire half: `Staff` round-trips through a `.drill`, the folder is
/// `staff/`, the old `actors/` is still readable, and the PII never reaches a
/// published projection.
///
/// The publish assertion is the one that earns its keep. `Plan.toPublishJson` is a
/// **denylist** — it starts from `toJson()` and removes what must not ship — so the
/// rename had to move the denylist entry in the same commit as the field. Had it
/// not, publishing would have started including real names and phone numbers with
/// no error, no token, and nothing failing. A denylist guarding PII needs a test
/// that fails when the name drifts.
const _planUuid = 'plan-staff-wire';

Staff _staff() => const Staff(
  uuid: 'staff-1',
  realName: 'Kari Nordmann',
  phone: '+4799999999',
  notes: 'Keep in character',
  roles: {StaffRole.director, StaffRole.instructor},
);

Plan _plan({List<Staff>? staff}) => Plan(
  uuid: _planUuid,
  name: 'Staff Wire Plan',
  description: '',
  metadata: PlanMetadata(
    created: DateTime.utc(2026, 1, 1),
    updated: DateTime.utc(2026, 1, 1),
    version: '1.1',
  ),
  exercises: const [],
  teams: const [],
  sessions: const [],
  rolePlays: const [
    RolePlay(
      uuid: 'rp-1',
      index: 0,
      exerciseUuid: 'ex-1',
      stationIndex: 0,
      name: 'Hilde',
      staffUuid: 'staff-1',
    ),
  ],
  staff: staff ?? [_staff()],
);

void main() {
  group('the model', () {
    test('roles round-trip through JSON', () {
      final decoded = Staff.fromJson(_staff().toJson());

      expect(decoded.roles, {StaffRole.director, StaffRole.instructor});
      expect(decoded.realName, 'Kari Nordmann');
    });

    // `roles` is additive with a default, so a record written before DESIGN-011
    // must still read back rather than throwing on the absent key.
    test('a record with no roles key reads as an empty set', () {
      final decoded = Staff.fromJson(const {
        'uuid': 'staff-legacy',
        'realName': 'Ola Nordmann',
      });

      expect(decoded.roles, isEmpty);
      expect(decoded.uuid, 'staff-legacy');
    });

    test('markør is not a stored role', () {
      expect(
        StaffRole.values.map((r) => r.name),
        isNot(contains('markor')),
        reason: 'a markør is derived from casting, never stored (DESIGN-011)',
      );
      expect(
        StaffRole.values.map((r) => r.name),
        isNot(contains('participant')),
        reason: 'participants are a Team count, not staff',
      );
    });
  });

  group('the archive', () {
    test('writes staff/ and reads it back, roles included', () async {
      final decoded = DrillFile.fromPlan(_plan(), 'test').plan();

      expect(decoded.staff, hasLength(1));
      expect(decoded.staff.single.uuid, 'staff-1');
      expect(decoded.staff.single.realName, 'Kari Nordmann');
      expect(decoded.staff.single.phone, '+4799999999');
      // notes lives in a sidecar markdown file, not the JSON.
      expect(decoded.staff.single.notes, 'Keep in character');
      expect(decoded.staff.single.roles, {
        StaffRole.director,
        StaffRole.instructor,
      });
      // The casting link travels under its new name.
      expect(decoded.rolePlays.single.staffUuid, 'staff-1');
    });

    test('the folder is named staff/, not actors/', () {
      final names = _entryNames(DrillFile.fromPlan(_plan(), 'test').content);

      expect(names.any((n) => n.startsWith('staff/')), isTrue);
      expect(
        names.any((n) => n.startsWith('actors/')),
        isFalse,
        reason: 'DESIGN-011 renames the folder; nothing should still write it',
      );
    });

    // A .drill exported before the rename is still on someone's disk, and these
    // files are shared peer-to-peer by design (ADR-0018), so import keeps
    // accepting the old folder even though nothing writes it.
    test('still reads a legacy actors/ archive', () {
      final original = DrillFile.fromPlan(_plan(), 'test');
      final decoded = DrillFile(
        schema: original.schema,
        mimeType: original.mimeType,
        fileName: 'legacy.drill',
        content: _renameFolder(original.content, from: 'staff/', to: 'actors/'),
      ).plan();

      expect(decoded.staff, hasLength(1));
      expect(decoded.staff.single.realName, 'Kari Nordmann');
      expect(decoded.staff.single.notes, 'Keep in character');
    });
  });

  // Where the PII actually is, which is what makes the server-side strip
  // sufficient. `program.json` clears staff before serializing, so the only place
  // a real name or phone appears is the staff/ folder — the one drills-upload
  // removes. If PII ever leaked into program.json, stripping the folder would
  // still publish it, and nothing in the upload path would notice.
  group('the PII boundary', () {
    test('program.json carries no staff at all', () {
      final entries = _entryContents(
        DrillFile.fromPlan(_plan(), 'test').content,
      );
      final program =
          jsonDecode(entries['program.json']!) as Map<String, dynamic>;

      expect(program['staff'], isEmpty);
      expect(program.toString(), isNot(contains('Kari Nordmann')));
      expect(program.toString(), isNot(contains('+4799999999')));
    });

    test('PII appears only under staff/', () {
      final entries = _entryContents(
        DrillFile.fromPlan(_plan(), 'test').content,
      );

      final leaking = entries.entries
          .where((e) => !e.key.startsWith('staff/'))
          .where(
            (e) =>
                e.value.contains('Kari Nordmann') ||
                e.value.contains('+4799999999'),
          )
          .map((e) => e.key)
          .toList();

      expect(
        leaking,
        isEmpty,
        reason:
            'the server strips staff/ and nothing else, so PII outside it is '
            'published',
      );
    });

    test('the content hash ignores staff', () {
      final withStaff = _plan().computeContentHash();
      final without = _plan(staff: const []).computeContentHash();

      expect(
        withStaff,
        without,
        reason:
            'staff are excluded from the hash, so adding one is not a change',
      );
    });
  });
}

/// Entry names inside a .drill archive.
List<String> _entryNames(List<int> content) => ZipDecoder()
    .decodeBytes(content)
    .files
    .where((f) => f.isFile)
    .map((f) => f.name)
    .toList();

/// Rebuilds an archive with one folder prefix renamed — the cheapest way to get a
/// pre-DESIGN-011 archive without checking a binary fixture into the repo.
List<int> _renameFolder(
  List<int> content, {
  required String from,
  required String to,
}) {
  final archive = ZipDecoder().decodeBytes(content);
  final out = Archive();
  for (final f in archive.files.where((f) => f.isFile)) {
    final bytes = f.content as List<int>;
    final name = f.name.startsWith(from)
        ? '$to${f.name.substring(from.length)}'
        : f.name;
    out.addFile(ArchiveFile(name, bytes.length, bytes));
  }
  return ZipEncoder().encode(out);
}

/// Entry name -> decoded text for every file in a .drill archive.
Map<String, String> _entryContents(List<int> content) => {
  for (final f
      in ZipDecoder().decodeBytes(content).files.where((f) => f.isFile))
    f.name: utf8.decode(f.content as List<int>),
};
