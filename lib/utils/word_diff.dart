/// Word-level diff between two strings, used to render a changed field as
/// one merged line (new text with removed words struck through, added words
/// highlighted) instead of two separate before/after strings.
///
/// Pure Dart — no Flutter import — so it stays importable from the CLI
/// (bin/ringdrill.dart) and is unit-testable without a widget test harness.
library;

/// The kind of edit a [WordDiffSegment] represents.
enum WordDiffOp {
  /// The words are identical on both sides.
  equal,

  /// Words present in the new text that were not in the old text.
  insert,

  /// Words present in the old text that are not in the new text.
  delete,

  /// A deleted run immediately paired with an inserted run — rendered as a
  /// single "this was replaced" unit rather than independent insert/delete,
  /// e.g. "30" replaced by "31".
  replace,
}

/// One run of the diff. [oldText] is set for [WordDiffOp.delete],
/// [WordDiffOp.replace] and [WordDiffOp.equal]; [newText] is set for
/// [WordDiffOp.insert], [WordDiffOp.replace] and [WordDiffOp.equal].
class WordDiffSegment {
  const WordDiffSegment(this.op, {this.oldText, this.newText});

  final WordDiffOp op;
  final String? oldText;
  final String? newText;

  @override
  bool operator ==(Object other) =>
      other is WordDiffSegment &&
      other.op == op &&
      other.oldText == oldText &&
      other.newText == newText;

  @override
  int get hashCode => Object.hash(op, oldText, newText);

  @override
  String toString() => 'WordDiffSegment($op, old: $oldText, new: $newText)';
}

/// Word-level diff of [oldText] against [newText].
///
/// Splits both strings on whitespace (runs of whitespace collapse to a
/// single space on rejoin — exact spacing/newlines are not preserved) and
/// computes the longest common subsequence of words, producing an ordered
/// list of [WordDiffOp.equal]/[WordDiffOp.insert]/[WordDiffOp.delete] runs.
/// A delete run immediately adjacent to an insert run (in either order) is
/// then coalesced into a single [WordDiffOp.replace] — this is what lets
/// the view render "30" → "31" as one "changed" unit instead of unrelated
/// red/green spans.
List<WordDiffSegment> diffWords(String oldText, String newText) {
  final oldWords = _tokenize(oldText);
  final newWords = _tokenize(newText);
  final raw = _lcsDiff(oldWords, newWords);
  return _coalesceReplacements(raw);
}

List<String> _tokenize(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return const [];
  return trimmed.split(RegExp(r'\s+'));
}

/// Classic LCS via dynamic programming, then backtrack to produce a
/// word-by-word equal/insert/delete sequence. O(n*m) time and space, which
/// is fine here — these are short UI strings, not documents.
List<WordDiffSegment> _lcsDiff(List<String> oldWords, List<String> newWords) {
  final m = oldWords.length;
  final n = newWords.length;
  final lengths = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));
  for (var i = m - 1; i >= 0; i--) {
    for (var j = n - 1; j >= 0; j--) {
      lengths[i][j] = oldWords[i] == newWords[j]
          ? lengths[i + 1][j + 1] + 1
          : (lengths[i + 1][j] > lengths[i][j + 1]
                ? lengths[i + 1][j]
                : lengths[i][j + 1]);
    }
  }

  final segments = <WordDiffSegment>[];
  var i = 0;
  var j = 0;
  while (i < m && j < n) {
    if (oldWords[i] == newWords[j]) {
      segments.add(
        WordDiffSegment(
          WordDiffOp.equal,
          oldText: oldWords[i],
          newText: newWords[j],
        ),
      );
      i++;
      j++;
    } else if (lengths[i + 1][j] >= lengths[i][j + 1]) {
      segments.add(WordDiffSegment(WordDiffOp.delete, oldText: oldWords[i]));
      i++;
    } else {
      segments.add(WordDiffSegment(WordDiffOp.insert, newText: newWords[j]));
      j++;
    }
  }
  while (i < m) {
    segments.add(WordDiffSegment(WordDiffOp.delete, oldText: oldWords[i]));
    i++;
  }
  while (j < n) {
    segments.add(WordDiffSegment(WordDiffOp.insert, newText: newWords[j]));
    j++;
  }
  return segments;
}

/// Merges a maximal run of consecutive delete/insert segments (regardless of
/// their relative order within the run) into a single [WordDiffOp.replace]
/// carrying the joined old and new text. A run containing only deletes (or
/// only inserts) stays as-is — only a run with *both* becomes a replace.
List<WordDiffSegment> _coalesceReplacements(List<WordDiffSegment> raw) {
  final result = <WordDiffSegment>[];
  var i = 0;
  while (i < raw.length) {
    final segment = raw[i];
    if (segment.op == WordDiffOp.equal) {
      result.add(segment);
      i++;
      continue;
    }
    // Collect the maximal run of consecutive delete/insert segments.
    final deleted = <String>[];
    final inserted = <String>[];
    var j = i;
    while (j < raw.length && raw[j].op != WordDiffOp.equal) {
      if (raw[j].op == WordDiffOp.delete) {
        deleted.add(raw[j].oldText!);
      } else {
        inserted.add(raw[j].newText!);
      }
      j++;
    }
    if (deleted.isNotEmpty && inserted.isNotEmpty) {
      result.add(
        WordDiffSegment(
          WordDiffOp.replace,
          oldText: deleted.join(' '),
          newText: inserted.join(' '),
        ),
      );
    } else if (deleted.isNotEmpty) {
      result.add(WordDiffSegment(WordDiffOp.delete, oldText: deleted.join(' ')));
    } else {
      result.add(WordDiffSegment(WordDiffOp.insert, newText: inserted.join(' ')));
    }
    i = j;
  }
  return result;
}
