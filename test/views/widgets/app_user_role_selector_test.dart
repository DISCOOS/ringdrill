import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/services/app_user_role.dart';
import 'package:ringdrill/utils/app_config.dart';
import 'package:ringdrill/utils/prefs.dart';
import 'package:ringdrill/views/widgets/app_user_role_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The role selector, which replaced the radio list in Settings.
///
/// The role now decides what this device may *edit* (ADR-0057), not only which
/// brief variant it defaults to — so it has to be reachable in passing, and every
/// gated affordance already on screen has to react when it changes. That second
/// part is why the role is a listenable at all.
void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Prefs.reset();
    appUserRole.value = StaffRole.director;
    addTearDown(Prefs.reset);
  });

  Widget harness({bool iconOnly = false}) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: AppUserRoleButton(iconOnly: iconOnly)),
  );

  testWidgets('shows the current role, and follows it when it changes', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    expect(find.text(l10n.briefAudienceDirector), findsOneWidget);

    // Not via the picker: this is the listenable half — a role changed anywhere
    // must reach a button already on screen.
    appUserRole.value = StaffRole.actor;
    await tester.pump();

    expect(find.text(l10n.appUserRoleActor), findsOneWidget);
    expect(find.text(l10n.briefAudienceDirector), findsNothing);
  });

  testWidgets('offers all three roles, marking the current one', (
    tester,
  ) async {
    await tester.pumpWidget(harness());

    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();

    expect(find.text(l10n.appUserRoleSectionTitle), findsOneWidget);
    expect(find.widgetWithText(ListTile, l10n.briefAudienceDirector), findsOne);
    expect(
      find.widgetWithText(ListTile, l10n.briefAudienceInstructor),
      findsOne,
    );
    expect(find.widgetWithText(ListTile, l10n.appUserRoleActor), findsOne);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('picking a role publishes and persists it', (tester) async {
    Prefs.bind(await SharedPreferences.getInstance());
    await tester.pumpWidget(harness());

    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, l10n.appUserRoleActor));
    await tester.pumpAndSettle();

    expect(appUserRole.value, StaffRole.actor);
    expect(
      Prefs.instanceOrNull!.getString(AppConfig.keyAppUserRole),
      StaffRole.actor.name,
    );
    // And the button reflects it without being rebuilt by its host.
    expect(find.text(l10n.appUserRoleActor), findsOneWidget);
  });

  // The drawer is a menu: once a choice is made it has served its purpose, and
  // leaving it open hides the very UI whose affordances just changed.
  testWidgets('picking from a drawer closes it', (tester) async {
    final scaffoldKey = GlobalKey<ScaffoldState>();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          key: scaffoldKey,
          drawer: const Drawer(child: AppUserRoleButton()),
          body: const SizedBox.shrink(),
        ),
      ),
    );
    scaffoldKey.currentState!.openDrawer();
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsOneWidget);

    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, l10n.appUserRoleActor));
    await tester.pumpAndSettle();

    expect(appUserRole.value, StaffRole.actor);
    expect(find.byType(Drawer), findsNothing);
  });

  // Same button in the rail, where there is no drawer to close.
  testWidgets('picking outside a drawer pops nothing extra', (tester) async {
    await tester.pumpWidget(harness());

    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, l10n.appUserRoleActor));
    await tester.pumpAndSettle();

    expect(appUserRole.value, StaffRole.actor);
    expect(find.byType(TextButton), findsOneWidget, reason: 'still mounted');
  });

  testWidgets('re-picking the current role is a no-op', (tester) async {
    await tester.pumpWidget(harness());

    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, l10n.briefAudienceDirector));
    await tester.pumpAndSettle();

    expect(appUserRole.value, StaffRole.director);
  });

  // The rail form: 72px and label-less by design, so the label moves into the
  // tooltip rather than being dropped.
  testWidgets('iconOnly keeps the role legible through its tooltip', (
    tester,
  ) async {
    appUserRole.value = StaffRole.instructor;
    await tester.pumpWidget(harness(iconOnly: true));

    expect(find.byIcon(staffRoleIcon(StaffRole.instructor)), findsOneWidget);
    expect(
      find.byTooltip(
        '${l10n.appUserRoleSectionTitle}: ${l10n.briefAudienceInstructor}',
      ),
      findsOneWidget,
    );
  });

  test('each role has its own icon and label', () {
    final icons = StaffRole.values.map(staffRoleIcon).toSet();
    expect(icons.length, StaffRole.values.length);
  });

  // Every role reads the brief as itself (ADR-0063): the mapping is the identity,
  // so no role borrows another's view. It used to collapse four roles onto three
  // audiences — an actor read as a director, `other` as an instructor.
  test('each role reads the brief as its own audience', () {
    for (final role in StaffRole.values) {
      expect(role.briefAudience.name, role.name);
    }
  });

  test('an actor gets the cast but not the control notes', () {
    // Markörer coordinate with each other, so they need the contact details; the
    // instructor-facing notes are not theirs to hold next to a participant.
    expect(StaffRole.actor.briefAudience.includesActorPii, isTrue);
    expect(StaffRole.actor.briefAudience.includesDirectorNotes, isFalse);

    // The veileder responsible for that markör needs to reach them too.
    expect(StaffRole.instructor.briefAudience.includesActorPii, isTrue);
    expect(StaffRole.instructor.briefAudience.includesDirectorNotes, isTrue);

    // A role whose duties are undefined is granted nothing in particular.
    expect(StaffRole.other.briefAudience.includesActorPii, isFalse);
    expect(StaffRole.other.briefAudience.includesDirectorNotes, isFalse);
  });
}
