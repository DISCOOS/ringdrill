import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/map_picker_screen.dart';
import 'package:ringdrill/views/position_form_field.dart';

/// Finds the picker's own [FlutterMap] — the field's thumbnail renders one
/// too, so a bare `find.byType(FlutterMap)` matches both once the picker
/// is open. `byWidgetPredicate` (not `find.byType`) because
/// `MapPickerScreen<K>`'s `runtimeType` is never `==` to the bare
/// `MapPickerScreen` type token for a non-dynamic `K`.
Finder _pickerMap() => find.descendant(
  of: find.byWidgetPredicate((widget) => widget is MapPickerScreen),
  matching: find.byType(FlutterMap),
);

/// End-to-end coverage for the exact bug fixed in station_form_screen.dart,
/// team_form_screen.dart and (already correct) roleplay_form_screen.dart:
/// PositionFormField.onChanged must fire — with the *newly picked* value —
/// as soon as the map picker is confirmed, not only once the surrounding
/// Form is saved. Drives the real MapPickerScreen (real FlutterMap, real
/// pan gesture, real "confirm" tap) rather than constructing a LatLng by
/// hand, so a regression in the picker's own pop-with-value plumbing would
/// also be caught here.
///
/// Hosted directly (no surrounding side panel) since this test is about
/// onChanged wiring, not layout.
void main() {
  testWidgets(
    'picking a new position fires onChanged before the form is saved',
    (tester) async {
      LatLng? initialValue = LatLng(59.0, 10.0);
      LatLng? changed;
      LatLng? saved;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Form(
              child: PositionFormField(
                initialValue: initialValue,
                onChanged: (v) => changed = v,
                onSaved: (v) => saved = v,
              ),
            ),
          ),
        ),
      );

      // Open the map picker by tapping the surface (there is no separate
      // map icon button; the whole card opens the picker).
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();
      expect(_pickerMap(), findsOneWidget);

      // Pan the map: map_picker_screen.dart tracks the fixed centre
      // crosshair's geographic point via mapEventStream, so dragging moves
      // the point that gets confirmed.
      await tester.drag(_pickerMap(), const Offset(-200, -150));
      await tester.pump(const Duration(milliseconds: 300));

      // Confirm the pick and return to the form.
      await tester.tap(find.byIcon(Icons.check));
      await tester.pumpAndSettle();

      // onChanged must have fired already — before Save — with a position
      // different from the original. This is the exact behaviour that was
      // missing: onChanged was never wired up in station/team_form_screen,
      // so the caller's own state (and anything derived from it, like a
      // marker filter or the map picker's recentring on reopen) stayed
      // frozen at the old value until save.
      expect(changed, isNotNull);
      expect(changed, isNot(initialValue));

      // Saving the Form must hand back that same picked value, not the
      // stale initialValue.
      Form.of(tester.element(find.byType(PositionFormField))).save();
      expect(saved, changed);
    },
  );

  testWidgets(
    'card variant renders overlayActions over the thumbnail and tapping '
    'the surface still opens the picker',
    (tester) async {
      var actionTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Form(
              child: PositionFormField(
                initialValue: LatLng(59.0, 10.0),
                variant: PositionFieldVariant.card,
                overlayActions: [
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => actionTapped = true,
                  ),
                ],
                onSaved: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.refresh), findsOneWidget);
      await tester.tap(find.byIcon(Icons.refresh));
      expect(actionTapped, isTrue);

      // Tapping elsewhere on the card still opens the picker.
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();
      expect(_pickerMap(), findsOneWidget);
    },
  );
}
