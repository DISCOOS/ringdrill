import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/utils/app_config.dart';
import 'package:ringdrill/views/concept_primer_screen.dart';
import 'package:ringdrill/views/main_screen.dart';
import 'package:ringdrill/views/widgets/concept_primer_content.dart';
import 'package:ringdrill/views/widgets/ring_rotation_figure.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _programUuid = 'primer-test-program';

Map<String, Object> _basePrefs({bool onboardingSeen = false}) => {
  'app:activeProgram:v1': _programUuid,
  'app:librarySchema:v1': '1',
  if (onboardingSeen) AppConfig.keyOnboardingSeen: true,
  'p:$_programUuid': jsonEncode({
    'uuid': _programUuid,
    'name': 'Primer Test Program',
    'description': '',
    'metadata': {
      'created': '2026-01-01T00:00:00.000Z',
      'updated': '2026-01-01T00:00:00.000Z',
      'version': '1.1',
    },
    'exercises': [],
    'teams': [],
    'sessions': [],
    'rolePlays': [],
    'actors': [],
  }),
};

Widget _app(GoRouter router) => MaterialApp.router(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  routerConfig: router,
);

String _location(GoRouter router) =>
    router.routeInformationProvider.value.uri.path;

Future<GoRouter> _pumpRouterWithGate(
  WidgetTester tester,
  bool isOnboardingSeen,
) async {
  SharedPreferences.setMockInitialValues(
    _basePrefs(onboardingSeen: isOnboardingSeen),
  );
  await ProgramService().init();
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = buildRouter(false, isOnboardingSeen);
  addTearDown(router.dispose);
  await tester.pumpWidget(_app(router));
  await tester.pumpAndSettle();
  return router;
}

void main() {
  // Route gate: redirect to /welcome when onboarding is unseen ---------------

  testWidgets('root path redirects to /welcome when onboarding unseen', (
    tester,
  ) async {
    final router = await _pumpRouterWithGate(tester, false);
    expect(_location(router), '/welcome');
    expect(find.byType(ConceptPrimerScreen), findsOneWidget);
  });

  testWidgets('root path skips /welcome when onboarding already seen', (
    tester,
  ) async {
    final router = await _pumpRouterWithGate(tester, true);
    expect(_location(router), isNot('/welcome'));
    expect(find.byType(ConceptPrimerScreen), findsNothing);
  });

  // CTA flag-writes and navigation -------------------------------------------

  testWidgets('"Hopp over" marks onboarding seen and leaves /welcome', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final router = await _pumpRouterWithGate(tester, false);
    expect(_location(router), '/welcome');

    await tester.tap(find.text(l10n.primerSkip));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(AppConfig.keyOnboardingSeen), isTrue);
    expect(_location(router), isNot('/welcome'));
  });

  testWidgets('"Start en tom plan" marks onboarding seen and leaves /welcome', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final router = await _pumpRouterWithGate(tester, false);
    expect(_location(router), '/welcome');

    await tester.tap(find.text(l10n.primerStartEmpty));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(AppConfig.keyOnboardingSeen), isTrue);
    expect(_location(router), isNot('/welcome'));
  });

  testWidgets(
    '"Åpne et eksempel" marks onboarding seen and leaves /welcome (stubbed)',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final router = await _pumpRouterWithGate(tester, false);
      expect(_location(router), '/welcome');

      await tester.tap(find.text(l10n.primerOpenExample));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(AppConfig.keyOnboardingSeen), isTrue);
      expect(_location(router), isNot('/welcome'));
    },
  );

  // Figure renders inside primer in light and dark ---------------------------

  testWidgets('ConceptPrimerContent paints RingRotationFigure in light theme', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData.light(),
        home: Scaffold(
          body: ConceptPrimerContent(
            onSkip: () {},
            onOpenExample: () {},
            onStartEmpty: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(RingRotationFigure), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ConceptPrimerContent paints RingRotationFigure in dark theme', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData.dark(),
        home: Scaffold(
          body: ConceptPrimerContent(
            onSkip: () {},
            onOpenExample: () {},
            onStartEmpty: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(RingRotationFigure), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
