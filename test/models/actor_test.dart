import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/models/actor.dart';

void main() {
  test('Actor round-trips JSON with all fields', () {
    const actor = Actor(
      uuid: 'actor-1',
      realName: 'Kari Nordmann',
      phone: '+4791234567',
      notes: 'Comes from north side',
    );
    final json = actor.toJson();
    final decoded = Actor.fromJson(json);
    expect(decoded, actor);
  });

  test('Actor round-trips JSON with minimal fields', () {
    const actor = Actor(uuid: 'actor-2', realName: 'Ola Nordmann');
    final json = actor.toJson();
    final decoded = Actor.fromJson(json);
    expect(decoded, actor);
    expect(decoded.phone, isNull);
    expect(decoded.notes, isNull);
  });
}
