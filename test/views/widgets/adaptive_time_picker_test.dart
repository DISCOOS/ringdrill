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
}
