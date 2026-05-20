import 'package:flutter/foundation.dart';

/// Possible states of the online catalog service.
enum CatalogServiceState { unknown, checking, online, unavailable, corsBlocked }

/// Immutable snapshot of catalog availability.
@immutable
class CatalogStatus {
  const CatalogStatus({required this.state, this.tooltip});

  final CatalogServiceState state;

  /// Optional tooltip with technical details (e.g. raw error message).
  final String? tooltip;

  static const CatalogStatus unknown = CatalogStatus(
    state: CatalogServiceState.unknown,
  );

  CatalogStatus copyWith({CatalogServiceState? state, String? tooltip}) {
    return CatalogStatus(
      state: state ?? this.state,
      tooltip: tooltip ?? this.tooltip,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CatalogStatus &&
          runtimeType == other.runtimeType &&
          state == other.state &&
          tooltip == other.tooltip;

  @override
  int get hashCode => Object.hash(state, tooltip);
}

/// Singleton holder for the most recently observed catalog service status.
///
/// Updated by code that talks to the catalog (typically [library_view]) and
/// observed by widgets that want to surface the status globally (typically
/// the AppBar plan badge). No background polling — this just remembers the
/// most recent outcome.
class CatalogStatusService {
  CatalogStatusService._internal();

  static final CatalogStatusService _instance =
      CatalogStatusService._internal();

  factory CatalogStatusService() => _instance;

  final ValueNotifier<CatalogStatus> _status = ValueNotifier<CatalogStatus>(
    CatalogStatus.unknown,
  );

  /// Listenable that rebuilds widgets when the catalog status changes.
  ValueListenable<CatalogStatus> get listenable => _status;

  CatalogStatus get value => _status.value;

  void setStatus(CatalogServiceState state, {String? tooltip}) {
    final next = CatalogStatus(state: state, tooltip: tooltip);
    if (_status.value != next) {
      _status.value = next;
    }
  }
}
