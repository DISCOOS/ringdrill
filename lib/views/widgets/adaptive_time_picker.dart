import 'package:flutter/cupertino.dart'
    show CupertinoDatePicker, CupertinoDatePickerMode;
import 'package:flutter/material.dart';
import 'package:ringdrill/utils/context_extensions.dart';
import 'package:ringdrill/views/widgets/ringdrill_sheet.dart';

/// The app's time picker: a Material dialog, a Cupertino wheel on iOS, and **24-hour
/// on both** regardless of the device's 12-hour preference.
///
/// The canonical encoding is 24-hour HH:MM (DESIGN-008 follow-up 11) and every
/// surface renders it that way — `TimeOfDayX.formal()`, the round tables, the brief.
/// A picker offering "5 PM" beside a table reading `17:20` is how an exercise gets
/// planned twelve hours out, and in this domain 24-hour is operational rather than a
/// matter of taste.
///
/// Forcing it also removes a platform split that was invisible from the code. The
/// Material picker honours `MediaQuery.alwaysUse24HourFormat` on its own, so Android
/// already followed the device setting; `CupertinoDatePicker.use24hFormat` defaults to
/// **false**, so iOS showed AM/PM even with iOS's own 24-Hour Time switched on. The
/// same picker behaved two ways, and neither was this rule.
Future<TimeOfDay?> pickAdaptiveTime(
  BuildContext context, {
  required TimeOfDay initialTime,
}) {
  if (Theme.of(context).platform != TargetPlatform.iOS) {
    return showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
  }

  final initialDateTime = DateTime(
    0,
    1,
    1,
    initialTime.hour,
    initialTime.minute,
  );
  var selectedTime = initialTime;

  return showRingdrillActionSheet<TimeOfDay>(
    context: context,
    builder: (sheetContext) {
      final localizations = sheetContext.l10n;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: Text(localizations.cancel),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(selectedTime),
                  child: Text(localizations.done),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 216,
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.time,
              // Not the default. `use24hFormat` is false unless said, so this wheel
              // showed AM/PM on every iOS device, including ones set to 24-hour.
              use24hFormat: true,
              initialDateTime: initialDateTime,
              onDateTimeChanged: (value) {
                selectedTime = TimeOfDay.fromDateTime(value);
              },
            ),
          ),
        ],
      );
    },
  );
}
