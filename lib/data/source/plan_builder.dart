/// Builds a [Plan] from a parsed source document, filling everything derived.
///
/// This is the half of `build` that owns structure: ordering and indices, the
/// rotation schedule, minted uuids, the team roster, relocating role plays from
/// under their station to the plan level, and denormalizing a role play's
/// effective identity from the person it portrays. Value-level shape checking
/// already happened in `source_parser.dart`.
///
/// Entities are assembled by handing the wire-shaped map to the model's own
/// `fromJson` and then patching in the markdown fields — the same two-step
/// `DrillFile.plan()` uses, and for the same reason: markdown lives in `.md`
/// companion files (ADR-0022) and is excluded from `toJson`, so it cannot travel
/// through the JSON map. Going through `fromJson` rather than the constructors
/// means enum decoding, the `LatLng` converter and every `@Default` are reused
/// rather than re-implemented.
///
/// Free of `package:flutter/*` (AGENTS.md rule 7).
library;

import 'dart:math';

import 'package:nanoid/nanoid.dart';
import 'package:ringdrill/data/drill_file.dart';
import 'package:ringdrill/data/source/source_diagnostic.dart';
import 'package:ringdrill/data/source/source_field.dart';
import 'package:ringdrill/data/source/source_fields.dart';
import 'package:ringdrill/data/source/source_parser.dart';
import 'package:ringdrill/l10n/headless_labels.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/numbering.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/schedule.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/models/team.dart';

/// Turns source documents into plans.
class PlanBuilder {
  PlanBuilder({
    required this.diagnostics,
    DateTime? now,
    String Function()? mintUuid,
  }) : _now = now,
       _mintUuid = mintUuid ?? (() => nanoid(8));

  final DiagnosticSink diagnostics;

  /// Timestamp for `metadata.created`/`updated`. Injectable so a test — and
  /// `tools/`-style generators — can produce byte-comparable output; the field
  /// is outside `computeContentHash` either way.
  final DateTime? _now;

  /// Injectable so tests can assert on identity handling without matching
  /// random ids. Production mints `nanoid(8)`, matching `PlanService`.
  final String Function() _mintUuid;

  /// Builds the plan, then stamps its content hash.
  ///
  /// Throws [SourceFormatException] if anything in [document] (or in the parse
  /// that produced it) was an error.
  Plan build(SourceDocument document) {
    diagnostics.throwIfErrors();

    final planMap = document.plan;
    final languageCode = planMap['language'] as String?;
    final labels = HeadlessLabels(languageCode: languageCode);

    final variables = _variables(document);
    final exercises = _exercises(document, labels);
    final rolePlays = _rolePlays(document, exercises);
    final teams = _teams(document, exercises, labels);

    diagnostics.throwIfErrors();

    final created = _now ?? DateTime.now().toUtc();
    final plan = Plan(
      uuid: (planMap['uuid'] as String?) ?? _mintUuid(),
      name: (planMap['name'] as String?) ?? '',
      description: (planMap['description'] as String?) ?? '',
      exerciseNumberFormat: _enum(
        planMap['exerciseNumberFormat'],
        ExerciseNumberFormat.values,
        ExerciseNumberFormat.hash,
      ),
      stationNumberFormat: _enum(
        planMap['stationNumberFormat'],
        StationNumberFormat.values,
        StationNumberFormat.dotted,
      ),
      metadata: PlanMetadata(
        created: created,
        updated: created,
        // The plan's own revision, not the archive schema — `DrillFile.fromPlan`
        // stamps the schema itself.
        version: sourceFormatVersion,
        schema: DrillFile.drillSchemaCurrent,
        languageCode: languageCode,
      ),
      source: const PlanSource.local(),
      tags: ((planMap['tags'] as List?) ?? const []).cast<String>(),
      variables: variables,
      teams: teams,
      sessions: const [],
      exercises: exercises,
      rolePlays: rolePlays,
      staff: const [],
      briefIntroMd: planMap['intro'] as String?,
      commsMd: planMap['comms'] as String?,
      beforeRoundMd: planMap['before_round'] as String?,
    );

    return plan.copyWith(contentHash: plan.computeContentHash());
  }

  // --------------------------------------------------------------------------
  // Variables
  // --------------------------------------------------------------------------

  List<DrillVariable> _variables(SourceDocument document) {
    final out = <DrillVariable>[];
    document.variables.forEach((name, raw) {
      final path = 'plan.variables.$name';
      if (!_isSlug(name)) {
        diagnostics.error(
          path,
          'variable name "$name" is not a valid reference',
          hint:
              r'names must match ^[a-z][a-z0-9_]*$ so {{var.<name>}} resolves',
        );
      }
      final wire = <String, dynamic>{
        'name': name,
        'value': raw['value'] ?? '',
        if (raw['hint'] != null) 'hint': raw['hint'],
        if (raw['type'] != null) 'type': raw['type'],
      };
      final location = raw['location'];
      if (location != null) {
        final parsed = _variableLocation(location, '$path.location');
        if (parsed != null) wire['location'] = parsed;
      }
      out.add(DrillVariable.fromJson(wire));
    });
    // Sorted by name so archive order never affects the content hash — the same
    // normalization computeContentHash applies (ADR-0046). Doing it here too
    // means two documents differing only in variable order build byte-identical
    // manifests, not just equal hashes.
    out.sort((a, b) => a.name.compareTo(b.name));
    return out;
  }

  /// `{place, position}` for a `location`-typed variable.
  ///
  /// Hand-shaped rather than table-driven: `VariableLocation` is the only nested
  /// object that is neither a scope nor a scalar, and inventing a table entry for
  /// one two-field shape would cost more than it saves. The `position` field is
  /// declared as a plain string in the table for the same reason, so the
  /// coordinate arrives unconverted and is flipped here.
  Map<String, dynamic>? _variableLocation(Object? raw, String path) {
    if (raw is! Map) {
      diagnostics.error(path, 'expected {place, position}');
      return null;
    }
    final map = raw.map((k, v) => MapEntry('$k', v));
    final out = <String, dynamic>{'place': '${map['place'] ?? ''}'};
    final position = map['position'];
    if (position != null) {
      final converted = _position(position, '$path.position');
      if (converted != null) out['position'] = converted;
    }
    return out;
  }

  Map<String, dynamic>? _position(Object? raw, String path) {
    // Either notation (ADR-0061), through the one shared parse.
    if (raw is String) {
      final parsed = coordinateFromString(raw);
      if (parsed == null) {
        diagnostics.error(
          path,
          'not a coordinate: "$raw"',
          hint:
              'write {lat, lng} in decimal degrees, or a coordinate string like '
              '"32V 0580083E 6551794N"',
        );
      }
      return parsed;
    }
    if (raw is! Map) {
      diagnostics.error(
        path,
        'expected a coordinate as {lat, lng} or a UTM string',
      );
      return null;
    }
    final map = raw.map((k, v) => MapEntry('$k', v));
    final lat = _num(map['lat']);
    final lng = _num(map['lng']);
    if (lat == null || lng == null) {
      diagnostics.error(path, 'a coordinate needs numeric lat and lng');
      return null;
    }
    if (lat.abs() > 90 || lng.abs() > 180) {
      diagnostics.error(path, 'coordinate out of range');
      return null;
    }
    return {
      'coordinates': [lng, lat],
    };
  }

  // --------------------------------------------------------------------------
  // Exercises and stations
  // --------------------------------------------------------------------------

  List<Exercise> _exercises(SourceDocument document, HeadlessLabels labels) {
    final out = <Exercise>[];
    for (var i = 0; i < document.exercises.length; i++) {
      final raw = document.exercises[i];
      final path = '${SourceDocumentKeys.exercises}[$i]';

      final startTime = raw['startTime'] as Map<String, dynamic>?;
      if (startTime == null) {
        diagnostics.error('$path.startTime', 'an exercise needs a startTime');
        continue;
      }

      final rounds = _positiveInt(
        raw['numberOfRounds'],
        '$path.numberOfRounds',
        1,
      );
      final execution = _positiveInt(
        raw['executionTime'],
        '$path.executionTime',
        0,
      );
      final evaluation = _positiveInt(
        raw['evaluationTime'],
        '$path.evaluationTime',
        0,
      );
      final rotation = _positiveInt(
        raw['rotationTime'],
        '$path.rotationTime',
        0,
      );

      final stations = _stations(raw, path, labels);
      final teamsWanted = _positiveInt(
        raw['numberOfTeams'],
        '$path.numberOfTeams',
        1,
      );
      final start = SimpleTimeOfDay(
        hour: startTime['hour'] as int,
        minute: startTime['minute'] as int,
      );

      final mode = _mode(raw['mode'], '$path.mode', diagnostics);
      final groups = _groups(raw, path, mode, stations.length, diagnostics);
      if (mode == ExerciseMode.ring && teamsWanted > stations.length) {
        // A ring route puts one team on each station, so more teams than stations
        // leaves some with nowhere to be and the rotation undefined. The app only
        // asserts it — a debug crash there and nothing in release — so here it is a
        // hard error.
        //
        // Only `ring`, though: `together` puts every team on one station on purpose,
        // and `split` divides them into groups that are smaller than the team count
        // by definition. Applying the ring rule to those rejected the very plans
        // ADR-0062 exists to express.
        diagnostics.error(
          '$path.numberOfTeams',
          'numberOfTeams is $teamsWanted but the exercise has '
              '${stations.length} station(s)',
          hint:
              'a ring route needs at least one station per team — or use '
              'mode: together, where every team works the same station',
        );
      }
      // How many rounds the mode implies. In `ring` the author says; in the others it
      // follows from the stations, and an authored count is then a derived value the
      // document should not be restating (ADR-0062).
      final effectiveRounds = ExerciseSchedule.roundsForMode(
        mode: mode,
        numberOfRounds: rounds,
        numberOfStations: stations.length,
        numberOfGroups: groups.length,
      );
      final executionMinutes = ExerciseSchedule.executionMinutesFor(
        mode: mode,
        numberOfRounds: effectiveRounds,
        executionTime: execution,
        stationMinutes: [
          for (final station in stations) station.executionTime ?? execution,
        ],
        groups: [
          for (final group in groups)
            [for (final slot in group.stations) slot.stationIndex],
        ],
      );

      final wire = <String, dynamic>{
        'uuid': (raw['uuid'] as String?) ?? _mintUuid(),
        'index': i,
        'name': raw['name'] ?? '',
        'startTime': startTime,
        'numberOfTeams': teamsWanted,
        'numberOfRounds': effectiveRounds,
        'mode': mode.name,
        // Built by hand rather than via `toJson()`: json_serializable does not nest
        // `toJson` calls by default, so the generated map would carry live GroupSlot
        // objects and the `fromJson` below would fail casting them to maps. Encoding
        // to a string hides this — `jsonEncode` calls `toJson` itself — so it only
        // shows up on the path this builder takes.
        if (groups.isNotEmpty)
          'groups': [
            for (final group in groups)
              {
                'stations': [
                  for (final slot in group.stations)
                    {'stationIndex': slot.stationIndex, 'teams': slot.teams},
                ],
              },
          ],
        'executionTime': execution,
        'evaluationTime': evaluation,
        'rotationTime': rotation,
        'stations': const <Map<String, dynamic>>[],
        'schedule': ExerciseSchedule.roundsFrom(
          startTime: start,
          executionMinutes: executionMinutes,
          evaluationTime: evaluation,
          rotationTime: rotation,
        ).map((round) => round.map((t) => t.toJson()).toList()).toList(),
        'endTime': ExerciseSchedule.endTimeFrom(
          startTime: start,
          executionMinutes: executionMinutes,
          evaluationTime: evaluation,
          rotationTime: rotation,
        ).toJson(),
        if (raw['templateId'] != null) 'templateId': raw['templateId'],
        'variableOverrides':
            raw['variableOverrides'] ?? const <String, String>{},
      };

      var exercise = Exercise.fromJson(wire).copyWith(stations: stations);
      exercise = _patchMarkdown(
        exercise,
        raw,
        SourceScopes.exercise,
        (ex, key, value) => switch (key) {
          'methodMd' => ex.copyWith(methodMd: value),
          'learningGoalsMd' => ex.copyWith(learningGoalsMd: value),
          'trainingFocusMd' => ex.copyWith(trainingFocusMd: value),
          'orderFormatMd' => ex.copyWith(orderFormatMd: value),
          'executionTipsMd' => ex.copyWith(executionTipsMd: value),
          'commsMd' => ex.copyWith(commsMd: value),
          _ => ex,
        },
      );
      out.add(exercise);
    }
    return out;
  }

  /// Reads an authored `mode`, defaulting to `ring`.
  ///
  /// An unknown value never reaches here: `mode` is declared with `enumValues` in the
  /// field table, so the parser has already rejected `mode: paralell` and passed null
  /// on. That is the right place for it — one check, driven by the same table `schema`
  /// publishes — and it is why this needs no error branch of its own. A document that
  /// names a mode the format does not have is an error, not a silent ring route.
  ExerciseMode _mode(Object? raw, String path, DiagnosticSink diagnostics) {
    final name = raw?.toString().trim().toLowerCase();
    for (final mode in ExerciseMode.values) {
      if (mode.name == name) return mode;
    }
    return ExerciseMode.ring;
  }

  /// Reads the authored parallel groups, checking what only the author can know is
  /// wrong (ADR-0062).
  ///
  /// Two rules, and they are different kinds of wrong. A team in two stations of one
  /// group is an **error**: the stations run at once, so it cannot be at both, and
  /// both placements are flagged rather than one because neither is more wrong and
  /// the author is who knows which to drop. A team in none of a group's stations is a
  /// **warning**: holding a team back is legitimate, and with groups of unequal size
  /// it is also easy to do by accident.
  List<ExerciseGroup> _groups(
    Map<String, dynamic> exercise,
    String exercisePath,
    ExerciseMode mode,
    int stationCount,
    DiagnosticSink diagnostics,
  ) {
    final raw =
        (exercise['groups'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    if (raw.isEmpty) return const [];
    if (mode != ExerciseMode.split) {
      diagnostics.warn(
        '$exercisePath.groups',
        'groups are only used by mode: split; ignored here',
        hint:
            'in ring the rotation is generated, and in together a round is a '
            'station',
      );
      return const [];
    }

    final teamCount = _positiveInt(
      exercise['numberOfTeams'],
      '$exercisePath.numberOfTeams',
      1,
    );
    final out = <ExerciseGroup>[];
    for (var g = 0; g < raw.length; g++) {
      final path = '$exercisePath.groups[$g]';
      final slotsRaw =
          (raw[g]['stations'] as List?)?.cast<Map<String, dynamic>>() ??
          const [];
      final slots = <GroupSlot>[];
      // Which station each team was placed on in this group, so a second placement
      // can name the first.
      final placedOn = <int, int>{};
      for (var i = 0; i < slotsRaw.length; i++) {
        final slotPath = '$path.stations[$i]';
        // Source keys here, not wire keys: this reads the parsed *document*, and the
        // field's `wireKey: stationIndex` only applies on the way out.
        final stationIndex = slotsRaw[i]['station'];
        if (stationIndex is! int ||
            stationIndex < 0 ||
            stationIndex >= stationCount) {
          diagnostics.error(
            '$slotPath.station',
            'no station at position $stationIndex',
            hint: 'the exercise has $stationCount station(s), counting from 0',
          );
          continue;
        }
        final teams = (slotsRaw[i]['teams'] as List?)?.cast<int>() ?? const [];
        for (final team in teams) {
          if (team < 0 || team >= teamCount) {
            diagnostics.error(
              '$slotPath.teams',
              'no team at position $team',
              hint: 'the exercise has $teamCount team(s), counting from 0',
            );
            continue;
          }
          final already = placedOn[team];
          if (already != null) {
            diagnostics.error(
              '$slotPath.teams',
              'team $team is on stations $already and $stationIndex in the '
                  'same group',
              hint:
                  'these stations run at the same time, so a team can only be '
                  'at one of them',
            );
            continue;
          }
          placedOn[team] = stationIndex;
        }
        slots.add(GroupSlot(stationIndex: stationIndex, teams: teams));
      }
      for (var team = 0; team < teamCount; team++) {
        if (!placedOn.containsKey(team)) {
          diagnostics.warn(
            path,
            'team $team has no station in this round',
            hint: 'deliberate if the team is held back; otherwise place it',
          );
        }
      }
      out.add(ExerciseGroup(stations: slots));
    }
    return out;
  }

  List<Station> _stations(
    Map<String, dynamic> exercise,
    String exercisePath,
    HeadlessLabels labels,
  ) {
    final raw =
        (exercise['stations'] as List?)?.cast<Map<String, dynamic>>() ??
        const [];
    final out = <Station>[];
    for (var i = 0; i < raw.length; i++) {
      final source = raw[i];
      final path = '$exercisePath.stations[$i]';
      final wire = <String, dynamic>{
        'index': i,
        // A station with no name still needs one to render; the app's own
        // ensureStations does exactly this, which is why the label subset
        // includes `station`.
        'name': source['name'] ?? '${labels.plural('station', 1)} ${i + 1}',
        // Absent inherits the exercise's, which is what almost every station does
        // (ADR-0062). Present and non-positive is meaningless, so it is reported
        // rather than silently making a zero-length round.
        if (source['executionTime'] != null)
          'executionTime': _positiveInt(
            source['executionTime'],
            '$path.executionTime',
            1,
          ),
        if (source['variantSuffix'] != null)
          'variantSuffix': source['variantSuffix'],
        if (source['position'] != null) 'position': source['position'],
        if (source['description'] != null) 'description': source['description'],
        'variableOverrides':
            source['variableOverrides'] ?? const <String, String>{},
        'locations': _slugged(
          source['locations'],
          '$path.locations',
          'location',
        ),
        'persons': _slugged(source['persons'], '$path.persons', 'person'),
      };

      var station = Station.fromJson(wire);
      station = _patchMarkdown(
        station,
        source,
        SourceScopes.station,
        (st, key, value) => switch (key) {
          'equipmentMd' => st.copyWith(equipmentMd: value),
          'situationMd' => st.copyWith(situationMd: value),
          'missionMd' => st.copyWith(missionMd: value),
          'logisticsMd' => st.copyWith(logisticsMd: value),
          'criticalQuestionsMd' => st.copyWith(criticalQuestionsMd: value),
          'leaderAnswersMd' => st.copyWith(leaderAnswersMd: value),
          'directorNotesMd' => st.copyWith(directorNotesMd: value),
          _ => st,
        },
      );
      out.add(station);
    }
    return out;
  }

  /// Locations and persons, validated for slug shape and uniqueness.
  ///
  /// A duplicate or malformed slug is an error rather than a warning because the
  /// slug is the whole addressing mechanism: `{{station.loc.lkp.utm}}` silently
  /// resolves to whichever entry won, and the author has no way to see which.
  List<Map<String, dynamic>> _slugged(Object? raw, String path, String what) {
    final items = (raw as List?)?.cast<Map<String, dynamic>>() ?? const [];
    final seen = <String>{};
    final out = <Map<String, dynamic>>[];
    for (var i = 0; i < items.length; i++) {
      final item = Map<String, dynamic>.from(items[i]);
      final at = '$path[$i]';
      final slug = item['slug'];
      if (slug is! String || slug.isEmpty) {
        diagnostics.error('$at.slug', 'a $what needs a slug');
        continue;
      }
      if (!_isSlug(slug)) {
        diagnostics.error(
          '$at.slug',
          '"$slug" is not a valid slug',
          hint: r'slugs must match ^[a-z][a-z0-9_]*$',
        );
      }
      if (!seen.add(slug)) {
        diagnostics.error(
          '$at.slug',
          'duplicate $what slug "$slug" on this station',
          hint: 'slugs address one entry each; make them unique',
        );
        continue;
      }
      out.add(item);
    }
    // Sorted by slug for the same reason variables are sorted by name: archive
    // order must not reach the content hash (ADR-0047).
    out.sort((a, b) => (a['slug'] as String).compareTo(b['slug'] as String));
    return out;
  }

  // --------------------------------------------------------------------------
  // Role plays
  // --------------------------------------------------------------------------

  /// Lifts role plays out of their stations and onto the plan.
  ///
  /// Nesting in the source is what makes `exerciseUuid` and `stationIndex`
  /// derivable (worked example decision 4); `RolePlay` itself stores them flat.
  /// `index` is a plan-global sequence in document order, matching how the
  /// existing archives are written.
  List<RolePlay> _rolePlays(SourceDocument document, List<Exercise> exercises) {
    final out = <RolePlay>[];
    var index = 0;
    for (var e = 0; e < document.exercises.length; e++) {
      if (e >= exercises.length) break;
      final exercise = exercises[e];
      final stations =
          (document.exercises[e]['stations'] as List?)
              ?.cast<Map<String, dynamic>>() ??
          const [];
      for (var s = 0; s < stations.length; s++) {
        final raw =
            (stations[s]['roleplays'] as List?)?.cast<Map<String, dynamic>>() ??
            const [];
        final persons = <String, Map<String, dynamic>>{
          for (final p
              in (stations[s]['persons'] as List?)
                      ?.cast<Map<String, dynamic>>() ??
                  const [])
            p['slug'] as String: p,
        };
        for (var r = 0; r < raw.length; r++) {
          final source = raw[r];
          final path =
              '${SourceDocumentKeys.exercises}[$e].stations[$s].roleplays[$r]';
          final personRef = source['personRef'] as String?;
          Map<String, dynamic>? person;
          if (personRef != null) {
            person = persons[personRef];
            if (person == null) {
              diagnostics.error(
                '$path.personRef',
                'no person "$personRef" on this station',
                hint: persons.isEmpty
                    ? 'declare the person under the station\'s persons:'
                    : 'the station declares ${persons.keys.join(', ')}',
              );
            }
          }

          // Effective identity: the role play's own value when written, the
          // person's otherwise (ADR-0047). Denormalized onto the role play so a
          // reader never sees a blank marker, and so resolution needs no lookup.
          final wire = <String, dynamic>{
            'uuid': (source['uuid'] as String?) ?? _mintUuid(),
            'index': index++,
            'exerciseUuid': exercise.uuid,
            'stationIndex': s,
            'name': source['name'] ?? person?['name'] ?? '',
            if (_inherited(source, person, 'age') != null)
              'age': _inherited(source, person, 'age'),
            if (_inherited(source, person, 'gender') != null)
              'gender': _inherited(source, person, 'gender'),
            if (_inherited(source, person, 'description') != null)
              'description': _inherited(source, person, 'description'),
            'personRef': ?personRef,
          };

          // Position follows the person's location unless overridden — the same
          // inherit-or-override rule the editor applies when a person is
          // selected (DESIGN-009 prompt 4i).
          final position =
              source['position'] ?? _personPosition(person, stations[s]);
          if (position != null) wire['position'] = position;

          var rolePlay = RolePlay.fromJson(wire);
          rolePlay = _patchMarkdown(
            rolePlay,
            source,
            SourceScopes.roleplay,
            (rp, key, value) => switch (key) {
              'behavior' => rp.copyWith(behavior: value),
              'background' => rp.copyWith(background: value),
              'propsMd' => rp.copyWith(propsMd: value),
              _ => rp,
            },
          );
          out.add(rolePlay);
        }
      }
    }
    return out;
  }

  Object? _inherited(
    Map<String, dynamic> source,
    Map<String, dynamic>? person,
    String key,
  ) => source.containsKey(key) ? source[key] : person?[key];

  /// The coordinate of the location a person points at, if any.
  Map<String, dynamic>? _personPosition(
    Map<String, dynamic>? person,
    Map<String, dynamic> station,
  ) {
    final locSlug = person?['locSlug'];
    if (locSlug is! String) return null;
    final locations =
        (station['locations'] as List?)?.cast<Map<String, dynamic>>() ??
        const [];
    for (final location in locations) {
      if (location['slug'] == locSlug) {
        return location['position'] as Map<String, dynamic>?;
      }
    }
    return null;
  }

  // --------------------------------------------------------------------------
  // Teams
  // --------------------------------------------------------------------------

  /// The team roster: authored when given, otherwise derived.
  ///
  /// Mirrors `PlanService.ensureTeams`: as many teams as the largest
  /// `numberOfTeams` across the exercises, and an authored list longer than that
  /// wins rather than being truncated — `max(numberOfTeams, teams.length)`. A
  /// roster longer than any exercise can seat is legitimate (several teams
  /// grouped into one temporary team for a full-scale exercise), so it warns
  /// rather than failing.
  List<Team> _teams(
    SourceDocument document,
    List<Exercise> exercises,
    HeadlessLabels labels,
  ) {
    final authored = document.teams;
    final needed = exercises.fold<int>(
      0,
      (acc, ex) => max(acc, ex.numberOfTeams),
    );
    final count = max(needed, authored.length);

    if (authored.length > needed && needed > 0) {
      final surplus = authored.length - needed;
      diagnostics.warn(
        SourceDocumentKeys.teams,
        '$surplus team(s) have no slot: no exercise runs more than $needed '
        'team(s)',
        hint:
            'expected when teams are grouped into one temporary team for a '
            'full-scale exercise; otherwise raise numberOfTeams or drop them',
      );
    }

    return [
      for (var i = 0; i < count; i++)
        Team.fromJson({
          'uuid':
              (i < authored.length ? authored[i]['uuid'] as String? : null) ??
              _mintUuid(),
          'index': i,
          'name':
              (i < authored.length ? authored[i]['name'] as String? : null) ??
              '${labels.plural('team', 1)} ${i + 1}',
          if (i < authored.length && authored[i]['numberOfMembers'] != null)
            'numberOfMembers': authored[i]['numberOfMembers'],
          if (i < authored.length && authored[i]['position'] != null)
            'position': authored[i]['position'],
        }),
    ];
  }

  // --------------------------------------------------------------------------
  // Shared helpers
  // --------------------------------------------------------------------------

  /// Applies every markdown field [scope] declares, via [apply].
  ///
  /// Table-driven so adding a markdown field to a scope needs one table entry
  /// plus one `switch` arm, and forgetting the arm is a visible hole rather than
  /// a silently dropped field.
  T _patchMarkdown<T>(
    T entity,
    Map<String, dynamic> source,
    SourceScope scope,
    T Function(T entity, String wireKey, String value) apply,
  ) {
    var out = entity;
    for (final field in scope.markdownFields) {
      final value = source[field.sourceKey];
      if (value is String) out = apply(out, field.wireKey, value);
    }
    return out;
  }

  T _enum<T extends Enum>(Object? raw, List<T> values, T fallback) {
    if (raw is! String) return fallback;
    for (final value in values) {
      if (value.name == raw) return value;
    }
    return fallback;
  }

  int _positiveInt(Object? raw, String path, int minimum) {
    final value = raw is int ? raw : null;
    if (value == null) {
      diagnostics.error(path, 'this field is required and must be a number');
      return minimum;
    }
    if (value < minimum) {
      diagnostics.error(path, '$value is below the minimum of $minimum');
      return minimum;
    }
    return value;
  }

  num? _num(Object? raw) {
    if (raw is num) return raw;
    if (raw is String) return num.tryParse(raw.trim());
    return null;
  }

  static bool _isSlug(String value) =>
      RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(value);
}
