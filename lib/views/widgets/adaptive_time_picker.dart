import 'package:flutter/cupertino.dart'
    show CupertinoDatePicker, CupertinoDatePickerMode;
import 'package:flutter/material.dart';
import 'package:ringdrill/utils/context_extensions.dart';
import 'package:ringdrill/views/widgets/ringdrill_sheet.dart';

Future<TimeOfDay?> pickAdaptiveTime(
  BuildContext context, {
  required TimeOfDay initialTime,
}) {
  if (Theme.of(context).platform != TargetPlatform.iOS) {
    return showTimePicker(context: context, initialTime: initialTime);
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
