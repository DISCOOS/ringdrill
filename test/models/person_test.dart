import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/models/person.dart';

void main() {
  test('Person round-trips unchanged with all fields', () {
    const person = Person(
      slug: 'anne',
      name: 'Anne Glemsk',
      age: 74,
      gender: 'female',
      signalement: 'Blå jakke, grå bukse',
      homeSlug: 'home_anne',
      notes: 'Diabetiker',
    );
    final decoded = Person.fromJson(person.toJson());
    expect(decoded, person);
  });

  test('Person with only slug deserializes with defaults', () {
    final decoded = Person.fromJson({'slug': 'anne'});
    expect(decoded.slug, 'anne');
    expect(decoded.name, '');
    expect(decoded.age, isNull);
    expect(decoded.gender, isNull);
    expect(decoded.signalement, isNull);
    expect(decoded.homeSlug, isNull);
    expect(decoded.notes, isNull);
  });
}
