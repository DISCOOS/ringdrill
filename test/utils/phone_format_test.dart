import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/utils/phone_format.dart';

/// What counts as a number somebody could dial.
///
/// The bar is deliberately low. A coordinator who cannot save the number they
/// were handed types it into the notes field instead, where nothing can find
/// it — so this rejects only what is not a number at all.
void main() {
  test('accepts the shapes people actually write', () {
    for (final value in [
      '+47 900 12 345',
      '90012345',
      '+4790012345',
      '(047) 900-12-345',
      '815 00 200',
      '22 11 33 44 / 22 11 33 45',
      '22 11 33 44,4',
    ]) {
      expect(isDialablePhone(value), isTrue, reason: value);
    }
  });

  test('rejects what cannot be dialled', () {
    // The reported case: a hand typed across the keyboard, saved, and sitting
    // on a roster looking answered until somebody needs it.
    expect(isDialablePhone('dssdfsdfsdf'), isFalse);
    expect(isDialablePhone('ring meg'), isFalse);
    // Letters are the line, so an extension has to be written with the comma
    // that a keypad understands rather than the word.
    expect(isDialablePhone('22 11 33 44 ext 4'), isFalse);
    expect(isDialablePhone('12345'), isFalse, reason: 'too few digits');
  });

  test('empty is not invalid, because the field is optional', () {
    expect(isDialablePhone(''), isTrue);
    expect(isDialablePhone('   '), isTrue);
  });
}
