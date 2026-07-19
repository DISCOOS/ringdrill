import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/views/widgets/ringdrill_picker.dart';

/// ADR-0049 — the adaptive picker primitive: bottom sheet on compact,
/// dialog (reusing the form-dialog's rounded chrome) on medium/expanded,
/// with a threshold-gated search field and optional footer actions.

/// `tester.binding.setSurfaceSize` does not update `MediaQuery`, which
/// would keep reporting flutter_test's default ~800x600 regardless — so a
/// sub-600 "compact" size here would still make `WindowSizeClass` read as
/// medium/expanded (see the note in `roleplay_form_screen_layout_test.dart`
/// / `section_rollup_indentation_test.dart`). `tester.view.physicalSize`
/// keeps layout and MediaQuery consistent.
void _setWidth(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

class _Captured {
  String? value;
}

/// Opens the picker and waits for it to settle, without waiting for a
/// choice — [captured] is filled in once the picker resolves, whether that
/// happens before or after this returns.
Future<void> _open(
  WidgetTester tester,
  _Captured captured, {
  required List<String> items,
  String Function(String)? searchText,
  int searchThreshold = 8,
  List<Widget> footerActions = const [],
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            captured.value = await showRingdrillPicker<String>(
              context: context,
              title: 'Velg element',
              items: items,
              itemBuilder: (context, item, onTap) =>
                  ListTile(title: Text(item), onTap: onTap),
              searchText: searchText,
              searchHint: 'Søk',
              searchThreshold: searchThreshold,
              footerActions: footerActions,
            );
          },
          child: const Text('Open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('compact width opens as a bottom sheet with a drag handle', (
    tester,
  ) async {
    _setWidth(tester, 400);
    await _open(tester, _Captured(), items: const ['Alpha', 'Beta']);

    expect(
      find.byKey(const Key('ringdrill-sheet-drag-handle')),
      findsOneWidget,
    );
    expect(find.byType(Dialog), findsNothing);
    expect(find.byKey(const Key('ringdrill-picker-close')), findsNothing);
  });

  testWidgets('expanded width opens as a dialog with a close button', (
    tester,
  ) async {
    _setWidth(tester, 1000);
    await _open(tester, _Captured(), items: const ['Alpha', 'Beta']);

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byKey(const Key('ringdrill-sheet-drag-handle')), findsNothing);
    expect(find.byKey(const Key('ringdrill-picker-close')), findsOneWidget);
  });

  testWidgets('below the search threshold no search field renders', (
    tester,
  ) async {
    _setWidth(tester, 1000);
    await _open(
      tester,
      _Captured(),
      items: const ['Alpha', 'Beta'],
      searchText: (s) => s,
      searchThreshold: 8,
    );

    expect(find.byKey(const Key('ringdrill-picker-search')), findsNothing);
  });

  testWidgets(
    'at/past the search threshold a search field renders and filters live',
    (tester) async {
      _setWidth(tester, 1000);
      final items = List.generate(8, (i) => 'Item $i');
      await _open(
        tester,
        _Captured(),
        items: items,
        searchText: (s) => s,
      );

      expect(find.byKey(const Key('ringdrill-picker-search')), findsOneWidget);
      expect(find.text('Item 0'), findsOneWidget);
      expect(find.text('Item 1'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('ringdrill-picker-search')),
        'Item 1',
      );
      await tester.pump();

      expect(find.widgetWithText(ListTile, 'Item 1'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Item 0'), findsNothing);
    },
  );

  testWidgets('tapping a row resolves with that item', (tester) async {
    _setWidth(tester, 1000);
    final captured = _Captured();
    await _open(tester, captured, items: const ['Alpha', 'Beta']);

    await tester.tap(find.text('Beta'));
    await tester.pumpAndSettle();

    expect(captured.value, 'Beta');
  });

  testWidgets('dismissing without choosing resolves null', (tester) async {
    _setWidth(tester, 1000);
    final captured = _Captured();
    await _open(tester, captured, items: const ['Alpha', 'Beta']);

    await tester.tap(find.byKey(const Key('ringdrill-picker-close')));
    await tester.pumpAndSettle();

    expect(captured.value, isNull);
  });

  testWidgets('footer actions render below the list with a divider', (
    tester,
  ) async {
    _setWidth(tester, 1000);
    await _open(
      tester,
      _Captured(),
      items: const ['Alpha', 'Beta'],
      footerActions: [
        ListTile(
          key: const Key('footer-action'),
          title: const Text('+ New'),
          onTap: () {},
        ),
      ],
    );

    expect(find.byKey(const Key('footer-action')), findsOneWidget);
    // Two dividers now: one under the title (header separator) and one above
    // the footer actions.
    expect(find.byType(Divider), findsNWidgets(2));
    expect(
      tester.getTopLeft(find.byKey(const Key('footer-action'))).dy,
      greaterThan(tester.getTopLeft(find.text('Beta')).dy),
    );
  });

  testWidgets(
    'focusing the sheet search field on compact does not throw and keeps '
    'the list visible',
    (tester) async {
      _setWidth(tester, 400);
      final items = List.generate(8, (i) => 'Item $i');
      await _open(tester, _Captured(), items: items, searchText: (s) => s);

      await tester.tap(find.byKey(const Key('ringdrill-picker-search')));
      await tester.enterText(
        find.byKey(const Key('ringdrill-picker-search')),
        'Item',
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Item 0'), findsOneWidget);
    },
  );
}
