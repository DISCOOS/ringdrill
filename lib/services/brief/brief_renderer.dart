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
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/numbering.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/brief/brief_audience.dart';
import 'package:ringdrill/services/brief/field_resolver.dart' as resolver;
import 'package:ringdrill/services/brief/template_registry.dart';
import 'package:ringdrill/utils/exercise_share_format.dart';
// Aliased alongside the unprefixed import above: exerciseTimeLabel/
// exerciseDurationLabel share a name with BriefRenderer's own
// @visibleForTesting static wrappers of the same name, so an unqualified
// call from inside the class body would resolve to the static method
// itself (infinite self-recursion) rather than this shared util —
// mirrors field_resolver.dart's `as resolver` import for the same reason.
import 'package:ringdrill/utils/exercise_share_format.dart' as exercise_format;
import 'package:ringdrill/utils/plan_variables.dart';

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
    final programName = resolver.substituteTypedVariables(
      program.name,
      programVars,
      l10n,
    );
    final programDescription = resolver.substituteTypedVariables(
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
        'briefIntroMd': resolver.resolveField(
          program.briefIntroMd,
          vars: programVars,
          l10n: l10n,
          refContext: programRefContext,
        ),
        'commsMd': resolver.resolveField(
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
    final effectiveComms = resolver.resolveField(
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

    final exerciseName = resolver.substituteTypedVariables(
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
      'exerciseTimeLabel': exercise_format.exerciseTimeLabel(exercise),
      'exerciseDurationLabel': exercise_format.exerciseDurationLabel(
        exercise,
        l10n,
      ),
      'methodMd': resolver.resolveField(
        exercise.methodMd,
        vars: exerciseVars,
        l10n: l10n,
        refContext: exerciseRefContext,
      ),
      'learningGoalsMd': resolver.resolveField(
        exercise.learningGoalsMd,
        vars: exerciseVars,
        l10n: l10n,
        refContext: exerciseRefContext,
      ),
      'trainingFocusMd': resolver.resolveField(
        exercise.trainingFocusMd,
        vars: exerciseVars,
        l10n: l10n,
        refContext: exerciseRefContext,
      ),
      'orderFormatMd': resolver.resolveField(
        exercise.orderFormatMd,
        vars: exerciseVars,
        l10n: l10n,
        refContext: exerciseRefContext,
      ),
      'executionTipsMd': resolver.resolveField(
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
    final utmStr = resolver.formatUtm(station.position);
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
        'position': resolver.briefCopyChip(utmStr),
      },
    };

    final stationVars = _effectiveVariables(
      program,
      exercise: exercise,
      station: station,
    );
    final resolvedStationName = resolver.substituteTypedVariables(
      cleanName,
      stationVars,
      l10n,
    );

    String? resolveField(String? content) => resolver.resolveField(
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
          // Fold the parentheses into the phone chip (like the UTM chip) so
          // "(", pill and ")" stay together and the copied value is the bare
          // number.
          final phone = actor.phone;
          actorContext = {
            'realName': actor.realName,
            'phone': (phone == null || phone.isEmpty)
                ? ''
                : resolver.briefCopyChip('($phone)'),
          };
        }
      }
      final resolvedRpName = resolver.substituteTypedVariables(
        rp.name,
        stationVars,
        l10n,
      );
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
          'position': resolver.briefCopyChip(resolver.formatUtm(rp.position)),
        },
      };
      String? resolveRoleplayField(String? content) => resolver.resolveField(
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
      'position': resolver.briefCopyChip(utmStr),
      'positionValue': positionValue,
      'stationDurationLabel': _stationDurationLabel(exercise),
      'descriptionMd': resolveField(station.description),
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
      exercise_format.exerciseTimeLabel(exercise);

  /// Total duration plus per-round breakdown for the exercise.
  /// Examples: "2 timer (60 min pr oppdrag)", "90 min (30 min pr oppdrag)".
  @visibleForTesting
  static String exerciseDurationLabel(
    Exercise exercise,
    AppLocalizations l10n,
  ) => exercise_format.exerciseDurationLabel(exercise, l10n);

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
  static String formatUtm(LatLng? latLng) => resolver.formatUtm(latLng);

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
      resolver.resolveField(
        content,
        vars: _programVariables(program),
        l10n: l10n,
        refContext: _programRefContext(program),
      ) ??
      content;

  /// Declared plan variables' display values, keyed by name, at the
  /// program scope — see [effectivePlanVariables].
  @visibleForTesting
  static Map<String, String> programVariables(Program program) =>
      effectivePlanVariables(program);

  /// Effective variable display values for a scope: the program's declared
  /// values overlaid by [exercise]'s overrides, then by [station]'s
  /// overrides. See ADR-0046 for the resolution chain.
  @visibleForTesting
  static Map<String, String> effectiveVariables(
    Program program, {
    Exercise? exercise,
    Station? station,
  }) => effectivePlanVariables(program, exercise: exercise, station: station);

  /// Replaces every `{{var.<name>}}` token in [content] with its value in
  /// [vars], or with the localized unknown-variable placeholder when
  /// `<name>` is not a key of [vars]. The plain string-map substitution —
  /// the renderer itself resolves through the typed path
  /// (`resolveTypedPlanVariables`) internally.
  @visibleForTesting
  static String substituteVariables(
    String content,
    Map<String, String> vars,
    AppLocalizations l10n,
  ) => substitutePlanVariables(
    content,
    vars,
    onUnknown: (name) => l10n.briefUnknownVariable(name),
  );
}

// ---------------------------------------------------------------------------
// Private helpers (top-level functions for testability via @visibleForTesting
// static wrappers above). The token-resolution pipeline itself
// (`resolveField`/`substituteTypedVariables`/`formatUtm` and the scenario
// facet resolution) lives in `field_resolver.dart` (ADR-0048) — this file
// only assembles the resolution context and delegates to it.
// ---------------------------------------------------------------------------

// Matches leading "Nx) " or "Nxy) " station-name prefixes.
// Workaround pending data cleanup of Station.name — see ADR-0023 follow-up 01.
final _kStationNamePrefix = RegExp(r'^[0-9]+[a-z]\)\s*');

int _exerciseNumber(Program program, Exercise exercise) {
  final idx = program.exercises.indexWhere((e) => e.uuid == exercise.uuid);
  return idx < 0 ? 1 : idx + 1;
}

/// Per-round duration with phase breakdown for a station: "30 min (15 | 10 | 5)".
String _stationDurationLabel(Exercise exercise) {
  final round = rotationRoundMinutes(exercise);
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
  final beforeRound = resolver.resolveField(
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

String? _effectiveCommsMd(Program program, Exercise exercise) {
  return exercise.commsMd ?? program.commsMd;
}

/// Partial program context for cross-reference resolution inside
/// program-scope markdown fields (e.g. `{{program.name}}` inside
/// `briefIntroMd`), mirroring `_buildStationContext`'s `stationRefContext`.
///
/// Without this, `{{program.name}}` has no key to resolve against —
/// `mustache_template` throws "Value was missing for variable tag" for an
/// absent key (not a silent empty string), which `resolveField`'s catch-all
/// then turns into "leave the field's mustache pass unrendered", so the
/// literal `{{program.name}}` stayed in the output instead of being
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
    'timeLabel': exerciseTimeLabel(exercise),
    'durationLabel': exerciseDurationLabel(exercise, l10n),
    'executionTime': exercise.executionTime,
    'evaluationTime': exercise.evaluationTime,
    'rotationTime': exercise.rotationTime,
    'phaseBreakdown': rotationPhaseBreakdown(exercise),
  },
};

/// Effective *typed* plan variables, keyed by name, at the program scope
/// (DESIGN-008 follow-up 11). Delegates to the shared
/// `lib/utils/plan_variables.dart` helper — kept as a private wrapper here
/// so every call site below stays unchanged.
Map<String, DrillVariable> _programVariables(Program program) =>
    effectiveTypedPlanVariables(program);

/// Effective typed variables for a scope (ADR-0046) — see
/// [effectiveTypedPlanVariables] for the resolution rule.
Map<String, DrillVariable> _effectiveVariables(
  Program program, {
  Exercise? exercise,
  Station? station,
}) =>
    effectiveTypedPlanVariables(program, exercise: exercise, station: station);

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
