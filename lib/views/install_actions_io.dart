import 'package:flutter/widgets.dart';

/// Native stub: there is no PWA install concept off the web, so never offer
/// the install entry and make the opener a no-op.
bool get canShowInstallEntry => false;

void openInstallGuide(BuildContext context) {}
