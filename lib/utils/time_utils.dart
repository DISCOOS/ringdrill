import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';

extension DateTimeX on DateTime {
  static DateTime fromMinutes(int minutes) {
    final now = DateTime.now();
    final hours = minutes ~/ 60;
    return DateTime(
      now.year,
      now.month,
      now.day,
      hours == 0 ? now.hour : hours,
      hours == 0 ? now.minute : minutes - hours * 60,
      now.second,
    );
  }

  String formal(
    AppLocalizations localizations, [
    DateTime? reference,
    bool abs = true,
  ]) {
    final now = reference ?? DateTime.now();
    final diff = abs ? now.difference(this).abs() : now.difference(this);
    final absDiff = diff.abs();

    if (absDiff.inSeconds < 60) {
      return localizations.second(diff.inSeconds);
    }
    if (absDiff.inMinutes < 60) {
      return localizations.minute(absDiff.inMinutes);
    }
    if (absDiff.inHours < 24) {
      return localizations.hour(diff.inHours);
    }
    if (absDiff.inDays < 7) {
      return localizations.day(diff.inDays);
    }
    if (absDiff.inDays < 30) {
      return localizations.week(diff.inDays ~/ 7);
    }
    if (absDiff.inDays < 365) {
      return localizations.month(diff.inDays ~/ 30);
    }
    return localizations.year(diff.inDays ~/ 365);
  }
}

extension TimeOfDayX on TimeOfDay {
  static TimeOfDay fromMinutes(int minutes) {
    return TimeOfDay.fromDateTime(
      DateTime.now().add(Duration(minutes: minutes)),
    );
  }

  /// Format without any context
  String formal() {
    String addLeadingZeroIfNeeded(int value) {
      if (value < 10) {
        return '0$value';
      }
      return value.toString();
    }

    final String hourLabel = addLeadingZeroIfNeeded(hour);
    final String minuteLabel = addLeadingZeroIfNeeded(minute);

    return '$hourLabel:$minuteLabel';
  }

  DateTime toDateTime([DateTime? when]) {
    DateTime now = when ?? DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute, now.second);
  }
}
