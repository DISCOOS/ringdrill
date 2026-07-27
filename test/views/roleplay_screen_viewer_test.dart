import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/data/plan_repository.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/actor.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/person.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/brief/field_resolver.dart' show formatUtm;
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/views/roleplay_form_screen.dart';
import 'package:ringdrill/views/roleplay_screen.dart';
import 'package:ringdrill/views/shell/detail_empty_pane.dart';
import 'package:ringdrill/views/widgets/collapse_chevron.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The Spill viewer's consolidated Spill card — effective identity (person
/// values inherited, roleplay values overriding non-empty ones), the script
/// sections (behavior/background/props, all resolved) and the cast footer,
/// all in one CollapsibleSectionCard — plus the position card (labeled with
/// the source location the position follows).
///
/// RolePlay.background/behavior/propsMd are excluded from JSON (like
/// Station's *Md fields) — persisting them for `PlanService.init()` to
/// pick up needs `PlanRepository.saveRolePlay`'s sidecar-key path.
const _planUuid = 'prog-role-viewer';
const _exerciseUuid = 'ex-role-viewer';
const _roleUuid = 'role-viewer';
const _actorUuid = 'actor-viewer';

const _homeLocation = Location(
  slug: 'home',
  label: 'Bosted',
  kind: LocationKind.home,
  position: LatLng(59.92, 10.76),
);

const _hilde = Person(
  slug: 'hilde',
  name: 'Hilde',
  age: 34,
  gender: 'woman',
  description: 'Gul regnjakke, hjemme',
  locSlug: 'home',
  notes: 'Skadd venstre ankel, kan ikke gå selv.',
);

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
    actors: const [Actor(uuid: _actorUuid, realName: 'Nina Actor')],
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
      persons: [_hilde],
      locations: [_homeLocation],
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

/// Age/description are left null (inherited from `_hilde`); gender is set
/// to 'man' (overrides `_hilde`'s 'woman' — ADR-0047's effective-identity
/// rule: the roleplay's own non-empty value wins).
RolePlay _rolePlay() => const RolePlay(
  uuid: _roleUuid,
  index: 0,
  exerciseUuid: _exerciseUuid,
  stationIndex: 0,
  name: 'Hilde',
  gender: 'man',
  personRef: 'hilde',
  actorUuid: _actorUuid,
  position: LatLng(59.92, 10.76),
  // `{{roleplay.age}}` deliberately not used here: RoleplayScope exposes
  // the roleplay's own bare fields (ADR-0048), not the effective/merged
  // value the identity card computes — age is null on this roleplay
  // itself (only the linked person has it), so that token would resolve
  // empty. `{{roleplay.name}}` is always set directly on the roleplay.
  behavior: 'Rolig, følger {{roleplay.name}}.',
  background: 'Sett ved {{station.name}}.',
  propsMd: 'Fiskestang.',
);

Future<void> _seedAndInit() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final repo = PlanRepository(prefs);
  await repo.savePlanShell(_shell());
  await repo.setActivePlanUuid(_planUuid);
  await repo.saveExercise(_exercise());
  // Actor storage is a separate sidecar keyspace (`pa:<plan>:<actor>`) —
  // Plan.actors on the shell alone is not what PlanService.getActor
  // reads.
  await repo.saveActor(const Actor(uuid: _actorUuid, realName: 'Nina Actor'));
  await repo.saveRolePlay(_rolePlay());
  await PlanService().init();
}

Widget _buildScreen() {
  return const MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: RolePlayScreen(uuid: _roleUuid),
  );
}

void main() {
  setUp(() async {
    await _seedAndInit();
  });

  testWidgets(
    'effective identity shows the person\'s inherited age/description and '
    'the roleplay\'s overridden gender',
    (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      // Age (inherited, roleplay.age is null) and the overridden gender show
      // together in the Spill card's lead meta line, e.g. "34 years · Man".
      expect(find.textContaining(l10n.rolePlayAgeYears(34)), findsOneWidget);
      // Gender: the roleplay's own 'male' wins over the person's 'female'.
      expect(find.textContaining('Man'), findsOneWidget);
      expect(find.textContaining('Woman'), findsNothing);
      // Description: inherited from the person (roleplay.description null).
      expect(
        find.text('Gul regnjakke, hjemme', findRichText: true),
        findsOneWidget,
      );
      // Cast actor footer.
      expect(find.text(l10n.castedByLine('Nina Actor')), findsOneWidget);
    },
  );

  testWidgets(
    'Markørordre resolves tokens in behavior/background and shows props',
    (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(
        find.text('Rolig, følger Hilde.', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Sett ved Post 1.', findRichText: true), findsOneWidget);
      expect(find.text('Fiskestang.', findRichText: true), findsOneWidget);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      // The props section label is now an uppercase kicker in the Spill card.
      expect(find.text(l10n.roleProps.toUpperCase()), findsOneWidget);
    },
  );

  /// The Spill card's own collapse chevron, disambiguated from the
  /// Post/position cards' — anchored on the cast quick-action IconButton, which
  /// is the only IconButton inside a body card (the Spill card).
  Finder identityCollapseChevron() => find.descendant(
    of: find
        .ancestor(of: find.byType(IconButton), matching: find.byType(Card))
        .first,
    matching: find.byType(CollapseChevron),
  );

  /// The Spill identity card's body reveal — the outermost [SizeTransition]
  /// inside that card (CollapsibleSectionCard wraps its body in one). The body
  /// stays in the tree when collapsed and is clipped to zero height, so
  /// "folded away" is asserted as zero height here, not as absent widgets.
  Finder identityBodyReveal() => find
      .descendant(
        of: find
            .ancestor(of: find.byType(IconButton), matching: find.byType(Card))
            .first,
        matching: find.byType(SizeTransition),
      )
      .first;

  testWidgets(
    'the identity card is expanded by default and shows the person\'s '
    'notes and linked location; the "Spilles av" footer renders as the '
    'shared CastPill chip',
    (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(
        find.text('Skadd venstre ankel, kan ikke gå selv.'),
        findsOneWidget,
      );
      final expectedCoordinate = formatUtm(const LatLng(59.92, 10.76));
      expect(find.textContaining('Bosted'), findsOneWidget);
      expect(find.textContaining(expectedCoordinate), findsWidgets);

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final footerText = find.text(l10n.castedByLine('Nina Actor'));
      // The footer uses the same CastPill chip as the collapsed tile's face
      // chip and roleplays_view's cast row — its `.cast` variant always
      // paints a colored (primaryContainer) background.
      final footerContainer = tester.widget<Container>(
        find.ancestor(of: footerText, matching: find.byType(Container)).first,
      );
      final decoration = footerContainer.decoration as BoxDecoration?;
      expect(decoration?.color, isNotNull);
    },
  );

  testWidgets(
    'collapsing the identity card hides gender, description, notes, location '
    'and the "Spilles av" footer, leaving just the name line with the '
    'marker first name in parentheses',
    (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      await tester.tap(identityCollapseChevron());
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      // Gender, description, notes, the linked location and the cast footer
      // all live in the body, which folds away — clipped to zero height, not
      // removed from the tree.
      expect(tester.getSize(identityBodyReveal()).height, 0);
      // The collapsed header reads the uppercase "SPILLES AV {markør}"
      // (castedByLine), e.g. "PLAYED BY NINA ACTOR" (en) — it sits outside the
      // folded body, so it stays visible while the mixed-case footer inside is
      // clipped away.
      expect(
        find.text(l10n.castedByLine('Nina Actor').toUpperCase()),
        findsOneWidget,
      );

      // Expanding again reveals the body (notes, location, footer) and the
      // header returns to just the "SPILL" kicker.
      await tester.tap(identityCollapseChevron());
      await tester.pumpAndSettle();
      expect(tester.getSize(identityBodyReveal()).height, greaterThan(0));
      expect(
        find.text('Skadd venstre ankel, kan ikke gå selv.'),
        findsOneWidget,
      );
      expect(find.text(l10n.castedByLine('Nina Actor')), findsOneWidget);
    },
  );

  testWidgets(
    'tapping a roleplay-owned Play-card section opens the roleplay form at '
    'that form section',
    (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      // Tap the Behaviour (Oppførsel) script section — its form id is
      // 'behavior', distinct from the base 'roleplay' section, so it proves
      // the tap jumps to the *tapped* section, not just opens the form.
      final behaviorSection = find.text(l10n.roleBehavior.toUpperCase());
      await tester.ensureVisible(behaviorSection);
      await tester.tap(behaviorSection);
      await tester.pumpAndSettle();

      final form = find.byType(RolePlayFormScreen);
      expect(form, findsOneWidget);
      expect(
        tester.widget<RolePlayFormScreen>(form).initialSectionId,
        'behavior',
      );
    },
  );

  testWidgets(
    'tapping the PERSON section opens the roleplay form at the Rolle section',
    (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      // The identity is edited on the roleplay's own "Rolle" section (person
      // selection + per-marker overrides), so the PERSON block opens the
      // roleplay form there.
      final personSection = find.text(l10n.rolePlayPersonLabel.toUpperCase());
      await tester.ensureVisible(personSection);
      await tester.tap(personSection);
      await tester.pumpAndSettle();

      final form = find.byType(RolePlayFormScreen);
      expect(form, findsOneWidget);
      expect(
        tester.widget<RolePlayFormScreen>(form).initialSectionId,
        'roleplay',
      );
    },
  );

  // Regression: the viewer caches `_rolePlay` and must refresh when the SAME
  // roleplay is mutated elsewhere (roster re-cast, another master/detail
  // pane), not only on its own actions. It subscribes to
  // PlanService.events via SubscriptionBag; without that it would keep
  // showing the stale cast.
  // A roleplay that cannot be resolved — a stale deep link, or one deleted
  // from another master/detail pane while this viewer was open — must not
  // silently dismiss itself: the reader would see the view vanish with no
  // explanation. It explains instead, and leaves closing to them.
  group('an unresolvable roleplay', () {
    testWidgets(
      'explains itself instead of closing, and offers a close action',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: RolePlayScreen(uuid: 'role-does-not-exist'),
          ),
        );
        await tester.pumpAndSettle();

        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        expect(tester.takeException(), isNull);
        expect(find.byType(DetailGonePane), findsOneWidget);
        expect(find.text(l10n.detailGoneRolePlay), findsOneWidget);
        // Still on screen after settling — it did not close itself.
        expect(find.byType(RolePlayScreen), findsOneWidget);
        // And the close action is the reader's, to take when they choose.
        expect(
          find.widgetWithText(FilledButton, l10n.briefClose),
          findsOneWidget,
        );
      },
    );

    testWidgets('a resolvable roleplay shows no gone pane', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(find.byType(DetailGonePane), findsNothing);
    });
  });

  testWidgets('the viewer refreshes when the roleplay is re-cast externally', (
    tester,
  ) async {
    await tester.pumpWidget(_buildScreen());
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.castedByLine('Nina Actor')), findsOneWidget);

    // Cast a different actor through the service, as the roster would.
    final service = PlanService();
    await service.saveActor(
      l10n,
      const Actor(uuid: 'actor-2', realName: 'Ola Actor'),
    );
    await service.saveRolePlay(
      l10n,
      _rolePlay().copyWith(actorUuid: 'actor-2'),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.castedByLine('Ola Actor')), findsOneWidget);
    expect(find.text(l10n.castedByLine('Nina Actor')), findsNothing);
  });
}
