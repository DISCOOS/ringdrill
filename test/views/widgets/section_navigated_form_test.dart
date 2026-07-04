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
}
