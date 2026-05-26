// Centralised route path constants for the GoRouter setup in
// [main_screen.dart]. Kept in a tiny standalone file so that views can
// reference these constants without importing main_screen.dart (which
// would create cyclic imports back into the router setup).

const String routeProgram = '/program';

/// Map tab — formerly known as the "Stations" tab. The widget at this
/// route is [StationsView], which renders every station with a
/// position as a marker on a shared map. Per DESIGN-002 the path was
/// moved off `/stations` so the canonical list of stations can take
/// that URL.
const String routeMap = '/map';

/// Stations list tab — flat list of `(Exercise, Station)` pairs with
/// expandable rows. The deep-link subpath
/// `/stations/:exerciseUuid/:stationIndex` still resolves to
/// [StationExerciseScreen] regardless of which tab the navigation
/// started from.
const String routeStations = '/stations';

const String routeTeams = '/teams';

/// RolePlays tab — flat list of RolePlay rows across all exercises.
/// Introduced in DESIGN-003.
const String routeRolePlays = '/roleplays';

/// Brief route — read-mode renderer of an exercise or program as a
/// markdown document. Reachable as `/brief/program/:programUuid` for
/// the whole program and `/brief/:exerciseUuid` for a single exercise.
/// Not in the bottom navigation; pushed onto the root navigator from
/// the Brief action on `CoordinatorScreen` and `ProgramView`. See
/// DESIGN-004.
const String routeBrief = '/brief';
