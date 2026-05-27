import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/views/widgets/brief_theme.dart';

void main() {
  group('BriefTheme — palette', () {
    test('light canvas is #FFFFFF', () {
      expect(BriefTheme.light().surfaces.canvas, const Color(0xFFFFFFFF));
    });

    test('dark canvas is #0B0F17', () {
      expect(BriefTheme.dark().surfaces.canvas, const Color(0xFF0B0F17));
    });

    test('light link.color equals light text.body (same slate-700 token)', () {
      final theme = BriefTheme.light();
      expect(theme.link.color, theme.text.body);
    });
  });

  group('BriefTheme — typography', () {
    test('light body height is 1.65', () {
      expect(BriefTheme.light().typography.body.height, 1.65);
    });

    test('dark body height is 1.65', () {
      expect(BriefTheme.dark().typography.body.height, 1.65);
    });
  });

  group('BriefTheme.of', () {
    testWidgets('returns dark when brightness override is Brightness.dark', (
      tester,
    ) async {
      late BriefTheme result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              result = BriefTheme.of(context, override: Brightness.dark);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(result.surfaces.canvas, BriefTheme.dark().surfaces.canvas);
    });

    testWidgets('returns light when brightness override is Brightness.light', (
      tester,
    ) async {
      late BriefTheme result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              result = BriefTheme.of(context, override: Brightness.light);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(result.surfaces.canvas, BriefTheme.light().surfaces.canvas);
    });
  });
}
