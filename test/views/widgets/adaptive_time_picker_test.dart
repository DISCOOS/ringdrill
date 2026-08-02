import 'package:flutter/cupertino.dart' show CupertinoDatePicker;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/widgets/adaptive_time_picker.dart';

void main() {
  testWidgets('iOS platform uses a Cupertino time picker sheet', (
    tester,
  ) async {
    TimeOfDay? picked;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              picked = await pickAdaptiveTime(
                context,
                initialTime: const TimeOfDay(hour: 9, minute: 30),
              );
            },
            child: const Text('Pick'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Pick'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoDatePicker), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(picked, const TimeOfDay(hour: 9, minute: 30));
  });

  testWidgets('non-iOS platform uses the Material time picker dialog', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () {
              pickAdaptiveTime(
                context,
                initialTime: const TimeOfDay(hour: 9, minute: 30),
              );
            },
            child: const Text('Pick'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Pick'));
    await tester.pumpAndSettle();

    expect(find.byType(TimePickerDialog), findsOneWidget);
    expect(find.byType(CupertinoDatePicker), findsNothing);
  });

  // The canonical encoding is 24-hour HH:MM (DESIGN-008 follow-up 11) and every other
  // surface renders it that way, so the picker must not offer AM/PM beside a table
  // reading 17:20. Both platforms are asserted because they had *different* bugs: the
  // Material picker silently followed the device's 12-hour preference, and the
  // Cupertino wheel ignored the device entirely — `use24hFormat` defaults to false, so
  // iOS showed AM/PM even with iOS's own 24-Hour Time turned on.
  group('always 24-hour, whatever the device prefers', () {
    Widget app(TargetPlatform platform) => MaterialApp(
      theme: ThemeData(platform: platform),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => pickAdaptiveTime(
            context,
            initialTime: const TimeOfDay(hour: 17, minute: 20),
          ),
          child: const Text('Pick'),
        ),
      ),
    );

    testWidgets('iOS: the wheel is told to use 24-hour', (tester) async {
      await tester.pumpWidget(app(TargetPlatform.iOS));
      await tester.tap(find.text('Pick'));
      await tester.pumpAndSettle();

      final picker = tester.widget<CupertinoDatePicker>(
        find.byType(CupertinoDatePicker),
      );
      expect(picker.use24hFormat, isTrue);
      // And the wheel shows it: no meridiem column to pick from.
      expect(find.text('AM'), findsNothing);
      expect(find.text('PM'), findsNothing);
    });

    testWidgets('Android: the dialog is handed a 24-hour MediaQuery', (
      tester,
    ) async {
      await tester.pumpWidget(app(TargetPlatform.android));
      await tester.tap(find.text('Pick'));
      await tester.pumpAndSettle();

      final media = MediaQuery.of(
        tester.element(find.byType(TimePickerDialog)),
      );
      expect(media.alwaysUse24HourFormat, isTrue);
      // The dialog drops its AM/PM toggle when the format is 24-hour.
      expect(find.text('AM'), findsNothing);
      expect(find.text('PM'), findsNothing);
    });
  });
}
