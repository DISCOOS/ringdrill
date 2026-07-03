import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/utils/word_diff.dart';

void main() {
  test('pure insertions render as equal runs with inserts interleaved', () {
    // The exact worked example from the catalog-conflict design discussion:
    // nothing was removed, three words were added.
    final segments = diffWords(
      'Søk og redning (ringøvelse)',
      '123 Søk og 45 redning (ringøvelse) 678',
    );

    expect(segments, [
      const WordDiffSegment(WordDiffOp.insert, newText: '123'),
      const WordDiffSegment(WordDiffOp.equal, oldText: 'Søk', newText: 'Søk'),
      const WordDiffSegment(WordDiffOp.equal, oldText: 'og', newText: 'og'),
      const WordDiffSegment(WordDiffOp.insert, newText: '45'),
      const WordDiffSegment(
        WordDiffOp.equal,
        oldText: 'redning',
        newText: 'redning',
      ),
      const WordDiffSegment(
        WordDiffOp.equal,
        oldText: '(ringøvelse)',
        newText: '(ringøvelse)',
      ),
      const WordDiffSegment(WordDiffOp.insert, newText: '678'),
    ]);
  });

  test('pure deletion — a word removed with nothing replacing it', () {
    final segments = diffWords('Løp fort til målet', 'Løp til målet');

    expect(segments, [
      const WordDiffSegment(WordDiffOp.equal, oldText: 'Løp', newText: 'Løp'),
      const WordDiffSegment(WordDiffOp.delete, oldText: 'fort'),
      const WordDiffSegment(WordDiffOp.equal, oldText: 'til', newText: 'til'),
      const WordDiffSegment(
        WordDiffOp.equal,
        oldText: 'målet',
        newText: 'målet',
      ),
    ]);
  });

  test('a single-token substitution coalesces into one replace', () {
    final segments = diffWords('30', '31');

    expect(segments, [
      const WordDiffSegment(WordDiffOp.replace, oldText: '30', newText: '31'),
    ]);
  });

  test('adjacent delete+insert coalesces into replace, not separate spans', () {
    final segments = diffWords(
      'Bruk karabinkroker og hjelm',
      'Bruk låsekarabin og hjelm',
    );

    expect(segments, [
      const WordDiffSegment(WordDiffOp.equal, oldText: 'Bruk', newText: 'Bruk'),
      const WordDiffSegment(
        WordDiffOp.replace,
        oldText: 'karabinkroker',
        newText: 'låsekarabin',
      ),
      const WordDiffSegment(WordDiffOp.equal, oldText: 'og', newText: 'og'),
      const WordDiffSegment(
        WordDiffOp.equal,
        oldText: 'hjelm',
        newText: 'hjelm',
      ),
    ]);
  });

  test('a deletion and an unrelated insertion elsewhere stay separate', () {
    // The deleted and inserted words are not adjacent, so they must NOT
    // coalesce into a replace — each keeps its own color.
    final segments = diffWords('a b c d', 'x a c d');

    expect(segments, [
      const WordDiffSegment(WordDiffOp.insert, newText: 'x'),
      const WordDiffSegment(WordDiffOp.equal, oldText: 'a', newText: 'a'),
      const WordDiffSegment(WordDiffOp.delete, oldText: 'b'),
      const WordDiffSegment(WordDiffOp.equal, oldText: 'c', newText: 'c'),
      const WordDiffSegment(WordDiffOp.equal, oldText: 'd', newText: 'd'),
    ]);
  });

  test('identical strings produce only equal segments', () {
    final segments = diffWords('same text here', 'same text here');

    expect(segments, [
      const WordDiffSegment(WordDiffOp.equal, oldText: 'same', newText: 'same'),
      const WordDiffSegment(WordDiffOp.equal, oldText: 'text', newText: 'text'),
      const WordDiffSegment(WordDiffOp.equal, oldText: 'here', newText: 'here'),
    ]);
  });

  test('empty old text is all insertions, merged into one run', () {
    // No equal segments break up the run, so the three inserted words
    // coalesce into a single insert segment (same color regardless).
    final segments = diffWords('', 'brand new text');

    expect(segments, [
      const WordDiffSegment(WordDiffOp.insert, newText: 'brand new text'),
    ]);
  });

  test('empty new text is all deletions, merged into one run', () {
    final segments = diffWords('all removed now', '');

    expect(segments, [
      const WordDiffSegment(WordDiffOp.delete, oldText: 'all removed now'),
    ]);
  });

  test('both empty produces no segments', () {
    expect(diffWords('', ''), isEmpty);
  });

  test('runs of whitespace collapse to single spaces on tokenize', () {
    final segments = diffWords('a   b', 'a  b  c');

    expect(segments, [
      const WordDiffSegment(WordDiffOp.equal, oldText: 'a', newText: 'a'),
      const WordDiffSegment(WordDiffOp.equal, oldText: 'b', newText: 'b'),
      const WordDiffSegment(WordDiffOp.insert, newText: 'c'),
    ]);
  });
}
