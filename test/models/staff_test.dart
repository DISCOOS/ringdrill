import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/models/staff.dart';

void main() {
  test(
    'Staff round-trips JSON for structural fields; notes excluded from JSON',
    () {
      // notes is @JsonKey(includeFromJson: false, includeToJson: false) per
      // ADR-0022 — it lives in actors/<uuid>/notes.md in the drill archive and
      // in a separate SharedPreferences key in local storage.
      const actor = Staff(
        uuid: 'actor-1',
        realName: 'Kari Nordmann',
        phone: '+4791234567',
        notes: 'Comes from north side',
      );
      final json = actor.toJson();
      expect(json.containsKey('notes'), isFalse);
      final decoded = Staff.fromJson(json);
      expect(decoded.uuid, actor.uuid);
      expect(decoded.realName, actor.realName);
      expect(decoded.phone, actor.phone);
      expect(decoded.notes, isNull); // notes is not in JSON
    },
  );

  test('Staff round-trips JSON with minimal fields', () {
    const actor = Staff(uuid: 'actor-2', realName: 'Ola Nordmann');
    final json = actor.toJson();
    final decoded = Staff.fromJson(json);
    expect(decoded, actor);
    expect(decoded.phone, isNull);
    expect(decoded.notes, isNull);
  });
}
