void listenForPwaUpdates({
  required void Function(void Function() reloadNow) onUpdateReady,
}) async {
  // No-op on non-web platforms.
}

Future<void> forcePwaUpdate() async {
  // No-op on non-web platforms. Native apps update via the store / Shorebird.
}
