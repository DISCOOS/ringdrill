import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/widgets/cast_roster_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _programUuid = 'prog-crs';

Map<String, Object> _basePrefs({bool includeActor = false}) {
  final prefs = <String, Object>{
    'app:activeProgram:v1': _programUuid,
    'app:librarySchema:v1': '1',
    'p:$_programUuid': '''{
      "uuid": "$_programUuid",
      "name": "Test",
      "description": "",
      "metadata": {"created":"2024-01-01T00:00:00.000Z","updated":"2024-01-01T00:00:00.000Z","version":"1.1"},
      "exercises": [], "teams": [], "sessions": [], "rolePlays": [], "actors": []
    }''',
  };
  if (includeActor) {
    prefs['pa:$_programUuid:actor-x'] =
        '{"uuid":"actor-x","realName":"Per Hansen"}';
  }
  return prefs;
}

Widget _buildSheet() {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const Scaffold(body: CastRosterSheet()),
  );
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(_basePrefs());
    await ProgramService().init();
  });

  testWidgets('sheet renders no AppBar widget', (tester) async {
    await tester.pumpWidget(_buildSheet());
    await tester.pump();
    expect(find.byType(AppBar), findsNothing);
  });

  testWidgets('header row shows castRoster title text', (tester) async {
    await tester.pumpWidget(_buildSheet());
    await tester.pump();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.castRoster), findsOneWidget);
  });

  testWidgets('empty state shows noActorsInRoster text', (tester) async {
    await tester.pumpWidget(_buildSheet());
    await tester.pump();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.noActorsInRoster), findsOneWidget);
  });

  testWidgets('FAB with newActor label is present', (tester) async {
    await tester.pumpWidget(_buildSheet());
    await tester.pump();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text(l10n.newActor), findsOneWidget);
  });
}
