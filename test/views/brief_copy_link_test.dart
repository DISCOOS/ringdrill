import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/brief/brief_audience.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/brief_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

const _programUuid = 'copy-program';
const _exerciseUuid = 'copy-exercise';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  String? clipboardText;

  setUpAll(() async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    SharedPreferences.setMockInitialValues(_prefs());
    await ProgramService().init();
    await rootBundle.loadString(
      'assets/templates/ringdrill-standard-v1.nb.md.mustache',
    );
    await rootBundle.loadString(
      'assets/templates/ringdrill-standard-v1.en.md.mustache',
    );
  });

  setUp(() {
    clipboardText = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            final data = call.arguments as Map<Object?, Object?>;
            clipboardText = data['text'] as String?;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('exercise brief copy appends viewer link', (tester) async {
    await tester.pumpWidget(
      _app(
        const BriefScreen(
          exerciseUuid: _exerciseUuid,
          initialAudience: BriefAudience.participant,
        ),
      ),
    );
    await _settleBrief(tester);

    await tester.tap(find.byTooltip('Copy as markdown'));
    await tester.pump();

    final copied = clipboardText ?? '';
    expect(
      copied,
      endsWith(
        '→ https://ringdrill.app/brief/$_exerciseUuid?audience=participant',
      ),
    );
    expect(copied.split('\n\n→ ').first.trim(), isNotEmpty);
  });

  testWidgets('program brief copy appends viewer link', (tester) async {
    await tester.pumpWidget(
      _app(
        const BriefScreen(
          programUuid: _programUuid,
          initialAudience: BriefAudience.director,
        ),
      ),
    );
    await _settleBrief(tester);

    await tester.tap(find.byTooltip('Copy as markdown'));
    await tester.pump();

    final copied = clipboardText ?? '';
    expect(
      copied,
      endsWith(
        '→ https://ringdrill.app/brief/program/$_programUuid?audience=director',
      ),
    );
    expect(copied.split('\n\n→ ').first.trim(), isNotEmpty);
  });
}

Widget _app(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

Future<void> _settleBrief(WidgetTester tester) async {
  final l10n = await AppLocalizations.delegate.load(const Locale('en'));
  final copyButton = find.byTooltip(l10n.briefCopyMarkdown);
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
    if (copyButton.evaluate().isNotEmpty) {
      await tester.pump();
      return;
    }
  }
  await tester.pump();
}

Map<String, Object> _prefs() {
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
      'name': 'Copy Program',
      'description': 'Copy body',
      'metadata': meta,
      'exercises': [],
      'teams': [],
      'sessions': [],
      'rolePlays': [],
      'actors': [],
    }),
    'pe:$_programUuid:$_exerciseUuid': jsonEncode(_exercise().toJson()),
  };
}

Exercise _exercise() => Exercise(
  uuid: _exerciseUuid,
  name: 'Copy Exercise',
  startTime: const SimpleTimeOfDay(hour: 9, minute: 0),
  endTime: const SimpleTimeOfDay(hour: 10, minute: 0),
  numberOfTeams: 1,
  numberOfRounds: 1,
  executionTime: 60,
  evaluationTime: 15,
  rotationTime: 5,
  stations: const [
    Station(
      index: 0,
      name: 'Copy Station',
      position: LatLng(59, 10),
      situationMd: 'Copy situation.',
    ),
  ],
  schedule: const [],
);
