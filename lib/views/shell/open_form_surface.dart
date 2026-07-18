import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/shell/window_size_class.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';
import 'package:ringdrill/views/widgets/exercise_scope.dart';
import 'package:ringdrill/views/widgets/plan_scope.dart';
import 'package:ringdrill/views/widgets/ringdrill_sheet.dart';
import 'package:ringdrill/views/widgets/station_scope.dart';

Future<T?> openFormSurface<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool commitsToParent = false,
}) async {
  // Capture the ancestor resolve scopes (DESIGN-010's PlanScope/
  // ExerciseScope/StationScope cascade) up front, before any `await` — both
  // push paths below land on the root Navigator's Overlay, a sibling of (not
  // a descendant of) the calling context's InheritedWidget ancestry, so an
  // ancestor scope never reaches the pushed child without being re-provided
  // here. This is the single mechanism every form opened through this
  // choke point relies on for resolve-scope continuity — a snapshot at push
  // is correct, since these surfaces are modal.
  final planScope = PlanScope.maybeOf(context);
  final exerciseScope = ExerciseScope.maybeOf(context);
  final stationScope = StationScope.maybeOf(context);
  final wrappedBuilder = _reprovideScopes(
    builder,
    planScope: planScope,
    exerciseScope: exerciseScope,
    stationScope: stationScope,
    commitsToParent: commitsToParent,
  );

  if (WindowSizeClass.of(context).hasMasterDetail) {
    return showRingdrillFormDialog<T>(
      context: context,
      builder: wrappedBuilder,
    );
  }

  // If we're inside a ContextSheet bottom sheet, dismiss it before pushing
  // the form. The sheet's `_ModalBottomSheet` wraps the body in
  // `AnimatedPadding(EdgeInsets.only(bottom: viewInsets.bottom))`, so when
  // the keyboard opens on any field of the form route above, the sheet
  // beneath kicks off a keyboard-avoidance animation. The resulting
  // viewInsets/layout cascade tears down the form's `TextInputConnection`
  // and the keyboard immediately closes — observed when tapping Navn or
  // Alder in `RolePlayFormScreen` opened from a station sheet. There is no
  // public flag on `showModalBottomSheet` to opt out of that AnimatedPadding,
  // so the only reliable fix is to not have the sheet alive beneath the
  // form. We re-open it to the same target after the form closes so the
  // user lands back where they were.
  final sheetController = ContextSheet.maybeOf(context);
  ContextSheetTarget? savedTarget;
  if (sheetController != null && sheetController.isModal) {
    savedTarget = sheetController.target.value;
    sheetController.close();
  }

  // Push on the root navigator so the form route lives above any other
  // overlay still attached to the shell navigator.
  final rootNavigator = Navigator.of(context, rootNavigator: true);
  final result = await rootNavigator.push<T>(
    MaterialPageRoute(
      // This route sits on the root Navigator's Overlay, a sibling of
      // MainScreen (DESIGN-008 follow-up 11) — the PlanScope wrapping
      // MainScreen never reaches it without a scope of its own.
      builder: wrappedBuilder,
    ),
  );

  // Re-open the sheet (modal mode) to the saved target so the user is
  // returned to where they invoked the form. Use the root navigator's
  // context — the original calling context belonged to the (now disposed)
  // sheet body and is no longer mounted.
  //
  // Deliberately NOT awaited: `ContextSheetController.show()` only resolves
  // when the re-opened sheet is *dismissed*, so awaiting it here parks this
  // function before `return result`. The caller's
  // `await openFormSurface(...)` then never resolves and its
  // `ProgramService.save*` call never runs — the edit silently vanishes
  // (the editor save-loss regression). The re-open is cosmetic; fire it and
  // hand the result back immediately.
  if (savedTarget != null && sheetController != null && rootNavigator.mounted) {
    unawaited(sheetController.show(rootNavigator.context, savedTarget));
  }

  return result;
}

/// Wraps [builder] so the pushed surface sees the same resolve scopes
/// (whichever were present) as the calling context did — re-provided from
/// scratch since the push lands outside the ancestor `InheritedWidget` tree.
/// [planScope] falls back to the active program's variables (no program
/// facets) when absent, matching this choke point's pre-DESIGN-010
/// behaviour for callers with no ambient `PlanScope` at all.
WidgetBuilder _reprovideScopes(
  WidgetBuilder builder, {
  required PlanScope? planScope,
  required ExerciseScope? exerciseScope,
  required StationScope? stationScope,
  required bool commitsToParent,
}) {
  return (context) {
    Widget child = FormSurfaceScope(
      commitsToParent: commitsToParent,
      child: builder(context),
    );
    if (stationScope != null) {
      child = StationScope(
        locations: stationScope.locations,
        persons: stationScope.persons,
        portrayerOf: stationScope.portrayerOf,
        name: stationScope.name,
        stationCode: stationScope.stationCode,
        description: stationScope.description,
        variantSuffix: stationScope.variantSuffix,
        positionUtm: stationScope.positionUtm,
        child: child,
      );
    }
    if (exerciseScope != null) {
      child = ExerciseScope(
        exercise: exerciseScope.exercise,
        variableOverrides: exerciseScope.variableOverrides,
        child: child,
      );
    }
    return PlanScope(
      variables:
          planScope?.variables ??
          ProgramService().activeProgram?.variables ??
          const [],
      programName: planScope?.programName,
      programDescription: planScope?.programDescription,
      child: child,
    );
  };
}

/// Signals to a form pushed through [openFormSurface] whether its result is
/// persisted immediately by the caller, or only folded into a parent's own
/// unsaved working copy (persisted later, by that parent's own save) — see
/// the design note above [openFormSurface] on "nested vs committing" being a
/// property of the call site, not the form. The shared form chrome
/// (`SectionNavigatedForm`) reads [commitsToParent] to pick its primary
/// action's label: "Lagre"/"Save" when false (the default — the caller
/// persists on return), "Ferdig"/"Done" when true (the result is only
/// merged into a parent's working copy).
class FormSurfaceScope extends InheritedWidget {
  const FormSurfaceScope({
    super.key,
    required this.commitsToParent,
    required super.child,
  });

  final bool commitsToParent;

  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<FormSurfaceScope>()
          ?.commitsToParent ??
      false;

  @override
  bool updateShouldNotify(FormSurfaceScope oldWidget) =>
      commitsToParent != oldWidget.commitsToParent;
}
