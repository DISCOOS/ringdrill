void listenForPwaUpdates({
  required void Function(void Function() reloadNow, bool canAutoApply)
  onUpdateReady,
}) async {
  // No-op on non-web platforms.
}

Future<void> forcePwaUpdate() async {
  // No-op on non-web platforms. Native apps update via the store / Shorebird.
}

void reloadCurrentPage() {
  // No-op on non-web platforms. The boot-failure screen never reaches the
  // reload button there because the same code paths would crash the
  // process at a layer lower than the web splash issue this exists for.
}

Future<void> clearWebStorageAndReload() async {
  // No-op on non-web platforms.
}
