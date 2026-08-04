/// Modelling shortcuts: correct as written, past something the format models
/// (ADR-0071).
///
/// `SourceAnalyzer` answers "will this render". These rules answer a different
/// question — "did the author use the format, or write around it" — and they exist
/// because the answer measured badly. A cold agent with only the MCP server
/// converted a real course booklet into a plan that compiled with 0 errors and 0
/// warnings and contained **no entities and no tokens at all**: 0 `persons`, 0
/// `locations`, 0 `{{var.*}}`, 0 `{{station.*}}`, against 24, 23, 49 and 77 in the
/// hand-authored plan for the same booklet. Its structural layer was *exact* —
/// modes, split groups, per-station time overrides all matched occurrence for
/// occurrence.
///
/// That split is the whole design rationale: everything the compiler enforces got
/// done, everything only the prose asks for got skipped. [ADR-0046] decided plan
/// variables and [ADR-0047] decided scenario locations and persons; neither left
/// anything that notices a document doing without them. So this adds nothing to the
/// format — it makes two accepted decisions observable.
///
/// Everything here is a [DiagnosticSeverity.suggestion]. These are heuristics on a
/// document that already compiles, and the guidance still states every rule in
/// prose, so a miss costs a sentence nobody read while a false positive costs the
/// channel. This repo has already deleted an over-firing warning rather than repair
/// it (commit 51377382 — "a warning that is always on is a banner"), and that is the
/// standard these have to meet. Every tuning choice below resolves toward precision.
///
/// Free of `package:flutter/*` (AGENTS.md rule 7).
library;

import 'package:ringdrill/data/source/source_diagnostic.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/models/station.dart';

/// One markdown field to scan: where it is, what is in it, and the station that
/// owns it (null above station scope).
typedef ModellingField = ({String path, String? content, Station? station});

/// The four rules of ADR-0071.
class SourceModelling {
  const SourceModelling._();

  /// Runs every rule, appending suggestions to [diagnostics].
  ///
  /// [fields] is the same field walk `SourceAnalyzer` uses for token checks, passed
  /// in rather than recomputed so the two cannot disagree about which fields exist.
  static void analyze(
    Plan plan,
    Iterable<ModellingField> fields,
    DiagnosticSink diagnostics,
  ) {
    final scanned = fields
        .where((f) => (f.content ?? '').trim().isNotEmpty)
        .toList(growable: false);

    for (final field in scanned) {
      _coordinateInProse(field, diagnostics);
      _entityNamedLiterally(field, diagnostics);
    }
    _rolePlayWithoutPerson(plan, diagnostics);
    _literalWantingVariable(plan, scanned, diagnostics);
  }

  // ---------------------------------------------------------------------------
  // Rule 1 — a coordinate in a markdown field wants a location
  // ---------------------------------------------------------------------------

  /// A UTM or decimal-degree coordinate typed into prose.
  ///
  /// The format has a first-class home for it: a station-owned `location` with a
  /// `position`, written as `{{station.loc.<slug>.position}}`. `position:` accepts
  /// the UTM string form directly (ADR-0061), so the remedy costs the author nothing
  /// in notation.
  ///
  /// The measured separation is 23 prose coordinates in the cold plan against 1 in
  /// the hand-authored one, where 46 of the human's 47 coordinates sit in the field
  /// built for them. Nobody writes a coordinate into a sentence for narrative
  /// reasons, so this is the cheapest rule here and the one least able to misfire.
  static void _coordinateInProse(
    ModellingField field,
    DiagnosticSink diagnostics,
  ) {
    final content = field.content!;
    final found = <String>{};
    for (final pattern in [_utmPattern, _decimalDegreePattern]) {
      for (final m in pattern.allMatches(content)) {
        found.add(m.group(0)!.trim());
      }
    }
    if (found.isEmpty) return;

    final sample = (found.toList()..sort()).first;
    final more = found.length > 1 ? ' (and ${found.length - 1} more)' : '';
    diagnostics.suggest(
      field.path,
      'coordinate "$sample" written into prose$more',
      hint: field.station == null
          ? 'a coordinate belongs on a station, as a location with a position'
          : 'declare it as a location on this station and write '
                '{{station.loc.<slug>.position}} — position: takes this exact UTM '
                'form, and only then does it reach the map',
    );
  }

  // ---------------------------------------------------------------------------
  // Rule 2 — a role play that invents its own person wants a personRef
  // ---------------------------------------------------------------------------

  /// A role play with no `personRef` on a station that declares no persons.
  ///
  /// A role play is "a role portraying one of the station's persons; identity fields
  /// are inherited from that person unless written here". Measured 0 of 11 role plays
  /// carrying a `personRef` in the cold plan against 11 of 11 in the hand-authored
  /// one, whose role plays are a `personRef` and a `behavior` and nothing else.
  ///
  /// Scoped to the conjunction — no `personRef` **and** no persons on the owning
  /// station — for two reasons. A plan that models its persons and then adds one odd
  /// role (a dispatcher, a bystander) must not be nagged. And the identity fields
  /// cannot be used as evidence: `RolePlay.name`/`age`/`gender` are populated even
  /// when a `personRef` is set, since they hold the effective denormalized identity,
  /// so "wrote its own identity" is not observable and only the absence is.
  ///
  /// This rule therefore reads intent from an absence, which is its weakness. The
  /// message is phrased as a question for that reason.
  static void _rolePlayWithoutPerson(Plan plan, DiagnosticSink diagnostics) {
    for (var e = 0; e < plan.exercises.length; e++) {
      final exercise = plan.exercises[e];
      for (var s = 0; s < exercise.stations.length; s++) {
        final station = exercise.stations[s];
        if (station.persons.isNotEmpty) continue;

        final rolePlays = plan.rolePlays
            .where(
              (rp) => rp.exerciseUuid == exercise.uuid && rp.stationIndex == s,
            )
            .toList(growable: false);
        var r = 0;
        for (final rolePlay in rolePlays) {
          final at = 'exercises[$e].stations[$s].roleplays[${r++}]';
          if (rolePlay.personRef != null) continue;
          diagnostics.suggest(
            at,
            'role "${rolePlay.name}" portrays nobody this station declares',
            hint:
                'if it plays a scenario subject, declare that person on the '
                'station and set personRef — the role then inherits the '
                'identity, and {{station.person.<slug>.*}} can name them in '
                'prose. If it plays no subject at all, this is fine as written.',
          );
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Rule 3 — a declared entity named as a literal wants a token
  // ---------------------------------------------------------------------------

  /// A station's own location or person, named verbatim in that station's prose.
  ///
  /// The rule that actually produces the 77 missing `{{station.*}}` references — and
  /// the reason rules 1 and 2 come first: nothing can ask for a reference to an
  /// entity that does not exist, so this reports nothing at all on a plan with no
  /// entities and cannot stand alone.
  ///
  /// Exact rather than heuristic in principle — the comparison is against strings the
  /// author declared in the same document — but two guards keep it from matching
  /// inside unrelated words, which is where the tuning the ADR admits to lives:
  /// whole-token matching, and a minimum length, because a station with a location
  /// labelled `KO` or `Bua` would otherwise match half its prose.
  static void _entityNamedLiterally(
    ModellingField field,
    DiagnosticSink diagnostics,
  ) {
    final station = field.station;
    if (station == null) return;
    if (_inheritedIdentityPath.hasMatch(field.path)) return;
    final content = field.content!;

    for (final entry in _referableNames(station)) {
      final (:literal, :token) = entry;
      if (literal.length < _minEntityNameLength) continue;
      if (!_containsWholeToken(content, literal)) continue;
      diagnostics.suggest(
        field.path,
        '"$literal" is declared on this station but written out here',
        hint:
            'write $token instead, so a correction to the entity reaches '
            'every field that names it',
      );
    }
  }

  /// The station's declared names, each with the token that resolves to it.
  ///
  /// **A location's `label` is deliberately excluded**, and finding out why is what
  /// stopped this rule shipping as a banner. Run against the hand-authored reference
  /// plan it produced 42 suggestions, essentially all of them labels: `hytta`,
  /// `lekeplassen`, `Bopel`. Those are *descriptive nouns* — a label says what kind
  /// of place this is, so it is the same word the prose uses to talk about the place,
  /// and "hytta" in a sentence is Norwegian rather than a missed token. No amount of
  /// boundary matching separates the two, because there is nothing to separate: the
  /// author is using a common noun, correctly, and the reference plan uses 77 tokens
  /// *and* writes these words in prose.
  ///
  /// What survives is proper nouns — a `place` ("Ødekjærveien 74") and a person's
  /// name ("Kåre Skogstad"). Those name one thing, so writing one out is a real
  /// missed reference, and [_looksLikeProperNoun] is what keeps a one-word common
  /// noun from sneaking back in through `place`.
  static Iterable<({String literal, String token})> _referableNames(
    Station station,
  ) sync* {
    for (final loc in station.locations) {
      final place = loc.place.trim();
      if (_looksLikeProperNoun(place)) {
        yield (literal: place, token: '{{station.loc.${loc.slug}.place}}');
      }
    }
    for (final person in station.persons) {
      final name = person.name.trim();
      if (_looksLikeProperNoun(name)) {
        yield (literal: name, token: '{{station.person.${person.slug}.name}}');
      }
    }
  }

  /// A role play's `name`, which is not prose and must never be read as prose.
  ///
  /// `RolePlay.name` holds the **effective, denormalized identity**: when a role play
  /// sets `personRef`, the compiler fills the identity fields from that person and
  /// they are "never emptied". So a correctly modelled role play necessarily repeats
  /// its person's name there, and comparing the two finds a match every single time.
  ///
  /// This was 9 of the 11 remaining hits against the reference plan — a rule
  /// reporting the format working as designed. Excluded structurally rather than by
  /// tuning, because it is not a close call: the field is a copy on purpose.
  static final _inheritedIdentityPath = RegExp(r'\.roleplays\[\d+\]\.name$');

  /// Whether [value] names one specific thing rather than a kind of thing.
  ///
  /// Multi-word, or carrying a digit — a street address, a full name, a numbered
  /// place. A single lower-case or capitalised word is treated as a common noun and
  /// left alone, which is the whole lesson of the 42 false positives above.
  static bool _looksLikeProperNoun(String value) {
    if (value.length < _minEntityNameLength) return false;
    if (value.contains(RegExp(r'\d'))) return true;
    return value.trim().contains(' ');
  }

  /// Shortest declared name this rule will look for.
  ///
  /// `KO`, `IPP` and `Bua` are real labels, and searching prose for a two-letter
  /// string finds it everywhere. Four is long enough that a match is meaningful and
  /// short enough to keep real place names in scope; the cost is that a plan whose
  /// entities are all abbreviations gets no help from this rule.
  static const _minEntityNameLength = 4;

  /// Whether [content] contains [literal] delimited by non-word characters.
  ///
  /// Hand-rolled rather than `RegExp(r'\b')` because the literal is author text and
  /// may hold regex metacharacters, and because `\b` is ASCII-only in Dart — it would
  /// treat `å` as a boundary and match "Bua" inside "Buåsen".
  static bool _containsWholeToken(String content, String literal) {
    final haystack = content.toLowerCase();
    final needle = literal.toLowerCase();
    var from = 0;
    while (true) {
      final at = haystack.indexOf(needle, from);
      if (at < 0) return false;
      final before = at == 0 ? null : haystack.codeUnitAt(at - 1);
      final afterAt = at + needle.length;
      final after = afterAt >= haystack.length
          ? null
          : haystack.codeUnitAt(afterAt);
      if (!_isWordChar(before) && !_isWordChar(after)) return true;
      from = at + 1;
    }
  }

  static bool _isWordChar(int? unit) {
    if (unit == null) return false;
    final c = String.fromCharCode(unit);
    return RegExp(r'[\wÀ-ɏ]').hasMatch(c);
  }

  // ---------------------------------------------------------------------------
  // Rule 4 — a value used in many places wants a variable
  // ---------------------------------------------------------------------------

  /// A literal that should be a plan variable, by either criterion the guidance
  /// states: repeated across fields, or a contact value that changes on the day.
  ///
  /// This is the only rule here with tuning in it, so the false-positive defence is a
  /// **shape restriction rather than a stop-word list**: a candidate must look like a
  /// *value*, never like prose. Ordinary words cannot qualify, which is the concrete
  /// meaning of the guidance's "do not promote a word that merely recurs in prose."
  static void _literalWantingVariable(
    Plan plan,
    List<ModellingField> fields,
    DiagnosticSink diagnostics,
  ) {
    // Already promoted values must not be re-suggested: their *resolved* text can
    // legitimately appear once a default is substituted.
    final declared = {
      for (final v in plan.variables)
        if (v.value.trim().isNotEmpty) v.value.trim().toLowerCase(),
    };

    /// Which fields each candidate literal appears in — fields, not occurrences.
    /// `Lag 2.X` thirty-nine times inside one `method` is one editing site; the same
    /// string across eleven station `comms` is eleven.
    final sites = <String, Set<String>>{};
    final contacts = <String, String>{};

    for (final field in fields) {
      final content = field.content!;
      for (final value in _valueShapedLiterals(content)) {
        if (declared.contains(value.toLowerCase())) continue;
        sites.putIfAbsent(value, () => <String>{}).add(field.path);
      }
      for (final contact in _contactLiterals(content)) {
        if (declared.contains(contact.toLowerCase())) continue;
        contacts.putIfAbsent(contact, () => field.path);
        sites.putIfAbsent(contact, () => <String>{}).add(field.path);
      }
    }

    // Contacts first, at a single occurrence: a duty number is the guidance's
    // canonical "decided late or changed on the day" value, and does not need to
    // repeat to want a variable.
    for (final entry in contacts.entries) {
      final where = sites[entry.key] ?? {entry.value};
      diagnostics.suggest(
        entry.value,
        'contact number "${entry.key}" written into prose',
        hint: where.length > 1
            ? 'declare a plan variable and write {{var.<slug>}} — it appears in '
                  '${where.length} fields, and it is the kind of value that '
                  'changes on the day'
            : 'declare a plan variable and write {{var.<slug>}}, so whoever '
                  'changes it on the day edits one field',
      );
    }

    for (final entry in sites.entries) {
      if (contacts.containsKey(entry.key)) continue; // already reported above
      if (entry.value.length < _repeatedFieldThreshold) continue;
      final paths = entry.value.toList()..sort();
      diagnostics.suggest(
        paths.first,
        '"${entry.key}" is written into ${paths.length} fields',
        hint:
            'declare a plan variable and write {{var.<slug>}} in each, so it '
            'is edited in one place — also in: ${paths.skip(1).join(', ')}',
      );
    }
  }

  /// How many distinct fields a repeated literal must appear in.
  ///
  /// Three, which is the threshold the authoring guidance already states and argues
  /// for, so this is not a new number.
  static const _repeatedFieldThreshold = 3;

  /// Literals that look like a *coded value* rather than like prose or domain
  /// vocabulary.
  ///
  /// The first draft accepted any token containing a digit, and the reference plan
  /// answered with twelve suggestions promoting `R25`, `R50`, `R75`, `2026` and
  /// `300` — search radii, years and a distance. All of those are domain vocabulary
  /// or plain content: they recur because the subject recurs, and none of them is
  /// "decided late and changed on the day", which is what a variable is for.
  ///
  /// So a candidate needs **internal punctuation and length**: `RK-VFOLD-ØV4` and
  /// `DMO-ANDRE-1` qualify, `R25` and `2026` cannot. Structure is what separates an
  /// assigned code from a number someone wrote — a talegruppe, a callsign and an
  /// asset tag all carry it, and a radius does not.
  ///
  /// The honest cost is that a multi-word literal is out of reach, including the
  /// guidance's own flagship example: `Lag 2.X` is two tokens to any scanner working
  /// a word at a time, so the repetition half cannot see it. That case stays a prose
  /// rule. Better to miss it than to promote every year in the document.
  static Iterable<String> _valueShapedLiterals(String content) {
    final out = <String>{};
    final stripped = _withoutExcluded(content);
    for (final m in _valueTokenPattern.allMatches(stripped)) {
      final value = m.group(0)!;
      if (value.length < _minCodedValueLength) continue;
      if (!value.contains(RegExp(r'[-_/]'))) continue;
      // Upper case is the last discriminator, and it is doing real work:
      // `5-punktsordre` is hyphenated, digit-bearing and six characters long, and it
      // is a doctrinal term appearing in three fields of *both* plans. An assigned
      // code is written in capitals; a hyphenated word is a word.
      if (value != value.toUpperCase()) continue;
      if (!value.contains(RegExp(r'[A-ZÆØÅ]'))) continue;
      out.add(value);
    }
    return out;
  }

  /// Shortest literal the repetition rule treats as a code.
  ///
  /// Six, which admits `DMO-ANDRE-1` and excludes the short hyphenated fragments
  /// ordinary prose produces.
  static const _minCodedValueLength = 6;

  /// Contact numbers, in every format at once.
  ///
  /// **The plan's language is deliberately not an input.** A plan's `language` says
  /// who reads it, not whose phone numbers are in it: a Norwegian organisation
  /// running an international exercise writes `language: en` and fills it with `+47`
  /// duty numbers, and one plan legitimately mixes a duty mobile, a satellite number
  /// and a foreign liaison. Keying on language would miss exactly that case, which is
  /// worse than being imprecise because it fails where the plan is most complicated.
  ///
  /// So every known shape is matched in every plan, and precision comes from
  /// [_withoutExcluded] and from label adjacency rather than from locale.
  static Iterable<String> _contactLiterals(String content) {
    final stripped = _withoutExcluded(content);

    // Span-tracked, because matching every format concurrently means the formats
    // overlap: `+47 93 25 89 30` is one E.164 match *and* contains a Norwegian
    // 2-2-2-2 match at `47 93 25 89`. Reporting both would tell an author to promote
    // a number and a fragment of the same number.
    final spans = <({int start, int end, String text})>[];

    void offer(int start, int end, String raw) {
      final text = raw.trim();
      if (text.isEmpty) return;
      final digits = text.replaceAll(RegExp(r'\D'), '');
      if (_emergencyNumbers.contains(digits)) return;
      spans.add((start: start, end: end, text: text));
    }

    for (final pattern in _contactPatterns) {
      for (final m in pattern.allMatches(stripped)) {
        offer(m.start, m.end, m.group(0)!);
      }
    }

    // Label adjacency: a digit run beside a contact word is a contact whatever its
    // shape, which lets an unrecognised format still fire. The lexicon is a union
    // across languages rather than selected by the plan's — a plan in one language
    // routinely labels things in another, and matching a word it "should not"
    // contain costs nothing.
    for (final m in _labelledNumberPattern.allMatches(stripped)) {
      final value = m.group(2)!;
      if (value.replaceAll(RegExp(r'\D'), '').length < 5) {
        continue; // an extension or a room number
      }
      // Dart exposes no per-group offsets, but the number is the last thing
      // `_labelledNumberPattern` matches, so its span ends where the match does.
      offer(m.end - value.length, m.end, value);
    }

    // Longest wins, then anything overlapping it is dropped. Longest rather than
    // first because the more specific format is the longer one — the country code
    // belongs to the number.
    spans.sort((a, b) => (b.end - b.start).compareTo(a.end - a.start));
    final kept = <({int start, int end, String text})>[];
    for (final span in spans) {
      final overlaps = kept.any(
        (k) => span.start < k.end && k.start < span.end,
      );
      if (!overlaps) kept.add(span);
    }
    return kept.map((s) => s.text).toSet();
  }

  /// Blanks out text that must never be read as a value or a contact, so no later
  /// pattern can match inside it.
  ///
  /// Replaced with spaces rather than removed so nothing that was separate becomes
  /// adjacent. Every entry is a *shape*, which is what makes the exclusions
  /// language-independent — and it is where the real maintenance of rule 4 lives: a
  /// newly added contact format can start matching something an old exclusion was
  /// never written against.
  static String _withoutExcluded(String content) {
    var out = content;
    for (final pattern in _excludedPatterns) {
      out = out.replaceAllMapped(pattern, (m) => ' ' * m.group(0)!.length);
    }
    return out;
  }

  /// Real content that looks like a value or a number.
  static final _excludedPatterns = <RegExp>[
    // A coordinate — rule 1 reports these, and rule 4 must not double-report.
    _utmPattern,
    _decimalDegreePattern,
    // AMIS incident numbers: six digits, a hyphen, a digit.
    RegExp(r'\b\d{6}-\d\b'),
    // Vehicle registrations: two letters then digits.
    RegExp(r'\b[A-ZÆØÅ]{2}\s?\d{4,5}\b'),
    // A parenthesised age.
    RegExp(r'\(\s?\d{1,2}\s?\)'),
    // A clock time, which the schedule derives and nobody promotes.
    RegExp(r'\b\d{1,2}[:.]\d{2}\b'),
    // An ISO date: hyphenated and digit-bearing, so it would otherwise read as a
    // coded value.
    RegExp(r'\b\d{4}-\d{2}-\d{2}\b'),
  ];

  /// Emergency numbers: real, and never a variable, because a variable is for a
  /// value that changes and these never will.
  ///
  /// The one exclusion justified by semantics rather than by the shape of the text,
  /// which also makes it the one a later reader is most likely to delete as
  /// arbitrary. It is not arbitrary.
  static const _emergencyNumbers = {
    '110',
    '112',
    '113',
    '911',
    '999',
    '116117',
  };

  /// Contact number shapes, all active in every plan.
  static final _contactPatterns = <RegExp>[
    // E.164 international, any country code. Language-independent by construction.
    RegExp(r'\+\d{1,3}[\s-]?(?:\d[\s-]?){6,12}\d'),
    // Norwegian: eight digits, bare or grouped 2-2-2-2 / 3-2-3.
    RegExp(
      r'(?<![\d-])(?:\d{8}|\d{2}(?:\s\d{2}){3}|\d{3}\s\d{2}\s\d{3})(?![\d-])',
    ),
    // NANP: (NNN) NNN-NNNN or NNN-NNN-NNNN.
    RegExp(r'(?<![\d-])(?:\(\d{3}\)\s?\d{3}-\d{4}|\d{3}-\d{3}-\d{4})(?![\d-])'),
    // UK: 0NNNN NNNNNN and 0NN NNNN NNNN.
    RegExp(r'(?<![\d-])0\d{2,4}\s\d{3,6}(?:\s\d{4})?(?![\d-])'),
  ];

  /// A contact label followed by a number — the union lexicon, not selected by the
  /// plan's language.
  static final _labelledNumberPattern = RegExp(
    r'\b(tlf|telefon|telefonnr|mob|mobil|vakttelefon|vakttlf|ring|nummer|'
    r'phone|tel|telephone|mobile|cell|call|contact|duty)\b'
    r'[\s.:=]*([+()\d][\d\s()-]{4,})',
    caseSensitive: false,
  );

  /// A bare word-like token, the candidate unit for [_valueShapedLiterals].
  static final _valueTokenPattern = RegExp(
    r'[A-Za-z0-9ÆØÅæøåÄÖäö][A-Za-z0-9ÆØÅæøåÄÖäö._/-]*'
    r'[A-Za-z0-9ÆØÅæøåÄÖäö]',
  );

  /// `32V 0580307E 6552025N` and friends (ADR-0061's input form).
  static final _utmPattern = RegExp(
    r'\b\d{1,2}\s?[C-HJ-NP-X]\s+\d{6,7}\s?m?E?\s+\d{6,7}\s?m?N?\b',
    caseSensitive: false,
  );

  /// A decimal-degree pair written into prose: `59.096857, 10.401633`.
  ///
  /// Both parts must carry a decimal point with at least four places, so a pair of
  /// ordinary numbers in a sentence cannot match.
  ///
  /// The trailing guard is `(?!\d)` rather than `(?![\d.])`: excluding a following
  /// dot rejected every coordinate that ends a sentence, which is where a coordinate
  /// typed into prose usually is.
  static final _decimalDegreePattern = RegExp(
    r'(?<![\d.])-?\d{1,3}\.\d{4,}\s*,\s*-?\d{1,3}\.\d{4,}(?!\d)',
  );
}
