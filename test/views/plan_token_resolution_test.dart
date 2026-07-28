import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/views/widgets/plan_scope.dart';
import 'package:ringdrill/views/widgets/plan_text.dart';
import 'package:ringdrill/views/widgets/ringdrill_text.dart';

/// Two surfaces that cannot read a `PlanScope` from the tree, and so used to
/// render `{{var.*}}` literally: snackbars and cross-plan lists.
///
/// A `SnackBar` is built by the `ScaffoldMessenger` in an `Overlay` that is a
/// *sibling* of the subtree carrying the scope, so wrapping the caller does not
/// help — the message has to be resolved before it is handed over. A cross-plan
/// list has the opposite problem: a scope *is* available and it belongs to the
/// wrong plan, which would silently substitute one plan's values into another's
/// name. That failure is worse than the literal token, because it looks right.
const _year = DrillVariable(
  name: 'year',
  type: VariableType.string,
  value: '2026',
);
const _otherYear = DrillVariable(
  name: 'year',
  type: VariableType.string,
  value: '1999',
);

Plan _plan({
  required String uuid,
  required String name,
  required DrillVariable year,
}) => Plan(
  uuid: uuid,
  name: name,
  description: '',
  metadata: PlanMetadata(
    created: DateTime.utc(2026, 1, 1),
    updated: DateTime.utc(2026, 1, 1),
    version: '1.1',
  ),
  exercises: const [],
  teams: const [],
  sessions: const [],
  rolePlays: const [],
  staff: const [],
  variables: [year],
);

final _subject = _plan(
  uuid: 'plan-subject',
  name: 'LSOR Eidene {{var.year}}',
  year: _year,
);

/// The plan the ambient scope belongs to — a *different* one, with a different
/// value for the same variable, so resolving against the wrong scope is
/// detectable rather than coincidentally identical.
final _ambient = _plan(
  uuid: 'plan-ambient',
  name: 'Ambient {{var.year}}',
  year: _otherYear,
);

Widget _app({required Widget child}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: PlanScope(
    variables: _ambient.variables,
    planName: _ambient.name,
    child: Scaffold(body: child),
  ),
);

void main() {
  group('a cross-plan list row', () {
    testWidgets('resolves against its own plan, not the ambient scope', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(child: RingDrillText.forPlan(_subject, _subject.name)),
      );
      await tester.pumpAndSettle();

      expect(find.text('LSOR Eidene 2026'), findsOneWidget);
      expect(
        find.textContaining('{{'),
        findsNothing,
        reason: 'the reported bug: the raw token reached the row',
      );
      expect(
        find.textContaining('1999'),
        findsNothing,
        reason:
            "the ambient plan's value must not leak into another plan's name",
      );
    });
  });

  group('a snackbar', () {
    testWidgets('resolves the active plan\'s tokens in its message', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => showRingdrillSnackBar(
                context,
                '${_subject.name} er allerede oppdatert',
                plan: _subject,
              ),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(
        find.text('LSOR Eidene 2026 er allerede oppdatert'),
        findsOneWidget,
      );
      expect(find.textContaining('{{'), findsNothing);
    });

    // The snackbar is built by the ScaffoldMessenger, outside the caller's
    // subtree — so this must hold even though the button sits inside a scope.
    testWidgets('does so even though SnackBar renders outside the scope', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          child: Builder(
            builder: (context) => TextButton(
              // No plan: — falls back to the active plan, and there is none in
              // this harness, so the message must survive unchanged rather than
              // resolving to the *ambient* scope's unrelated values.
              onPressed: () =>
                  showRingdrillSnackBar(context, 'Plain, no tokens'),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.text('Plain, no tokens'), findsOneWidget);
    });

    // The narrower half: only Exercise and Station carry variableOverrides
    // (ADR-0046), so a message naming an exercise must resolve at *that* level.
    // Resolving one level too high yields the plan's value — no literal token to
    // give it away, which is why this is asserted rather than assumed.
    testWidgets('an exercise-scoped message uses the exercise\'s override', (
      tester,
    ) async {
      const exercise = Exercise(
        uuid: 'ex-override',
        name: 'Øvelse {{var.year}}',
        startTime: SimpleTimeOfDay(hour: 8, minute: 0),
        numberOfTeams: 1,
        numberOfRounds: 1,
        executionTime: 10,
        evaluationTime: 5,
        rotationTime: 2,
        stations: [],
        schedule: [],
        endTime: SimpleTimeOfDay(hour: 8, minute: 17),
        // Shadows the plan's 2026.
        variableOverrides: {'year': '2027'},
      );

      await tester.pumpWidget(
        _app(
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => showRingdrillSnackBar(
                context,
                'Stopp ${exercise.name} først',
                plan: _subject,
                exercise: exercise,
              ),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.text('Stopp Øvelse 2027 først'), findsOneWidget);
      expect(
        find.textContaining('2026'),
        findsNothing,
        reason: "the plan's value must not win over the exercise's override",
      );
    });

    testWidgets('the messenger variant resolves too', (tester) async {
      late ScaffoldMessengerState messenger;
      late AppLocalizations l10n;
      await tester.pumpWidget(
        _app(
          child: Builder(
            builder: (context) {
              messenger = ScaffoldMessenger.of(context);
              l10n = AppLocalizations.of(context)!;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      showRingdrillSnackBarVia(
        messenger,
        '${_subject.name} er allerede oppdatert',
        l10n: l10n,
        plan: _subject,
      );
      await tester.pumpAndSettle();

      expect(
        find.text('LSOR Eidene 2026 er allerede oppdatert'),
        findsOneWidget,
      );
    });
  });
}
