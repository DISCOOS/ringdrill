import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/views/widgets/plan_scope.dart';

/// Reads [PlanScope.of] on every build and reports how many times it has
/// been built, so a test can tell whether an ancestor rebuild actually
/// notified this descendant.
class _Probe extends StatefulWidget {
  const _Probe({required this.onBuild});

  final ValueChanged<List<DrillVariable>> onBuild;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  Widget build(BuildContext context) {
    widget.onBuild(PlanScope.of(context).variables);
    return const SizedBox.shrink();
  }
}

void main() {
  testWidgets('maybeOf returns null when built outside a PlanScope', (
    tester,
  ) async {
    PlanScope? found;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            found = PlanScope.maybeOf(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(found, isNull);
  });

  testWidgets('of returns the variables the nearest PlanScope provides', (
    tester,
  ) async {
    const variables = [DrillVariable(name: 'frekvens', value: 'Kanal 6')];
    List<DrillVariable>? seen;

    await tester.pumpWidget(
      MaterialApp(
        home: PlanScope(
          variables: variables,
          child: _Probe(onBuild: (v) => seen = v),
        ),
      ),
    );

    expect(seen, variables);
  });

  testWidgets(
    'updateShouldNotify only rebuilds the descendant on a real change',
    (tester) async {
      var builds = 0;
      // Constructed once and reused by reference across every pumpWidget
      // call below: since PlanScope.child is `identical` every time,
      // Flutter's own "widget == newWidget" short-circuit skips rebuilding
      // it through normal top-down propagation, isolating this test to
      // only the InheritedWidget notification path (updateShouldNotify).
      // Reconstructing a new _Probe() each pump would rebuild it every
      // time regardless of updateShouldNotify, defeating the test.
      final probe = _Probe(onBuild: (_) => builds++);

      Widget host(List<DrillVariable> variables) =>
          MaterialApp(home: PlanScope(variables: variables, child: probe));

      await tester.pumpWidget(
        host(const [DrillVariable(name: 'frekvens', value: 'Kanal 6')]),
      );
      expect(builds, 1);

      // Same content, a different (but value-equal) List instance — must
      // not rebuild the descendant.
      await tester.pumpWidget(
        host([const DrillVariable(name: 'frekvens', value: 'Kanal 6')]),
      );
      expect(builds, 1);

      // A real change — value edited — must rebuild it.
      await tester.pumpWidget(
        host(const [DrillVariable(name: 'frekvens', value: 'Kanal 8')]),
      );
      expect(builds, 2);
    },
  );
}
