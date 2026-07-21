import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

Future<bool> launchExternalApp(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    if (kDebugMode) {
      debugPrint('[chip] launch skipped — unparseable URL "$url"');
    }
    return false;
  }
  final can = await canLaunchUrl(uri);
  if (kDebugMode) {
    // `canLaunchUrl` is false on the iOS simulator for `tel:` (no Phone app),
    // so a phone chip is a silent no-op there — expected; it works on a
    // device. This log tells that case apart from a genuine launch failure.
    debugPrint('[chip] $uri — canLaunchUrl=$can');
  }
  if (!can) return false;
  try {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (kDebugMode) debugPrint('[chip] launchUrl($uri) → $launched');
    return launched;
  } catch (error, stackTrace) {
    if (kDebugMode) {
      debugPrint('[chip] launchUrl($uri) threw: $error\n$stackTrace');
    }
  }
  return false;
}
