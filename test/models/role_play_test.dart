import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/models/role_play.dart';

void main() {
  test('RolePlay round-trips JSON with all fields populated', () {
    const rp = RolePlay(
      uuid: 'rp-1',
      index: 0,
      exerciseUuid: 'ex-1',
      name: 'Anna Hansen',
      age: 67,
      signalement: 'Blå jakke, rød lue',
      background: 'Erfaren turgåer',
      behavior: 'Forvirret, underavkjølt',
      stationIndex: 2,
      actorUuid: 'actor-1',
    );
    final json = rp.toJson();
    final decoded = RolePlay.fromJson(json);
    expect(decoded, rp);
  });

  test('RolePlay round-trips JSON with minimal fields only', () {
    const rp = RolePlay(
      uuid: 'rp-2',
      index: 1,
      exerciseUuid: 'ex-1',
      name: 'Minimal role',
    );
    final json = rp.toJson();
    final decoded = RolePlay.fromJson(json);
    expect(decoded, rp);
    expect(decoded.age, isNull);
    expect(decoded.actorUuid, isNull);
    expect(decoded.position, isNull);
  });

  test('RolePlay round-trips JSON with position', () {
    const rp = RolePlay(
      uuid: 'rp-3',
      index: 0,
      exerciseUuid: 'ex-2',
      name: 'With position',
      position: LatLng(59.911491, 10.757933),
    );
    final json = rp.toJson();
    final decoded = RolePlay.fromJson(json);
    expect(decoded.position?.latitude, closeTo(59.911491, 0.000001));
    expect(decoded.position?.longitude, closeTo(10.757933, 0.000001));
  });
}
