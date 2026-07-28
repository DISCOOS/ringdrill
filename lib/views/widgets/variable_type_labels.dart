import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/utils/variable_values.dart';

/// Localized label, icon and per-type validation message for a
/// [VariableType] (DESIGN-008 follow-up 11). Depends on [AppLocalizations],
/// which is not Flutter-free — this lives under `lib/views/`, not
/// `lib/models/`, so `DrillVariable` itself stays reachable from
/// `bin/ringdrill.dart` (same split as `location_kind_labels.dart`).
extension VariableTypeX on VariableType {
  String label(AppLocalizations l) => switch (this) {
    VariableType.string => l.variableTypeLabelString,
    VariableType.number => l.variableTypeLabelNumber,
    VariableType.time => l.variableTypeLabelTime,
    VariableType.date => l.variableTypeLabelDate,
    VariableType.duration => l.variableTypeLabelDuration,
    VariableType.location => l.variableTypeLabelLocation,
  };

  IconData get icon => switch (this) {
    VariableType.string => Icons.abc,
    VariableType.number => Icons.numbers,
    VariableType.time => Icons.access_time,
    VariableType.date => Icons.calendar_today,
    VariableType.duration => Icons.hourglass_empty,
    VariableType.location => Icons.place_outlined,
  };

  /// The inline error shown when a value does not read as this type, or
  /// null for types every string satisfies. `location`'s composite input
  /// validates its coordinate field separately
  /// ([AppLocalizations.variableValueInvalidCoordinate]).
  String? invalidValueMessage(AppLocalizations l) => switch (this) {
    VariableType.string || VariableType.location => null,
    VariableType.number => l.variableValueInvalidNumber,
    VariableType.time => l.variableValueInvalidTime,
    VariableType.date => l.variableValueInvalidDate,
    VariableType.duration => l.variableValueInvalidDuration,
  };
}

/// The [VariableFormat] for [l] — the single place the view/brief layers
/// turn an `AppLocalizations` into the pure formatter's locale inputs.
VariableFormat variableFormatOf(AppLocalizations l) => VariableFormat(
  localeName: l.localeName,
  hourUnit: l.variableDurationHourUnit,
);
