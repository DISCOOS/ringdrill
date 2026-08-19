/// Whether [value] could be a phone number somebody would dial.
///
/// **Deliberately lenient, and not E.164.** The numbers that end up on a
/// roster are not all mobiles: a switchboard with an extension, a duty phone
/// written with its country code, a KO number spaced for reading. A strict
/// parser rejects most of those, and a coordinator who cannot save the number
/// they were given types it into the notes field instead, where nothing can
/// find it.
///
/// So this rejects only what cannot be dialled at all — letters, and strings
/// with too few digits to be a number — and accepts the punctuation people
/// actually write: spaces, hyphens, parentheses, a leading plus, the slash
/// used for a pair of numbers, and the comma that means "pause" on a keypad,
/// which is how an extension is dialled without words.
///
/// **Letters are the line**, which does mean "22 11 33 44 ext 4" is refused
/// while "22 11 33 44,4" is accepted. That is the cost of catching a hand
/// dragged across the keyboard, and the wording of the error says what to do
/// about it.
///
/// Six digits is the floor because Norwegian short numbers (five digits, like
/// 02800) sit just under it and international numbers well above; five would
/// admit a year typed by accident.
bool isDialablePhone(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return true; // Absent is not invalid: the field is optional.
  if (!RegExp(r'^[+()/,.\-\s\d]+$').hasMatch(trimmed)) return false;
  return RegExp(r'\d').allMatches(trimmed).length >= 6;
}
