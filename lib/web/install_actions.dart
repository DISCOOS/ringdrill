import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:ringdrill/web/web_env.dart';

/// Whether to offer an "install the app" entry. True on the web when the
/// app is not already running as an installed PWA.
bool get canShowInstallEntry => !WebEnv.isStandalone;

/// Opens the shareable install guide route.
void openInstallGuide(BuildContext context) => context.push('/install');
