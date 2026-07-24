import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/views/widgets/map_command.dart';

/// Unit coverage for [MapCommandSize.fromViewport], the height-aware size
/// selection that fixed the landscape-phone "map commands are too big / not
/// all showing" report: a landscape phone is wide enough to read as
/// medium/expanded by width alone, but too short to fit a full column of
/// 56dp commands, so the whole stack must drop to the 40dp compact control.
void main() {
  test('a landscape phone (wide but short) is forced compact', () {
    // ~844x390 logical: an iPhone in landscape — width says regular, height
    // says there is no room for a regular command column.
    expect(
      MapCommandSize.fromViewport(const Size(844, 390)),
      MapCommandSize.compact,
    );
  });

  test('a tablet in landscape (wide and tall enough) stays regular', () {
    expect(
      MapCommandSize.fromViewport(const Size(1024, 768)),
      MapCommandSize.regular,
    );
  });

  test('a phone in portrait (narrow, tall) stays compact by width', () {
    expect(
      MapCommandSize.fromViewport(const Size(390, 844)),
      MapCommandSize.compact,
    );
  });

  test('a short but narrow viewport is compact (both signals agree)', () {
    expect(
      MapCommandSize.fromViewport(const Size(400, 400)),
      MapCommandSize.compact,
    );
  });

  test('an unbounded height falls back to the width-only mapping', () {
    // A defensive path: if an ancestor ever hands the map unbounded height,
    // the short-viewport check must not treat infinity as "short".
    expect(
      MapCommandSize.fromViewport(const Size(1000, double.infinity)),
      MapCommandSize.regular,
    );
  });
}
