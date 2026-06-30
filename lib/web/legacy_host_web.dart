import 'package:ringdrill/utils/app_flags.dart';
import 'package:web/web.dart' as web;

bool isLegacyHost() {
  if (AppFlags.migrationDisabled) return false;
  if (AppFlags.forceLegacyHost) return true;
  return checkIsLegacyHostName(web.window.location.hostname);
}

bool checkIsLegacyHostName(String hostname) => hostname == 'ringdrill.app';
