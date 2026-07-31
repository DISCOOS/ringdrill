import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/utils/station_scenario_tokens.dart';
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

/// Opens the menu with the caret placed *inside* existing text rather than at its
/// end, which is what `enterText` can express. Sets the value in one go so the
/// controller notifies exactly once, the way a real caret move does.
Future<void> _openAt(
  WidgetTester tester,
  TextEditingController controller,
  String text,
  int caret,
) async {
  controller.value = TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: caret),
  );
  await tester.pump();
  await tester.pump();
}

/// Mirrors `token_insertion_menu.dart`'s private `_locationFacetLabel`, so
/// the discovery test can assert every entry in the public
/// [locationFacetNames] renders its expected tile without duplicating the
/// widget's own switch inline at each call site.
String _locationFacetLabelFor(AppLocalizations l10n, String facet) =>
    switch (facet) {
      'place' => l10n.locationsSectionPlaceLabel,
      'label' => l10n.locationsSectionLabelLabel,
      'position' => l10n.positionUtm,
      _ => facet,
    };

/// The [personFacetNames] counterpart of [_locationFacetLabelFor].
String _personFacetLabelFor(AppLocalizations l10n, String facet) =>
    switch (facet) {
      'name' => l10n.roleName,
      'age' => l10n.roleAge,
      'gender' => l10n.roleGender,
      'description' => l10n.roleDescription,
      'loc' => l10n.personsSectionLocationLabel,
      _ => facet,
    };

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
            // A real one from the LSOR plan: long enough that ListTile used to
            // hand the whole row to the value.
            VariableToken(
              name: 'talegruppe_ovelse',
              effectiveValue: 'RK-VFOLD-ØV4 / DMO-ANDRE-1',
            ),
          ],
          planFields: const [
            PlanFieldToken(
              name: 'exercise.name',
              label: 'Øvelsesnavn',
              hint: 'øvelse',
            ),
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

    group('the caret inside an existing token', () {
      // The menu opens when the caret sits inside a token, which is right — the
      // author is editing that token. But the insertion replaced only up to the
      // caret, so the rest of the token stayed behind: picking an entry with the
      // caret just after the braces of `{{var.year}}` produced
      // `{{var.frekvens}}var.year}}`.
      testWidgets('replaces the whole token, not just up to the caret', (
        tester,
      ) async {
        final controller = await _pump(tester);

        // `{{|var.year}}` — caret between the braces and the name.
        await _openAt(tester, controller, '{{var.year}}', 2);
        await tester.tap(find.text('frekvens'));
        await tester.pump();

        expect(controller.text, '{{var.frekvens}}');
      });

      testWidgets('replaces from mid-name too, keeping surrounding prose', (
        tester,
      ) async {
        final controller = await _pump(tester);

        // `Kanal {{var.frek|}} i dag` — caret inside the name.
        await _openAt(tester, controller, 'Kanal {{var.frek}} i dag', 16);
        await tester.tap(find.text('frekvens'));
        await tester.pump();

        expect(controller.text, 'Kanal {{var.frekvens}} i dag');
      });

      testWidgets('takes nothing when what follows is prose, not a token tail', (
        tester,
      ) async {
        final controller = await _pump(tester);

        // `{{| min.` — an unclosed trigger with ordinary text after it. There is
        // no token ahead to replace, and prose after the caret is not ours to eat.
        await _openAt(tester, controller, '{{ min.', 2);
        await tester.tap(find.text('frekvens'));
        await tester.pump();

        expect(controller.text, '{{var.frekvens}} min.');
      });

      testWidgets('a "/" trigger never consumes a later "}}"', (tester) async {
        final controller = await _pump(tester);

        // After a `/` the braces ahead belong to whatever the author already
        // wrote, so only a `{{` trigger may reach past the caret.
        await _openAt(tester, controller, 'se /frek}} her', 8);
        await tester.tap(find.text('frekvens'));
        await tester.pump();

        expect(controller.text, 'se {{var.frekvens}}}} her');
      });

      testWidgets('stops at the first "}}", leaving a later token alone', (
        tester,
      ) async {
        final controller = await _pump(tester);

        await _openAt(
          tester,
          controller,
          '{{var.frek}} og {{var.talegruppe_ovelse}}',
          10,
        );
        await tester.tap(find.text('frekvens'));
        await tester.pump();

        expect(
          controller.text,
          '{{var.frekvens}} og {{var.talegruppe_ovelse}}',
        );
      });
    });

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

    group('facet completion (DESIGN-009 follow-up 4d)', () {
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
        'discovery: an exact location slug shows the bare entry plus its '
        'facets, unfiltered',
        (tester) async {
          await _pump(tester, stationLocations: const [location]);

          await _typeAndOpen(tester, '{{station.loc.lkp');

          expect(find.text('Siste kjente posisjon'), findsOneWidget);
          final l10n = await AppLocalizations.delegate.load(const Locale('en'));
          for (final facet in locationFacetNames) {
            expect(
              find.text(_locationFacetLabelFor(l10n, facet)),
              findsOneWidget,
              reason: 'missing facet tile for $facet',
            );
          }
        },
      );

      testWidgets(
        'discovery: an exact person slug shows the bare entry plus its '
        'facets, unfiltered',
        (tester) async {
          await _pump(tester, stationPersons: const [person]);

          await _typeAndOpen(tester, '{{station.person.anne');

          expect(find.text('Anne Glemsk'), findsOneWidget);
          final l10n = await AppLocalizations.delegate.load(const Locale('en'));
          // The bare entry plus all 5 person facets don't all fit within
          // the menu's fixed max height at once (a real author scrolls the
          // same way); scroll each one into view before asserting it.
          for (final facet in personFacetNames) {
            final label = _personFacetLabelFor(l10n, facet);
            await tester.scrollUntilVisible(
              find.text(label),
              50,
              scrollable: find.descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              ),
            );
            expect(
              find.text(label),
              findsOneWidget,
              reason: 'missing facet tile for $facet',
            );
          }
        },
      );

      testWidgets(
        'completion: "station.person.anne.desc" narrows to description and '
        'inserts the full dotted token',
        (tester) async {
          final controller = await _pump(
            tester,
            stationPersons: const [person],
          );

          await _typeAndOpen(tester, '{{station.person.anne.desc');

          final l10n = await AppLocalizations.delegate.load(const Locale('en'));
          expect(find.text(l10n.roleDescription), findsOneWidget);
          expect(find.text(l10n.roleAge), findsNothing);
          expect(find.text('Anne Glemsk'), findsNothing);

          await tester.tap(find.text(l10n.roleDescription));
          await tester.pump();

          expect(controller.text, '{{station.person.anne.description}}');
        },
      );

      testWidgets(
        'completion: "station.loc.lkp.pos" narrows to position and inserts '
        'the full dotted token',
        (tester) async {
          final controller = await _pump(
            tester,
            stationLocations: const [location],
          );

          await _typeAndOpen(tester, '{{station.loc.lkp.pos');

          final l10n = await AppLocalizations.delegate.load(const Locale('en'));
          expect(find.text(l10n.positionUtm), findsOneWidget);
          expect(find.text(l10n.locationsSectionPlaceLabel), findsNothing);
          expect(find.text('Siste kjente posisjon'), findsNothing);

          await tester.tap(find.text(l10n.positionUtm));
          await tester.pump();

          expect(controller.text, '{{station.loc.lkp.position}}');
        },
      );

      testWidgets(
        'loc chaining: "station.person.anne.loc.pos" offers the location '
        'position facet and inserts {{station.person.anne.loc.position}}',
        (tester) async {
          final controller = await _pump(
            tester,
            stationPersons: const [person],
          );

          await _typeAndOpen(tester, '{{station.person.anne.loc.pos');

          final l10n = await AppLocalizations.delegate.load(const Locale('en'));
          expect(find.text(l10n.positionUtm), findsOneWidget);
          expect(find.text(l10n.roleAge), findsNothing);

          await tester.tap(find.text(l10n.positionUtm));
          await tester.pump();

          expect(controller.text, '{{station.person.anne.loc.position}}');
        },
      );

      testWidgets(
        'fallthrough: an unknown slug offers "Create …", not facets',
        (tester) async {
          await _pump(
            tester,
            stationPersons: const [person],
            onCreatePerson: (label) => 'slug',
          );

          await _typeAndOpen(tester, '{{station.person.ukjent');

          final l10n = await AppLocalizations.delegate.load(const Locale('en'));
          expect(
            find.text(l10n.tokenMenuCreatePerson('ukjent')),
            findsOneWidget,
          );
          expect(find.text(l10n.roleAge), findsNothing);
          expect(find.text(l10n.roleDescription), findsNothing);
        },
      );
    });

    testWidgets('a long value lays out instead of consuming the whole tile', (
      tester,
    ) async {
      // The bug this guards is not cosmetic. The card is 360 wide and `ListTile`
      // lays its trailing out at whatever width the text wants, giving the title
      // the remainder — so a value like "RK-VFOLD-ØV4 / DMO-ANDRE-1" (a real
      // talegruppe from the LSOR plan) took the entire tile and `ListTile`
      // asserted "Trailing widget consumes the entire tile width", leaving the
      // tile with no size at all: `RenderBox was not laid out ... hasSize`.
      //
      // In a release build there is no assert to catch it. The tile is left
      // needing layout every frame, its title paints as nothing, and the menu's
      // full-screen `Positioned.fill` barrier goes on swallowing every tap — the
      // reported symptom being "no menu appears and then the whole app stops
      // responding to clicks". It surfaced on web and not on iOS/Android because
      // whether the value crosses the tile width depends on how wide the string
      // measures in that renderer's font, not on any web-specific code path.
      await _pump(tester);
      await _typeAndOpen(tester, '/');

      expect(
        tester.takeException(),
        isNull,
        reason: 'the row must lay out; an exception here is the livelock',
      );

      final name = find.text('talegruppe_ovelse');
      final value = find.text('RK-VFOLD-ØV4 / DMO-ANDRE-1');
      expect(name, findsOneWidget);
      expect(value, findsOneWidget);

      final nameWidth = tester.getSize(name).width;
      expect(
        nameWidth,
        greaterThan(60),
        reason:
            'the name is what the author is scanning for, so it keeps the '
            'larger share rather than ellipsising to nothing',
      );
      expect(
        tester.getSize(value).width,
        lessThanOrEqualTo(360 * 0.42),
        reason: 'the value is the capped side',
      );
    });

    testWidgets('a plan-field entry names the scope it reads from', (
      tester,
    ) async {
      // Every entry used to show the same "planfelt" hint, whatever scope it
      // came from, so an {{exercise.*}} token claimed to be a plan field.
      await _pump(tester);
      await _typeAndOpen(tester, '/');

      expect(find.text('Øvelsesnavn'), findsOneWidget);
      expect(find.text('øvelse'), findsOneWidget);
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
