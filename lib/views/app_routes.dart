// Centralised route path constants for the GoRouter setup in
// [main_screen.dart]. Kept in a tiny standalone file so that views can
// reference these constants without importing main_screen.dart (which
// would create cyclic imports back into the router setup).

const String routePlan = '/plan';

String planPath(String planUuid) => '$routePlan/$planUuid';

/// Path slugs for the four Plan-tab segments (ADR-0032 *Canonical scheme*).
/// Kept here so the router and the segment switcher share one canonical list
/// without dragging the [PlanSegment] enum into [app_routes.dart].
const String planSegmentExercisesSlug = 'exercises';
const String planSegmentStationsSlug = 'stations';
const String planSegmentScriptSlug = 'script';
const String planSegmentTeamsSlug = 'teams';

const List<String> planSegmentSlugs = [
  planSegmentExercisesSlug,
  planSegmentStationsSlug,
  planSegmentScriptSlug,
  planSegmentTeamsSlug,
];

/// Default segment when only the plan UUID is present in the URL.
const String planSegmentDefaultSlug = planSegmentExercisesSlug;

String planSegmentPath(String planUuid, String segmentSlug) =>
    '${planPath(planUuid)}/$segmentSlug';

String planMapPath(String planUuid) => '${planPath(planUuid)}/map';

String planExercisePath(String planUuid, String exerciseUuid) =>
    '${planPath(planUuid)}/exercise/$exerciseUuid';

String planStationPath(
  String planUuid,
  String exerciseUuid,
  int stationIndex,
) => '${planExercisePath(planUuid, exerciseUuid)}/station/$stationIndex';

String planTeamPath(String planUuid, int teamIndex) =>
    '${planPath(planUuid)}/team/$teamIndex';

String planRolePlayPath(String planUuid, String rolePlayUuid) =>
    '${planPath(planUuid)}/roleplay/$rolePlayUuid';

String planBriefPath(String planUuid) => '${planPath(planUuid)}/brief';

String planExerciseBriefPath(String planUuid, String exerciseUuid) =>
    '${planExercisePath(planUuid, exerciseUuid)}/brief';

String planRosterPath(String planUuid) => '${planPath(planUuid)}/roster';

/// Legacy Map tab path. New navigation uses [planMapPath].
const String routeMap = '/map';

/// Legacy Roster tab path. New navigation uses [planRosterPath].
const String routeRoster = '/roster';

/// Legacy Stations tab path. Redirected into the matching Plan segment or
/// canonical station detail route.
const String routeStations = '/stations';

/// Legacy Teams tab path. Redirected into the Plan tab.
const String routeTeams = '/teams';

/// Legacy RolePlays tab path. Redirected into the Plan tab.
const String routeRolePlays = '/roleplays';

/// Legacy Brief route prefix. New navigation uses [planBriefPath] and
/// [planExerciseBriefPath].
const String routeBrief = '/brief';
