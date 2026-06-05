import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/actor.dart';
import 'package:ringdrill/views/widgets/brief_markdown.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/brief/brief_audience.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/brief_screen.dart';
import 'package:ringdrill/views/widgets/brief_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

// ---------------------------------------------------------------------------
// Fixtures — based on the DESIGN-004 brief_renderer_test fixture
// ---------------------------------------------------------------------------

const _programUuid = 'prog-bs';
const _exerciseUuid = 'ex-3';
const _actorUuid = 'actor-12';

final _actor = Actor(
  uuid: _actorUuid,
  realName: 'Kari Hansen',
  phone: '99887766',
);

const _rolePlay = RolePlay(
  uuid: 'rp-anne',
  index: 0,
  exerciseUuid: _exerciseUuid,
  name: 'Anne Glemsk',
  age: 39,
  signalement: '160 cm, grått hår, blå anorakk',
  behavior: 'Du spiller en dement dame i god fysisk form.',
  stationIndex: 0,
  actorUuid: _actorUuid,
);

Exercise _exercise() => Exercise(
  uuid: _exerciseUuid,
  name: 'Øvelse 3',
  startTime: const SimpleTimeOfDay(hour: 8, minute: 30),
  endTime: const SimpleTimeOfDay(hour: 10, minute: 30),
  numberOfTeams: 4,
  numberOfRounds: 4,
  executionTime: 60,
  evaluationTime: 15,
  rotationTime: 5,
  stations: const [
    Station(
      index: 0,
      name: 'Demens',
      position: LatLng(58.99, 10.43),
      situationMd: 'Anne Glemsk er savnet.',
      directorNotesMd: 'Notater til instruktør: Markør utplassert.',
    ),
  ],
  schedule: const [
    [
      SimpleTimeOfDay(hour: 8, minute: 30),
      SimpleTimeOfDay(hour: 9, minute: 30),
      SimpleTimeOfDay(hour: 9, minute: 45),
    ],
    [
      SimpleTimeOfDay(hour: 9, minute: 50),
      SimpleTimeOfDay(hour: 10, minute: 50),
      SimpleTimeOfDay(hour: 10, minute: 5),
    ],
    [
      SimpleTimeOfDay(hour: 10, minute: 10),
      SimpleTimeOfDay(hour: 11, minute: 10),
      SimpleTimeOfDay(hour: 11, minute: 25),
    ],
    [
      SimpleTimeOfDay(hour: 11, minute: 30),
      SimpleTimeOfDay(hour: 12, minute: 30),
      SimpleTimeOfDay(hour: 12, minute: 45),
    ],
  ],
);

Map<String, Object> _buildPrefs() {
  final ex = _exercise();
  final now = DateTime(2026);
  final meta = {
    'created': now.toIso8601String(),
    'updated': now.toIso8601String(),
    'version': '1.1',
  };
  return {
    'app:activeProgram:v1': _programUuid,
    'app:librarySchema:v1': '1',
    'p:$_programUuid': jsonEncode({
      'uuid': _programUuid,
      'name': 'Test Program BS',
      'description': '',
      'metadata': meta,
      'exercises': [],
      'teams': [],
      'sessions': [],
      'rolePlays': [],
      'actors': [],
    }),
    'pe:$_programUuid:$_exerciseUuid': jsonEncode(ex.toJson()),
    'pr:$_programUuid:rp-anne': jsonEncode(_rolePlay.toJson()),
    'pa:$_programUuid:$_actorUuid': jsonEncode(_actor.toJson()),
  };
}

Widget _buildScreen({
  String? exerciseUuid,
  String? programUuid,
  BriefAudience? initialAudience,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: BriefScreen(
      exerciseUuid: exerciseUuid,
      programUuid: programUuid,
      initialAudience: initialAudience,
    ),
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Pump the widget tree enough to let the async BriefRenderer future complete
/// and the MarkdownWidget be placed in the tree.
///
/// Uses runAsync to allow the real async Future (rootBundle.loadString) to
/// resolve outside fake-async on the first call (pre-warmed in setUpAll so
/// the cache is hot for all subsequent calls).  Two pump() calls are needed:
/// the first drains the microtask chain that resolves _renderFuture; the
/// second lets FutureBuilder's internal setState rebuild the widget tree.
/// VisibilityDetectorController.updateInterval is set to Duration.zero in
/// setUpAll so the package does not leave a pending timer that would make
/// tests fail.
Future<void> _awaitRender(WidgetTester tester) async {
  await tester.runAsync(() async {
    await Future<void>.delayed(Duration.zero);
  });
  await tester.pump(); // drains _renderFuture microtask chain
  await tester.pump(); // FutureBuilder rebuilds after Future completes
}

/// Returns the markdown data currently displayed by the single BriefMarkdown.
String _markdownData(WidgetTester tester) {
  return tester.widget<BriefMarkdown>(find.byType(BriefMarkdown)).data;
}

/// Open the audience PopupMenuButton and tap the menu item with [label].
Future<void> _tapAudience(WidgetTester tester, String label) async {
  await tester.tap(find.byType(PopupMenuButton<BriefAudience>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await _awaitRender(tester);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Set up once for the whole test file:
  // - Disable visibility_detector debounce to avoid pending-timer failures.
  // - Load ProgramService with the exercise fixture once; ProgramService is a
  //   singleton whose init() skips on subsequent calls, so we call it once here
  //   and all tests in this file share the same loaded state.
  setUpAll(() async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    SharedPreferences.setMockInitialValues(_buildPrefs());
    await ProgramService().init();
    // Pre-warm the rootBundle cache in the real async zone so that subsequent
    // loadString calls inside fake-async test zones see an already-completed
    // Future and resolve via microtask (a single pump() is then sufficient).
    await rootBundle.loadString(
      'assets/templates/ringdrill-standard-v1.nb.md.mustache',
    );
  });

  // Default audience is director (Øvelsesleder) — DESIGN-006 step 3/4.
  // Participants do not use the app, so the brief opens at director level.
  group('BriefScreen — director audience (default)', () {
    testWidgets('renders exercise brief markdown', (tester) async {
      await tester.pumpWidget(_buildScreen(exerciseUuid: _exerciseUuid));
      await _awaitRender(tester);

      // Role name appears for all audiences.
      expect(_markdownData(tester), contains('Anne Glemsk'));
    });

    testWidgets('shows actor PII by default (director audience)', (tester) async {
      await tester.pumpWidget(_buildScreen(exerciseUuid: _exerciseUuid));
      await _awaitRender(tester);

      final md = _markdownData(tester);
      // Director audience includes actor real name and phone.
      expect(md, contains('Kari Hansen'));
      expect(md, contains('99887766'));
    });
  });

  group('BriefScreen — participant audience (explicit)', () {
    testWidgets('hides actor PII for participant', (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          exerciseUuid: _exerciseUuid,
          initialAudience: BriefAudience.participant,
        ),
      );
      await _awaitRender(tester);

      final md = _markdownData(tester);
      expect(md, isNot(contains('Kari Hansen')));
      expect(md, isNot(contains('99887766')));
    });
  });

  group('BriefScreen — instructor audience', () {
    testWidgets('hides actor PII for instructor audience', (tester) async {
      await tester.pumpWidget(_buildScreen(exerciseUuid: _exerciseUuid));
      await _awaitRender(tester);

      await _tapAudience(tester, 'Instructor');

      final md = _markdownData(tester);
      // directorNotesMd is excluded from the SharedPreferences JSON schema
      // (@JsonKey includeFromJson/includeToJson: false), so it is null after
      // round-trip. Director-notes content coverage lives in brief_renderer_test.
      // Verify only that actor PII is hidden when instructor is selected.
      expect(md, isNot(contains('Kari Hansen')));
      expect(md, isNot(contains('99887766')));
    });
  });

  group('BriefScreen — empty states', () {
    // These tests verify that BriefScreen reads from ProgramService at
    // build time. Since ProgramService has the exercise fixture loaded,
    // we test "missing exercise" via a non-existent UUID. For "missing
    // program" we cannot reinitialize the singleton, so we test the
    // programUuid mismatch path instead (the screen still renders with
    // the active program, logging a debug warning).
    testWidgets('missing exercise shows empty state', (tester) async {
      await tester.pumpWidget(_buildScreen(exerciseUuid: 'does-not-exist'));
      await tester.pump();

      expect(find.text('Exercise not found'), findsOneWidget);
    });

    testWidgets('programUuid renders the active program brief', (tester) async {
      // The active program IS loaded; opening via programUuid should render.
      await tester.pumpWidget(_buildScreen(programUuid: _programUuid));
      await _awaitRender(tester);

      expect(_markdownData(tester), contains('Test Program BS'));
    });
  });

  group('BriefScreen — layout', () {
    testWidgets('narrow layout keeps audience picker in the app bar', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildScreen(exerciseUuid: _exerciseUuid));
      await _awaitRender(tester);

      final picker = find.byType(PopupMenuButton<BriefAudience>);
      expect(picker, findsOneWidget);

      // Audience picker lives in the AppBar regardless of width — the slim
      // PopupMenuButton replaces the old SegmentedButton-in-body layout.
      expect(
        find.descendant(of: find.byType(AppBar), matching: picker),
        findsOneWidget,
      );
    });

    testWidgets(
      'wide layout shows audience picker in app bar and TOC sidebar',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(_buildScreen(exerciseUuid: _exerciseUuid));
        await _awaitRender(tester);

        final picker = find.byType(PopupMenuButton<BriefAudience>);
        expect(picker, findsOneWidget);

        // TOC sidebar heading visible
        expect(find.text('Contents'), findsOneWidget);

        // The picker must be inside the AppBar widget tree
        expect(
          find.descendant(of: find.byType(AppBar), matching: picker),
          findsOneWidget,
        );
      },
    );
  });

  group('BriefScreen — search', () {
    testWidgets('search field appears when search button is tapped', (
      tester,
    ) async {
      await tester.pumpWidget(_buildScreen(exerciseUuid: _exerciseUuid));
      await _awaitRender(tester);

      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.byIcon(Icons.search));
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets(
      'typing a query wraps matches in <mark>/<curr-mark> tags in BriefMarkdown.data',
      (tester) async {
        await tester.pumpWidget(_buildScreen(exerciseUuid: _exerciseUuid));
        await _awaitRender(tester);

        await tester.tap(find.byIcon(Icons.search));
        await tester.pump();

        await tester.enterText(find.byType(TextField), 'Anne');
        await tester.pump();

        // BriefScreen wraps the active match in <curr-mark> and any remaining
        // matches in <mark>. With a single match the wrapping tag is always
        // <curr-mark>; accept either to keep the assertion stable across
        // fixtures with more or fewer matches.
        final md = _markdownData(tester);
        expect(
          md.contains('<mark>Anne') || md.contains('<curr-mark>Anne'),
          isTrue,
          reason: 'expected one of <mark>Anne / <curr-mark>Anne in: $md',
        );
      },
    );
  });

  group('BriefScreen — TOC H4 filter', () {
    testWidgets('wide layout TOC does not show H4 headings', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildScreen(exerciseUuid: _exerciseUuid));
      await _awaitRender(tester);
      await _awaitRender(
        tester,
      ); // second render after _wideTocSidebar transitions

      // Sidebar is visible
      expect(find.text('Contents'), findsOneWidget);

      // H4 headings must not appear in the TocWidget
      expect(
        find.descendant(
          of: find.byType(ListView),
          matching: find.text('Varighet'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(ListView),
          matching: find.text('Utstyrsbehov'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(ListView),
          matching: find.text('Situasjon'),
        ),
        findsNothing,
      );
    });
  });

  group('BriefScreen — print button', () {
    testWidgets('print button is hidden on non-web', (tester) async {
      await tester.pumpWidget(_buildScreen(exerciseUuid: _exerciseUuid));
      await _awaitRender(tester);

      // kIsWeb is false in the vm test environment
      expect(find.byIcon(Icons.print), findsNothing);
    });
  });

  group('BriefScreen — BriefTheme', () {
    testWidgets('scaffold background matches BriefTheme.light canvas', (
      tester,
    ) async {
      await tester.pumpWidget(_buildScreen(exerciseUuid: _exerciseUuid));
      await _awaitRender(tester);

      // Find the inner Theme widget that sets scaffoldBackgroundColor
      final themes = tester.widgetList<Theme>(find.byType(Theme));
      final canvasColor = BriefTheme.light().surfaces.canvas;
      final found = themes.any(
        (t) => t.data.scaffoldBackgroundColor == canvasColor,
      );
      expect(
        found,
        isTrue,
        reason:
            'A Theme in the tree must set scaffoldBackgroundColor to the '
            'BriefTheme.light() canvas color',
      );
    });

    testWidgets(
      'wide layout (1024px): markdown omits in-doc TOC after layout settles',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(_buildScreen(exerciseUuid: _exerciseUuid));
        await _awaitRender(tester); // first render + _wideTocSidebar transition
        await _awaitRender(tester); // second render with wideTocSidebar: true

        expect(
          _markdownData(tester),
          isNot(contains('Innholdsfortegnelse')),
          reason:
              'Wide layout passes wideTocSidebar: true, suppressing in-doc TOC',
        );
      },
    );

    testWidgets('narrow layout (600px): markdown includes in-doc TOC', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(600, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // The in-doc TOC only renders in multi-exercise (program) mode; the
      // single-exercise template suppresses the program-level header block
      // entirely. Use programUuid so isSingleExercise=false and the
      // {{#if_in_doc_toc}} block emits the "## Innholdsfortegnelse" section.
      await tester.pumpWidget(_buildScreen(programUuid: _programUuid));
      await _awaitRender(tester);

      expect(
        _markdownData(tester),
        contains('Innholdsfortegnelse'),
        reason:
            'Narrow layout passes wideTocSidebar: false, rendering in-doc TOC',
      );
    });
  });
}
