/// Audience filter for brief rendering. Drives which mustache sections are
/// active when the template is expanded. See DESIGN-004.
enum BriefAudience {
  participant,
  instructor,
  director;

  bool get includesDirectorNotes => this != BriefAudience.participant;
  bool get includesActorPii => this == BriefAudience.director;
}
