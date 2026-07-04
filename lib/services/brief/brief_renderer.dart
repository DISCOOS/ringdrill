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
import 'package:ringdrill/models/numbering.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/brief/brief_audience.dart';
import 'package:ringdrill/services/brief/template_registry.dart';
import 'package:ringdrill/utils/exercise_share_format.dart';
import 'package:ringdrill/utils/projection.dart';

/// Thrown when a brief template asset cannot be loaded from the bundle.
///
/// Surfaced to the user as a clean, actionable message instead of the raw
/// Flutter "Unable to load asset" exception. The usual cause is that the
/// running build's `AssetManifest` predates a newly added template asset: a
/// hot reload or hot restart does not regenerate the manifest, and an
/// offline-first PWA may serve a stale service-worker cache. A full restart
/// (or a clean rebuild and hard refresh on web) resolves it.
class BriefTemplateException implements Exception {
  const BriefTemplateException({
    required this.templateId,
    required this.assetPath,
    this.cause,
  });

  /// Id of the template that failed to resolve, e.g. `ringdrill-standard-v1`.
  final String templateId;

  /// Asset path the renderer tried to load via the bundle.
  final String assetPath;

  /// The underlying error thrown by the asset bundle, if any.
  final Object? cause;

  @override
  String toString() =>
      'BriefTemplateException(templateId: $templateId, '
      'assetPath: $assetPath, cause: $cause)';
}

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
    final template = _registry.resolve(exercise?.templateId, l10n.localeName);
    final String source;
    try {
      source = await _bundle.loadString(template.assetPath);
    } catch (e) {
      throw BriefTemplateException(
        templateId: template.id,
        assetPath: template.assetPath,
        cause: e,
      );
    }
    final mustache = Template(source, htmlEscapeValues: false);

    final exercises = exercise != null ? [exercise] : program.exercises;

    final actorMap = {for (final a in program.actors) a.uuid: a};
    final rolePlaysByExercise = <String, List<RolePlay>>{};
    for (final rp in program.rolePlays) {
      rolePlaysByExercise.putIfAbsent(rp.exerciseUuid, () => []).add(rp);
    }

    final programVars = _programVariables(program);
    final programRefContext = _programRefContext(program);

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
        'briefIntroMd': _resolveField(
          program.briefIntroMd,
          vars: programVars,
          l10n: l10n,
          refContext: programRefContext,
        ),
        'commsMd': _resolveField(
          program.commsMd,
          vars: programVars,
          l10n: l10n,
          refContext: programRefContext,
        ),
      },
      'exercises': exerciseContexts,
      'if_director': audience.includesActorPii,
      'if_instructor_or_director': audience.includesDirectorNotes,
      'if_in_doc_toc': !wideTocSidebar,
      // Single-exercise mode skips the program-level header (H1, description,
      // in-doc TOC, briefIntroMd, commsMd, divider) because the reader is
      // looking at one exercise, not the whole program. The template wraps
      // those blocks in an inverted section keyed on this flag.
      'isSingleExercise': exercise != null,
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
    final exerciseVars = _effectiveVariables(program, exercise: exercise);
    final effectiveComms = _resolveField(
      _effectiveCommsMd(program, exercise),
      vars: exerciseVars,
      l10n: l10n,
    );

    final stationContexts = exercise.stations.map((station) {
      return _buildStationContext(
        program: program,
        exercise: exercise,
        exerciseNumber: exNum,
        station: station,
        audience: audience,
        actorMap: actorMap,
        rolePlays: rolePlays
            .where((rp) => rp.stationIndex == station.index)
            .toList(),
        effectiveCommsMd: effectiveComms,
        l10n: l10n,
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
      'methodMd': _resolveField(exercise.methodMd, vars: exerciseVars, l10n: l10n),
      'learningGoalsMd': _resolveField(
        exercise.learningGoalsMd,
        vars: exerciseVars,
        l10n: l10n,
      ),
      'trainingFocusMd': _resolveField(
        exercise.trainingFocusMd,
        vars: exerciseVars,
        l10n: l10n,
      ),
      'orderFormatMd': _resolveField(
        exercise.orderFormatMd,
        vars: exerciseVars,
        l10n: l10n,
      ),
      'executionTipsMd': _resolveField(
        exercise.executionTipsMd,
        vars: exerciseVars,
        l10n: l10n,
      ),
      'effectiveCommsMd': effectiveComms,
      'organisationBlock': _organisationBlock(program, exercise, l10n),
      'stations': stationContexts,
    };
  }

  Map<String, dynamic> _buildStationContext({
    required Program program,
    required Exercise exercise,
    required int exerciseNumber,
    required Station station,
    required BriefAudience audience,
    required Map<String, Actor> actorMap,
    required List<RolePlay> rolePlays,
    required String? effectiveCommsMd,
    required AppLocalizations l10n,
  }) {
    final stationCode = Numbering.station(
      program.stationNumberFormat,
      exerciseNumber: exerciseNumber,
      stationIndex: station.index,
    );
    final utmStr = _formatUtm(station.position);
    // Pre-formatted markdown for the "Post Nx plassering:" value. Renders as
    // an inline-code chip when the station has a UTM position, or as a
    // muted italic "no position" label when the position is null/empty.
    final positionValue = utmStr.isEmpty
        ? '_${l10n.briefStationNoPosition}_'
        : '`$utmStr`';
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

    final stationVars = _effectiveVariables(
      program,
      exercise: exercise,
      station: station,
    );

    String? resolveField(String? content) => _resolveField(
      content,
      vars: stationVars,
      l10n: l10n,
      refContext: stationRefContext,
    );

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
      '$stationCode – $cleanName'
      '${station.variantSuffix != null ? ' – ${station.variantSuffix}' : ''}',
    );

    return {
      'name': cleanName,
      'variantSuffix': station.variantSuffix,
      'stationCode': stationCode,
      'stationAnchor': stationAnchor,
      'position': {'utm': utmStr},
      'positionValue': positionValue,
      'stationDurationLabel': _stationDurationLabel(exercise),
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

  /// Converts [heading] to the same GitHub-flavored anchor id the template
  /// emits as link targets in the in-doc table of contents (lowercase,
  /// non-word characters dropped, runs of whitespace collapsed to a single
  /// hyphen). Exposed so callers — primarily `BriefScreen` — can resolve
  /// `#anchor` link taps against the rendered heading list without
  /// duplicating the slug logic.
  static String toAnchor(String heading) => _toAnchor(heading);

  /// Declared plan variables, keyed by name, at the program scope.
  @visibleForTesting
  static Map<String, String> programVariables(Program program) =>
      _programVariables(program);

  /// Effective variable values for a scope: the program's declared values
  /// overlaid by [exercise]'s overrides, then by [station]'s overrides. See
  /// ADR-0046 for the resolution chain.
  @visibleForTesting
  static Map<String, String> effectiveVariables(
    Program program, {
    Exercise? exercise,
    Station? station,
  }) => _effectiveVariables(program, exercise: exercise, station: station);

  /// Replaces every `{{var.<name>}}` token in [content] with its value in
  /// [vars], or with the localized unknown-variable placeholder when
  /// `<name>` is not a key of [vars].
  @visibleForTesting
  static String substituteVariables(
    String content,
    Map<String, String> vars,
    AppLocalizations l10n,
  ) => _substituteVariables(content, vars, l10n);
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
      ? l10n.hour(total ~/ 60)
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
  // Ringløype line: keep config + legend on the same physical line so the
  // legend doesn't wrap unnecessarily on wide screens. Markdown reflows the
  // line if the viewport is too narrow to fit both.
  final buf = StringBuffer()
    ..writeln(
      '**${l10n.briefRingRoute}:** '
      '${exercise.numberOfRounds} x ($phases) '
      '_(${l10n.rotationShareLegendPhases})_',
    )
    ..writeln();
  final beforeRound = _resolveField(
    program.beforeRoundMd,
    vars: _programVariables(program),
    l10n: l10n,
    refContext: _programRefContext(program),
  );
  if (beforeRound != null && beforeRound.isNotEmpty) {
    buf
      ..writeln(beforeRound)
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

/// Partial program context for cross-reference resolution inside
/// program-scope markdown fields (e.g. `{{program.name}}` inside
/// `briefIntroMd`), mirroring `_buildStationContext`'s `stationRefContext`.
///
/// Without this, `{{program.name}}` has no key to resolve against —
/// `mustache_template` throws "Value was missing for variable tag" for an
/// absent key (not a silent empty string), which `_resolveField`'s
/// catch-all then turns into "leave the field's mustache pass unrendered",
/// so the literal `{{program.name}}` stayed in the output instead of being
/// substituted.
Map<String, dynamic> _programRefContext(Program program) => {
  'program': {'name': program.name, 'description': program.description},
};

// Matches `{{var.<name>}}`, tolerating inner whitespace around the name.
// Only `var.*` tokens are handled here — every other `{{...}}` expression is
// left untouched for the subsequent mustache pass.
final _varTokenPattern = RegExp(r'\{\{\s*var\.([a-z][a-z0-9_]*)\s*\}\}');

/// Declared plan variables, keyed by name, at the program scope.
Map<String, String> _programVariables(Program program) => {
  for (final v in program.variables) v.name: v.value,
};

/// Effective variable values for a scope (ADR-0046): start from the
/// program's declared values, then overlay [exercise]'s overrides, then
/// [station]'s overrides — later scopes win. An override key that is not a
/// declared variable name is ignored, per ADR-0046's "undeclared override
/// key is meaningless" rule.
Map<String, String> _effectiveVariables(
  Program program, {
  Exercise? exercise,
  Station? station,
}) {
  final vars = _programVariables(program);
  if (exercise != null) {
    for (final entry in exercise.variableOverrides.entries) {
      if (vars.containsKey(entry.key)) vars[entry.key] = entry.value;
    }
  }
  if (station != null) {
    for (final entry in station.variableOverrides.entries) {
      if (vars.containsKey(entry.key)) vars[entry.key] = entry.value;
    }
  }
  return vars;
}

/// Replaces every `{{var.<name>}}` token in [content] with its effective
/// value, or with the localized unknown-variable placeholder when `<name>`
/// is not declared. A declared-but-empty variable substitutes the empty
/// string — that is a valid authoring state, not an error (ADR-0046).
///
/// Runs before the mustache pass (see [BriefRenderer]'s `resolveField`), so
/// cross-references like `{{station.position.utm}}` are still handled by the
/// existing `Template(...).renderString(...)` call afterwards. A variable
/// *value* that itself contains `{{...}}` is inserted literally here and may
/// be re-parsed by that subsequent mustache pass — authors should not put
/// mustache syntax in variable values in v1.
String _substituteVariables(
  String content,
  Map<String, String> vars,
  AppLocalizations l10n,
) {
  return content.replaceAllMapped(_varTokenPattern, (match) {
    final name = match.group(1)!;
    return vars[name] ?? l10n.briefUnknownVariable(name);
  });
}

/// Resolves a markdown field for rendering: substitutes `{{var.<name>}}`
/// tokens against [vars] first, then feeds the result through the existing
/// mustache cross-reference pass against [refContext] (e.g.
/// `{{station.position.utm}}`). Falls back to the variable-substituted (but
/// not mustache-rendered) content if that pass throws — the same fallback
/// behaviour the renderer had before variable substitution was introduced.
String? _resolveField(
  String? content, {
  required Map<String, String> vars,
  required AppLocalizations l10n,
  Map<String, dynamic> refContext = const {},
}) {
  if (content == null) return null;
  final withVars = _substituteVariables(content, vars, l10n);
  try {
    return Template(withVars, htmlEscapeValues: false).renderString(refContext);
  } catch (_) {
    return withVars;
  }
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
