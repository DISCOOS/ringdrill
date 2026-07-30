/// Reference-integrity and structural analysis of a built plan.
///
/// `build` already refuses a document it cannot compile — a malformed time, a
/// coordinate out of range, more teams than stations. What is left, and what this
/// adds, is everything that compiles fine but will not *render*: a
/// `{{var.talegruppe}}` naming no declared variable, a
/// `{{station.loc.lkp.utm}}` on a station with no such location, an
/// `{{exercise.phaseBreakdown}}` misspelled, a declared variable nothing uses.
/// Those are exactly the mistakes a generating agent makes, and they are silent
/// at build time — the token is stored raw and only fails at render, in front of
/// a reader.
///
/// Reuses the utilities the app's own integrity checks use
/// (`plan_variables.dart`, `station_scenario_tokens.dart`,
/// `plan_field_names.dart`), all already Flutter-free, rather than
/// re-implementing the token grammar. A second grammar would drift from the
/// renderer's and start disagreeing about what resolves.
///
/// Free of `package:flutter/*` (AGENTS.md rule 7).
library;

import 'package:ringdrill/data/source/source_diagnostic.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/utils/plan_field_names.dart';
import 'package:ringdrill/utils/plan_variable_refs.dart';
import 'package:ringdrill/utils/plan_variables.dart';
import 'package:ringdrill/utils/station_scenario_tokens.dart';

/// A markdown or text field to scan, with where it sits.
class _Field {
  const _Field(this.path, this.content, this.scope, {this.station});

  final String path;
  final String? content;
  final PlanFieldScope scope;

  /// The station whose `locations`/`persons` a `{{station.*}}` token resolves
  /// against. Null above station scope, where such a token cannot resolve at all.
  final Station? station;
}

/// Checks a plan for references that will not resolve.
class SourceAnalyzer {
  const SourceAnalyzer._();

  /// Analyzes [plan], appending to [diagnostics].
  ///
  /// Errors are references that will visibly fail — the renderer substitutes a
  /// "‹missing variable: x›" marker into the brief. Warnings are things that
  /// render fine but suggest the author meant something else.
  static void analyze(Plan plan, DiagnosticSink diagnostics) {
    final declared = {for (final v in plan.variables) v.name};

    for (final field in _fields(plan)) {
      _checkVariableTokens(field, declared, diagnostics);
      _checkScenarioTokens(field, diagnostics);
      _checkFacetTokens(field, diagnostics);
    }

    _checkOverrides(plan, declared, diagnostics);
    _checkUnusedVariables(plan, diagnostics);
    _checkPersonLocRefs(plan, diagnostics);
    _checkUuidUniqueness(plan, diagnostics);
  }

  /// `{{var.<name>}}` naming an undeclared variable.
  static void _checkVariableTokens(
    _Field field,
    Set<String> declared,
    DiagnosticSink diagnostics,
  ) {
    final content = field.content;
    if (content == null) return;
    for (final match in planVariableTokenPattern.allMatches(content)) {
      final name = match.group(1)!;
      if (declared.contains(name)) continue;
      diagnostics.error(
        field.path,
        'no variable named "$name" is declared',
        hint: declared.isEmpty
            ? 'declare it under plan.variables'
            : 'declared: ${(declared.toList()..sort()).join(', ')}',
      );
    }
  }

  /// `{{station.loc.<slug>}}` / `{{station.person.<slug>}}` against the station
  /// that owns them.
  static void _checkScenarioTokens(_Field field, DiagnosticSink diagnostics) {
    final content = field.content;
    if (content == null) return;
    for (final match in stationScenarioTokenPattern.allMatches(content)) {
      final kind = match.group(1)!;
      final slug = match.group(2)!;
      final station = field.station;
      if (station == null) {
        // Scenario data is station-owned (DESIGN-009), so a plan- or
        // exercise-level field has no station to resolve against — the token is
        // unresolvable wherever the author put it, not merely misspelled.
        diagnostics.error(
          field.path,
          '{{station.$kind.$slug}} cannot resolve outside a station',
          hint:
              'scenario locations and persons are owned by a station; '
              'move the text onto the station, or use a plan variable',
        );
        continue;
      }
      final known = kind == 'loc'
          ? station.locations.map((l) => l.slug).toSet()
          : station.persons.map((p) => p.slug).toSet();
      if (known.contains(slug)) continue;
      diagnostics.error(
        field.path,
        'this station has no $kind "$slug"',
        hint: known.isEmpty
            ? 'the station declares no ${kind == 'loc' ? 'locations' : 'persons'}'
            : 'declared: ${(known.toList()..sort()).join(', ')}',
      );
    }
  }

  /// `{{plan.name}}`-style facet references, against what resolves at that scope.
  ///
  /// Catches both a misspelling (`{{exercise.phasebreakdown}}`) and a scope
  /// mistake (`{{exercise.name}}` in a plan-level field, which has no exercise in
  /// context) — the second being the one an author is least likely to predict.
  static void _checkFacetTokens(_Field field, DiagnosticSink diagnostics) {
    final content = field.content;
    if (content == null) return;
    final resolvable = PlanFieldNames.resolvableAt(field.scope);
    for (final match in _facetPattern.allMatches(content)) {
      final name = match.group(1)!;
      if (resolvable.contains(name)) continue;
      if (PlanFieldNames.all.contains(name)) {
        final owner = name.split('.').first;
        diagnostics.error(
          field.path,
          '{{$name}} cannot resolve here',
          hint:
              'a $owner reference needs a $owner in context; this field is '
              'at ${field.scope.name} scope',
        );
        continue;
      }
      diagnostics.error(
        field.path,
        '{{$name}} is not a resolvable reference',
        hint: 'resolvable here: ${(resolvable.toList()..sort()).join(', ')}',
      );
    }
  }

  /// `variableOverrides` keys that name no declared variable.
  ///
  /// A warning rather than an error: resolution ignores an unknown key (ADR-0046),
  /// so nothing breaks — but the author wrote it expecting an effect, and it has
  /// none.
  static void _checkOverrides(
    Plan plan,
    Set<String> declared,
    DiagnosticSink diagnostics,
  ) {
    void check(Map<String, String> overrides, String path) {
      for (final key in overrides.keys) {
        if (declared.contains(key)) continue;
        diagnostics.warn(
          '$path.$key',
          'overrides "$key", which is not a declared variable; ignored',
          hint:
              'an override sets a value for a plan variable; it cannot '
              'declare one',
        );
      }
    }

    for (var e = 0; e < plan.exercises.length; e++) {
      final exercise = plan.exercises[e];
      check(exercise.variableOverrides, 'exercises[$e].variableOverrides');
      for (var s = 0; s < exercise.stations.length; s++) {
        check(
          exercise.stations[s].variableOverrides,
          'exercises[$e].stations[$s].variableOverrides',
        );
      }
    }
  }

  /// Declared but never referenced.
  ///
  /// The amber case DESIGN-014 names: harmless, but usually either a leftover or
  /// a token that was meant to be written and was not.
  static void _checkUnusedVariables(Plan plan, DiagnosticSink diagnostics) {
    for (final variable in plan.variables) {
      if (variableReferenceCount(plan, variable.name) > 0) continue;
      diagnostics.warn(
        'plan.variables.${variable.name}',
        'declared but never referenced',
        hint: 'reference it as {{var.${variable.name}}}, or remove it',
      );
    }
  }

  /// A person's `locSlug` pointing at no location on the same station.
  static void _checkPersonLocRefs(Plan plan, DiagnosticSink diagnostics) {
    for (var e = 0; e < plan.exercises.length; e++) {
      for (var s = 0; s < plan.exercises[e].stations.length; s++) {
        final station = plan.exercises[e].stations[s];
        final slugs = station.locations.map((l) => l.slug).toSet();
        for (final person in station.persons) {
          final locSlug = person.locSlug;
          if (locSlug == null || slugs.contains(locSlug)) continue;
          diagnostics.error(
            'exercises[$e].stations[$s].persons[${person.slug}].locSlug',
            'no location "$locSlug" on this station',
            hint: slugs.isEmpty
                ? 'the station declares no locations'
                : 'declared: ${(slugs.toList()..sort()).join(', ')}',
          );
        }
      }
    }
  }

  /// Duplicate uuids across the plan.
  ///
  /// Only reachable when a document hand-writes them (or a decompiled one is
  /// copy-pasted), which is exactly when it happens. A duplicate exercise uuid
  /// makes role-play ownership ambiguous and perturbs the content hash's
  /// uuid-sorted ordering, so it is an error rather than a warning.
  static void _checkUuidUniqueness(Plan plan, DiagnosticSink diagnostics) {
    void check(Iterable<String> uuids, String what, String path) {
      final seen = <String>{};
      for (final uuid in uuids) {
        if (seen.add(uuid)) continue;
        diagnostics.error(path, 'duplicate $what uuid "$uuid"');
      }
    }

    check(plan.exercises.map((e) => e.uuid), 'exercise', 'exercises');
    check(plan.teams.map((t) => t.uuid), 'team', 'teams');
    check(plan.rolePlays.map((r) => r.uuid), 'roleplay', 'roleplays');
  }

  /// Every field a token can occur in, with its scope.
  ///
  /// Mirrors `PlanVariableField` in `plan_variable_refs.dart` — that enum is the
  /// app's list of the same fields, and the paths here are source-document paths
  /// rather than display labels.
  static Iterable<_Field> _fields(Plan plan) sync* {
    yield _Field('plan.name', plan.name, PlanFieldScope.plan);
    yield _Field('plan.description', plan.description, PlanFieldScope.plan);
    yield _Field('plan.intro', plan.briefIntroMd, PlanFieldScope.plan);
    yield _Field('plan.comms', plan.commsMd, PlanFieldScope.plan);
    yield _Field('plan.before_round', plan.beforeRoundMd, PlanFieldScope.plan);

    for (var e = 0; e < plan.exercises.length; e++) {
      final exercise = plan.exercises[e];
      final at = 'exercises[$e]';
      const scope = PlanFieldScope.exercise;
      yield _Field('$at.name', exercise.name, scope);
      yield _Field('$at.method', exercise.methodMd, scope);
      yield _Field('$at.learning_goals', exercise.learningGoalsMd, scope);
      yield _Field('$at.training_focus', exercise.trainingFocusMd, scope);
      yield _Field('$at.order_format', exercise.orderFormatMd, scope);
      yield _Field('$at.execution_tips', exercise.executionTipsMd, scope);
      yield _Field('$at.comms', exercise.commsMd, scope);

      for (var s = 0; s < exercise.stations.length; s++) {
        final station = exercise.stations[s];
        final sAt = '$at.stations[$s]';
        const sScope = PlanFieldScope.station;
        yield _Field('$sAt.name', station.name, sScope, station: station);
        yield _Field(
          '$sAt.description',
          station.description,
          sScope,
          station: station,
        );
        yield _Field(
          '$sAt.equipment',
          station.equipmentMd,
          sScope,
          station: station,
        );
        yield _Field(
          '$sAt.situation',
          station.situationMd,
          sScope,
          station: station,
        );
        yield _Field(
          '$sAt.mission',
          station.missionMd,
          sScope,
          station: station,
        );
        yield _Field(
          '$sAt.logistics',
          station.logisticsMd,
          sScope,
          station: station,
        );
        yield _Field(
          '$sAt.critical_questions',
          station.criticalQuestionsMd,
          sScope,
          station: station,
        );
        yield _Field(
          '$sAt.leader_answers',
          station.leaderAnswersMd,
          sScope,
          station: station,
        );
        yield _Field(
          '$sAt.director_notes',
          station.directorNotesMd,
          sScope,
          station: station,
        );

        final rolePlays = plan.rolePlays.where(
          (rp) => rp.exerciseUuid == exercise.uuid && rp.stationIndex == s,
        );
        var r = 0;
        for (final rolePlay in rolePlays) {
          final rAt = '$sAt.roleplays[${r++}]';
          const rScope = PlanFieldScope.roleplay;
          yield _Field('$rAt.name', rolePlay.name, rScope, station: station);
          yield _Field(
            '$rAt.behavior',
            rolePlay.behavior,
            rScope,
            station: station,
          );
          yield _Field(
            '$rAt.background',
            rolePlay.background,
            rScope,
            station: station,
          );
          yield _Field(
            '$rAt.props',
            rolePlay.propsMd,
            rScope,
            station: station,
          );
        }
      }
    }
  }

  /// `{{plan.name}}`-style tokens: a scope, a dot, a facet — and not `var.` or
  /// `station.loc`/`station.person`, which the other two checks own.
  static final _facetPattern = RegExp(
    r'\{\{\s*((?!var\.)(?!station\.loc\.)(?!station\.person\.)'
    r'[a-zA-Z]+\.[a-zA-Z][a-zA-Z0-9_]*)\s*\}\}',
  );
}
