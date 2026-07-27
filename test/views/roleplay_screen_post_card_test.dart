import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/data/plan_repository.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/views/roleplay_screen.dart';
import 'package:ringdrill/views/shell/master_detail_scope.dart';
import 'package:ringdrill/views/widgets/collapse_chevron.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// DESIGN-010's Spill/Post viewer card consistency prompt, Fix 1: the
/// Spill viewer's post-context card (`_StationContextCard`, private to
/// roleplay_screen.dart) is now a `CollapsibleSectionCard` — a "Post"
/// header (flag icon + collapse chevron) over a body that is itself the
/// tappable navigating row. Exercised only through the public
/// `RolePlayScreen`, since the card class itself is private.
const _planUuid = 'prog-role-post-card';
const _exerciseUuid = 'ex-role-post-card';
const _roleUuid = 'role-post-card';

Plan _shell() {
  final now = DateTime.utc(2026, 1, 1);
  return Plan(
    uuid: _planUuid,
    name: 'Test Plan',
    description: '',
    metadata: PlanMetadata(created: now, updated: now, version: '1.0'),
    teams: const [],
    sessions: const [],
    exercises: const [],
  );
}

Exercise _exercise() => Exercise(
  uuid: _exerciseUuid,
  index: 0,
  name: 'Test Exercise',
  startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
  numberOfTeams: 1,
  numberOfRounds: 1,
  executionTime: 10,
  evaluationTime: 5,
  rotationTime: 2,
  stations: const [
    Station(
      index: 0,
      name: 'Post 1',
      description: 'Finsøk rundt IPP innenfor R25.',
    ),
  ],
  schedule: const [
    [
      SimpleTimeOfDay(hour: 8, minute: 0),
      SimpleTimeOfDay(hour: 8, minute: 10),
      SimpleTimeOfDay(hour: 8, minute: 15),
    ],
  ],
  endTime: const SimpleTimeOfDay(hour: 8, minute: 17),
);

RolePlay _rolePlay() => const RolePlay(
  uuid: _roleUuid,
  index: 0,
  exerciseUuid: _exerciseUuid,
  stationIndex: 0,
  name: 'Turgåer',
);

Future<void> _seedAndInit() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final repo = PlanRepository(prefs);
  await repo.savePlanShell(_shell());
  await repo.setActivePlanUuid(_planUuid);
  await repo.saveExercise(_exercise());
  await repo.saveRolePlay(_rolePlay());
  await PlanService().init();
}

/// The Post card's own collapse chevron, disambiguated from the identity
/// and position cards' — anchored on the flag icon, unique to this card's
/// header.
Finder postCollapseChevron() => find.descendant(
  of: find
      .ancestor(of: find.byIcon(Icons.flag), matching: find.byType(Card))
      .first,
  matching: find.byType(CollapseChevron),
);

/// The Post card's body reveal — the outermost [SizeTransition] inside that
/// card. CollapsibleSectionCard keeps its body in the tree when collapsed and
/// clips it to zero height (so it slides rather than vanishes), so "hidden" is
/// asserted as zero height here, not as an absent widget.
Finder postBodyReveal() => find
    .descendant(
      of: find
          .ancestor(of: find.byIcon(Icons.flag), matching: find.byType(Card))
          .first,
      matching: find.byType(SizeTransition),
    )
    .first;

void main() {
  setUp(() async {
    await _seedAndInit();
  });

  testWidgets(
    'renders a "Post"/"Station" header with a flag icon and a collapse '
    'chevron, expanded by default with the station name/description shown',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const RolePlayScreen(uuid: _roleUuid),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.stationLabel.toUpperCase()), findsOneWidget);
      expect(find.byIcon(Icons.flag), findsOneWidget);
      expect(postCollapseChevron(), findsOneWidget);
      expect(find.text('1.1 Post 1'), findsOneWidget);
      expect(find.text('Finsøk rundt IPP innenfor R25.'), findsOneWidget);
    },
  );

  testWidgets(
    'collapsing the card hides the station row; it reappears on expand',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const RolePlayScreen(uuid: _roleUuid),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(postCollapseChevron());
      await tester.pumpAndSettle();
      // Clipped to zero height, not removed from the tree.
      expect(tester.getSize(postBodyReveal()).height, 0);

      await tester.tap(postCollapseChevron());
      await tester.pumpAndSettle();
      expect(tester.getSize(postBodyReveal()).height, greaterThan(0));
      expect(find.text('1.1 Post 1'), findsOneWidget);
    },
  );

  testWidgets(
    'expanded, tapping the body row navigates — targets the linked station '
    'via ContextSheet.replace',
    (tester) async {
      final controller = ContextSheetController();
      addTearDown(controller.dispose);
      // Mirrors the wide layout's "already open" invariant: the roleplay
      // was reached via the master pane (adoptWideSelection), not a modal
      // show(), so ContextSheet.replace's "requires an open sheet" assert
      // is satisfied the same way MainScreen's auto-select/segment-memory
      // restore satisfy it.
      controller.adoptWideSelection(
        const RoleSheetTarget(rolePlayUuid: _roleUuid),
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ContextSheet(
            controller: controller,
            child: MasterDetailScope(
              target: controller.targetNotifier,
              emptyPaneBuilder: (_) => const SizedBox.shrink(),
              child: const RolePlayScreen(uuid: _roleUuid),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('1.1 Post 1'));
      await tester.pumpAndSettle();

      final target = controller.targetNotifier.value;
      expect(target, isA<StationSheetTarget>());
      expect((target as StationSheetTarget).exerciseUuid, _exerciseUuid);
      expect(target.stationIndex, 0);
    },
  );
}
