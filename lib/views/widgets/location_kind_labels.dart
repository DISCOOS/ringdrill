import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/location.dart';

/// Localized `label`/`description` for a [LocationKind] (ADR-0047,
/// DESIGN-009). Depends on [AppLocalizations], which is not Flutter-free —
/// this lives under `lib/views/`, not `lib/models/`, so `Location` itself
/// stays reachable from `bin/ringdrill.dart`.
extension LocationKindX on LocationKind {
  String label(AppLocalizations l) => switch (this) {
    LocationKind.lkp => l.locationKindLkpLabel,
    LocationKind.ipp => l.locationKindIppLabel,
    LocationKind.pp => l.locationKindPpLabel,
    LocationKind.rendezvous => l.locationKindRendezvousLabel,
    LocationKind.commandPost => l.locationKindCommandPostLabel,
    LocationKind.home => l.locationKindHomeLabel,
    LocationKind.trackFound => l.locationKindTrackFoundLabel,
    LocationKind.dogInterest => l.locationKindDogInterestLabel,
    LocationKind.obstacle => l.locationKindObstacleLabel,
    LocationKind.notSearchable => l.locationKindNotSearchableLabel,
    LocationKind.phoneTrace => l.locationKindPhoneTraceLabel,
    LocationKind.observation => l.locationKindObservationLabel,
    LocationKind.vantagePoint => l.locationKindVantagePointLabel,
    LocationKind.containmentPost => l.locationKindContainmentPostLabel,
    LocationKind.personFound => l.locationKindPersonFoundLabel,
    LocationKind.other => l.locationKindOtherLabel,
  };

  String description(AppLocalizations l) => switch (this) {
    LocationKind.lkp => l.locationKindLkpDescription,
    LocationKind.ipp => l.locationKindIppDescription,
    LocationKind.pp => l.locationKindPpDescription,
    LocationKind.rendezvous => l.locationKindRendezvousDescription,
    LocationKind.commandPost => l.locationKindCommandPostDescription,
    LocationKind.home => l.locationKindHomeDescription,
    LocationKind.trackFound => l.locationKindTrackFoundDescription,
    LocationKind.dogInterest => l.locationKindDogInterestDescription,
    LocationKind.obstacle => l.locationKindObstacleDescription,
    LocationKind.notSearchable => l.locationKindNotSearchableDescription,
    LocationKind.phoneTrace => l.locationKindPhoneTraceDescription,
    LocationKind.observation => l.locationKindObservationDescription,
    LocationKind.vantagePoint => l.locationKindVantagePointDescription,
    LocationKind.containmentPost => l.locationKindContainmentPostDescription,
    LocationKind.personFound => l.locationKindPersonFoundDescription,
    LocationKind.other => l.locationKindOtherDescription,
  };
}
