// ADR-0071's modelling rules: correct as written, past something the format models.
//
// Every document here compiles with zero errors and zero warnings. That is the
// premise — these are shortcuts, not mistakes, and nothing else in the pipeline has
// an opinion about them.
//
// The negative cases are the important half. Each one is a false positive that an
// earlier draft of these rules actually produced against the hand-authored reference
// plan, and each is named after the reason it fired. That plan went 42 → 11 → 3
// suggestions as they were fixed, and the three that remain are true positives, so
// these tests are what stops it climbing back.
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/data/source/source_analyzer.dart';
import 'package:ringdrill/data/source/source_compiler.dart';
import 'package:ringdrill/data/source/source_diagnostic.dart';

List<SourceDiagnostic> _all(String yaml) {
  final result = SourceCompiler.toPlan(yaml, now: DateTime.utc(2026, 1, 1));
  final sink = DiagnosticSink()..addAll(result.diagnostics);
  SourceAnalyzer.analyze(result.plan, sink);
  return sink.items;
}

/// The suggestions, having asserted the document is otherwise clean — so a case
/// cannot pass by accident on a document that fails to compile.
List<SourceDiagnostic> _suggestions(String yaml) {
  final items = _all(yaml);
  expect(
    items.where((d) => d.isError).map((d) => d.toString()),
    isEmpty,
    reason: 'fixture must compile cleanly',
  );
  expect(
    items.where((d) => d.isWarning).map((d) => d.toString()),
    isEmpty,
    reason: 'fixture must be warning-free, or the case is not about modelling',
  );
  return items.where((d) => d.isSuggestion).toList();
}

/// One exercise, one station, with [station] extending the station body.
String _doc({String plan = '', String station = ''}) =>
    '''
plan:
  name: "Test"
$plan
exercises:
  - name: "Ex"
    startTime: "09:00"
    numberOfTeams: 1
    numberOfRounds: 1
    executionTime: 15
    evaluationTime: 5
    rotationTime: 2
    stations:
      - name: "Post"
$station
''';

void main() {
  group('severity', () {
    test('a modelling finding is a suggestion, and never blocks --strict', () {
      final found = _suggestions(
        _doc(station: '        situation: "IPP 32V 0580307E 6552025N."'),
      );
      expect(found, isNotEmpty);
      for (final d in found) {
        expect(d.isSuggestion, isTrue);
        expect(d.isError, isFalse);
        expect(d.isWarning, isFalse);
        // The reason this severity exists: `build --strict` refuses over
        // anything blocking, and a heuristic must not be able to fail a build.
        expect(d.isBlockingUnderStrict, isFalse);
      }
    });
  });

  group('rule 1 — a coordinate in prose wants a location', () {
    test('a UTM coordinate in a markdown field is reported', () {
      final found = _suggestions(
        _doc(
          station:
              '        situation: "Savnet sist sett 32V 0580307E 6552025N."',
        ),
      );
      expect(found.single.message, contains('32V 0580307E 6552025N'));
      expect(found.single.message, contains('written into prose'));
      expect(found.single.hint, contains('{{station.loc.'));
      expect(found.single.path, endsWith('situation'));
    });

    test('a decimal-degree pair in prose is reported', () {
      final found = _suggestions(
        _doc(station: '        mission: "Møt på 59.096857, 10.401633."'),
      );
      expect(found.single.message, contains('59.096857, 10.401633'));
    });

    test('a coordinate in position: is where it belongs, so silent', () {
      // The measured discriminator: 46 of the reference plan's 47 coordinates sit
      // here, and this rule must have no opinion about them.
      expect(
        _suggestions(
          _doc(
            station:
                '        position: "32V 0580307E 6552025N"\n'
                '        situation: "Savnet sist sett ved bilen."',
          ),
        ),
        isEmpty,
      );
    });

    test('ordinary numbers in a sentence are not a coordinate', () {
      expect(
        _suggestions(
          _doc(
            station:
                '        situation: "4 lag, 25 minutter, 300 meter til '
                'neste post. Kl 09.15 møtes de."',
          ),
        ),
        isEmpty,
      );
    });
  });

  group('rule 2 — a role play wants the person it portrays', () {
    test('a role play on a station with no persons is reported', () {
      final found = _suggestions(
        _doc(
          station:
              '        roleplays:\n'
              '          - name: "Markør"\n'
              '            behavior: "Ligger stille."',
        ),
      );
      expect(found.single.message, contains('portrays nobody'));
      expect(found.single.hint, contains('personRef'));
      expect(found.single.path, endsWith('roleplays[0]'));
    });

    test('a role play with a personRef is silent', () {
      expect(
        _suggestions(
          _doc(
            station:
                '        persons:\n'
                '          - slug: kaare\n'
                '            name: "Kåre Skogstad"\n'
                '            age: 46\n'
                '        roleplays:\n'
                '          - personRef: kaare\n'
                '            behavior: "Ligger stille."',
          ),
        ),
        isEmpty,
      );
    });

    test('a station that models its persons may still add an unlinked role', () {
      // Scoped to the conjunction on purpose: a dispatcher or a bystander is not a
      // scenario subject, and nagging about it would make the rule a banner on
      // exactly the plans that got the modelling right.
      expect(
        _suggestions(
          _doc(
            station:
                '        persons:\n'
                '          - slug: kaare\n'
                '            name: "Kåre Skogstad"\n'
                '        roleplays:\n'
                '          - personRef: kaare\n'
                '            behavior: "Ligger stille."\n'
                '          - name: "Vaktleder"\n'
                '            behavior: "Svarer på samband."',
          ),
        ),
        isEmpty,
      );
    });
  });

  group('rule 3 — a declared entity wants its token', () {
    test('a declared place written out in prose is reported', () {
      final found = _suggestions(
        _doc(
          station:
              '        locations:\n'
              '          - slug: skole\n'
              '            place: "Tjøme ungdomsskole"\n'
              '        mission: "Etabler KO ved Tjøme ungdomsskole."',
        ),
      );
      expect(found.single.message, contains('Tjøme ungdomsskole'));
      expect(found.single.hint, contains('{{station.loc.skole.place}}'));
    });

    test("a role play's inherited name is not the author writing it out", () {
      // The regression this rule shipped with, and 9 of its 11 remaining hits
      // against the reference plan. `RolePlay.name` holds the *effective,
      // denormalized* identity, so a correctly modelled role play necessarily
      // repeats its person's name and comparing the two always matched.
      expect(
        _suggestions(
          _doc(
            station:
                '        persons:\n'
                '          - slug: tonje\n'
                '            name: "Tonje Bakken"\n'
                '            age: 39\n'
                '        roleplays:\n'
                '          - personRef: tonje\n'
                '            behavior: "Svarer sjelden på tilrop."',
          ),
        ),
        isEmpty,
      );
    });

    test('a location label that is an ordinary noun is left alone', () {
      // 42 of 42 first-draft false positives. `hytta` is both a label and the
      // Norwegian word for the thing, so prose using it is prose, not a missed
      // reference — which is why only `place` and a person's name are compared.
      expect(
        _suggestions(
          _doc(
            station:
                '        locations:\n'
                '          - slug: hytta\n'
                '            label: "hytta"\n'
                '        situation: "Savnede gikk fra hytta ved soloppgang."',
          ),
        ),
        isEmpty,
      );
    });

    test('a declared name inside a longer word does not match', () {
      expect(
        _suggestions(
          _doc(
            station:
                '        locations:\n'
                '          - slug: bua\n'
                '            place: "Bua 12"\n'
                '        situation: "Laget søkte mot Bua 1234 og videre."',
          ),
        ),
        isEmpty,
      );
    });
  });

  group('rule 4 — a repeated code wants a variable', () {
    test(
      'a talegruppe in three fields is reported once, naming the others',
      () {
        final found = _suggestions(
          _doc(
            station:
                '        situation: "Samband på RK-VFOLD-ØV4."\n'
                '        mission: "Meld inn på RK-VFOLD-ØV4."\n'
                '        logistics: "Reserve er RK-VFOLD-ØV4."',
          ),
        );
        expect(found.single.message, contains('RK-VFOLD-ØV4'));
        expect(found.single.message, contains('3 fields'));
        expect(found.single.hint, contains('{{var.'));
      },
    );

    test('two fields is under the threshold', () {
      expect(
        _suggestions(
          _doc(
            station:
                '        situation: "Samband på RK-VFOLD-ØV4."\n'
                '        mission: "Meld inn på RK-VFOLD-ØV4."',
          ),
        ),
        isEmpty,
      );
    });

    test('a value already promoted to a variable is not re-suggested', () {
      // A half-migrated document: the variable exists and is used somewhere, and the
      // literal still appears elsewhere. Re-suggesting its own resolved value would
      // be unfixable advice. `equipment` references it so the existing
      // "declared but never referenced" warning stays out of the way.
      expect(
        _suggestions(
          _doc(
            plan: '  variables:\n    tg: {value: "RK-VFOLD-ØV4"}',
            station:
                '        equipment: "Samband: {{var.tg}}."\n'
                '        situation: "Samband på RK-VFOLD-ØV4."\n'
                '        mission: "Meld inn på RK-VFOLD-ØV4."\n'
                '        logistics: "Reserve er RK-VFOLD-ØV4."',
          ),
        ),
        isEmpty,
      );
    });

    test('domain vocabulary and years are not codes', () {
      // 11 first-draft false positives: R25/R50/R75 are search radii and 2026 is a
      // year. They recur because the subject recurs, and neither is decided late.
      expect(
        _suggestions(
          _doc(
            station:
                '        situation: "Grovsøk R25 rundt IPP i 2026."\n'
                '        mission: "Utvid til R50, deretter R75 i 2026."\n'
                '        logistics: "R25 først, så R50 og R75. 300 meter."',
          ),
        ),
        isEmpty,
      );
    });

    test('a hyphenated word is a word, not a code', () {
      // `5-punktsordre` is hyphenated, digit-bearing, six characters long, and a
      // doctrinal term appearing in three fields of *both* reference plans. Upper
      // case is what separates an assigned code from a compound word.
      expect(
        _suggestions(
          _doc(
            station:
                '        situation: "Bruk 5-punktsordre."\n'
                '        mission: "Gi 5-punktsordre til laget."\n'
                '        logistics: "5-punktsordre er malen."',
          ),
        ),
        isEmpty,
      );
    });
  });

  group('rule 4 — a contact number wants a variable at one occurrence', () {
    test('a Norwegian eight-digit number is reported once', () {
      final found = _suggestions(
        _doc(station: '        director_notes: "ØVLE: 93258930."'),
      );
      expect(found.single.message, contains('93258930'));
      expect(found.single.message, contains('contact number'));
      expect(found.single.hint, contains('changes it on the day'));
    });

    test('an international number is reported whatever the plan language', () {
      // The plan's language is deliberately not an input: a Norwegian
      // organisation running an international exercise writes `language: en` and
      // fills it with +47 duty numbers.
      final found = _suggestions(
        _doc(
          plan: '  language: en',
          station: '        director_notes: "Duty phone +47 93 25 89 30."',
        ),
      );
      expect(found, hasLength(1));
      expect(found.single.message, contains('contact number'));
    });

    test('a NANP number in a Norwegian-language plan is reported', () {
      final found = _suggestions(
        _doc(
          plan: '  language: nb',
          station: '        director_notes: "Liaison: (555) 019-2837."',
        ),
      );
      expect(found.single.message, contains('(555) 019-2837'));
    });

    test('a labelled number of an unrecognised shape still fires', () {
      final found = _suggestions(
        _doc(station: '        director_notes: "Tlf: 12 345 6789 01."'),
      );
      expect(found.single.message, contains('contact number'));
    });

    test('emergency numbers are never promoted', () {
      // Real numbers, excluded on semantics rather than shape: a variable is for a
      // value that changes, and 112 never will.
      expect(
        _suggestions(
          _doc(
            station:
                '        situation: "Ring 113 ved funn, 110 ved brann."\n'
                '        mission: "AMK nås på 113."',
          ),
        ),
        isEmpty,
      );
    });

    test('an AMIS number, a plate and a clock time are content', () {
      expect(
        _suggestions(
          _doc(
            station:
                '        director_notes: "AMIS# 987654-1, bil EK35989, '
                'oppmøte 09.15."\n'
                '        mission: "AMIS# 987660-1 for lag 2."',
          ),
        ),
        isEmpty,
      );
    });
  });
}
