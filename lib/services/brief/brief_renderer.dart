/// BriefRenderer — renders a plan or single-exercise brief as markdown.
///
/// The renderer is a pure function over the in-memory [Plan]. It does not
/// call [DrillFile.fromPlan] or [plan()]. The brief is rendered after
/// the plan is already loaded.
///
/// Template authors: fields that contain literal `{{` not intended as mustache
/// must be escaped with the `{{=<% %>=}}` delimiter-change pragma at the start
/// of the field content, e.g. `{{=<% %>=}} some {{literal}} text <%={{ }}=%>`.
library;

import 'package:latlong2/latlong.dart';
import 'package:meta/meta.dart';
import 'package:mustache_template/mustache_template.dart';
import 'package:ringdrill/services/brief/brief_labels.dart';
import 'package:ringdrill/services/brief/brief_template_source.dart';
import 'package:ringdrill/data/source/source_field.dart';
import 'package:ringdrill/data/source/source_fields.dart';
import 'package:ringdrill/models/staff.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/numbering.dart';
import 'package:ringdrill/models/plan.dart';
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
  BriefRenderer({TemplateRegistry? registry, BriefTemplateSource? templates})
    : _registry = registry ?? TemplateRegistry.instance,
      _templates = templates ?? const BakedBriefTemplateSource();

  final TemplateRegistry _registry;

  /// Where template source text comes from.
  ///
  /// Was an `AssetBundle`, which made this class — and so the whole brief layer
  /// — unusable outside a Flutter app even though rendering is pure string work
  /// (DESIGN-014's amendment to ADR-0048). The default reads the baked-in copies,
  /// which works identically in the app, under `dart run` and inside a compiled
  /// CLI; a test can still substitute its own source.
  final BriefTemplateSource _templates;

  /// Renders a brief for [plan]. When [exercise] is non-null, scopes the
  /// brief to that exercise. When null, renders the whole plan. The
  /// template is resolved from [exercise?.templateId] (single-exercise mode)
  /// or from the system default (plan mode).
  ///
  /// [wideTocSidebar] signals that [BriefScreen] is displaying a dedicated
  /// sidebar TOC (wide layout). When `true`, the mustache context sets
  /// `if_in_doc_toc` to `false`, suppressing the duplicate in-document
  /// `## Innholdsfortegnelse` block. When `false` (default), the in-document
  /// TOC is rendered so narrow-screen readers still have a contents list.
  Future<String> render({
    required Plan plan,
    Exercise? exercise,
    required BriefAudience audience,
    required BriefLabels l10n,
    bool wideTocSidebar = false,
  }) async {
    final template = _registry.resolve(exercise?.templateId, l10n.localeName);
    final String source;
    try {
      source = await _templates.load(template.assetPath);
    } catch (e) {
      throw BriefTemplateException(
        templateId: template.id,
        assetPath: template.assetPath,
        cause: e,
      );
    }
    final mustache = Template(source, htmlEscapeValues: false);

    final exercises = exercise != null ? [exercise] : plan.exercises;

    final actorMap = {for (final a in plan.staff) a.uuid: a};
    final rolePlaysByExercise = <String, List<RolePlay>>{};
    for (final rp in plan.rolePlays) {
      rolePlaysByExercise.putIfAbsent(rp.exerciseUuid, () => []).add(rp);
    }

    final planVars = _planVariables(plan);
    final planRefContext = _planRefContext(plan);
    final planName = resolver.substituteTypedVariables(
      plan.name,
      planVars,
      l10n,
    );
    final planDescription = resolver.substituteTypedVariables(
      plan.description,
      planVars,
      l10n,
    );

    final exerciseContexts = exercises.map((ex) {
      return _buildExerciseContext(
        plan: plan,
        exercise: ex,
        audience: audience,
        actorMap: actorMap,
        rolePlays: rolePlaysByExercise[ex.uuid] ?? [],
        l10n: l10n,
        planRefContext: planRefContext,
      );
    }).toList();

    final context = {
      'plan': _forAudience(audience, {
        'name': planName,
        'description': planDescription.isEmpty ? null : planDescription,
        'briefIntroMd': resolver.resolveField(
          plan.briefIntroMd,
          vars: planVars,
          l10n: l10n,
          refContext: planRefContext,
        ),
        'commsMd': resolver.resolveField(
          plan.commsMd,
          vars: planVars,
          l10n: l10n,
          refContext: planRefContext,
        ),
      }),
      'exercises': exerciseContexts,
      'if_in_doc_toc': !wideTocSidebar,
      // Single-exercise mode skips the plan-level header (H1, description,
      // in-doc TOC, briefIntroMd, commsMd, divider) because the reader is
      // looking at one exercise, not the whole plan. The template wraps
      // those blocks in an inverted section keyed on this flag.
      'isSingleExercise': exercise != null,
    };

    return mustache.renderString(context);
  }

  Map<String, dynamic> _buildExerciseContext({
    required Plan plan,
    required Exercise exercise,
    required BriefAudience audience,
    required Map<String, Staff> actorMap,
    required List<RolePlay> rolePlays,
    required BriefLabels l10n,
    required Map<String, dynamic> planRefContext,
  }) {
    final exNum = _exerciseNumber(plan, exercise);
    final exerciseVars = _effectiveVariables(plan, exercise: exercise);
    // Cascades plan cross-references (e.g. {{plan.name}}) into
    // exercise-scope fields too, on top of this exercise's own {{exercise.*}}
    // — mirrors the ADR-0046 variable cascade applied to cross-references.
    final exerciseRefContext = {
      ...planRefContext,
      ..._exerciseRefContext(exercise, l10n),
    };
    final effectiveComms = resolver.resolveField(
      _effectiveCommsMd(plan, exercise),
      vars: exerciseVars,
      l10n: l10n,
      refContext: exerciseRefContext,
    );

    final stationContexts = exercise.stations.map((station) {
      return _buildStationContext(
        plan: plan,
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

    return _forAudience(audience, {
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
      'organisationBlock': _organisationBlock(plan, exercise, l10n),
      'stations': stationContexts,
    });
  }

  Map<String, dynamic> _buildStationContext({
    required Plan plan,
    required Exercise exercise,
    required int exerciseNumber,
    required Station station,
    required BriefAudience audience,
    required Map<String, Staff> actorMap,
    required List<RolePlay> rolePlays,
    required String? effectiveCommsMd,
    required BriefLabels l10n,
    required Map<String, dynamic> exerciseRefContext,
  }) {
    final stationCode = Numbering.station(
      plan.stationNumberFormat,
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

    // Cascades plan + exercise cross-references on top of this station's
    // own {{station.*}} — a station field can reference e.g.
    // {{exercise.name}} or {{plan.name}} as well as {{station.name}}.
    final stationRefContext = {
      ...exerciseRefContext,
      'station': {
        'name': cleanName,
        'stationCode': stationCode,
        'description': station.description,
        'variantSuffix': station.variantSuffix,
        'position': resolver.briefCopyChip(utmStr),
        // How long a team gets here — derived from the round, and printed under
        // every post in a course booklet, so an author converting one will
        // otherwise type it. The station's own execution time wins where it has
        // one (ADR-0062).
        'duration': stationDurationLabel(
          exercise,
          executionTime: station.executionTime,
          evaluationTime: station.evaluationTime,
          rotationTime: station.rotationTime,
        ),
      },
    };

    final stationVars = _effectiveVariables(
      plan,
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
      if (audience.includesActorPii && rp.staffUuid != null) {
        final actor = actorMap[rp.staffUuid];
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
      // Cascades station (+ exercise + plan) on top of this roleplay's
      // own {{roleplay.*}} — roleplay fields resolve through the station's
      // effective variables too, per DESIGN-008 ("a roleplay reads through
      // its station's overrides at render time").
      final roleplayRefContext = {
        ...stationRefContext,
        'roleplay': {
          'name': rp.name,
          'age': rp.age,
          'description': rp.description,
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
      return _forAudience(audience, {
        'name': resolvedRpName,
        'age': rp.age,
        'description': rp.description,
        'behavior': resolveRoleplayField(rp.behavior),
        'background': resolveRoleplayField(rp.background),
        'propsMd': resolveRoleplayField(rp.propsMd),
        'actor': actorContext,
      });
    }).toList();

    final stationAnchor = _toAnchor(
      '$stationCode – $resolvedStationName'
      '${station.variantSuffix != null ? ' – ${station.variantSuffix}' : ''}',
    );

    return _forAudience(audience, {
      'name': resolvedStationName,
      'variantSuffix': station.variantSuffix,
      'stationCode': stationCode,
      'stationAnchor': stationAnchor,
      'position': resolver.briefCopyChip(utmStr),
      'positionValue': positionValue,
      'stationDurationLabel': stationDurationLabel(
        exercise,
        executionTime: station.executionTime,
        evaluationTime: station.evaluationTime,
        rotationTime: station.rotationTime,
      ),
      'descriptionMd': resolveField(station.description),
      'equipmentMd': resolveField(station.equipmentMd),
      'situationMd': resolveField(station.situationMd),
      'missionMd': resolveField(station.missionMd),
      'logisticsMd': resolveField(station.logisticsMd),
      'criticalQuestionsMd': resolveField(station.criticalQuestionsMd),
      'leaderAnswersMd': resolveField(station.leaderAnswersMd),
      'directorNotesMd': resolveField(station.directorNotesMd),
      'effectiveCommsMd': effectiveCommsMd,
      'roleplays': _showsRolePlays(audience) ? roleplayContexts : const [],
    });
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Whether [audience] sees role plays at all (ADR-0063).
  ///
  /// Emptying the role-play *fields* is not enough. The section heading and the
  /// marker's name come from the `{{#roleplays}}` loop itself, so a participant
  /// would still get "Markørspill (Anne Glemsk)" with nothing under it — which
  /// announces both that the station has a marker and who plays them. An audience
  /// that can see none of the role-play fields gets no role plays.
  bool _showsRolePlays(BriefAudience audience) => SourceScopes.roleplay.fields
      .any((f) => f.shape == SourceShape.markdown && f.visibleTo(audience));

  /// Empties the markdown entries [audience] may not see (ADR-0063).
  ///
  /// Applied to a finished context rather than at each `resolveField` call, so a
  /// field added to the map later is filtered by construction instead of by
  /// somebody remembering to wrap it — the failure mode this replaces, where
  /// visibility lived in two mustache conditionals and every unwrapped field was
  /// public by default.
  ///
  /// The key stays and its value becomes null, rather than the key being removed.
  /// The template is rendered non-leniently, so a *missing* key is an error —
  /// which is worth keeping, since it catches a context key that no longer
  /// matches the template. A withheld field is absent content, not an absent
  /// field, and mustache treats null as an empty section either way.
  ///
  /// Keys the field table does not describe as markdown pass through untouched:
  /// `description` is a plain-string lead-in, and the rest are labels, numbers
  /// and nested contexts that belong to whatever section renders them.
  Map<String, dynamic> _forAudience(
    BriefAudience audience,
    Map<String, dynamic> context,
  ) {
    final out = <String, dynamic>{};
    for (final entry in context.entries) {
      final field = SourceScopes.markdownByWireKey[entry.key];
      final withheld = field != null && !field.visibleTo(audience);
      out[entry.key] = withheld ? null : entry.value;
    }
    return out;
  }

  /// Returns the 1-based position of [exercise] in [plan]'s exercise list.
  @visibleForTesting
  static int exerciseNumber(Plan plan, Exercise exercise) =>
      _exerciseNumber(plan, exercise);

  /// Clock-time span for the exercise: "08:30–10:30".
  /// "Tid" in copy is reserved for clock-time, never duration.
  @visibleForTesting
  static String exerciseTimeLabel(Exercise exercise) =>
      exercise_format.exerciseTimeLabel(exercise);

  /// Total duration plus per-round breakdown for the exercise.
  /// Examples: "2 timer (60 min pr oppdrag)", "90 min (30 min pr oppdrag)".
  @visibleForTesting
  static String exerciseDurationLabel(Exercise exercise, BriefLabels l10n) =>
      exercise_format.exerciseDurationLabel(exercise, l10n);

  /// Per-round duration with phase breakdown for a station: "30 min (15 | 10 | 5)".
  @visibleForTesting
  static String stationDurationLabel(
    Exercise exercise, {
    int? executionTime,
    int? evaluationTime,
    int? rotationTime,
  }) => exercise_format.stationDurationLabel(
    exercise,
    executionTime: executionTime,
    evaluationTime: evaluationTime,
    rotationTime: rotationTime,
  );

  /// Full Organisering markdown block.
  @visibleForTesting
  static String organisationBlock(
    Plan plan,
    Exercise exercise,
    BriefLabels l10n,
  ) => _organisationBlock(plan, exercise, l10n);

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

  /// Resolves `{{var.<name>}}` tokens and plan-scope cross-references
  /// (`{{plan.name}}`, `{{plan.description}}`) in [content] against
  /// [plan]. For lightweight previews of a plan-scope markdown field
  /// — e.g. the Plan view's collapsed overview card — that show a
  /// snippet of `briefIntroMd`/`commsMd`/`beforeRoundMd` without running
  /// the full brief template through [render].
  ///
  /// [exercise]/[station] narrow the *variable* values to that level of
  /// ADR-0046's chain, for text that belongs to one — an exercise's own name
  /// resolved with no scoped subtree to read, such as a snackbar message.
  /// Without them a variable the exercise overrides resolves to the plan's
  /// value: not a literal token, so it looks fine, and is wrong.
  ///
  /// Cross-references stay at the plan level — `{{exercise.*}}`/`{{station.*}}`
  /// facets are not added here. A surface that needs those wants
  /// `resolveModelField`, which builds the per-item facet maps.
  static String resolvePlanScopeText(
    Plan plan,
    String content,
    BriefLabels l10n, {
    Exercise? exercise,
    Station? station,
  }) =>
      resolver.resolveField(
        content,
        vars: effectiveTypedPlanVariables(
          plan,
          exercise: exercise,
          station: station,
        ),
        l10n: l10n,
        refContext: _planRefContext(plan),
      ) ??
      content;

  /// Declared plan variables' display values, keyed by name, at the
  /// plan scope — see [effectivePlanVariables].
  @visibleForTesting
  static Map<String, String> planVariables(Plan plan) =>
      effectivePlanVariables(plan);

  /// Effective variable display values for a scope: the plan's declared
  /// values overlaid by [exercise]'s overrides, then by [station]'s
  /// overrides. See ADR-0046 for the resolution chain.
  @visibleForTesting
  static Map<String, String> effectiveVariables(
    Plan plan, {
    Exercise? exercise,
    Station? station,
  }) => effectivePlanVariables(plan, exercise: exercise, station: station);

  /// Replaces every `{{var.<name>}}` token in [content] with its value in
  /// [vars], or with the localized unknown-variable placeholder when
  /// `<name>` is not a key of [vars]. The plain string-map substitution —
  /// the renderer itself resolves through the typed path
  /// (`resolveTypedPlanVariables`) internally.
  @visibleForTesting
  static String substituteVariables(
    String content,
    Map<String, String> vars,
    BriefLabels l10n,
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

int _exerciseNumber(Plan plan, Exercise exercise) {
  final idx = plan.exercises.indexWhere((e) => e.uuid == exercise.uuid);
  return idx < 0 ? 1 : idx + 1;
}

/// What the Organisering line calls this exercise's conduct.
///
/// `ring` keeps the route noun the brief has always used; the other two name what a
/// reader will actually see. Not `exerciseModeLabel` — that lives under `lib/views/`,
/// which this layer cannot import (it is Flutter-free, because the CLI renders briefs
/// too), so the brief's own label set carries them.
String _conductLabel(Exercise exercise, BriefLabels l10n) =>
    switch (exercise.mode) {
      ExerciseMode.ring => l10n.briefRingRoute,
      ExerciseMode.together => l10n.briefModeTogether,
      ExerciseMode.split => l10n.briefModeSplit,
    };

/// Full Organisering markdown block used in the brief template.
String _organisationBlock(Plan plan, Exercise exercise, BriefLabels l10n) {
  final phases = rotationPhaseBreakdown(exercise);
  // The conduct line: keep config + legend on the same physical line so the
  // legend doesn't wrap unnecessarily on wide screens. Markdown reflows the
  // line if the viewport is too narrow to fit both.
  //
  // Two things here used to be true of every exercise and are now true of `ring`
  // alone (ADR-0062). The label said "Ringløype" whatever the mode, which tells a
  // veileder to expect one team per post rotating — something they might brief teams
  // on. And `N x (phases)` asserts a *uniform* cycle, which is exactly the claim the
  // modes exist to stop making: with rounds of differing length it multiplied a cycle
  // that does not exist, and beside a spanned breakdown it reads as nonsense.
  final rounds = exercise.numberOfRounds;
  final minutes = effectivePhaseMinutes(exercise);
  final uniform = minutes.every((m) => m == minutes.first);
  final buf = StringBuffer()
    ..writeln(
      '**${_conductLabel(exercise, l10n)}:** '
      '${uniform ? '$rounds x ($phases)' : '$rounds ${l10n.round(rounds).toLowerCase()} ($phases)'} '
      '_(${l10n.rotationShareLegendPhases})_',
    )
    ..writeln();
  final beforeRound = resolver.resolveField(
    plan.beforeRoundMd,
    vars: _planVariables(plan),
    l10n: l10n,
    refContext: _planRefContext(plan),
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

String? _effectiveCommsMd(Plan plan, Exercise exercise) {
  return exercise.commsMd ?? plan.commsMd;
}

/// Partial plan context for cross-reference resolution inside
/// plan-scope markdown fields (e.g. `{{plan.name}}` inside
/// `briefIntroMd`), mirroring `_buildStationContext`'s `stationRefContext`.
///
/// Without this, `{{plan.name}}` has no key to resolve against —
/// `mustache_template` throws "Value was missing for variable tag" for an
/// absent key (not a silent empty string), which `resolveField`'s catch-all
/// then turns into "leave the field's mustache pass unrendered", so the
/// literal `{{plan.name}}` stayed in the output instead of being
/// substituted.
Map<String, dynamic> _planRefContext(Plan plan) => {
  'plan': {
    'name': plan.name,
    'description': plan.description,
    // Counts, because a plan description routinely states them ("Sju øvelser
    // fredag–søndag") and the plan scope had nothing to offer instead, so they got
    // typed in and went stale on the next added exercise.
    'exerciseCount': plan.exercises.length,
    'teamCount': plan.teams.length,
    'stationCount': plan.exercises.fold<int>(
      0,
      (sum, e) => sum + e.stations.length,
    ),
  },
};

/// Partial exercise context for cross-reference resolution inside
/// exercise-scope markdown fields (`methodMd`, `learningGoalsMd`,
/// `trainingFocusMd`, `orderFormatMd`, `executionTipsMd`, `commsMd`) —
/// same rationale as [_planRefContext]. Cascaded into station and
/// roleplay refContexts too (see `_buildStationContext`), so
/// `{{exercise.name}}` also resolves from inside a station or roleplay
/// field, not just the exercise's own.
Map<String, dynamic> _exerciseRefContext(Exercise exercise, BriefLabels l10n) =>
    {
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
        // Derived, so an author never hand-rolls the round times into prose.
        'roundTable': rotationRoundTable(exercise, l10n),
      },
    };

/// Effective *typed* plan variables, keyed by name, at the plan scope
/// (DESIGN-008 follow-up 11). Delegates to the shared
/// `lib/utils/plan_variables.dart` helper — kept as a private wrapper here
/// so every call site below stays unchanged.
Map<String, DrillVariable> _planVariables(Plan plan) =>
    effectiveTypedPlanVariables(plan);

/// Effective typed variables for a scope (ADR-0046) — see
/// [effectiveTypedPlanVariables] for the resolution rule.
Map<String, DrillVariable> _effectiveVariables(
  Plan plan, {
  Exercise? exercise,
  Station? station,
}) => effectiveTypedPlanVariables(plan, exercise: exercise, station: station);

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
