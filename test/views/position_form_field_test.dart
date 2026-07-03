import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/position_form_field.dart';

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

      // Open the map picker.
      await tester.tap(find.byIcon(Icons.map));
      await tester.pumpAndSettle();
      expect(find.byType(FlutterMap), findsOneWidget);

      // Pan the map: map_picker_screen.dart tracks the fixed centre
      // crosshair's geographic point via mapEventStream, so dragging moves
      // the point that gets confirmed.
      await tester.drag(find.byType(FlutterMap), const Offset(-200, -150));
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
}
