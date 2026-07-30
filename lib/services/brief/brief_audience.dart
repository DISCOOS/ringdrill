/// Audience filter for brief rendering. Drives which fields the renderer puts
/// in the mustache context, and which sections the template can therefore
/// expand. See DESIGN-004 and ADR-0063.
///
/// One value per [StaffRole] — `StaffRole.briefAudience` is the identity — plus
/// [participant], the one audience with no role, because a participant is not
/// staff. That is exactly why they are the audience that gets least.
///
/// The values are deliberately **not** an ordered chain. An actor needs their
/// own role-play script and none of the withheld answers; an instructor needs
/// the answers and the evaluation rubric. Neither contains the other, so
/// visibility is a declared set per field (`SourceField.audiences`) rather than
/// a minimum level.
enum BriefAudience {
  /// The printed handout. Participants do not use the app, so this audience is
  /// absent from the in-app selector and reachable through `render` — which
  /// makes it the render with the widest and least controlled distribution.
  participant,

  /// Markør. Their own scenario: the role-play fields and the cast's contact
  /// details, so co-located markers can find each other, but none of the
  /// instructor-facing material they would be holding next to a participant.
  actor,

  /// Veileder.
  instructor,

  /// Øvelsesleder.
  director,

  /// A staffing role the enum does not name. Gets the participant field set, on
  /// the same default-deny logic ADR-0057 applies to edit rights: a role whose
  /// duties are undefined by construction is granted nothing in particular.
  other;

  /// Instructor-facing station notes (ADR-0063). Not an actor: what a marker
  /// needs to do is their role play, not the control notes.
  bool get includesDirectorNotes =>
      this == BriefAudience.instructor || this == BriefAudience.director;

  /// The real person cast as a marker — name and phone.
  ///
  /// Every staff role that has to coordinate with a marker on the ground:
  /// markörer need each other (a station can post two), and a veileder is
  /// responsible for the markör at the station they supervise. Not `other`,
  /// which gets the participant set.
  bool get includesActorPii =>
      this == BriefAudience.actor ||
      this == BriefAudience.instructor ||
      this == BriefAudience.director;
}
