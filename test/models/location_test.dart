import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/models/location.dart';

void main() {
  test('Location round-trips unchanged with all fields', () {
    const location = Location(
      slug: 'lkp',
      label: 'Last known position',
      kind: LocationKind.lkp,
      place: 'Fjellheisen',
      position: LatLng(59.9, 10.7),
      note: 'Seen at 14:00',
    );
    final decoded = Location.fromJson(location.toJson());
    expect(decoded, location);
  });

  test('Location with only slug deserializes with defaults', () {
    final decoded = Location.fromJson({'slug': 'lkp'});
    expect(decoded.slug, 'lkp');
    expect(decoded.label, '');
    expect(decoded.kind, LocationKind.other);
    expect(decoded.place, '');
    expect(decoded.position, isNull);
    expect(decoded.note, isNull);
  });

  test('a known LocationKind value decodes unchanged', () {
    final decoded = Location.fromJson({'slug': 'ko', 'kind': 'commandPost'});
    expect(decoded.kind, LocationKind.commandPost);
  });

  test('an unknown LocationKind value decodes to other (forward-compat)', () {
    final decoded = Location.fromJson({
      'slug': 'future',
      'kind': 'someFutureKind',
    });
    expect(decoded.kind, LocationKind.other);
  });
}
