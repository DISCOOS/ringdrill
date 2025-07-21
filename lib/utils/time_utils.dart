import 'package:flutter/material.dart';

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

  String formal([DateTime? reference, bool abs = true]) {
    String plural(int value, String single, String plural) {
      return value < 2 ? '$value $single' : '$value $plural';
    }

    final now = reference ?? DateTime.now();
    final diff = abs ? now.difference(this).abs() : now.difference(this);
    final absDiff = diff.abs();

    if (absDiff.inSeconds < 60) {
      return plural(diff.inSeconds, 'second', 'seconds');
    }
    if (absDiff.inMinutes < 60) {
      return plural(diff.inMinutes, 'minute', 'minutes');
    }
    if (absDiff.inHours < 24) {
      return plural(diff.inHours, 'hour', 'hours');
    }
    if (absDiff.inDays < 7) {
      return plural(diff.inDays, 'day', 'days');
    }
    if (absDiff.inDays < 30) {
      return plural(diff.inDays ~/ 7, 'week', 'weeks');
    }
    if (absDiff.inDays < 365) {
      return plural(diff.inDays ~/ 30, 'month', 'months');
    }
    return plural(diff.inDays ~/ 365, 'year', 'years');
  }

  String pretty([DateTime? reference]) {
    final now = reference ?? DateTime.now();
    final diff = now.difference(this);
    final isFuture = diff.isNegative;
    final absDiff = diff.abs();

    if (absDiff.inSeconds < 60) {
      return isFuture ? "in a few seconds" : "Just now";
    }
    if (absDiff.inMinutes < 60) {
      return isFuture
          ? "in ${absDiff.inMinutes} minutes"
          : "${absDiff.inMinutes} minutes ago";
    }
    if (absDiff.inHours < 24) {
      return isFuture
          ? "in ${absDiff.inHours} hours"
          : "${absDiff.inHours} hours ago";
    }
    if (absDiff.inDays == 1) return isFuture ? "Tomorrow" : "Yesterday";
    if (absDiff.inDays < 7) {
      return isFuture
          ? "in ${absDiff.inDays} days"
          : "${absDiff.inDays} days ago";
    }
    if (absDiff.inDays < 30) {
      return isFuture
          ? "in ${absDiff.inDays ~/ 7} weeks"
          : "${absDiff.inDays ~/ 7} weeks ago";
    }

    return toLocal().toString().split(' ').first;
  }
}

extension TimeOfDayX on TimeOfDay {
  static TimeOfDay fromMinutes(int minutes) {
    final now = DateTime.now();
    final hours = minutes ~/ 60;

    return TimeOfDay(
      hour: hours == 0 ? now.hour : hours,
      minute: now.minute + minutes - hours * 60,
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
    final now = when ?? DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute, now.second);
  }

  Duration difference(TimeOfDay other) {
    final now = DateTime.now();
    return DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      minute,
      now.second,
    ).difference(
      DateTime(
        now.year,
        now.month,
        now.day,
        other.hour,
        other.minute,
        now.second,
      ),
    );
  }
}
