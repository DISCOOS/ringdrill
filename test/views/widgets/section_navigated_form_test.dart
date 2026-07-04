import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/widgets/section_navigated_form.dart';

/// DESIGN-008 follow-up 02 — prev/next section commands on
/// [SectionNavigatedForm], exercised directly (no [Program]/flag needed;
/// this widget is presentation-only, per its own doc comment).

List<FormSection> _sections([int count = 3]) => [
  for (var i = 0; i < count; i++)
    FormSection(
      id: String.fromCharCode('a'.codeUnitAt(0) + i),
      label: 'Section ${String.fromCharCode('A'.codeUnitAt(0) + i)}',
      icon: Icons.description_outlined,
      builder: (_) => Text('Body ${String.fromCharCode('A'.codeUnitAt(0) + i)}'),
    ),
];

Future<AppLocalizations> _pump(
  WidgetTester tester, {
  required List<FormSection> sections,
  List<FormSection> addable = const [],
  String? initialSectionId,
  Size size = const Size(400, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SectionNavigatedForm(
        title: 'Test',
        sections: sections,
        addable: addable,
        initialSectionId: initialSectionId,
        onAdd: (_) {},
        onRemove: (_) {},
        onSave: () {},
        onClose: () {},
      ),
    ),
  );
  await tester.pumpAndSettle();
  return AppLocalizations.delegate.load(const Locale('en'));
}

/// The [IconButton] with tooltip [message] — `find.byTooltip` locates the
/// wrapping `Tooltip`, not the button itself, so this walks up to the
/// `IconButton` ancestor that actually carries `onPressed`.
IconButton _iconButton(WidgetTester tester, String message) => tester.widget<IconButton>(
  find.ancestor(
    of: find.byTooltip(message),
    matching: find.byType(IconButton),
  ),
);

void main() {
  testWidgets(
    'compact: previous is disabled on the first section, next advances',
    (tester) async {
      final l = await _pump(tester, sections: _sections());

      expect(
        _iconButton(tester, l.formSectionPrevious).onPressed,
        isNull,
      );
      expect(find.text('Body A'), findsOneWidget);

      await tester.tap(find.byTooltip(l.formSectionNext));
      await tester.pumpAndSettle();

      expect(find.text('Body B'), findsOneWidget);
    },
  );

  testWidgets('compact: next is disabled on the last section, previous goes back', (
    tester,
  ) async {
    final l = await _pump(
      tester,
      sections: _sections(),
      initialSectionId: 'c',
    );

    expect(
      _iconButton(tester, l.formSectionNext).onPressed,
      isNull,
    );
    expect(find.text('Body C'), findsOneWidget);

    await tester.tap(find.byTooltip(l.formSectionPrevious));
    await tester.pumpAndSettle();

    expect(find.text('Body B'), findsOneWidget);
  });

  testWidgets('compact: in the middle both controls work', (tester) async {
    final l = await _pump(tester, sections: _sections(), initialSectionId: 'b');

    expect(
      _iconButton(tester, l.formSectionPrevious).onPressed,
      isNotNull,
    );
    expect(
      _iconButton(tester, l.formSectionNext).onPressed,
      isNotNull,
    );

    await tester.tap(find.byTooltip(l.formSectionNext));
    await tester.pumpAndSettle();
    expect(find.text('Body C'), findsOneWidget);

    await tester.tap(find.byTooltip(l.formSectionPrevious));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(l.formSectionPrevious));
    await tester.pumpAndSettle();
    expect(find.text('Body A'), findsOneWidget);
  });

  testWidgets(
    'arrows traverse only active sections, never the addable ones',
    (tester) async {
      final l = await _pump(
        tester,
        sections: _sections(2),
        addable: [
          FormSection(
            id: 'addable',
            label: 'Addable',
            icon: Icons.add_circle_outline,
            builder: (_) => const Text('Body Addable'),
          ),
        ],
        initialSectionId: 'b',
      );

      // At the last active section, next is disabled even though an
      // addable section exists beyond it — the arrows never reach into
      // `addable`.
      expect(
        _iconButton(tester, l.formSectionNext).onPressed,
        isNull,
      );
      expect(find.text('Body B'), findsOneWidget);
    },
  );

  testWidgets('compact: with a single active section both are disabled', (
    tester,
  ) async {
    final l = await _pump(tester, sections: _sections(1));

    expect(
      _iconButton(tester, l.formSectionPrevious).onPressed,
      isNull,
    );
    expect(
      _iconButton(tester, l.formSectionNext).onPressed,
      isNull,
    );
  });

  testWidgets('wide: previous/next appear in the detail-pane header and work', (
    tester,
  ) async {
    final l = await _pump(
      tester,
      sections: _sections(),
      size: const Size(900, 800),
    );

    expect(
      _iconButton(tester, l.formSectionPrevious).onPressed,
      isNull,
    );
    expect(find.text('Body A'), findsOneWidget);

    await tester.tap(find.byTooltip(l.formSectionNext));
    await tester.pumpAndSettle();

    expect(find.text('Body B'), findsOneWidget);
    expect(
      _iconButton(tester, l.formSectionPrevious).onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'compact: the top AppBar shows only the entity title and Save '
    '(follow-up 04)',
    (tester) async {
      final l = await _pump(tester, sections: _sections());

      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('Test')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text(l.save)),
        findsOneWidget,
      );

      // The switcher, prev/next and overflow all moved out of the AppBar.
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Section A'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.chevron_left),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.more_vert),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'compact: the selector and prev/next live in the bottom bar, not the AppBar',
    (tester) async {
      final l = await _pump(tester, sections: _sections());

      expect(
        find.descendant(
          of: find.byType(BottomAppBar),
          matching: find.text('Section A'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(BottomAppBar),
          matching: find.byTooltip(l.formSectionPrevious),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(BottomAppBar),
          matching: find.byTooltip(l.formSectionNext),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'compact: tapping the bottom bar selector opens the switcher sheet',
    (tester) async {
      await _pump(tester, sections: _sections());

      await tester.tap(
        find.descendant(
          of: find.byType(BottomAppBar),
          matching: find.text('Section A'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Section B'), findsOneWidget);
      expect(find.text('Section C'), findsOneWidget);

      await tester.tap(find.text('Section B'));
      await tester.pumpAndSettle();

      expect(find.text('Body B'), findsOneWidget);
    },
  );

  testWidgets(
    'compact: the bottom bar overflow is disabled unless the current '
    'section is removable, and removing falls back to the first section',
    (tester) async {
      final l = await _pump(
        tester,
        sections: [
          FormSection(
            id: 'a',
            label: 'A',
            icon: Icons.description_outlined,
            builder: (_) => const Text('Body A'),
          ),
          FormSection(
            id: 'b',
            label: 'B',
            icon: Icons.description_outlined,
            removable: true,
            builder: (_) => const Text('Body B'),
          ),
        ],
      );

      PopupMenuButton<String> overflow() => tester.widget<PopupMenuButton<String>>(
        find.descendant(
          of: find.byType(BottomAppBar),
          matching: find.byType(PopupMenuButton<String>),
        ),
      );

      // "A" is not removable: the overflow is present (so prev/next never
      // shift, per the earlier fix) but disabled.
      expect(overflow().enabled, isFalse);

      await tester.tap(find.byTooltip(l.formSectionNext));
      await tester.pumpAndSettle();

      // "B" is removable: enabled, and removing it falls back to "A".
      expect(overflow().enabled, isTrue);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text(l.formSectionRemoveAction), findsOneWidget);

      await tester.tap(find.text(l.formSectionRemoveAction));
      await tester.pumpAndSettle();

      expect(find.text('Body A'), findsOneWidget);
    },
  );
}
