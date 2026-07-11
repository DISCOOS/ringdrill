import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';

extension SimpleTimeOfDayX on SimpleTimeOfDay {
  TimeOfDay toMaterial() => TimeOfDay(hour: hour, minute: minute);
}

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

extension ExercisePhaseTimeX on Exercise {
  /// End time of the phase at [roundIndex]/[phaseIndex] as a wall-clock
  /// value. For execution and evaluation this is the start of the next
  /// phase in the same round. For rotation (the last phase of a round)
  /// this is the start of the next round's execution phase, or
  /// [Exercise.endTime] if [roundIndex] is already the last round.
  /// Shared by every running-state status card (DESIGN-010 follow-up:
  /// player-status-card) so the "ferdig HH:MM" reading is computed the
  /// same way on every surface.
  SimpleTimeOfDay? phaseEndTime(int roundIndex, int phaseIndex) {
    if (roundIndex < 0 || roundIndex >= schedule.length) return null;
    if (phaseIndex < 0 || phaseIndex > 2) return null;
    if (phaseIndex < 2) return schedule[roundIndex][phaseIndex + 1];
    if (roundIndex + 1 < schedule.length) return schedule[roundIndex + 1][0];
    return endTime;
  }
}

extension TimeOfDayX on TimeOfDay {
  SimpleTimeOfDay toSimple() => SimpleTimeOfDay(hour: hour, minute: minute);

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
