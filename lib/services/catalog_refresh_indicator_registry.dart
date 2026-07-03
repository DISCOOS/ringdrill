import 'package:flutter/material.dart';

/// Lets the currently visible tab's drag-to-update-from-catalog
/// [RefreshIndicator] be triggered programmatically from elsewhere in the
/// app — specifically the drawer's "Oppdater fra katalog" entry — so both
/// entry points show the exact same pull-to-refresh animation instead of
/// the drawer action popping up a separate progress indicator.
///
/// `MainScreen` registers one provider function in `initState` that
/// resolves, at call time, to whichever of its tabs' `RefreshIndicator` keys
/// is current — so nothing needs to be re-registered when the user switches
/// tabs.
class CatalogRefreshIndicatorRegistry {
  CatalogRefreshIndicatorRegistry._internal();

  static final CatalogRefreshIndicatorRegistry _instance =
      CatalogRefreshIndicatorRegistry._internal();

  factory CatalogRefreshIndicatorRegistry() => _instance;

  GlobalKey<RefreshIndicatorState>? Function()? _provider;

  void registerProvider(GlobalKey<RefreshIndicatorState>? Function() provider) {
    _provider = provider;
  }

  /// No-ops unless [provider] is the currently registered one — guards
  /// against a stale unregister call (e.g. from a disposed widget) clearing
  /// a different, still-live registration.
  void unregisterProvider(
    GlobalKey<RefreshIndicatorState>? Function() provider,
  ) {
    if (_provider == provider) _provider = null;
  }

  /// Triggers the currently active tab's [RefreshIndicator], running its
  /// `onRefresh` through the normal pull-to-refresh animation, and returns
  /// once it settles. Returns false without doing anything when there is no
  /// registered provider, the current tab has no indicator (e.g. it isn't a
  /// catalog-sourced plan), or its widget isn't mounted — callers should
  /// fall back to running the refresh without a visible indicator in that
  /// case.
  Future<bool> trigger() async {
    final state = _provider?.call()?.currentState;
    if (state == null) return false;
    await state.show();
    return true;
  }
}
