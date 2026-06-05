import 'package:flutter/foundation.dart';

/// True on the touch-first platforms (iOS and Android), where a precise
/// pointer cannot be assumed. Web is treated as a pointer platform because we
/// cannot reliably tell a touchscreen laptop from a desktop, and the safe
/// default there is to keep pointer affordances available.
///
/// Shared by [MapView] (to drop pinch-redundant zoom buttons) and the
/// settings page (to only offer the zoom-button toggle where it has effect).
bool get isTouchPlatform =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android);
