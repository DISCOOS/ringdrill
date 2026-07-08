import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/widgets/editor_token.dart';
import 'package:ringdrill/views/widgets/token_insertion_menu.dart';

/// Types [text] (typically ending in a trigger) and pumps twice: the menu
/// opens via a post-frame callback (deferred so the caret position is read
/// only after `RenderEditable` has relaid out for the new text — see
/// `TokenInsertionMenuState._onChanged`), and inserting the resulting
/// `OverlayEntry` itself only schedules its first real build for the frame
/// after that.
Future<void> _typeAndOpen(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
  await tester.pump();
}

/// A field whose `onChanged` rebuilds an ancestor on every keystroke —
/// mirroring `RolePlayFormScreen`'s own name field, which does this to keep
/// a live effective-identity preview in sync (DESIGN-009 follow-up 4c
/// regression coverage). No other field in the app wires `onChanged` this
/// way, which is why the bug this guards against went unexercised until a
/// test opened the picker on that specific field.
class _AncestorRebuildHarness extends StatefulWidget {
  const _AncestorRebuildHarness();

  @override
  State<_AncestorRebuildHarness> createState() =>
      _AncestorRebuildHarnessState();
}

class _AncestorRebuildHarnessState extends State<_AncestorRebuildHarness> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TokenInsertionMenu(
        controller: _controller,
        focusNode: _focusNode,
        variables: const [
          VariableToken(name: 'frekvens', effectiveValue: 'Kanal 6'),
        ],
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          onChanged: (_) => setState(() {}),
        ),
      ),
    );
  }
}

Future<TextEditingController> _pump(
  WidgetTester tester, {
  ValueChanged<String>? onCreateVariable,
  String Function(String label)? onCreateLocation,
  String Function(String label)? onCreatePerson,
  List<StationLocationToken> stationLocations = const [],
  List<StationPersonToken> stationPersons = const [],
}) async {
  final controller = TextEditingController();
  final focusNode = FocusNode();
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: TokenInsertionMenu(
          controller: controller,
          focusNode: focusNode,
          variables: const [
            VariableToken(name: 'frekvens', effectiveValue: 'Kanal 6'),
          ],
          planFields: const [
            PlanFieldToken(name: 'exercise.name', label: 'Øvelsesnavn'),
          ],
          stationLocations: stationLocations,
          stationPersons: stationPersons,
          onCreateVariable: onCreateVariable,
          onCreateLocation: onCreateLocation,
          onCreatePerson: onCreatePerson,
          child: TextField(controller: controller, focusNode: focusNode),
        ),
      ),
    ),
  );
  await tester.tap(find.byType(TextField));
  await tester.pump();
  return controller;
}

void main() {
  group('TokenInsertionMenu', () {
    testWidgets(
      '"/" opens the menu with the flat variable + plan-field list; selecting inserts and closes',
      (tester) async {
        final controller = await _pump(tester);

        await _typeAndOpen(tester, '/');

        expect(find.text('frekvens'), findsOneWidget);
        expect(find.text('Øvelsesnavn'), findsOneWidget);

        await tester.tap(find.text('frekvens'));
        await tester.pump();

        expect(controller.text, '{{var.frekvens}}');
        expect(
          tester
              .state<TokenInsertionMenuState>(find.byType(TokenInsertionMenu))
              .isMenuOpen,
          isFalse,
        );
      },
    );

    testWidgets(
      '"{{" opens the same picker directly; selecting a plan field inserts a bare cross-reference',
      (tester) async {
        final controller = await _pump(tester);

        await _typeAndOpen(tester, '{{');

        expect(find.text('frekvens'), findsOneWidget);
        expect(find.text('Øvelsesnavn'), findsOneWidget);

        await tester.tap(find.text('Øvelsesnavn'));
        await tester.pump();

        expect(controller.text, '{{exercise.name}}');
      },
    );

    testWidgets('filters the flat list as the user types after the trigger', (
      tester,
    ) async {
      await _pump(tester);

      await _typeAndOpen(tester, '/frek');

      expect(find.text('frekvens'), findsOneWidget);
      expect(find.text('Øvelsesnavn'), findsNothing);
    });

    testWidgets(
      'typing "{{var." keeps the menu open across the dot and narrows to '
      'variables, filtering by the name after the prefix '
      '(regression: the dot used to fall outside the trigger filter and '
      'close the menu immediately)',
      (tester) async {
        await _pump(tester);

        await _typeAndOpen(tester, '{{var');
        expect(
          tester
              .state<TokenInsertionMenuState>(find.byType(TokenInsertionMenu))
              .isMenuOpen,
          isTrue,
        );

        // The dot must not close the menu.
        await _typeAndOpen(tester, '{{var.');
        expect(
          tester
              .state<TokenInsertionMenuState>(find.byType(TokenInsertionMenu))
              .isMenuOpen,
          isTrue,
        );
        // "var." is the namespace prefix, not a name to match — narrows to
        // variables (no plan fields) rather than showing "no matches".
        expect(find.text('frekvens'), findsOneWidget);
        expect(find.text('Øvelsesnavn'), findsNothing);

        // Filters the variable list by what comes after the prefix.
        await _typeAndOpen(tester, '{{var.frek');
        expect(find.text('frekvens'), findsOneWidget);

        await _typeAndOpen(tester, '{{var.zzz');
        expect(find.text('frekvens'), findsNothing);

        // Closing the token (typing "}") ends the trigger.
        await tester.enterText(find.byType(TextField), '{{var.frekvens}}');
        await tester.pump();
        await tester.pump();
        expect(
          tester
              .state<TokenInsertionMenuState>(find.byType(TokenInsertionMenu))
              .isMenuOpen,
          isFalse,
        );
      },
    );

    testWidgets(
      'the "Opprett variabel" entry is hidden when onCreateVariable is null, '
      'even with a no-match filter',
      (tester) async {
        await _pump(tester, onCreateVariable: null);

        await _typeAndOpen(tester, '/zzz');

        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        expect(find.text(l10n.tokenMenuEmpty), findsOneWidget);
        expect(
          find.textContaining(l10n.tokenMenuCreateVariable('zzz')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'the "Opprett variabel" entry appears with a no-match filter once a '
      'callback is supplied, and invokes it on selection',
      (tester) async {
        String? created;
        final controller = await _pump(
          tester,
          onCreateVariable: (name) => created = name,
        );

        await _typeAndOpen(tester, '/zzz');

        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        final createLabel = l10n.tokenMenuCreateVariable('zzz');
        expect(find.text(createLabel), findsOneWidget);

        await tester.tap(find.text(createLabel));
        await tester.pump();

        expect(created, 'zzz');
        expect(controller.text, '{{var.zzz}}');
      },
    );

    testWidgets(
      'typing "{{var.zzz" offers "Opprett variabel «zzz»", using the name '
      'after the prefix rather than the literal "var.zzz"',
      (tester) async {
        String? created;
        final controller = await _pump(
          tester,
          onCreateVariable: (name) => created = name,
        );

        await _typeAndOpen(tester, '{{var.zzz');

        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        final createLabel = l10n.tokenMenuCreateVariable('zzz');
        expect(find.text(createLabel), findsOneWidget);

        await tester.tap(find.text(createLabel));
        await tester.pump();

        expect(created, 'zzz');
        expect(controller.text, '{{var.zzz}}');
      },
    );

    testWidgets(
      'anchors near the caret, not at the bottom of a full-screen field '
      '(regression: RingDrillTextArea sections use expands: true, so the '
      'field itself can be the height of the whole screen)',
      (tester) async {
        final controller = TextEditingController(text: '\n\n\n/');
        final focusNode = FocusNode();
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: TokenInsertionMenu(
                controller: controller,
                focusNode: focusNode,
                variables: const [
                  VariableToken(name: 'frekvens', effectiveValue: 'Kanal 6'),
                ],
                // Fills the whole Scaffold body, like a section-navigated
                // markdown field does (RingDrillTextArea's `expands`).
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  expands: true,
                  maxLines: null,
                  minLines: null,
                  textAlignVertical: TextAlignVertical.top,
                ),
              ),
            ),
          ),
        );

        focusNode.requestFocus();
        await tester.pump();
        // Moves the caret onto the trailing "/" and fires _onChanged (the
        // seed text was set before any listener was attached, so it never
        // ran the trigger detection on its own).
        controller.selection = TextSelection.collapsed(
          offset: controller.text.length,
        );
        await tester.pump();
        await tester.pump();

        final screenHeight =
            tester.view.physicalSize.height / tester.view.devicePixelRatio;
        final positioned = tester.widgetList<Positioned>(
          find.byType(Positioned),
        );
        final menuPositioned = positioned.firstWhere((p) => p.width != null);

        // The caret sits on the field's 4th line, near the top of an
        // 800-tall test viewport — the menu must anchor there, not at
        // (near) the bottom of the screen.
        expect(menuPositioned.top, isNotNull);
        expect(menuPositioned.top!, lessThan(screenHeight / 2));
      },
    );

    group('station.loc/person entries (DESIGN-009 follow-up 4)', () {
      const location = StationLocationToken(
        slug: 'lkp',
        label: 'Siste kjente posisjon',
        preview: 'Sentrum',
      );
      const person = StationPersonToken(
        slug: 'anne',
        label: 'Anne Glemsk',
        preview: 'effektivt navn',
      );

      testWidgets(
        '"/" offers station locations/persons alongside variables and plan fields',
        (tester) async {
          await _pump(
            tester,
            stationLocations: const [location],
            stationPersons: const [person],
          );

          await _typeAndOpen(tester, '/');

          expect(find.text('frekvens'), findsOneWidget);
          expect(find.text('Øvelsesnavn'), findsOneWidget);
          expect(find.text('Siste kjente posisjon'), findsOneWidget);
          expect(find.text('Anne Glemsk'), findsOneWidget);
        },
      );

      testWidgets(
        'selecting a station location inserts {{station.loc.<slug>}}',
        (tester) async {
          final controller = await _pump(
            tester,
            stationLocations: const [location],
          );

          await _typeAndOpen(tester, '/');
          await tester.tap(find.text('Siste kjente posisjon'));
          await tester.pump();

          expect(controller.text, '{{station.loc.lkp}}');
        },
      );

      testWidgets(
        'selecting a station person inserts {{station.person.<slug>}}',
        (tester) async {
          final controller = await _pump(
            tester,
            stationPersons: const [person],
          );

          await _typeAndOpen(tester, '/');
          await tester.tap(find.text('Anne Glemsk'));
          await tester.pump();

          expect(controller.text, '{{station.person.anne}}');
        },
      );

      testWidgets('typing "{{station.loc." narrows to locations only, hiding '
          'variables, plan fields and persons', (tester) async {
        await _pump(
          tester,
          stationLocations: const [location],
          stationPersons: const [person],
        );

        await _typeAndOpen(tester, '{{station.loc.');

        expect(find.text('Siste kjente posisjon'), findsOneWidget);
        expect(find.text('frekvens'), findsNothing);
        expect(find.text('Øvelsesnavn'), findsNothing);
        expect(find.text('Anne Glemsk'), findsNothing);
      });

      testWidgets('typing "{{station.person." narrows to persons only', (
        tester,
      ) async {
        await _pump(
          tester,
          stationLocations: const [location],
          stationPersons: const [person],
        );

        await _typeAndOpen(tester, '{{station.person.');

        expect(find.text('Anne Glemsk'), findsOneWidget);
        expect(find.text('Siste kjente posisjon'), findsNothing);
        expect(find.text('frekvens'), findsNothing);
      });

      testWidgets('empty stationLocations/stationPersons offer nothing extra', (
        tester,
      ) async {
        await _pump(tester);

        await _typeAndOpen(tester, '/');

        expect(find.text('frekvens'), findsOneWidget);
        expect(find.text('Øvelsesnavn'), findsOneWidget);
      });
    });

    group('inline create (DESIGN-009 follow-up 4)', () {
      testWidgets(
        '"Create location/person" entries are hidden when the callbacks '
        'are null, even with a no-match filter',
        (tester) async {
          await _pump(tester);

          await _typeAndOpen(tester, '/zzz');

          final l10n = await AppLocalizations.delegate.load(const Locale('en'));
          expect(find.text(l10n.tokenMenuEmpty), findsOneWidget);
          expect(
            find.textContaining(l10n.tokenMenuCreateLocation('zzz')),
            findsNothing,
          );
          expect(
            find.textContaining(l10n.tokenMenuCreatePerson('zzz')),
            findsNothing,
          );
        },
      );

      testWidgets(
        'a bare no-match filter offers create-variable, create-location and '
        'create-person all at once when every callback is supplied',
        (tester) async {
          await _pump(
            tester,
            onCreateVariable: (_) {},
            onCreateLocation: (label) => 'slug-for-$label',
            onCreatePerson: (label) => 'slug-for-$label',
          );

          await _typeAndOpen(tester, '/zzz');

          final l10n = await AppLocalizations.delegate.load(const Locale('en'));
          expect(
            find.text(l10n.tokenMenuCreateVariable('zzz')),
            findsOneWidget,
          );
          expect(
            find.text(l10n.tokenMenuCreateLocation('zzz')),
            findsOneWidget,
          );
          expect(find.text(l10n.tokenMenuCreatePerson('zzz')), findsOneWidget);
        },
      );

      testWidgets(
        'selecting "Create location «x»" calls onCreateLocation and inserts '
        '{{station.loc.<generated slug>}}',
        (tester) async {
          String? createdLabel;
          final controller = await _pump(
            tester,
            onCreateLocation: (label) {
              createdLabel = label;
              return 'lkp_2';
            },
          );

          await _typeAndOpen(tester, '/Ny_lokasjon');

          final l10n = await AppLocalizations.delegate.load(const Locale('en'));
          final createLabel = l10n.tokenMenuCreateLocation('Ny_lokasjon');
          expect(find.text(createLabel), findsOneWidget);

          await tester.tap(find.text(createLabel));
          await tester.pump();

          expect(createdLabel, 'Ny_lokasjon');
          expect(controller.text, '{{station.loc.lkp_2}}');
        },
      );

      testWidgets(
        'selecting "Create person «x»" calls onCreatePerson and inserts '
        '{{station.person.<generated slug>}}',
        (tester) async {
          String? createdLabel;
          final controller = await _pump(
            tester,
            onCreatePerson: (label) {
              createdLabel = label;
              return 'anne_2';
            },
          );

          await _typeAndOpen(tester, '/Anne');

          final l10n = await AppLocalizations.delegate.load(const Locale('en'));
          final createLabel = l10n.tokenMenuCreatePerson('Anne');
          expect(find.text(createLabel), findsOneWidget);

          await tester.tap(find.text(createLabel));
          await tester.pump();

          expect(createdLabel, 'Anne');
          expect(controller.text, '{{station.person.anne_2}}');
        },
      );

      testWidgets(
        'typing "{{station.loc.zzz" offers only "Create location", not '
        'variable or person, using the name after the prefix',
        (tester) async {
          final controller = await _pump(
            tester,
            onCreateVariable: (_) {},
            onCreateLocation: (label) => 'slug',
            onCreatePerson: (label) => 'slug',
          );

          await _typeAndOpen(tester, '{{station.loc.zzz');

          final l10n = await AppLocalizations.delegate.load(const Locale('en'));
          expect(
            find.text(l10n.tokenMenuCreateLocation('zzz')),
            findsOneWidget,
          );
          expect(find.text(l10n.tokenMenuCreateVariable('zzz')), findsNothing);
          expect(find.text(l10n.tokenMenuCreatePerson('zzz')), findsNothing);

          await tester.tap(find.text(l10n.tokenMenuCreateLocation('zzz')));
          await tester.pump();
          expect(controller.text, '{{station.loc.slug}}');
        },
      );
    });

    testWidgets('dismisses on Escape', (tester) async {
      await _pump(tester);

      await tester.enterText(find.byType(TextField), '/');
      await tester.pump();
      expect(
        tester
            .state<TokenInsertionMenuState>(find.byType(TokenInsertionMenu))
            .isMenuOpen,
        isTrue,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(
        tester
            .state<TokenInsertionMenuState>(find.byType(TokenInsertionMenu))
            .isMenuOpen,
        isFalse,
      );
    });

    testWidgets(
      "a second keystroke while the menu is open doesn't crash when the "
      "field's own onChanged rebuilds an ancestor on every change "
      '(regression: RolePlayFormScreen\'s name field does this to keep its '
      'identity preview live)',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: _AncestorRebuildHarness(),
          ),
        );
        await tester.tap(find.byType(TextField));
        await tester.pump();

        await _typeAndOpen(tester, '/');
        expect(
          tester
              .state<TokenInsertionMenuState>(find.byType(TokenInsertionMenu))
              .isMenuOpen,
          isTrue,
        );

        // The regression: previously, this second controller change — while
        // the menu was still open — rebuilt TokenInsertionMenu as part of
        // the ancestor's onChanged-triggered setState(), and
        // didUpdateWidget's synchronous _entry.markNeedsBuild() then threw
        // "setState() or markNeedsBuild() called during build" (the
        // OverlayEntry it targets sits outside the subtree currently being
        // built).
        await tester.enterText(find.byType(TextField), '/f');
        await tester.pump();
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(
          tester
              .state<TokenInsertionMenuState>(find.byType(TokenInsertionMenu))
              .isMenuOpen,
          isTrue,
        );
        expect(find.text('frekvens'), findsOneWidget);
      },
    );
  });
}
