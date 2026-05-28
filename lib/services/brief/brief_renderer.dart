/// BriefRenderer — renders a program or single-exercise brief as markdown.
///
/// The renderer is a pure function over the in-memory [Program]. It does not
/// call [DrillFile.fromProgram] or [program()]. The brief is rendered after
/// the program is already loaded.
///
/// Template authors: fields that contain literal `{{` not intended as mustache
/// must be escaped with the `{{=<% %>=}}` delimiter-change pragma at the start
/// of the field content, e.g. `{{=<% %>=}} some {{literal}} text <%={{ }}=%>`.
library;

import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:meta/meta.dart';
import 'package:mustache_template/mustache_template.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/actor.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/brief/brief_audience.dart';
import 'package:ringdrill/services/brief/template_registry.dart';
import 'package:ringdrill/utils/exercise_share_format.dart';
import 'package:ringdrill/utils/projection.dart';

class BriefRenderer {
  BriefRenderer({TemplateRegistry? registry, AssetBundle? bundle})
    : _registry = registry ?? TemplateRegistry.instance,
      _bundle = bundle ?? rootBundle;

  final TemplateRegistry _registry;
  final AssetBundle _bundle;

  /// Renders a brief for [program]. When [exercise] is non-null, scopes the
  /// brief to that exercise. When null, renders the whole program. The
  /// template is resolved from [exercise?.templateId] (single-exercise mode)
  /// or from the system default (program mode).
  ///
  /// [wideTocSidebar] signals that [BriefScreen] is displaying a dedicated
  /// sidebar TOC (wide layout). When `true`, the mustache context sets
  /// `if_in_doc_toc` to `false`, suppressing the duplicate in-document
  /// `## Innholdsfortegnelse` block. When `false` (default), the in-document
  /// TOC is rendered so narrow-screen readers still have a contents list.
  Future<String> render({
    required Program program,
    Exercise? exercise,
    required BriefAudience audience,
    required AppLocalizations l10n,
    bool wideTocSidebar = false,
  }) async {
    final template = _registry.resolve(exercise?.templateId);
    final source = await _bundle.loadString(template.assetPath);
    final mustache = Template(source, htmlEscapeValues: false);

    final exercises = exercise != null ? [exercise] : program.exercises;

    final actorMap = {for (final a in program.actors) a.uuid: a};
    final rolePlaysByExercise = <String, List<RolePlay>>{};
    for (final rp in program.rolePlays) {
      rolePlaysByExercise.putIfAbsent(rp.exerciseUuid, () => []).add(rp);
    }

    final exerciseContexts = exercises.map((ex) {
      return _buildExerciseContext(
        program: program,
        exercise: ex,
        audience: audience,
        actorMap: actorMap,
        rolePlays: rolePlaysByExercise[ex.uuid] ?? [],
        l10n: l10n,
      );
    }).toList();

    final context = {
      'program': {
        'name': program.name,
        'description': program.description.isEmpty ? null : program.description,
        'briefIntroMd': program.briefIntroMd,
        'commsMd': program.commsMd,
      },
      'exercises': exerciseContexts,
      'if_director': audience.includesActorPii,
      'if_instructor_or_director': audience.includesDirectorNotes,
      'if_in_doc_toc': !wideTocSidebar,
    };

    return mustache.renderString(context);
  }

  Map<String, dynamic> _buildExerciseContext({
    required Program program,
    required Exercise exercise,
    required BriefAudience audience,
    required Map<String, Actor> actorMap,
    required List<RolePlay> rolePlays,
    required AppLocalizations l10n,
  }) {
    final exNum = _exerciseNumber(program, exercise);
    final effectiveComms = _effectiveCommsMd(program, exercise);

    final stationContexts = exercise.stations.map((station) {
      return _buildStationContext(
        exercise: exercise,
        exerciseNumber: exNum,
        station: station,
        audience: audience,
        actorMap: actorMap,
        rolePlays: rolePlays
            .where((rp) => rp.stationIndex == station.index)
            .toList(),
        effectiveCommsMd: effectiveComms,
      );
    }).toList();

    // Anchor id for table of contents: lowercase, spaces to hyphens.
    final exerciseAnchor = _toAnchor(exercise.name);

    return {
      'name': exercise.name,
      'exerciseNumber': exNum,
      'exerciseAnchor': exerciseAnchor,
      'exerciseTimeLabel': _exerciseTimeLabel(exercise),
      'exerciseDurationLabel': _exerciseDurationLabel(exercise, l10n),
      'methodMd': exercise.methodMd,
      'learningGoalsMd': exercise.learningGoalsMd,
      'trainingFocusMd': exercise.trainingFocusMd,
      'orderFormatMd': exercise.orderFormatMd,
      'executionTipsMd': exercise.executionTipsMd,
      'effectiveCommsMd': effectiveComms,
      'organisationBlock': _organisationBlock(program, exercise, l10n),
      'stations': stationContexts,
      // Kept for backward compat with the old template until Step 4 swaps it.
      'durationLabel': _exerciseDurationLabel(exercise, l10n),
      'setupLabel': _legacySetupLabel(exercise),
    };
  }

  Map<String, dynamic> _buildStationContext({
    required Exercise exercise,
    required int exerciseNumber,
    required Station station,
    required BriefAudience audience,
    required Map<String, Actor> actorMap,
    required List<RolePlay> rolePlays,
    required String? effectiveCommsMd,
  }) {
    final letter = _stationLetter(station);
    final utmStr = _formatUtm(station.position);
    // Strip leading "Nx) " prefix — temporary workaround pending data cleanup.
    // The underlying Station.name is left unchanged.
    final cleanName = station.name.replaceFirst(_kStationNamePrefix, '');

    // Build a partial station context for cross-reference resolution inside
    // markdown fields (e.g. {{station.position.utm}} inside situationMd).
    final stationRefContext = {
      'station': {
        'name': cleanName,
        'position': {'utm': utmStr},
      },
    };

    String? resolveField(String? content) {
      if (content == null) return null;
      try {
        return Template(
          content,
          htmlEscapeValues: false,
        ).renderString(stationRefContext);
      } catch (_) {
        return content;
      }
    }

    final roleplayContexts = rolePlays.map((rp) {
      Map<String, dynamic>? actorContext;
      if (audience.includesActorPii && rp.actorUuid != null) {
        final actor = actorMap[rp.actorUuid];
        if (actor != null) {
          actorContext = {'realName': actor.realName, 'phone': actor.phone};
        }
      }
      return {
        'name': rp.name,
        'age': rp.age,
        'signalement': rp.signalement,
        'behavior': resolveField(rp.behavior),
        'background': resolveField(rp.background),
        'propsMd': resolveField(rp.propsMd),
        'actor': actorContext,
        'if_director': audience.includesActorPii,
      };
    }).toList();

    final stationAnchor = _toAnchor(
      '$exerciseNumber$letter – $cleanName'
      '${station.variantSuffix != null ? ' – ${station.variantSuffix}' : ''}',
    );

    return {
      'name': cleanName,
      'variantSuffix': station.variantSuffix,
      'exerciseNumber': exerciseNumber,
      'stationLetter': letter,
      'stationAnchor': stationAnchor,
      'position': {'utm': utmStr},
      'stationDurationLabel': _stationDurationLabel(exercise),
      // Kept for backward compat with the old template until Step 4 swaps it.
      'durationLabel': _stationDurationLabel(exercise),
      'equipmentMd': resolveField(station.equipmentMd),
      'situationMd': resolveField(station.situationMd),
      'missionMd': resolveField(station.missionMd),
      'logisticsMd': resolveField(station.logisticsMd),
      'criticalQuestionsMd': resolveField(station.criticalQuestionsMd),
      'leaderAnswersMd': resolveField(station.leaderAnswersMd),
      'directorNotesMd': audience.includesDirectorNotes
          ? resolveField(station.directorNotesMd)
          : null,
      'effectiveCommsMd': effectiveCommsMd,
      'roleplays': roleplayContexts,
      'if_director': audience.includesActorPii,
      'if_instructor_or_director': audience.includesDirectorNotes,
    };
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Returns the 1-based position of [exercise] in [program]'s exercise list.
  @visibleForTesting
  static int exerciseNumber(Program program, Exercise exercise) =>
      _exerciseNumber(program, exercise);

  /// Returns the lowercase letter for [station] based on its index.
  /// index 0 → 'a', index 1 → 'b', ..., index 25 → 'z'.
  @visibleForTesting
  static String stationLetter(Station station) => _stationLetter(station);

  /// Clock-time span for the exercise: "08:30–10:30".
  /// "Tid" in copy is reserved for clock-time, never duration.
  @visibleForTesting
  static String exerciseTimeLabel(Exercise exercise) =>
      _exerciseTimeLabel(exercise);

  /// Total duration plus per-round breakdown for the exercise.
  /// Examples: "2 timer (60 min pr oppdrag)", "90 min (30 min pr oppdrag)".
  @visibleForTesting
  static String exerciseDurationLabel(
    Exercise exercise,
    AppLocalizations l10n,
  ) => _exerciseDurationLabel(exercise, l10n);

  /// Per-round duration with phase breakdown for a station: "30 min (15 | 10 | 5)".
  @visibleForTesting
  static String stationDurationLabel(Exercise exercise) =>
      _stationDurationLabel(exercise);

  /// Full Organisering markdown block.
  @visibleForTesting
  static String organisationBlock(
    Program program,
    Exercise exercise,
    AppLocalizations l10n,
  ) => _organisationBlock(program, exercise, l10n);

  /// Formats [latLng] as "32V 0580414E 6552008N" (UTM, easting before
  /// northing). Returns empty string when [latLng] is null.
  @visibleForTesting
  static String formatUtm(LatLng? latLng) => _formatUtm(latLng);
}

// ---------------------------------------------------------------------------
// Private helpers (top-level functions for testability via @visibleForTesting
// static wrappers above)
// ---------------------------------------------------------------------------

// Matches leading "Nx) " or "Nxy) " station-name prefixes.
// Workaround pending data cleanup of Station.name — see ADR-0023 follow-up 01.
final _kStationNamePrefix = RegExp(r'^[0-9]+[a-z]\)\s*');

int _exerciseNumber(Program program, Exercise exercise) {
  final idx = program.exercises.indexWhere((e) => e.uuid == exercise.uuid);
  return idx < 0 ? 1 : idx + 1;
}

String _stationLetter(Station station) {
  return String.fromCharCode('a'.codeUnitAt(0) + station.index);
}

/// Clock-time span for the exercise: "08:30–10:30".
/// "Tid" in copy is reserved for clock-time, never duration.
String _exerciseTimeLabel(Exercise exercise) {
  return '${exercise.startTime}–${exercise.endTime}';
}

/// Total duration with per-round breakdown.
/// "2 timer (60 min pr oppdrag)" when total is a whole number of hours,
/// "90 min (30 min pr oppdrag)" otherwise. Single-round exercises show
/// just the total without the per-round suffix.
String _exerciseDurationLabel(Exercise exercise, AppLocalizations l10n) {
  final round =
      exercise.executionTime + exercise.evaluationTime + exercise.rotationTime;
  final total = exercise.numberOfRounds * round;
  final totalStr = (total >= 60 && total % 60 == 0)
      ? '${total ~/ 60} timer'
      : '$total min';
  if (exercise.numberOfRounds <= 1) return totalStr;
  return '$totalStr ($round min ${l10n.briefPerStation})';
}

/// Per-round duration with phase breakdown for a station: "30 min (15 | 10 | 5)".
String _stationDurationLabel(Exercise exercise) {
  final round =
      exercise.executionTime + exercise.evaluationTime + exercise.rotationTime;
  return '$round min (${rotationPhaseBreakdown(exercise)})';
}

/// Full Organisering markdown block used in the brief template.
String _organisationBlock(
  Program program,
  Exercise exercise,
  AppLocalizations l10n,
) {
  final phases = rotationPhaseBreakdown(exercise);
  final buf = StringBuffer()
    ..writeln(
      '**${l10n.briefRingRoute}:** '
      '${exercise.numberOfRounds} x ($phases)',
    )
    ..writeln('_(${l10n.rotationShareLegendPhases})_')
    ..writeln();
  if (program.beforeRoundMd != null && program.beforeRoundMd!.isNotEmpty) {
    buf
      ..writeln(program.beforeRoundMd)
      ..writeln();
  }
  buf
    ..writeln('**${l10n.rotationShareTitle}**')
    ..writeln();
  for (final r in rotationRounds(exercise, l10n)) {
    buf.writeln(
      '- ${l10n.round(1)} ${r.index}: ${r.timesText} _(${r.suffix})_',
    );
  }
  return buf.toString().trimRight();
}

/// Legacy setup label kept until Step 4 replaces the template.
String _legacySetupLabel(Exercise exercise) {
  final config =
      '${exercise.numberOfRounds} x (${exercise.executionTime} \\| '
      '${exercise.evaluationTime} \\| ${exercise.rotationTime})';
  final schedule = exercise.schedule;
  if (schedule.isEmpty) return config;
  final roundStarts = <String>[];
  for (final round in schedule) {
    if (round.isNotEmpty) {
      roundStarts.add(round.first.toString());
    }
  }
  if (roundStarts.isEmpty) return config;
  return '$config<br>${roundStarts.join(', ')}';
}

/// Formats a UTM coordinate as "32V 0580414E 6552008N" — zone+band, then
/// zero-padded 7-digit easting with 'E', then zero-padded 7-digit northing
/// with 'N'.  Returns empty string when [latLng] is null.
String _formatUtm(LatLng? latLng) {
  if (latLng == null) return '';
  final utm = latLng.utm();
  final e = utm.easting.toStringAsFixed(0).padLeft(7, '0');
  final n = utm.northing.toStringAsFixed(0).padLeft(7, '0');
  return '${utm.zone}${utm.band} ${e}E ${n}N';
}

String? _effectiveCommsMd(Program program, Exercise exercise) {
  return exercise.commsMd ?? program.commsMd;
}

/// Converts a heading string to a GitHub-flavored markdown anchor id:
/// lowercase, trim, replace spaces and special chars with hyphens.
String _toAnchor(String heading) {
  return heading
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w\s-]'), '')
      .trim()
      .replaceAll(RegExp(r'[\s]+'), '-')
      .replaceAll(RegExp(r'-+'), '-');
}
