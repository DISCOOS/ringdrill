import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/views/roleplay_form_screen.dart';
import 'package:ringdrill/views/station_form_screen.dart';
import 'package:ringdrill/views/widgets/brief_markdown.dart';

/// DESIGN-010 prompt 2b fix 2 — the rollup must render flush left,
/// regardless of how short its content is, in both editors.
///
/// The real bug (not caught by the first pass at this fix, which only
/// compared two equally-short fixtures against each other and found them
/// equal): `BriefMarkdownBlock` wrapped its content in `Align(topCenter)` +
/// `ConstrainedBox(maxWidth: readingColumnMax)` — the same reading-column
/// cap `BriefMarkdown` uses for the full-page brief. A `Column` that
/// doesn't itself stretch to fill that box sizes to its content's own
/// width, so `Align` then *centers* that shrink-wrapped box — invisible
/// for content close to the cap's width, but a large left gap for a short
/// one-line heading plus a short sentence (a `RolePlay.background` like
/// "Hilde er hovedpersonen", DESIGN-009's common case). Long station
/// content happened to mask the effect; a Post/Spill rollup showing only a
/// couple of short words did not.
Station _station({required String description}) =>
    Station(index: 0, name: 'Post 1', description: description);

Exercise _exercise() => Exercise(
  uuid: 'ex-1',
  name: 'Exercise',
  startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
  endTime: const SimpleTimeOfDay(hour: 9, minute: 0),
  numberOfTeams: 1,
  numberOfRounds: 1,
  executionTime: 10,
  evaluationTime: 5,
  rotationTime: 2,
  stations: [Station(index: 0, name: 'Post 1')],
  schedule: const [],
);

RolePlay _rolePlay({required String background}) => RolePlay(
  uuid: 'rp-1',
  index: 0,
  exerciseUuid: 'ex-1',
  name: 'Marker',
  background: background,
  stationIndex: 0,
);

Future<double> _showRollupAndGetContentX(
  WidgetTester tester,
  Widget editor,
  Size size,
  String content,
) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  // A fresh UniqueKey forces a brand-new Element/State on every call: two
  // calls within the same test otherwise reuse the previous StationFormScreen/
  // RolePlayFormScreen State (same widget type, same tree position), so the
  // second call would inherit the first's already-flipped _showRollup state.
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: KeyedSubtree(key: UniqueKey(), child: editor),
    ),
  );
  await tester.pumpAndSettle();
  final l = await AppLocalizations.delegate.load(const Locale('en'));

  await tester.tap(find.text(l.rollupShowAction));
  await tester.pumpAndSettle();

  final finder = find.descendant(
    of: find.byType(BriefMarkdownBlock),
    matching: find.textContaining(content),
  );
  return tester.getTopLeft(finder).dx;
}

void main() {
  group('a short rollup block is not centered', () {
    const short = 'Hi';
    // Long enough to approach BriefTheme's readingColumnMax (720) once
    // wrapped, so the pre-fix Align(topCenter) would have shown it flush
    // left "by accident" — the exact trap the first fix attempt fell into.
    final long = List.filled(40, 'word').join(' ');

    testWidgets('station editor, wide', (tester) async {
      const size = Size(800, 1200);
      final shortX = await _showRollupAndGetContentX(
        tester,
        StationFormScreen(station: _station(description: short)),
        size,
        short,
      );
      final longX = await _showRollupAndGetContentX(
        tester,
        StationFormScreen(station: _station(description: long)),
        size,
        'word',
      );
      expect(shortX, longX);
    });

    testWidgets('roleplay editor, wide', (tester) async {
      const size = Size(800, 1200);
      final shortX = await _showRollupAndGetContentX(
        tester,
        RolePlayFormScreen(
          rolePlay: _rolePlay(background: short),
          exercise: _exercise(),
        ),
        size,
        short,
      );
      final longX = await _showRollupAndGetContentX(
        tester,
        RolePlayFormScreen(
          rolePlay: _rolePlay(background: long),
          exercise: _exercise(),
        ),
        size,
        'word',
      );
      expect(shortX, longX);
    });

    testWidgets('roleplay editor, narrow', (tester) async {
      const size = Size(580, 1400);
      final shortX = await _showRollupAndGetContentX(
        tester,
        RolePlayFormScreen(
          rolePlay: _rolePlay(background: short),
          exercise: _exercise(),
        ),
        size,
        short,
      );
      final longX = await _showRollupAndGetContentX(
        tester,
        RolePlayFormScreen(
          rolePlay: _rolePlay(background: long),
          exercise: _exercise(),
        ),
        size,
        'word',
      );
      expect(shortX, longX);
    });
  });

  group('the roleplay and station rollups use the same horizontal insets', () {
    const content = 'Same content';

    testWidgets('wide', (tester) async {
      const size = Size(800, 1200);
      final stationX = await _showRollupAndGetContentX(
        tester,
        StationFormScreen(station: _station(description: content)),
        size,
        content,
      );
      final roleplayX = await _showRollupAndGetContentX(
        tester,
        RolePlayFormScreen(
          rolePlay: _rolePlay(background: content),
          exercise: _exercise(),
        ),
        size,
        content,
      );
      expect(roleplayX, stationX);
    });

    testWidgets('narrow', (tester) async {
      const size = Size(580, 1400);
      final stationX = await _showRollupAndGetContentX(
        tester,
        StationFormScreen(station: _station(description: content)),
        size,
        content,
      );
      final roleplayX = await _showRollupAndGetContentX(
        tester,
        RolePlayFormScreen(
          rolePlay: _rolePlay(background: content),
          exercise: _exercise(),
        ),
        size,
        content,
      );
      expect(roleplayX, stationX);
    });
  });
}
