/// Reducing a markdown field to a one-paragraph plain-text teaser.
///
/// The plan overview card shows three lines of a field when collapsed, measured
/// with a `TextPainter` — which cannot survive a markdown widget tree, so the
/// teaser has to be a plain string. The old helper split on blank lines and joined
/// the rest with spaces, which flattened a GFM pipe table into one line of pipe
/// soup on screen. A table is a block that has no readable one-line form, so the
/// answer is to *skip* it and tease the next block instead.
///
/// Free of `package:flutter/*` (AGENTS.md rule 7): `lib/utils/` is inside the CLI's
/// import closure.
library;

/// A markdown field reduced to a one-paragraph plain-text teaser.
///
/// [truncated] is true when there is more to the field than [text] — either a
/// block was skipped as un-teasable, or one follows the block returned. The
/// overview card uses it to decide whether a "Vis mer" toggle is needed at all.
typedef MarkdownTeaser = ({String text, bool truncated});

/// Reduces [md] to a plain-text teaser, or null when nothing in it reads as prose.
///
/// Null rather than an empty string, and null for a field holding only a table:
/// "there is nothing to tease here" and "there is nothing here" are different
/// facts, and the caller must not derive "the field is empty" from the first.
MarkdownTeaser? markdownTeaser(String? md) {
  if (md == null || md.trim().isEmpty) return null;

  final cleaned = _stripFences(md).replaceAll(_htmlComment, '');
  final blocks = cleaned
      .split(RegExp(r'\n\s*\n'))
      .map((b) => b.trim())
      .where((b) => b.isNotEmpty)
      .toList();
  if (blocks.isEmpty) return null;

  for (var i = 0; i < blocks.length; i++) {
    if (_isUnteasable(blocks[i])) continue;
    final text = _toPlainText(blocks[i]);
    if (text.isEmpty) continue;
    // Anything skipped before it, or anything at all after it, means the field
    // holds more than the teaser shows.
    final more = i > 0 || i < blocks.length - 1;
    return (text: text, truncated: more);
  }
  return null;
}

/// A fenced code block, dropped whole: its contents are not prose, and its fence
/// markers would otherwise leak into the teaser.
final _fence = RegExp(r'^\s*(```|~~~)', multiLine: true);
final _htmlComment = RegExp(r'<!--.*?-->', dotAll: true);

/// A pipe table: any line starting with `|`, or a delimiter row like `---|---`.
final _tableLine = RegExp(r'^\s*\|');
final _tableDelimiter = RegExp(r'^\s*:?-{2,}:?\s*\|');

/// `***`, `---`, `___` alone on a line.
final _horizontalRule = RegExp(r'^\s*([*_-])\s*(\1\s*){2,}$');

/// `![alt](src)` with nothing else in the block.
final _imageOnly = RegExp(r'^\s*!\[[^\]]*\]\([^)]*\)\s*$');

String _stripFences(String md) {
  if (!_fence.hasMatch(md)) return md;
  final out = <String>[];
  var inFence = false;
  for (final line in md.split('\n')) {
    if (_fence.hasMatch(line)) {
      inFence = !inFence;
      continue;
    }
    if (!inFence) out.add(line);
  }
  return out.join('\n');
}

/// Whether this block has no sensible one-line prose form.
///
/// A table is the case this exists for. A horizontal rule carries no text at all,
/// and an image-only block would tease as its alt text out of context.
bool _isUnteasable(String block) {
  final lines = block.split('\n');
  if (lines.any((l) => _tableLine.hasMatch(l) || _tableDelimiter.hasMatch(l))) {
    return true;
  }
  if (lines.every((l) => _horizontalRule.hasMatch(l))) return true;
  if (lines.every((l) => _imageOnly.hasMatch(l))) return true;
  return false;
}

/// Per-line block markers, stripped so a heading or list teases as its words.
final _lineMarkers = RegExp(r'^\s*(#{1,6}\s+|>\s?|[-*+]\s+|\d+[.)]\s+)');

/// Inline markers collapsed to the text they wrap.
final _inline = <RegExp, String>{
  RegExp(r'!\[([^\]]*)\]\([^)]*\)'): r'$1', // image → alt
  RegExp(r'\[([^\]]*)\]\([^)]*\)'): r'$1', // link → text
  RegExp(r'\*\*([^*]+)\*\*'): r'$1',
  RegExp(r'__([^_]+)__'): r'$1',
  RegExp(r'\*([^*]+)\*'): r'$1',
  RegExp(r'(?<!\w)_([^_]+)_(?!\w)'): r'$1',
  RegExp(r'`([^`]+)`'): r'$1',
  RegExp(r'~~([^~]+)~~'): r'$1',
};

String _toPlainText(String block) {
  var text = block
      .split('\n')
      .map((l) => l.replaceFirst(_lineMarkers, '').trim())
      .where((l) => l.isNotEmpty)
      .join(' ');
  for (final entry in _inline.entries) {
    text = text.replaceAllMapped(
      entry.key,
      (m) => entry.value.replaceAll(r'$1', m.group(1) ?? ''),
    );
  }
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}
