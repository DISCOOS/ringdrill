import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/roleplay_list_view.dart';
import 'package:ringdrill/views/widgets/plan_scope.dart';

import 'support/save_roundtrip_harness.dart';

/// Regression: an expanded role tile on the Spill tab renders the roleplay's
/// scenario fields, so a `{{roleplay.*}}` reference in them must resolve — the
/// tile now seeds a `RoleplayScope`. Before that it showed literally.
void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  setUp(() async {
    await initActivePlan('Roleplay resolution plan');
    await ProgramService().saveExercise(
      l10n,
      makeExercise(uuid: 'ex-1', name: 'Ex'),
    );
    await ProgramService().saveRolePlay(
      l10n,
      const RolePlay(
        uuid: 'role-1',
        index: 0,
        exerciseUuid: 'ex-1',
        stationIndex: 0,
        name: 'Vitne',
        // Crosses roleplay + exercise scope in one field: the tile wraps both
        // (RoleplayScope + StationScope.forStation, which also provides the
        // ExerciseScope), so both must resolve together.
        signalement: 'Heter {{roleplay.name}} i {{exercise.name}}',
      ),
    );
  });

  tearDown(() => ProgramService().clearAllForTest());

  testWidgets('an expanded role tile resolves {{roleplay.*}} and '
      '{{exercise.*}} together', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PlanScope(
          variables: const [],
          child: Scaffold(
            body: CustomScrollView(
              slivers: [RolePlayListView(controller: RolePlaysController())],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.expand_more).first);
    await tester.pumpAndSettle();

    expect(find.textContaining('{{'), findsNothing);
    expect(find.textContaining('Heter Vitne i Ex'), findsOneWidget);
  });
}
