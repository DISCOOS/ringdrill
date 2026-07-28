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
    appUserRole.value = AppUserRole.director;
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
    appUserRole.value = AppUserRole.actor;
    await tester.pump();

    expect(find.text(l10n.appUserRoleActor), findsOneWidget);
    expect(find.text(l10n.briefAudienceDirector), findsNothing);
  });

  testWidgets('offers all three roles, marking the current one', (tester) async {
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

    expect(appUserRole.value, AppUserRole.actor);
    expect(
      Prefs.instanceOrNull!.getString(AppConfig.keyAppUserRole),
      AppUserRole.actor.name,
    );
    // And the button reflects it without being rebuilt by its host.
    expect(find.text(l10n.appUserRoleActor), findsOneWidget);
  });

  testWidgets('re-picking the current role is a no-op', (tester) async {
    await tester.pumpWidget(harness());

    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, l10n.briefAudienceDirector));
    await tester.pumpAndSettle();

    expect(appUserRole.value, AppUserRole.director);
  });

  // The rail form: 72px and label-less by design, so the label moves into the
  // tooltip rather than being dropped.
  testWidgets('iconOnly keeps the role legible through its tooltip', (
    tester,
  ) async {
    appUserRole.value = AppUserRole.instructor;
    await tester.pumpWidget(harness(iconOnly: true));

    expect(find.byIcon(appUserRoleIcon(AppUserRole.instructor)), findsOneWidget);
    expect(
      find.byTooltip(
        '${l10n.appUserRoleSectionTitle}: ${l10n.briefAudienceInstructor}',
      ),
      findsOneWidget,
    );
  });

  test('each role has its own icon and label', () {
    final icons = AppUserRole.values.map(appUserRoleIcon).toSet();
    expect(icons.length, AppUserRole.values.length);
  });

  // Consequence of answering "director level" for the actor's brief: an actor is
  // staff running the scenario from the inside, so they get the same detail —
  // including other actors' PII, which they need to find and work with them.
  test('an actor reads the brief as a director', () {
    expect(AppUserRole.actor.briefAudience.includesActorPii, isTrue);
    expect(AppUserRole.actor.briefAudience.includesDirectorNotes, isTrue);
    expect(
      AppUserRole.instructor.briefAudience.includesActorPii,
      isFalse,
      reason: 'the instructor reduction is unchanged',
    );
  });
}
