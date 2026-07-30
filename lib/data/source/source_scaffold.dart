/// Generates a starting source document from a handful of answers.
///
/// The format is small but not obvious — which fields are authored, where role
/// plays nest, that numbering comes from order — and a blank file teaches none of
/// it. This produces a document that builds as-is and shows the shape by example:
/// one exercise carries the scenario layer (a location, a person, a role play, a
/// variable override) so an author can see how the pieces reference each other,
/// while the rest stay minimal.
///
/// Also the honest way to keep an example fixture: a hand-written one drifts
/// silently as the format changes, whereas this is generated from the same field
/// table the compiler reads and the test suite builds its output
/// (`test/data/source/source_scaffold_test.dart`).
///
/// **What is localized and what is not.** Entity *names* use the plan's language,
/// via the same generated-name path the app uses ("Øvelse 1" / "Post 1" in `nb`),
/// because those become the author's content and should read naturally from the
/// start. The placeholder prose and the header are tooling text — instructions to
/// whoever opens the file — and stay English, like the rest of the CLI's output
/// (AGENTS.md rule 12). Deliberate rather than an oversight: the names are kept,
/// the instructions are deleted.
///
/// Free of `package:flutter/*` (AGENTS.md rule 7).
library;

import 'package:ringdrill/data/source/source_emitter.dart';
import 'package:ringdrill/l10n/headless_labels.dart';

/// Builds skeleton source documents.
class SourceScaffold {
  const SourceScaffold._();

  /// Minutes per phase in a generated exercise.
  ///
  /// A 15/10/5 round is the shape the real plans in the catalog use, so a
  /// scaffolded plan looks plausible rather than looking like a placeholder that
  /// has to be replaced before anything makes sense.
  static const executionTime = 15;
  static const evaluationTime = 10;
  static const rotationTime = 5;

  /// The first exercise's start time, and the gap between exercises.
  static const firstStartHour = 9;
  static const _minutesBetweenExercises = 30;

  /// Generates a document for [name].
  ///
  /// [stationsPerExercise] defaults to [teams] — the fewest a rotation can have,
  /// since fewer stations than teams leaves a team with nowhere to go, which
  /// `build` rejects outright. [withExample] adds the scenario layer to the first
  /// exercise; pass false for a bare skeleton.
  static String generate({
    required String name,
    int exercises = 1,
    int teams = 4,
    int? stationsPerExercise,
    int rounds = 0,
    String languageCode = 'en',
    bool withExample = true,
  }) {
    final stations = stationsPerExercise ?? teams;
    // Rounds default to the station count: one round per station is a full
    // rotation, which is what "ringøvelse" means and what an author almost always
    // wants.
    final roundCount = rounds > 0 ? rounds : stations;
    final labels = HeadlessLabels(languageCode: languageCode);
    final exerciseWord = labels.plural('exercise', 1);
    final stationWord = labels.plural('station', 1);

    final planMap = <String, dynamic>{
      'name': name,
      'language': labels.localeName,
      'tags': <String>[],
      'exerciseNumberFormat': 'hash',
      'stationNumberFormat': 'dotted',
      if (withExample)
        'variables': <String, Map<String, dynamic>>{
          'talkgroup': {
            'value': 'CHANGE-ME',
            'hint': 'Referenced in prose as {{var.talkgroup}}',
          },
        },
    };

    final exerciseList = <Map<String, dynamic>>[];
    for (var e = 0; e < exercises; e++) {
      final startMinutes =
          firstStartHour * 60 +
          e *
              (roundCount * (executionTime + evaluationTime + rotationTime) +
                  _minutesBetweenExercises);
      exerciseList.add({
        // No uuid: the compiler mints one. A scaffold that pre-assigned them
        // would look like the field is required.
        'name': '$exerciseWord ${e + 1}',
        'startTime': _time(startMinutes),
        'numberOfTeams': teams,
        'numberOfRounds': roundCount,
        'executionTime': executionTime,
        'evaluationTime': evaluationTime,
        'rotationTime': rotationTime,
        'stations': [
          for (var s = 0; s < stations; s++)
            _station(
              '$stationWord ${s + 1}',
              // Only the first station of the first exercise carries the
              // scenario layer. Repeating it on every station would bury the
              // structure in noise and make the example look mandatory.
              withExample: withExample && e == 0 && s == 0,
            ),
        ],
      });
    }

    return SourceEmitter.emit(
      plan: planMap,
      exercises: exerciseList,
      // Teams are left out on purpose: the compiler derives as many as the
      // largest numberOfTeams, with generated names. An author who wants real
      // names (a callsign, a district) adds a teams: list — the header says so.
      teams: const [],
      header: _header(
        name: name,
        exercises: exercises,
        teams: teams,
        stations: stations,
        withExample: withExample,
      ),
    );
  }

  static Map<String, dynamic> _station(
    String name, {
    required bool withExample,
  }) => <String, dynamic>{
    'name': name,
    if (!withExample) 'situation': 'What the team finds. Replace this.\n',
    if (withExample) ...{
      'variableOverrides': {'talkgroup': 'CHANGE-ME-2'},
      'locations': [
        {
          'slug': 'lkp',
          'kind': 'lkp',
          'label': 'Last known position',
          'position': {'lat': 59.09672, 'lng': 10.40201},
        },
      ],
      'persons': [
        {
          'slug': 'subject',
          'name': 'CHANGE-ME',
          'age': 6,
          'description': 'Appearance and identifying detail.',
          'locSlug': 'lkp',
        },
      ],
      'situation':
          '{{station.person.subject}} '
          '({{station.person.subject.age}}), last seen at '
          '{{station.loc.lkp.utm}}. Comms on {{var.talkgroup}}.\n',
      'director_notes': 'Instructor-only notes. Not shown to participants.\n',
      'roleplays': [
        {
          'personRef': 'subject',
          'behavior': 'How the marker behaves when found.\n',
        },
      ],
    },
  };

  static String _header({
    required String name,
    required int exercises,
    required int teams,
    required int stations,
    required bool withExample,
  }) =>
      '''
RingDrill source document, scaffolded by `ringdrill create`.

  build     ringdrill build this-file.yaml
  check     ringdrill analyze this-file.yaml
  read      ringdrill render this-file.yaml --audience=director

$exercises exercise(s), $teams team(s), $stations station(s) each.

What the compiler fills in, so it is not here: the rotation schedule and end
time, every index, uuids, and the content hash. Numbering ("#2", "2.1") comes
from position in these lists — do not write it into a name.

Teams are omitted, so $teams are generated with default names. Add a top-level
`teams:` list to name them yourself; the names are free text, so a callsign or a
district works as well as "Team 1".
${withExample ? '''

The first station shows the scenario layer: a location and a person addressed by
slug, prose referencing them, and a role play portraying the person. Identity
fields a role play omits are inherited from its person. Delete what you do not
need.

Every CHANGE-ME is a placeholder.''' : ''}''';

  static String _time(int totalMinutes) {
    final hour = (totalMinutes ~/ 60) % 24;
    final minute = totalMinutes % 60;
    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
  }
}
