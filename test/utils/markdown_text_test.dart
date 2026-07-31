// Reducing a markdown field to a plain teaser (docs/prompts/plan-overview-markdown-tables.md).
//
// The bug this fixes: the old helper split on blank lines and joined the first
// block's lines with spaces, so the LSOR plan's "Talegrupper" pipe table arrived on
// screen as `| Rolle | Talegruppe | |---|---| | LSOR Deltakere | …`. A table has no
// readable one-line form, so it is skipped rather than flattened.
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/utils/markdown_text.dart';

void main() {
  test('drops a table in favour of the paragraph after it', () {
    const md = '''
| Rolle | Talegruppe |
|---|---|
| LSOR Deltakere | RK-VFOLD-ØV4 |
| LSOR Stab | RK-VFOLD-ØV5 |

Telefon til KO: 93258930.
''';
    final teaser = markdownTeaser(md);

    expect(teaser, isNotNull);
    expect(teaser!.text, 'Telefon til KO: 93258930.');
    expect(teaser.text, isNot(contains('|')));
    expect(teaser.truncated, isTrue, reason: 'the table was skipped');
  });

  test('a table-only field teases to null, not to an empty string', () {
    const md = '''
| Rolle | Talegruppe |
|---|---|
| LSOR Deltakere | RK-VFOLD-ØV4 |
''';
    // Null says "nothing here reads as prose", which is not the same fact as "the
    // field is empty" — the card must not derive emptiness from it and hide a field
    // that does hold a table.
    expect(markdownTeaser(md), isNull);
  });

  test('a single plain paragraph is not truncated', () {
    final teaser = markdownTeaser('Lev deg inn i spillet!');
    expect(teaser!.text, 'Lev deg inn i spillet!');
    expect(teaser.truncated, isFalse);
  });

  test('a following block makes it truncated', () {
    final teaser = markdownTeaser('First paragraph.\n\nSecond paragraph.');
    expect(teaser!.text, 'First paragraph.');
    expect(teaser.truncated, isTrue);
  });

  test('collapses inline markers to their text', () {
    final teaser = markdownTeaser(
      'A **bold** and _em_ and `code` and [link](https://x) and ~~gone~~.',
    );
    expect(teaser!.text, 'A bold and em and code and link and gone.');
  });

  test('keeps a heading, without its hashes', () {
    final teaser = markdownTeaser('## Generelt om spill\n\nResten.');
    expect(teaser!.text, 'Generelt om spill');
    expect(teaser.truncated, isTrue);
  });

  test('joins a wrapped paragraph and a list into one line', () {
    // Sentence-per-line is the house style for these fields, so the common case is
    // a block of several lines that is one paragraph.
    final teaser = markdownTeaser(
      'Første setning.\nAndre setning.\n\n- punkt en\n- punkt to',
    );
    expect(teaser!.text, 'Første setning. Andre setning.');
  });

  test('drops a fenced block and a horizontal rule', () {
    final teaser = markdownTeaser('```\ncode\n```\n\n---\n\nProse.');
    expect(teaser!.text, 'Prose.');
  });

  test('an image-only block is skipped', () {
    final teaser = markdownTeaser('![kart](kart.png)\n\nEtter kartet.');
    expect(teaser!.text, 'Etter kartet.');
  });

  test('null, empty and whitespace-only input return null', () {
    expect(markdownTeaser(null), isNull);
    expect(markdownTeaser(''), isNull);
    expect(markdownTeaser('   \n\n  '), isNull);
  });
}
