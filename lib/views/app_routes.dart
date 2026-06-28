// Centralised route path constants for the GoRouter setup in
// [main_screen.dart]. Kept in a tiny standalone file so that views can
// reference these constants without importing main_screen.dart (which
// would create cyclic imports back into the router setup).

const String routeProgram = '/program';

String programPath(String programUuid) => '$routeProgram/$programUuid';

/// Path slugs for the four Program-tab segments (ADR-0032 *Canonical scheme*).
/// Kept here so the router and the segment switcher share one canonical list
/// without dragging the [ProgramSegment] enum into [app_routes.dart].
const String programSegmentExercisesSlug = 'exercises';
const String programSegmentStationsSlug = 'stations';
const String programSegmentScriptSlug = 'script';
const String programSegmentTeamsSlug = 'teams';

const List<String> programSegmentSlugs = [
  programSegmentExercisesSlug,
  programSegmentStationsSlug,
  programSegmentScriptSlug,
  programSegmentTeamsSlug,
];

/// Default segment when only the program UUID is present in the URL.
const String programSegmentDefaultSlug = programSegmentExercisesSlug;

String programSegmentPath(String programUuid, String segmentSlug) =>
    '${programPath(programUuid)}/$segmentSlug';

String programMapPath(String programUuid) => '${programPath(programUuid)}/map';

String programExercisePath(String programUuid, String exerciseUuid) =>
    '${programPath(programUuid)}/exercise/$exerciseUuid';

String programStationPath(
  String programUuid,
  String exerciseUuid,
  int stationIndex,
) => '${programExercisePath(programUuid, exerciseUuid)}/station/$stationIndex';

String programTeamPath(String programUuid, int teamIndex) =>
    '${programPath(programUuid)}/team/$teamIndex';

String programRolePlayPath(String programUuid, String rolePlayUuid) =>
    '${programPath(programUuid)}/roleplay/$rolePlayUuid';

String programBriefPath(String programUuid) =>
    '${programPath(programUuid)}/brief';

String programExerciseBriefPath(String programUuid, String exerciseUuid) =>
    '${programExercisePath(programUuid, exerciseUuid)}/brief';

String programRosterPath(String programUuid) =>
    '${programPath(programUuid)}/roster';

/// Legacy Map tab path. New navigation uses [programMapPath].
const String routeMap = '/map';

/// Legacy Roster tab path. New navigation uses [programRosterPath].
const String routeRoster = '/roster';

/// Legacy Stations tab path. Redirected into the matching Program segment or
/// canonical station detail route.
const String routeStations = '/stations';

/// Legacy Teams tab path. Redirected into the Program tab.
const String routeTeams = '/teams';

/// Legacy RolePlays tab path. Redirected into the Program tab.
const String routeRolePlays = '/roleplays';

/// Legacy Brief route prefix. New navigation uses [programBriefPath] and
/// [programExerciseBriefPath].
const String routeBrief = '/brief';
