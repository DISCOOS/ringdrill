import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/brief/brief_renderer.dart';
import 'package:ringdrill/services/plan_service.dart';

/// Resolves [text] against [plan]'s own variables and `{{plan.*}}` facets,
/// without reading anything from the widget tree.
///
/// The eager counterpart to [resolveScopedField], for the two situations where
/// the tree cannot answer:
///
/// * **The ambient scope is the wrong plan.** A cross-plan surface (the library
///   list, the plan pickers) shows names belonging to plans that are not active.
///   Resolving those against the active [PlanScope] would substitute one plan's
///   values into another plan's name — which looks right and is wrong, a worse
///   failure than the literal token.
/// * **There is no scope to read.** A `SnackBar` is built by the
///   `ScaffoldMessenger`, in an `Overlay` that is a *sibling* of the subtree
///   carrying the scope, so a token-aware widget placed in `SnackBar.content`
///   finds nothing and renders every token verbatim. Same root cause as the
///   drill player's raw tokens (see [PlanScope.fromActivePlan]) — but a snackbar
///   cannot be fixed by wrapping it, since the caller does not own its subtree.
///   So the message is resolved *before* it is handed over.
/// Pass [exercise]/[station] when [text] belongs to one: only those two levels
/// carry `variableOverrides` (ADR-0046), and without them a variable the exercise
/// shadows resolves to the plan's value — no literal token to give it away.
String resolvePlanText(
  Plan plan,
  String text,
  AppLocalizations l10n, {
  Exercise? exercise,
  Station? station,
}) => text.isEmpty
    ? text
    : BriefRenderer.resolvePlanScopeText(
        plan,
        text,
        l10n,
        exercise: exercise,
        station: station,
      );

/// [resolvePlanText] against the active plan, or [text] unchanged when there is
/// none. For a message about the app rather than about a particular plan.
String resolveActivePlanText(
  String text,
  AppLocalizations l10n, {
  Exercise? exercise,
  Station? station,
}) {
  final plan = PlanService().activePlan;
  return plan == null
      ? text
      : resolvePlanText(plan, text, l10n, exercise: exercise, station: station);
}

/// Shows [message] with its plan tokens resolved.
///
/// Use this instead of `ScaffoldMessenger.of(context).showSnackBar(...)` for any
/// message that interpolates content the user authored — a plan, exercise,
/// station or markør name. Those names routinely contain `{{var.*}}`, and the
/// literal token then reaches the snackbar: "LSOR Eidene {{var.year}} er
/// allerede oppdatert".
///
/// Resolves against [plan] when the message is about a specific plan (the
/// library's rows act on plans that are *not* active), otherwise against the
/// active plan.
///
/// A message with no tokens passes through untouched, so it is safe — and
/// preferable — to route every snackbar through here rather than judging
/// case-by-case which ones can contain one. The judgement is what rots: a
/// message gains an interpolated name later and nobody revisits the call.
void showRingdrillSnackBar(
  BuildContext context,
  String message, {
  Plan? plan,
  Exercise? exercise,
  Station? station,
  SnackBarAction? action,
  Duration? duration,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  showRingdrillSnackBarVia(
    messenger,
    message,
    l10n: AppLocalizations.of(context),
    plan: plan,
    exercise: exercise,
    station: station,
    action: action,
    duration: duration,
  );
}

/// [showRingdrillSnackBar] for a caller that holds a long-lived
/// [ScaffoldMessengerState] instead of a usable [BuildContext].
///
/// Needed by anything that posts a snackbar *after* popping the surface it was
/// triggered from: that context is deactivated by the pop, so the messenger (and
/// the localizations) must be captured before the await. Passing [l10n] null
/// skips resolution and shows [message] as-is.
void showRingdrillSnackBarVia(
  ScaffoldMessengerState messenger,
  String message, {
  required AppLocalizations? l10n,
  Plan? plan,
  Exercise? exercise,
  Station? station,
  SnackBarAction? action,
  Duration? duration,
}) {
  final resolved = l10n == null
      ? message
      : (plan == null
            ? resolveActivePlanText(
                message,
                l10n,
                exercise: exercise,
                station: station,
              )
            : resolvePlanText(
                plan,
                message,
                l10n,
                exercise: exercise,
                station: station,
              ));
  messenger.showSnackBar(
    SnackBar(
      content: Text(resolved),
      action: action,
      duration: duration ?? const Duration(seconds: 4),
      // The chrome four hand-rolled copies of this helper all agreed on, kept so
      // consolidating them changes no snackbar's appearance.
      showCloseIcon: true,
      dismissDirection: DismissDirection.endToStart,
    ),
  );
}
