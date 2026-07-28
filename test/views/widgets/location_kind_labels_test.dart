import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations_en.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/views/widgets/location_kind_labels.dart';

/// DESIGN-009 prompt 3 — `LocationKindX` resolves every [LocationKind]
/// value to its own ARB entry (ADR-0047), not just a subset.
void main() {
  final l = AppLocalizationsEn();

  test('label returns the localized string for each value', () {
    expect(LocationKind.lkp.label(l), l.locationKindLkpLabel);
    expect(LocationKind.ipp.label(l), l.locationKindIppLabel);
    expect(LocationKind.pp.label(l), l.locationKindPpLabel);
    expect(LocationKind.rendezvous.label(l), l.locationKindRendezvousLabel);
    expect(LocationKind.commandPost.label(l), l.locationKindCommandPostLabel);
    expect(LocationKind.home.label(l), l.locationKindHomeLabel);
    expect(LocationKind.trackFound.label(l), l.locationKindTrackFoundLabel);
    expect(LocationKind.dogInterest.label(l), l.locationKindDogInterestLabel);
    expect(LocationKind.obstacle.label(l), l.locationKindObstacleLabel);
    expect(
      LocationKind.notSearchable.label(l),
      l.locationKindNotSearchableLabel,
    );
    expect(LocationKind.phoneTrace.label(l), l.locationKindPhoneTraceLabel);
    expect(LocationKind.observation.label(l), l.locationKindObservationLabel);
    expect(LocationKind.vantagePoint.label(l), l.locationKindVantagePointLabel);
    expect(
      LocationKind.containmentPost.label(l),
      l.locationKindContainmentPostLabel,
    );
    expect(LocationKind.personFound.label(l), l.locationKindPersonFoundLabel);
    expect(LocationKind.other.label(l), l.locationKindOtherLabel);
  });

  test('description returns the localized string for each value', () {
    expect(LocationKind.lkp.description(l), l.locationKindLkpDescription);
    expect(LocationKind.ipp.description(l), l.locationKindIppDescription);
    expect(LocationKind.pp.description(l), l.locationKindPpDescription);
    expect(
      LocationKind.rendezvous.description(l),
      l.locationKindRendezvousDescription,
    );
    expect(
      LocationKind.commandPost.description(l),
      l.locationKindCommandPostDescription,
    );
    expect(LocationKind.home.description(l), l.locationKindHomeDescription);
    expect(
      LocationKind.trackFound.description(l),
      l.locationKindTrackFoundDescription,
    );
    expect(
      LocationKind.dogInterest.description(l),
      l.locationKindDogInterestDescription,
    );
    expect(
      LocationKind.obstacle.description(l),
      l.locationKindObstacleDescription,
    );
    expect(
      LocationKind.notSearchable.description(l),
      l.locationKindNotSearchableDescription,
    );
    expect(
      LocationKind.phoneTrace.description(l),
      l.locationKindPhoneTraceDescription,
    );
    expect(
      LocationKind.observation.description(l),
      l.locationKindObservationDescription,
    );
    expect(
      LocationKind.vantagePoint.description(l),
      l.locationKindVantagePointDescription,
    );
    expect(
      LocationKind.containmentPost.description(l),
      l.locationKindContainmentPostDescription,
    );
    expect(
      LocationKind.personFound.description(l),
      l.locationKindPersonFoundDescription,
    );
    expect(LocationKind.other.description(l), l.locationKindOtherDescription);
  });
}
