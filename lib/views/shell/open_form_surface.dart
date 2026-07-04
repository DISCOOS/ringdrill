import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/shell/window_size_class.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';
import 'package:ringdrill/views/widgets/plan_scope.dart';
import 'package:ringdrill/views/widgets/ringdrill_sheet.dart';

Future<T?> openFormSurface<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) async {
  if (WindowSizeClass.of(context).hasMasterDetail) {
    return showRingdrillFormDialog<T>(context: context, builder: builder);
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
      builder: (ctx) => PlanScope(
        variables: ProgramService().activeProgram?.variables ?? const [],
        child: builder(ctx),
      ),
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
