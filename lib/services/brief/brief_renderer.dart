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
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/numbering.dart';
import 'package:ringdrill/models/person.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/brief/brief_audience.dart';
import 'package:ringdrill/services/brief/template_registry.dart';
import 'package:ringdrill/utils/exercise_share_format.dart';
import 'package:ringdrill/utils/plan_variables.dart';
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
    final programName = _substituteVariables(program.name, programVars, l10n);
    final programDescription = _substituteVariables(
      program.description,
      programVars,
      l10n,
    );

    final exerciseContexts = exercises.map((ex) {
      return _buildExerciseContext(
        program: program,
        exercise: ex,
        audience: audience,
        actorMap: actorMap,
        rolePlays: rolePlaysByExercise[ex.uuid] ?? [],
        l10n: l10n,
        programRefContext: programRefContext,
      );
    }).toList();

    final context = {
      'program': {
        'name': programName,
        'description': programDescription.isEmpty ? null : programDescription,
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
    required Map<String, dynamic> programRefContext,
  }) {
    final exNum = _exerciseNumber(program, exercise);
    final exerciseVars = _effectiveVariables(program, exercise: exercise);
    // Cascades program cross-references (e.g. {{program.name}}) into
    // exercise-scope fields too, on top of this exercise's own {{exercise.*}}
    // — mirrors the ADR-0046 variable cascade applied to cross-references.
    final exerciseRefContext = {
      ...programRefContext,
      ..._exerciseRefContext(exercise, l10n),
    };
    final effectiveComms = _resolveField(
      _effectiveCommsMd(program, exercise),
      vars: exerciseVars,
      l10n: l10n,
      refContext: exerciseRefContext,
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
        exerciseRefContext: exerciseRefContext,
      );
    }).toList();

    final exerciseName = _substituteVariables(
      exercise.name,
      exerciseVars,
      l10n,
    );
    // Anchor id for table of contents: lowercase, spaces to hyphens. Derived
    // from the resolved name so the in-doc contents link matches the heading
    // the template actually renders.
    final exerciseAnchor = _toAnchor(exerciseName);

    return {
      'name': exerciseName,
      'exerciseNumber': exNum,
      'exerciseAnchor': exerciseAnchor,
      'exerciseTimeLabel': _exerciseTimeLabel(exercise),
      'exerciseDurationLabel': _exerciseDurationLabel(exercise, l10n),
      'methodMd': _resolveField(
        exercise.methodMd,
        vars: exerciseVars,
        l10n: l10n,
        refContext: exerciseRefContext,
      ),
      'learningGoalsMd': _resolveField(
        exercise.learningGoalsMd,
        vars: exerciseVars,
        l10n: l10n,
        refContext: exerciseRefContext,
      ),
      'trainingFocusMd': _resolveField(
        exercise.trainingFocusMd,
        vars: exerciseVars,
        l10n: l10n,
        refContext: exerciseRefContext,
      ),
      'orderFormatMd': _resolveField(
        exercise.orderFormatMd,
        vars: exerciseVars,
        l10n: l10n,
        refContext: exerciseRefContext,
      ),
      'executionTipsMd': _resolveField(
        exercise.executionTipsMd,
        vars: exerciseVars,
        l10n: l10n,
        refContext: exerciseRefContext,
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
    required Map<String, dynamic> exerciseRefContext,
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

    // Cascades program + exercise cross-references on top of this station's
    // own {{station.*}} — a station field can reference e.g.
    // {{exercise.name}} or {{program.name}} as well as {{station.name}}.
    final stationRefContext = {
      ...exerciseRefContext,
      'station': {
        'name': cleanName,
        'stationCode': stationCode,
        'description': station.description,
        'variantSuffix': station.variantSuffix,
        'position': {'utm': utmStr},
      },
    };

    final stationVars = _effectiveVariables(
      program,
      exercise: exercise,
      station: station,
    );
    final resolvedStationName = _substituteVariables(
      cleanName,
      stationVars,
      l10n,
    );

    String? resolveField(String? content) => _resolveField(
      content,
      vars: stationVars,
      l10n: l10n,
      refContext: stationRefContext,
      scenarioStation: station,
      scenarioRolePlays: rolePlays,
    );

    final roleplayContexts = rolePlays.map((rp) {
      Map<String, dynamic>? actorContext;
      if (audience.includesActorPii && rp.actorUuid != null) {
        final actor = actorMap[rp.actorUuid];
        if (actor != null) {
          actorContext = {'realName': actor.realName, 'phone': actor.phone};
        }
      }
      final resolvedRpName = _substituteVariables(rp.name, stationVars, l10n);
      // Cascades station (+ exercise + program) on top of this roleplay's
      // own {{roleplay.*}} — roleplay fields resolve through the station's
      // effective variables too, per DESIGN-008 ("a roleplay reads through
      // its station's overrides at render time").
      final roleplayRefContext = {
        ...stationRefContext,
        'roleplay': {
          'name': rp.name,
          'age': rp.age,
          'signalement': rp.signalement,
          'position': {'utm': _formatUtm(rp.position)},
        },
      };
      String? resolveRoleplayField(String? content) => _resolveField(
        content,
        vars: stationVars,
        l10n: l10n,
        refContext: roleplayRefContext,
        scenarioStation: station,
        scenarioRolePlays: rolePlays,
      );
      return {
        'name': resolvedRpName,
        'age': rp.age,
        'signalement': rp.signalement,
        'behavior': resolveRoleplayField(rp.behavior),
        'background': resolveRoleplayField(rp.background),
        'propsMd': resolveRoleplayField(rp.propsMd),
        'actor': actorContext,
        'if_director': audience.includesActorPii,
      };
    }).toList();

    final stationAnchor = _toAnchor(
      '$stationCode – $resolvedStationName'
      '${station.variantSuffix != null ? ' – ${station.variantSuffix}' : ''}',
    );

    return {
      'name': resolvedStationName,
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

  /// Resolves `{{var.<name>}}` tokens and program-scope cross-references
  /// (`{{program.name}}`, `{{program.description}}`) in [content] against
  /// [program]. For lightweight previews of a program-scope markdown field
  /// — e.g. the Program view's collapsed overview card — that show a
  /// snippet of `briefIntroMd`/`commsMd`/`beforeRoundMd` without running
  /// the full brief template through [render].
  static String resolveProgramScopeText(
    Program program,
    String content,
    AppLocalizations l10n,
  ) =>
      _resolveField(
        content,
        vars: _programVariables(program),
        l10n: l10n,
        refContext: _programRefContext(program),
      ) ??
      content;

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

/// Partial exercise context for cross-reference resolution inside
/// exercise-scope markdown fields (`methodMd`, `learningGoalsMd`,
/// `trainingFocusMd`, `orderFormatMd`, `executionTipsMd`, `commsMd`) —
/// same rationale as [_programRefContext]. Cascaded into station and
/// roleplay refContexts too (see `_buildStationContext`), so
/// `{{exercise.name}}` also resolves from inside a station or roleplay
/// field, not just the exercise's own.
Map<String, dynamic> _exerciseRefContext(
  Exercise exercise,
  AppLocalizations l10n,
) => {
  'exercise': {
    'name': exercise.name,
    'numberOfTeams': exercise.numberOfTeams,
    'numberOfRounds': exercise.numberOfRounds,
    'startTime': exercise.startTime.toString(),
    'endTime': exercise.endTime.toString(),
    'timeLabel': _exerciseTimeLabel(exercise),
    'durationLabel': _exerciseDurationLabel(exercise, l10n),
    'executionTime': exercise.executionTime,
    'evaluationTime': exercise.evaluationTime,
    'rotationTime': exercise.rotationTime,
    'phaseBreakdown': rotationPhaseBreakdown(exercise),
  },
};

/// Declared plan variables, keyed by name, at the program scope. Delegates
/// to the shared `lib/utils/plan_variables.dart` helper (DESIGN-008
/// follow-up 06) — kept as a private wrapper here so every call site below
/// (and the `@visibleForTesting` statics) stays unchanged.
Map<String, String> _programVariables(Program program) =>
    effectivePlanVariables(program);

/// Effective variable values for a scope (ADR-0046) — see
/// [effectivePlanVariables] for the resolution rule.
Map<String, String> _effectiveVariables(
  Program program, {
  Exercise? exercise,
  Station? station,
}) => effectivePlanVariables(program, exercise: exercise, station: station);

/// Replaces every `{{var.<name>}}` token in [content] with its effective
/// value, or with the localized unknown-variable placeholder when `<name>`
/// is not declared. A declared-but-empty variable substitutes the empty
/// string — that is a valid authoring state, not an error (ADR-0046).
///
/// Runs before the mustache pass (see [_resolveField]), so cross-references
/// like `{{station.position.utm}}` are still handled by the existing
/// `Template(...).renderString(...)` call afterwards. A variable *value*
/// that itself contains `{{...}}` is inserted literally here and picked up
/// by a later pass of [_resolveField]'s fixpoint loop: a `{{var.*}}` value
/// resolves on the next iteration, a cross-reference token in it on the
/// mustache pass. A self- or mutually-referential value never converges and
/// is left literal once the loop's cap is hit.
String _substituteVariables(
  String content,
  Map<String, String> vars,
  AppLocalizations l10n,
) {
  return substitutePlanVariables(
    content,
    vars,
    onUnknown: (name) => l10n.briefUnknownVariable(name),
  );
}

/// Upper bound on [_resolveField]'s fixpoint iterations. Each successful
/// resolution removes tokens, so a well-formed field converges in one or two
/// passes; this cap only bites on a circular reference (e.g. a name that
/// references a description that references the name), guaranteeing
/// termination instead of an infinite loop. Any tokens still present when
/// the cap is reached are left as visible literal text, which surfaces the
/// cycle to the author rather than hanging the render.
const _maxResolvePasses = 10;

/// Resolves a markdown field for rendering by running the full token
/// pipeline — `{{var.<name>}}`, then (when [scenarioStation] is given)
/// `{{station.loc/person.<slug>}}`, then the mustache cross-reference pass
/// against [refContext] — repeatedly until the string stops changing
/// (bounded by [_maxResolvePasses]).
///
/// The loop is what makes *nested* tokens resolve: any of the three systems
/// can inject a value that itself contains further tokens. A `{{var.year}}`
/// living inside `program.name` and reached through `{{program.name}}`, or a
/// `{{program.name}}` living inside `program.description` and reached through
/// `{{program.description}}`, only appears in the text after the pass that
/// injected it, so a single pass would leave it literal. Re-running the
/// whole pipeline on each pass' output resolves the next layer down. This
/// also means the cross-reference source values in the various `refContext`
/// maps can stay raw (unresolved) — the following pass' `{{var.*}}`
/// substitution catches whatever they inject.
///
/// [scenarioStation] is omitted (null) for program- and exercise-scope
/// fields, which have no station in scope and so never resolve
/// `station.loc.*`/`station.person.*`; only station and roleplay fields pass
/// it, both scoped to that same station's `locations`/`persons`.
String? _resolveField(
  String? content, {
  required Map<String, String> vars,
  required AppLocalizations l10n,
  Map<String, dynamic> refContext = const {},
  Station? scenarioStation,
  List<RolePlay> scenarioRolePlays = const [],
}) {
  if (content == null) return null;
  var current = content;
  for (var pass = 0; pass < _maxResolvePasses; pass++) {
    final next = _resolveFieldOnce(
      current,
      vars: vars,
      l10n: l10n,
      refContext: refContext,
      scenarioStation: scenarioStation,
      scenarioRolePlays: scenarioRolePlays,
    );
    if (next == current) return next;
    current = next;
  }
  return current;
}

/// One iteration of the [_resolveField] pipeline: `{{var.<name>}}`
/// substitution, then optional `{{station.loc/person.<slug>}}` resolution,
/// then the mustache cross-reference pass. Falls back to the (variable- and
/// scenario-substituted, but not mustache-rendered) content if that pass
/// throws — the same fallback behaviour the renderer had before variable
/// substitution was introduced.
String _resolveFieldOnce(
  String content, {
  required Map<String, String> vars,
  required AppLocalizations l10n,
  required Map<String, dynamic> refContext,
  Station? scenarioStation,
  List<RolePlay> scenarioRolePlays = const [],
}) {
  final withVars = _substituteVariables(content, vars, l10n);
  final withScenario = scenarioStation == null
      ? withVars
      : _resolveStationScenarioTokens(
          withVars,
          station: scenarioStation,
          rolePlays: scenarioRolePlays,
          l10n: l10n,
        );
  try {
    return Template(
      withScenario,
      htmlEscapeValues: false,
    ).renderString(refContext);
  } catch (_) {
    return withScenario;
  }
}

/// Matches `{{station.loc.<slug>}}` / `{{station.person.<slug>}}`, with an
/// optional dotted facet path (`.place`, `.utm`, `.home.utm`, ...). Group 1
/// is `loc`/`person`, group 2 the slug, group 3 the facet path including its
/// leading dots (empty for the bare token).
final _stationScenarioTokenPattern = RegExp(
  r'\{\{\s*station\.(loc|person)\.([a-z][a-z0-9_]*)((?:\.[a-zA-Z]+)*)\s*\}\}',
);

/// Replaces every `{{station.loc.<slug>}}` / `{{station.person.<slug>}}`
/// token (with facets) in [content] against [station]'s own
/// `locations`/`persons` — the station-and-down scope ADR-0047 defines.
/// [rolePlays] are the roleplays on this same station, used to resolve a
/// person facet's effective (denormalized) identity. An unknown slug
/// renders the same kind of visible, localized placeholder an undeclared
/// `{{var.x}}` does; a known slug with an empty facet renders empty, which
/// is a valid authoring state, not an error.
///
/// Runs pre-mustache, alongside `{{var.<name>}}` substitution — this is a
/// second registry-like lookup, not mustache's fixed derived context, so it
/// stays on the same pre-pass rather than growing a second parser. The
/// remaining `{{station.position.*}}` etc. are untouched here and still
/// resolved by the subsequent mustache pass against `refContext`.
String _resolveStationScenarioTokens(
  String content, {
  required Station station,
  required List<RolePlay> rolePlays,
  required AppLocalizations l10n,
}) {
  return content.replaceAllMapped(_stationScenarioTokenPattern, (match) {
    final kind = match.group(1)!;
    final slug = match.group(2)!;
    final facets = (match.group(3) ?? '')
        .split('.')
        .where((s) => s.isNotEmpty)
        .toList();
    if (kind == 'loc') {
      final location = _bySlug(station.locations, slug, (l) => l.slug);
      if (location == null) {
        return l10n.briefUnknownReference('station.loc.$slug');
      }
      return _resolveLocationFacet(location, facets);
    }
    final person = _bySlug(station.persons, slug, (p) => p.slug);
    if (person == null) {
      return l10n.briefUnknownReference('station.person.$slug');
    }
    final portrayer = _bySlug(rolePlays, slug, (rp) => rp.personRef ?? '');
    return _resolvePersonFacet(person, portrayer, station, facets);
  });
}

T? _bySlug<T>(List<T> items, String slug, String Function(T item) slugOf) {
  for (final item in items) {
    if (slugOf(item) == slug) return item;
  }
  return null;
}

/// `{{station.loc.<slug>[.facet]}}` facet resolution. The bare/default and
/// `.utm` forms render the UTM as inline code (backtick-wrapped), matching
/// how the brief presents `station.position.utm` elsewhere; empty when the
/// location has no position.
String _resolveLocationFacet(Location location, List<String> facets) {
  switch (facets.isEmpty ? null : facets.first) {
    case 'place':
      return location.place;
    case 'label':
      return location.label;
    case 'utm':
      return _locationUtmCode(location);
    default:
      return _locationDefault(location);
  }
}

String _locationUtmCode(Location location) {
  final utm = _formatUtm(location.position);
  return utm.isEmpty ? '' : '`$utm`';
}

/// Sensible bare-token default: `place` plus, when a position is set, the
/// inline-code UTM.
String _locationDefault(Location location) {
  final utmCode = _locationUtmCode(location);
  if (location.place.isEmpty) return utmCode;
  if (utmCode.isEmpty) return location.place;
  return '${location.place} ($utmCode)';
}

/// `{{station.person.<slug>[.facet]}}` facet resolution. [portrayer] is the
/// roleplay on [station] whose `personRef` names this person, if any — its
/// identity fields take precedence over [person]'s own when set (the
/// effective, denormalized identity from ADR-0047); `.home` resolves
/// [Person.homeSlug] to a location on the same station and applies the
/// remaining facet path to it.
String _resolvePersonFacet(
  Person person,
  RolePlay? portrayer,
  Station station,
  List<String> facets,
) {
  switch (facets.isEmpty ? null : facets.first) {
    case 'age':
      final age = portrayer?.age ?? person.age;
      return age == null ? '' : '$age';
    case 'gender':
      return _effectiveField(portrayer?.gender, person.gender) ?? '';
    case 'signalement':
      return _effectiveField(portrayer?.signalement, person.signalement) ??
          '';
    case 'home':
      final homeSlug = person.homeSlug;
      final home = homeSlug == null
          ? null
          : _bySlug(station.locations, homeSlug, (l) => l.slug);
      return home == null
          ? ''
          : _resolveLocationFacet(home, facets.skip(1).toList());
    case 'name':
    default:
      return _effectivePersonName(person, portrayer);
  }
}

String _effectivePersonName(Person person, RolePlay? portrayer) =>
    _effectiveField(portrayer?.name, person.name) ?? '';

/// The portraying roleplay's value when non-empty, otherwise the person's
/// own value (ADR-0047's effective-identity rule).
String? _effectiveField(String? roleplayValue, String? personValue) {
  if (roleplayValue != null && roleplayValue.isNotEmpty) return roleplayValue;
  return personValue;
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
