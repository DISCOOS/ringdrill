import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/views/shell/window_size_class.dart';

void main() {
  Future<WindowSizeClass> pumpWithWidth(
    WidgetTester tester,
    double width,
  ) async {
    late WindowSizeClass actual;
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: Size(width, 800)),
        child: Builder(
          builder: (context) {
            actual = WindowSizeClass.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return actual;
  }

  testWidgets('WindowSizeClass.of uses Material 3 breakpoints', (tester) async {
    expect(await pumpWithWidth(tester, 599), WindowSizeClass.compact);
    expect(await pumpWithWidth(tester, 600), WindowSizeClass.medium);
    expect(await pumpWithWidth(tester, 839), WindowSizeClass.medium);
    expect(await pumpWithWidth(tester, 840), WindowSizeClass.expanded);
    expect(await pumpWithWidth(tester, 1280), WindowSizeClass.expanded);
  });

  test('rail and master/detail are enabled on medium and expanded', () {
    expect(WindowSizeClass.compact.hasRail, isFalse);
    expect(WindowSizeClass.compact.hasMasterDetail, isFalse);
    expect(WindowSizeClass.medium.hasRail, isTrue);
    expect(WindowSizeClass.medium.hasMasterDetail, isTrue);
    expect(WindowSizeClass.expanded.hasRail, isTrue);
    expect(WindowSizeClass.expanded.hasMasterDetail, isTrue);
  });
}
