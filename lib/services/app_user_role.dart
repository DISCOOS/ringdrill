import 'package:ringdrill/services/brief/brief_audience.dart';

/// The role the person holding *this* device has in the exercise.
///
/// This is a local, device-level preference — distinct from:
/// - [BriefAudience]: which document view a reader gets (export/print axis).
/// - The Roster/Bemanning staffing of *other* people (DESIGN-006).
/// - The ADR-0019 session role (coordinator / observer / roleplayer).
///
/// Participants do not use the app, so only two staff roles are offered.
/// The stored role drives [BriefAudience] as the default brief view: an
/// Øvelsesleder sees full director content (including actor PII), a
/// Veileder sees instructor content (PII hidden). See DESIGN-006 step 4.
enum AppUserRole {
  /// Øvelsesleder — full brief including actor PII.
  director,

  /// Veileder — brief without actor PII.
  instructor;

  /// Maps to the corresponding [BriefAudience] for the brief renderer.
  BriefAudience get briefAudience => switch (this) {
    AppUserRole.director => BriefAudience.director,
    AppUserRole.instructor => BriefAudience.instructor,
  };
}
