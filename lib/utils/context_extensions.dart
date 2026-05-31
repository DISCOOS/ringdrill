import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';

extension RingdrillContextX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get texts => Theme.of(this).textTheme;
}
