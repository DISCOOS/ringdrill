import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/notification_service.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/theme.dart';
import 'package:ringdrill/utils/app_config.dart';
import 'package:ringdrill/utils/sentry_config.dart';
import 'package:ringdrill/utils/subscription_bag.dart';
import 'package:ringdrill/views/about_page.dart';
import 'package:ringdrill/views/active_plan_actions.dart' as active_actions;
import 'package:ringdrill/views/app_routes.dart';
import 'package:ringdrill/views/coordinator_screen.dart';
import 'package:ringdrill/views/feedback.dart';
import 'package:ringdrill/views/install_link_handler.dart';
import 'package:ringdrill/views/open_file_widget.dart';
import 'package:ringdrill/views/page_widget.dart';
import 'package:ringdrill/views/plan_status_badge.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/views/program_form_screen.dart';
import 'package:ringdrill/views/program_view.dart';
import 'package:ringdrill/views/roleplays_view.dart';
import 'package:ringdrill/views/roster_view.dart';
import 'package:ringdrill/views/shell/detail_empty_pane.dart';
import 'package:ringdrill/views/shell/master_detail_scope.dart';
import 'package:ringdrill/views/shell/open_form_surface.dart';
import 'package:ringdrill/views/shell/window_size_class.dart';
import 'package:ringdrill/views/station_list_view.dart';
import 'package:ringdrill/views/stations_view.dart';
import 'package:ringdrill/views/teams_view.dart';
import 'package:ringdrill/views/drill_player/drill_mini_player.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';
import 'package:ringdrill/views/widgets/drill_player_sheet.dart';
import 'package:ringdrill/views/widgets/ringdrill_sheet.dart';
import 'package:ringdrill/views/widgets/sheet_title.dart';
import 'package:ringdrill/web/platform_widget.dart'
    if (dart.library.io) 'package:ringdrill/views/platform_widget.dart';
import 'package:ringdrill/web/settings_page.dart'
    if (dart.library.io) 'package:ringdrill/views/settings_page.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_io/io.dart';

String _activeProgramPath() {
  final uuid = ProgramService().activeProgramUuid;
  return uuid == null ? routeProgram : programPath(uuid);
}

@visibleForTesting
String? legacyProgramRedirect(String location) {
  final segments = Uri.parse(location).pathSegments;
  final service = ProgramService();
  final activeUuid = service.activeProgramUuid;
  if (activeUuid == null) return null;

  if (segments.isEmpty) return programPath(activeUuid);
  if (segments.length == 1) {
    return switch (segments.first) {
      'program' => programPath(activeUuid),
      'map' => programMapPath(activeUuid),
      'roster' => programRosterPath(activeUuid),
      'stations' || 'teams' || 'roleplays' => programPath(activeUuid),
      _ => null,
    };
  }
  if (segments.first == 'program' &&
      service.loadProgram(segments[1]) == null &&
      service.getExercise(segments[1]) != null) {
    if (segments.length == 2) {
      return programExercisePath(activeUuid, segments[1]);
    }
    if (segments.length == 4 && segments[2] == 'station') {
      final stationIndex = int.tryParse(segments[3]);
      return stationIndex == null
          ? null
          : programStationPath(activeUuid, segments[1], stationIndex);
    }
    if (segments.length == 4 && segments[2] == 'team') {
      final teamIndex = int.tryParse(segments[3]);
      return teamIndex == null ? null : programTeamPath(activeUuid, teamIndex);
    }
  }
  if (segments.first == 'stations' && segments.length == 3) {
    final stationIndex = int.tryParse(segments[2]);
    return stationIndex == null
        ? null
        : programStationPath(activeUuid, segments[1], stationIndex);
  }
  if (segments.first == 'teams' && segments.length == 2) {
    final teamIndex = int.tryParse(segments[1]);
    return teamIndex == null ? null : programTeamPath(activeUuid, teamIndex);
  }
  if (segments.first == 'roleplays' && segments.length == 2) {
    return programRolePlayPath(activeUuid, segments[1]);
  }
  if (segments.first == 'brief') {
    if (segments.length == 3 && segments[1] == 'program') {
      return programBriefPath(segments[2]);
    }
    if (segments.length == 2) {
      return programExerciseBriefPath(activeUuid, segments[1]);
    }
  }
  return null;
}

String? _activateCanonicalProgramPath(String location) {
  final segments = Uri.parse(location).pathSegments;
  if (segments.length < 2 || segments.first != 'program') return null;

  final candidateUuid = segments[1];
  final service = ProgramService();
  if (service.loadProgram(candidateUuid) == null) {
    return _activeProgramPath();
  }
  // Activation is a side effect, not a routing decision. Awaiting setActive
  // inside the redirect mutated ProgramService and rebuilt the shell during
  // SchedulerPhase.midFrameMicrotasks, which tripped
  // RenderParagraph._scheduleSystemFontsUpdate ("called during
  // SchedulerPhase.midFrameMicrotasks"). Defer it to a post-frame callback so
  // setActive's listeners fire when the scheduler is idle: the page renders
  // against the current active program for one frame, then the activation
  // triggers a clean rebuild. The redirect itself stays synchronous and pure.
  if (service.activeProgramUuid != candidateUuid) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final s = ProgramService();
      // Re-check inside the callback: the active program may have changed
      // (or the program been removed) between scheduling and the frame.
      if (s.activeProgramUuid != candidateUuid &&
          s.loadProgram(candidateUuid) != null) {
        await s.setActive(candidateUuid);
      }
    });
  }
  return null;
}

GoRouter buildRouter(bool isFirstLaunch) {
  final key = GlobalKey<NavigatorState>();
  // Explicit key for the ShellRoute's internal Navigator. GoRouter creates
  // one implicitly when omitted, but we own it here for two reasons:
  // (1) so we can pass `child` through to MainScreen and mount it ourselves
  //     — without that, the GlobalKey is never attached to a NavigatorState
  //     and pressing system back on Android crashes inside
  //     `GoRouterDelegate._findCurrentNavigators` with a null check failure
  //     on `walker.navigatorKey.currentState!`;
  // (2) so the diagnostic is obvious next time something accidentally
  //     drops the shell's Navigator out of the tree.
  final shellNavigatorKey = GlobalKey<NavigatorState>();
  return GoRouter(
    navigatorKey: key,
    debugLogDiagnostics: kDebugMode,
    redirect: (context, state) {
      final location = state.uri.path;
      debugPrint('[$GoRouter] redirect >> $location');
      if (location.startsWith('/i/')) {
        final slug = Uri.decodeComponent(location.substring('/i/'.length));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final context = key.currentContext;
          if (context != null) {
            handleInstallLink(context, slug);
          }
        });
        return _activeProgramPath();
      }
      if (location.startsWith('/o/')) {
        final filePath = Uri.decodeComponent(location.replaceFirst('/o', ''));
        // Show bottom sheet for remote file
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final context = key.currentContext;
          if (context != null) {
            _showOpenFileBottomSheet(
              context,
              filePath: filePath,
              location: _activeProgramPath(),
            );
          }
        });
        // OpenFileWidget requires a
        // ProgramPageController instance
        // to exist in widget tree. Always
        // redirect to programs page!
        return _activeProgramPath();
      }
      final legacyRedirect = legacyProgramRedirect(location);
      if (legacyRedirect != null && legacyRedirect != location) {
        return legacyRedirect;
      }
      return _activateCanonicalProgramPath(location);
    },
    routes: [
      GoRoute(path: '/i/:slug', redirect: (_, _) => _activeProgramPath()),
      // Brief routes — not tabs; pushed over the root navigator as a
      // fullscreen modal bottom sheet. The program variant is listed first so
      // go_router matches the more specific `program/` path before the bare
      // `:exerciseUuid` catch-all.
      GoRoute(
        path: '$routeBrief/program/:programUuid',
        parentNavigatorKey: key,
        pageBuilder: (BuildContext context, GoRouterState state) =>
            CustomTransitionPage(
              opaque: false,
              barrierColor: Colors.transparent,
              transitionsBuilder: (_, _, _, child) => child,
              child: _BriefDeepLinkLauncher(
                target: BriefSheetTarget(
                  programUuid: state.pathParameters['programUuid']!,
                ),
                fallbackRoute: routeProgram,
              ),
            ),
      ),
      GoRoute(
        path: '$routeBrief/:exerciseUuid',
        parentNavigatorKey: key,
        pageBuilder: (BuildContext context, GoRouterState state) =>
            CustomTransitionPage(
              opaque: false,
              barrierColor: Colors.transparent,
              transitionsBuilder: (_, _, _, child) => child,
              child: _BriefDeepLinkLauncher(
                target: BriefSheetTarget(
                  exerciseUuid: state.pathParameters['exerciseUuid']!,
                ),
                fallbackRoute: routeProgram,
              ),
            ),
      ),
      ShellRoute(
        navigatorKey: shellNavigatorKey,
        builder: (BuildContext context, GoRouterState state, Widget child) {
          return PlatformWidget(
            child: MainScreen(
              navigatorKey: key,
              isFirstLaunch: isFirstLaunch,
              router: GoRouter.of(context),
              location: state.matchedLocation,
              routes: [routeProgram, routeMap, routeRoster],
              // The shell's nested Navigator (identified by
              // [shellNavigatorKey]). MainScreen mounts it offstage so the
              // GlobalKey gets attached — see the comment on
              // [shellNavigatorKey] above for why this matters on Android.
              shellChild: child,
            ),
          );
        },
        routes: [
          GoRoute(path: '/', redirect: (_, _) => _activeProgramPath()),
          GoRoute(
            path: routeProgram,
            // ShellRoute's child is ignored by MainScreen (IndexedStack).
            // Stub builder avoids constructing a second ProgramPageController
            // that would only ever be mounted inside the offstage shell
            // sentinel and would double-subscribe to ProgramService events.
            builder: (BuildContext context, GoRouterState state) =>
                const SizedBox.shrink(),
            routes: [
              GoRoute(
                path: ':programUuid',
                builder: (BuildContext context, GoRouterState state) =>
                    const SizedBox.shrink(),
                routes: [
                  GoRoute(
                    path: 'map',
                    builder: (BuildContext context, GoRouterState state) =>
                        const SizedBox.shrink(),
                  ),
                  GoRoute(
                    path: 'roster',
                    // ShellRoute's child is ignored by MainScreen (IndexedStack).
                    // Stub builder avoids constructing a second RosterController.
                    builder: (BuildContext context, GoRouterState state) =>
                        const SizedBox.shrink(),
                  ),
                  GoRoute(
                    path: 'brief',
                    parentNavigatorKey: key,
                    pageBuilder: (BuildContext context, GoRouterState state) =>
                        CustomTransitionPage(
                          opaque: false,
                          barrierColor: Colors.transparent,
                          transitionsBuilder: (_, _, _, child) => child,
                          child: _BriefDeepLinkLauncher(
                            target: BriefSheetTarget(
                              programUuid: state.pathParameters['programUuid']!,
                            ),
                            fallbackRoute: programPath(
                              state.pathParameters['programUuid']!,
                            ),
                          ),
                        ),
                  ),
                  GoRoute(
                    path: 'exercise/:exerciseId/station/:stationIndex',
                    parentNavigatorKey: key,
                    builder: (BuildContext context, GoRouterState state) =>
                        _ContextSheetDeepLinkLauncher(
                          target: StationSheetTarget(
                            exerciseUuid: state.pathParameters['exerciseId']!,
                            stationIndex: int.parse(
                              state.pathParameters['stationIndex']!,
                            ),
                          ),
                          fallbackRoute: programPath(
                            state.pathParameters['programUuid']!,
                          ),
                        ),
                  ),
                  GoRoute(
                    path: 'exercise/:exerciseId/team/:teamIndex',
                    redirect: (context, state) => programTeamPath(
                      state.pathParameters['programUuid']!,
                      int.parse(state.pathParameters['teamIndex']!),
                    ),
                  ),
                  GoRoute(
                    path: 'exercise/:exerciseId/brief',
                    parentNavigatorKey: key,
                    pageBuilder: (BuildContext context, GoRouterState state) =>
                        CustomTransitionPage(
                          opaque: false,
                          barrierColor: Colors.transparent,
                          transitionsBuilder: (_, _, _, child) => child,
                          child: _BriefDeepLinkLauncher(
                            target: BriefSheetTarget(
                              exerciseUuid: state.pathParameters['exerciseId']!,
                            ),
                            fallbackRoute: programPath(
                              state.pathParameters['programUuid']!,
                            ),
                          ),
                        ),
                  ),
                  GoRoute(
                    path: 'exercise/:exerciseId',
                    parentNavigatorKey: key,
                    builder: (BuildContext context, GoRouterState state) =>
                        _ContextSheetDeepLinkLauncher(
                          target: ExerciseSheetTarget(
                            exerciseUuid: state.pathParameters['exerciseId']!,
                          ),
                          fallbackRoute: programPath(
                            state.pathParameters['programUuid']!,
                          ),
                        ),
                  ),
                  GoRoute(
                    path: 'team/:teamIndex',
                    parentNavigatorKey: key,
                    builder: (BuildContext context, GoRouterState state) {
                      final teamIndex = int.parse(
                        state.pathParameters['teamIndex']!,
                      );
                      final candidates = ProgramService()
                          .loadExercises()
                          .where((e) => e.numberOfTeams > teamIndex)
                          .toList();
                      if (candidates.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      final exerciseService = ExerciseService();
                      final exercise = candidates.firstWhere(
                        (e) => exerciseService.isStartedOn(e.uuid),
                        orElse: () => candidates.first,
                      );
                      return _ContextSheetDeepLinkLauncher(
                        target: TeamSheetTarget(
                          exerciseUuid: exercise.uuid,
                          teamIndex: teamIndex,
                        ),
                        fallbackRoute: programPath(
                          state.pathParameters['programUuid']!,
                        ),
                      );
                    },
                  ),
                  GoRoute(
                    path: 'roleplay/:roleUuid',
                    parentNavigatorKey: key,
                    builder: (BuildContext context, GoRouterState state) =>
                        _ContextSheetDeepLinkLauncher(
                          target: RoleSheetTarget(
                            rolePlayUuid: state.pathParameters['roleUuid']!,
                          ),
                          fallbackRoute: programPath(
                            state.pathParameters['programUuid']!,
                          ),
                        ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: routeMap,
            // ShellRoute's child is ignored by MainScreen (IndexedStack).
            // Stub builder avoids constructing a second StationsPageController
            // that would only ever be mounted inside the offstage shell
            // sentinel.
            builder: (BuildContext context, GoRouterState state) =>
                const SizedBox.shrink(),
          ),
          GoRoute(
            path: routeRoster,
            // ShellRoute's child is ignored by MainScreen (IndexedStack).
            // Stub builder avoids constructing a second RosterController.
            builder: (BuildContext context, GoRouterState state) =>
                const SizedBox.shrink(),
          ),
          GoRoute(
            path: routeStations,
            // ShellRoute's `child` is ignored by MainScreen, which owns
            // the visible widget tree via its `_pages` IndexedStack. The
            // builder here exists so the path matches in routing, but
            // the returned widget is never displayed. Returning a stub
            // also avoids constructing a second StationListController
            // that would never be reachable.
            builder: (BuildContext context, GoRouterState state) =>
                const SizedBox.shrink(),
            routes: [
              GoRoute(
                path: ':exerciseId/:stationIndex',
                parentNavigatorKey: key,
                builder: (BuildContext context, GoRouterState state) =>
                    _ContextSheetDeepLinkLauncher(
                      target: StationSheetTarget(
                        exerciseUuid: state.pathParameters['exerciseId']!,
                        stationIndex: int.parse(
                          state.pathParameters['stationIndex']!,
                        ),
                      ),
                      fallbackRoute: routeStations,
                    ),
              ),
            ],
          ),
          GoRoute(
            path: routeTeams,
            // ShellRoute's child is ignored by MainScreen (IndexedStack).
            // Stub builder avoids constructing a second TeamsPageController
            // that would only ever be mounted inside the offstage shell
            // sentinel.
            builder: (BuildContext context, GoRouterState state) =>
                const SizedBox.shrink(),
            routes: [
              GoRoute(
                path: ':teamIndex',
                parentNavigatorKey: key,
                builder: (BuildContext context, GoRouterState state) {
                  final teamIndex = int.parse(
                    state.pathParameters['teamIndex']!,
                  );
                  final candidates = ProgramService()
                      .loadExercises()
                      .where((e) => e.numberOfTeams > teamIndex)
                      .toList();
                  if (candidates.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  // Prefer the running exercise (match on uuid), not the
                  // first one by index, so the team detail reflects live
                  // state. Falls back to the first when none is started.
                  final exerciseService = ExerciseService();
                  final exercise = candidates.firstWhere(
                    (e) => exerciseService.isStartedOn(e.uuid),
                    orElse: () => candidates.first,
                  );
                  return _ContextSheetDeepLinkLauncher(
                    target: TeamSheetTarget(
                      exerciseUuid: exercise.uuid,
                      teamIndex: teamIndex,
                    ),
                    fallbackRoute: routeTeams,
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: routeRolePlays,
            // ShellRoute's child is ignored by MainScreen (IndexedStack).
            // Stub builder avoids constructing an extra RolePlaysController.
            builder: (BuildContext context, GoRouterState state) =>
                const SizedBox.shrink(),
            routes: [
              GoRoute(
                path: ':roleUuid',
                parentNavigatorKey: key,
                builder: (BuildContext context, GoRouterState state) =>
                    _ContextSheetDeepLinkLauncher(
                      target: RoleSheetTarget(
                        rolePlayUuid: state.pathParameters['roleUuid']!,
                      ),
                      fallbackRoute: routeRolePlays,
                    ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

void _showOpenFileBottomSheet(
  BuildContext context, {
  required String location,
  required String filePath,
}) {
  showRingdrillActionSheet<void>(
    context: context,
    builder: (context) {
      // REMEMBER! OpenFileWidget
      // requires a ProgramPageController
      // instance to exist in the widget tree
      return OpenFileWidget(
        file: File(filePath),
        location: location,
        isOnline: false,
      );
    },
  );
}

class _BriefDeepLinkLauncher extends StatefulWidget {
  const _BriefDeepLinkLauncher({
    required this.target,
    required this.fallbackRoute,
  });

  final BriefSheetTarget target;
  final String fallbackRoute;

  @override
  State<_BriefDeepLinkLauncher> createState() => _BriefDeepLinkLauncherState();
}

class _BriefDeepLinkLauncherState extends State<_BriefDeepLinkLauncher> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openSheet());
  }

  Future<void> _openSheet() async {
    if (!mounted) return;
    final controller = ContextSheet.currentController;
    if (controller == null) {
      context.go(widget.fallbackRoute);
      return;
    }
    await controller.show(context, widget.target);
    if (!mounted) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      context.go(widget.fallbackRoute);
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _ContextSheetDeepLinkLauncher extends StatefulWidget {
  const _ContextSheetDeepLinkLauncher({
    required this.target,
    required this.fallbackRoute,
  });

  final ContextSheetTarget target;
  final String fallbackRoute;

  @override
  State<_ContextSheetDeepLinkLauncher> createState() =>
      _ContextSheetDeepLinkLauncherState();
}

class _ContextSheetDeepLinkLauncherState
    extends State<_ContextSheetDeepLinkLauncher> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openSheet());
  }

  Future<void> _openSheet() async {
    if (!mounted) return;
    final controller = ContextSheet.currentController;
    if (controller == null) {
      context.go(widget.fallbackRoute);
      return;
    }
    await controller.show(context, widget.target);
    if (!mounted) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      context.go(widget.fallbackRoute);
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class Destination {
  const Destination({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

class MainScreen extends StatefulWidget {
  const MainScreen({
    super.key,
    required this.router,
    required this.routes,
    required this.location,
    required this.navigatorKey,
    required this.isFirstLaunch,
    required this.shellChild,
  });

  final GoRouter router;
  final String location;
  final bool isFirstLaunch;
  final List<String> routes;
  final GlobalKey<NavigatorState> navigatorKey;

  /// The Navigator produced by the surrounding [ShellRoute]. Not painted
  /// or interacted with — MainScreen renders its own [IndexedStack] of
  /// keep-alive tab pages — but mounted offstage so the shell Navigator's
  /// [GlobalKey] is attached. Without that, GoRouter crashes on Android
  /// system back inside `_findCurrentNavigators` with
  /// `walker.navigatorKey.currentState!` returning null.
  final Widget shellChild;

  static void showSettings(BuildContext context, [bool pop = false]) {
    if (pop) Navigator.pop(context);
    openFormSurface<void>(context, builder: (context) => const SettingsPage());
  }

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SubscriptionBag<MainScreen> {
  static final GlobalKey _indexedTabsKey = GlobalKey();
  static final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();

  // Held as a field so the page and the view can share the same
  // instance. Passing it through PageWidget's InheritedWidget only
  // works when the static type argument matches exactly, and that
  // gets erased to ScreenController by the List<PageWidget> context.
  // A direct constructor handoff sidesteps the inference issue.
  late final StationListController _stationListController =
      StationListController();

  late final RolePlaysController _rolePlaysController = RolePlaysController();
  late final TeamsPageController _teamsPageController =
      const TeamsPageController();
  late final RosterController _rosterController = RosterController();
  late final ProgramPageController _programPageController =
      ProgramPageController(
        stationListController: _stationListController,
        rolePlaysController: _rolePlaysController,
        teamsPageController: _teamsPageController,
      );
  late final ContextSheetController _contextSheetController =
      ContextSheetController();

  /// Order matches [routeProgram, routeMap, routeRoster]. Station, roleplay
  /// and team views remain reachable as Program segments rather than
  /// standalone shell tabs.
  late final List<PageWidget> _pages = [
    PageWidget(
      controller: _programPageController,
      child: ProgramView(
        controller: _programPageController,
        stationListController: _stationListController,
        rolePlaysController: _rolePlaysController,
      ),
    ),
    PageWidget(controller: StationsPageController(), child: StationsView()),
    PageWidget(
      controller: _rosterController,
      child: RosterView(controller: _rosterController),
    ),
  ];

  int _currentTab = 0;
  bool _migrationSnackBarChecked = false;

  @override
  void initState() {
    super.initState();
    _initTab();
    _programPageController.activeSegment.addListener(_onProgramSegmentChanged);
    // Rebuild when reorder mode toggles so the FAB (which is suppressed in
    // reorder mode) appears/disappears without waiting for another rebuild.
    _programPageController.exerciseReorderMode.addListener(
      _onProgramSegmentChanged,
    );
    if (widget.isFirstLaunch) _showConsentDialog();
    listen(NotificationService().events, (event) {
      if (event.action == NotificationAction.showSettings) {
        if (mounted) {
          MainScreen.showSettings(context);
        }
      }
    });
    listen(ProgramService().events, (event) {
      if (mounted) setState(() {});
    });
    // Rebuild bottom chrome when an exercise starts or stops so the floating
    // mini-bar appears/disappears without a manual state push. Also show a
    // passive snackbar when the service auto-stops the exercise (endTime or
    // totalTime reached) — the persistent notification handles the
    // "still has to be acknowledged" path.
    listen(ExerciseService().events, (event) {
      if (!mounted) return;
      setState(() {});
      if (event.isDone && event.autoStopped) {
        _showAutoStoppedSnackBar(event);
      }
    });
    // Gated startup validation: only when a stored active-program reference
    // exists. Skipped on fresh install so no auto-created plan appears.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      if (!prefs.containsKey(AppConfig.keyActiveProgram)) return;
      if (!mounted) return;
      final localizations = AppLocalizations.of(context)!;
      await ProgramService().ensureActiveProgram(localizations);
    });
  }

  void _initTab() {
    final loc = widget.location;
    final activeUuid = ProgramService().activeProgramUuid;
    if (activeUuid != null && loc == programMapPath(activeUuid)) {
      _currentTab = 1;
      return;
    }
    if (activeUuid != null && loc == programRosterPath(activeUuid)) {
      _currentTab = 2;
      return;
    }
    if (loc.startsWith('$routeProgram/')) {
      _currentTab = 0;
      return;
    }
    _currentTab = widget.routes.indexWhere(
      (r) => loc == r || loc.startsWith('$r/'),
    );
    if (_currentTab < 0) _currentTab = 0;
  }

  @override
  void didUpdateWidget(covariant MainScreen oldWidget) {
    if (oldWidget.location != widget.location) {
      _initTab();
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _showMigrationSnackBarOnce();
  }

  @override
  void dispose() {
    _contextSheetController.dispose();
    _programPageController.activeSegment.removeListener(
      _onProgramSegmentChanged,
    );
    _programPageController.exerciseReorderMode.removeListener(
      _onProgramSegmentChanged,
    );
    _programPageController.dispose();
    _stationListController.dispose();
    // Field-held controller, never disposed before. Its filterExerciseUuid
    // ValueNotifier leaked on shell teardown. (DESIGN-006 stage 1 follow-up.)
    _rolePlaysController.dispose();
    _rosterController.dispose();
    super.dispose();
  }

  void _onProgramSegmentChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final page = _pages[_currentTab];
    final windowSizeClass = WindowSizeClass.of(context);
    // Off-screen mount point for the ShellRoute's nested Navigator. Hosts
    // the GlobalKey GoRouter walks during system back; not painted, never
    // hit-tested. The visible tab UI is the IndexedStack below.
    final shellSentinel = Offstage(
      offstage: true,
      child: TickerMode(enabled: false, child: widget.shellChild),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // The rail + master/detail layout only earns its keep when there is
        // also room for a usable (>=360) detail pane. In narrower medium
        // widths the detail pane would be too cramped — and previously had no
        // home at all: detail opened only as a bottom sheet and the mini
        // player wasn't shown. So fall back to the compact narrow layout
        // there: bottom NavigationBar, floating mini player, detail via the
        // context sheet. This keeps `useRail` and `windowSizeClass.hasRail`
        // distinct — the size class still says "medium" but we render narrow.
        const railWidth = 72.0;
        final masterWidth = windowSizeClass == WindowSizeClass.expanded
            ? 420.0
            : 320.0;
        final useRail =
            windowSizeClass.hasRail &&
            (constraints.maxWidth - railWidth - masterWidth) >= 360;
        // The Map tab (index 1) is rendered without an AppBar so the map
        // gets the full height. The wide/master-detail layout already does
        // this via the `_currentTab == 1` branch in [_buildNavRail]; mirror
        // it here for the compact layout so the bottom-nav Map tab also goes
        // chrome-free at the top. Every other tab keeps its AppBar.
        final isMapTab = _currentTab == 1;
        final scaffoldBody = Stack(
          fit: StackFit.expand,
          children: [
            useRail
                ? _buildNavRail(
                    context,
                    constraints,
                    localizations,
                    page,
                    windowSizeClass,
                  )
                : SafeArea(
                    child:
                        // Keep all tabs in memory allowing
                        // state to persist between tab switches
                        IndexedStack(
                          key: _indexedTabsKey,
                          index: _currentTab,
                          children: _pages,
                        ),
                  ),
            shellSentinel,
          ],
        );
        final body = isMapTab
            ? AnnotatedRegion<SystemUiOverlayStyle>(
                value: Theme.of(context).brightness == Brightness.dark
                    ? SystemUiOverlayStyle.light
                    : SystemUiOverlayStyle.dark,
                child: scaffoldBody,
              )
            : scaffoldBody;
        return ContextSheet(
          controller: _contextSheetController,
          child: Scaffold(
            key: _scaffoldKey,
            extendBody: true,
            extendBodyBehindAppBar: true,
            drawerEnableOpenDragGesture:
                Theme.of(context).platform != TargetPlatform.iOS,
            appBar: (useRail || isMapTab)
                ? null
                : _buildAppBar(context, constraints, page, hasRail: false),
            drawer: _buildDrawer(context, localizations),
            // StackFit.expand is load-bearing: without it the Stack sizes
            // itself to the biggest non-positioned child, but the only
            // non-positioned child here is the Offstage shell sentinel
            // (which has zero size by design), so the Stack collapses to
            // 0x0 and the visible Positioned.fill child has nothing to
            // fill. Result: tabs render fine but at zero size, so the UI
            // looks completely empty even though no exception is thrown.
            body: body,
            floatingActionButton: useRail
                ? null
                : page.controller.buildFAB(context, constraints),
            bottomNavigationBar: _buildBottomChrome(
              context,
              localizations,
              useRail,
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    BoxConstraints constraints,
    PageWidget<ScreenController> page, {
    required bool hasRail,
  }) {
    // Master AppBar adopts the same 72px height as the detail screens'
    // `SheetTitle` AppBar when the master/detail layout is active, so the
    // first content row on each side starts at the same Y. Compact stays
    // 56 to preserve vertical space on phones.
    final toolbarHeight = hasRail ? kRingdrillHeaderHeight : kToolbarHeight;
    // In rail mode the master AppBar carries the masterAccent tone so the
    // selected NavigationRail indicator pill, the master AppBar and the
    // master pane body all share a single colour. Compact keeps the
    // theme default (`brandDeep` in dark, `lightScaffold` in light, so
    // detail AppBars merge with detail body in both modes).
    final appBarBackground = hasRail ? _masterAccent(context) : null;
    // In light hasRail mode the master accent is a light eggshell tone,
    // so the AppBar's white foreground must flip to dark for legibility.
    // Dark mode keeps the default white from `appBarTheme.foregroundColor`.
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final appBarForeground = hasRail && !isDark
        ? RingDrillColors.lightOnSurface
        : null;

    Widget appBar = AppBar(
      toolbarHeight: toolbarHeight,
      backgroundColor: appBarBackground,
      foregroundColor: appBarForeground,
      title: _buildAppBarTitle(context, page, hasRail: hasRail),
      // In wide layout the hamburger lives at the top of the NavigationRail;
      // suppress the AppBar's leading slot entirely so it doesn't duplicate.
      leadingWidth: hasRail ? 0 : null,
      leading: hasRail ? const SizedBox.shrink() : null,
      actions: [
        // Segment/page actions first, then the plan status badge pinned
        // furthest right.
        ...?page.controller.buildActions(context, constraints),
        const PlanStatusBadge(),
      ],
      actionsPadding: EdgeInsets.only(right: 16.0),
    );

    // PlanStatusBadge reads `theme.appBarTheme.foregroundColor` from the
    // inherited theme rather than the AppBar widget property, so we
    // additionally override the theme in light hasRail mode so the badge
    // flips alongside the rest of the AppBar foreground.
    if (appBarForeground != null) {
      appBar = Theme(
        data: theme.copyWith(
          appBarTheme: theme.appBarTheme.copyWith(
            foregroundColor: appBarForeground,
            backgroundColor: appBarBackground,
          ),
        ),
        child: appBar,
      );
    }

    return PreferredSize(
      preferredSize: Size.fromHeight(toolbarHeight),
      child: _removePadding(context: context, paddingLeft: 0, child: appBar),
    );
  }

  Widget _buildAppBarTitle(
    BuildContext context,
    PageWidget<ScreenController> page, {
    required bool hasRail,
  }) {
    final pageTitle = page.controller.title(context);
    // In master/detail mode, mirror the detail-screen `SheetTitle` pattern:
    // primary = tab title (e.g. "Markører"), secondary = active plan name.
    // The active plan was previously only visible via the tooltip on the
    // program tab title, which made cross-tab orientation invisible.
    final activePlanName = hasRail
        ? ProgramService().activeProgram?.name
        : null;
    // Suppress the secondary line when it would just repeat the primary.
    // The Program tab's title already is the active plan name, so without
    // this it printed the plan name twice. Other tabs (Map, Roster) keep
    // the plan name as orientation because their primary is a section name.
    final secondary = activePlanName == pageTitle ? null : activePlanName;
    final Widget titleChild = hasRail
        ? SheetTitle(primary: pageTitle, secondary: secondary)
        : Text(pageTitle);

    final controller = page.controller;
    if (controller is! ProgramPageControllerBase) return titleChild;
    final localizations = AppLocalizations.of(context)!;
    return Tooltip(
      message: localizations.editProgram,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () => _openProgramForm(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: titleChild,
        ),
      ),
    );
  }

  /// Opens the full [ProgramFormScreen] for the active plan (name,
  /// description and the addable brief sections), replacing the old
  /// name-only rename dialog on the AppBar title tap.
  Future<void> _openProgramForm(BuildContext context) async {
    final program = ProgramService().activeProgram;
    if (program == null) return;
    final updated = await openFormSurface<Program>(
      context,
      builder: (_) => ProgramFormScreen(program: program),
    );
    if (updated != null && context.mounted) {
      await ProgramService().replaceProgram(updated);
    }
  }

  Widget? _buildDrawer(BuildContext context, AppLocalizations localizations) {
    final activeProgram = ProgramService().activeProgram;
    final hasActivePlan = activeProgram != null;
    final isCatalogActive =
        activeProgram != null && active_actions.isCatalogProgram(activeProgram);
    return NavigationDrawer(
      elevation: 8,
      children: [
        Container(
          // Hardcode the brand-deep tone here regardless of theme so the
          // drawer header remains a distinct brand surface. Was
          // `appBarTheme.backgroundColor`, which now resolves to the
          // light scaffold tone in light mode and would render the
          // hardcoded white app-name text invisible.
          color: RingDrillColors.brandDeep,
          padding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 16.0),
          child: Row(
            children: [
              Text(
                localizations.appName,
                // ADR-0037: themed titleMedium instead of a hardcoded 18.
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16.0),
        _drawerTile(
          context,
          icon: Icons.folder_open,
          title: localizations.openPlan,
          onTap: () async {
            Navigator.pop(context);
            await active_actions.openPlan(context);
          },
        ),
        _drawerTile(
          context,
          icon: Icons.add_circle_outline,
          title: localizations.newPlanAction,
          enabled: hasActivePlan,
          disabledTooltip: localizations.requiresActivePlan,
          onTap: () async {
            Navigator.pop(context);
            await active_actions.createNewPlan(context);
          },
        ),
        _drawerTile(
          context,
          icon: Icons.playlist_add,
          title: localizations.addExercisesAction,
          enabled: hasActivePlan,
          disabledTooltip: localizations.requiresActivePlan,
          onTap: () async {
            Navigator.pop(context);
            await active_actions.addExercises(context);
          },
        ),
        const Divider(),
        _drawerTile(
          context,
          icon: Icons.link,
          title: localizations.shareActivePlan,
          enabled: isCatalogActive,
          disabledTooltip: hasActivePlan
              ? localizations.planStatusLocalTooltip
              : localizations.requiresActivePlan,
          onTap: () async {
            Navigator.pop(context);
            await active_actions.shareActivePlan(context);
          },
        ),
        if (ProgramPageController.canSendDrillFile)
          _drawerTile(
            context,
            icon: Icons.send,
            title: localizations.sendToAction,
            enabled: hasActivePlan,
            disabledTooltip: localizations.requiresActivePlan,
            onTap: () async {
              Navigator.pop(context);
              await active_actions.sendActivePlanTo(context);
            },
          ),
        if (ProgramPageController.canSaveDrillFile)
          _drawerTile(
            context,
            icon: Icons.download,
            title: localizations.exportAsDrill,
            enabled: hasActivePlan,
            disabledTooltip: localizations.requiresActivePlan,
            onTap: () async {
              Navigator.pop(context);
              await active_actions.exportActivePlan(context);
            },
          ),
        _drawerTile(
          context,
          icon: Icons.cloud_upload_outlined,
          title: localizations.publishActivePlan,
          enabled: hasActivePlan,
          disabledTooltip: localizations.requiresActivePlan,
          onTap: () async {
            Navigator.pop(context);
            await active_actions.publishActivePlan(context);
          },
        ),
        _drawerTile(
          context,
          icon: Icons.cloud_sync_outlined,
          title: localizations.publishAsActivePlan,
          enabled: hasActivePlan,
          disabledTooltip: localizations.requiresActivePlan,
          onTap: () async {
            Navigator.pop(context);
            await active_actions.publishAsActivePlan(context);
          },
        ),
        _drawerTile(
          context,
          icon: Icons.refresh,
          title: localizations.libraryRefresh,
          enabled: isCatalogActive,
          disabledTooltip: hasActivePlan
              ? localizations.planStatusLocalTooltip
              : localizations.requiresActivePlan,
          onTap: () async {
            Navigator.pop(context);
            await active_actions.refreshActivePlanFromCatalog(context);
          },
        ),
        _drawerTile(
          context,
          icon: Icons.delete,
          title: localizations.libraryDelete,
          enabled: hasActivePlan,
          disabledTooltip: localizations.requiresActivePlan,
          onTap: () async {
            Navigator.pop(context);
            await active_actions.deleteActivePlan(context);
          },
        ),
        const Divider(),
        _drawerTile(
          context,
          icon: Icons.settings,
          title: localizations.settings,
          onTap: () => MainScreen.showSettings(context, true),
        ),
        _drawerTile(
          context,
          icon: Icons.info,
          title: localizations.about,
          onTap: () {
            Navigator.pop(context);
            openFormSurface<void>(
              context,
              builder: (context) => const AboutPage(),
            );
          },
        ),
        _drawerTile(
          context,
          icon: Icons.feedback,
          title: localizations.feedback,
          onTap: () {
            Navigator.pop(context);
            showFeedbackSheet(
              context,
              appState: {
                '_exerciseService': {
                  'lastEvent': ExerciseService().last?.toJson(),
                },
              },
            );
          },
        ),
      ],
    );
  }

  Widget _drawerTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool enabled = true,
    String? disabledTooltip,
  }) {
    final tile = ListTile(
      leading: Icon(icon),
      title: Text(title),
      enabled: enabled,
      onTap: enabled ? onTap : null,
    );
    if (enabled || disabledTooltip == null) return tile;
    return Tooltip(message: disabledTooltip, child: tile);
  }

  void _onDestinationSelected(int tab) {
    setState(() {
      _currentTab = tab;
    });
    _contextSheetController.close();
    stationsMapDetailClearTick.value = stationsMapDetailClearTick.value + 1;
    widget.router.go(_routeForTab(tab));
    // The StationsView is kept alive inside the IndexedStack, so its map
    // does not re-fit on tab switch on its own. Nudge it via the reselect
    // tick whenever the Map tab is (re)activated.
    if (tab == 1) {
      stationsTabReselectTick.value = stationsTabReselectTick.value + 1;
    }
  }

  String _routeForTab(int tab) {
    final activeUuid = ProgramService().activeProgramUuid;
    if (activeUuid == null) return widget.routes[tab];
    return switch (tab) {
      0 => programPath(activeUuid),
      1 => programMapPath(activeUuid),
      2 => programRosterPath(activeUuid),
      _ => widget.routes[tab],
    };
  }

  List<Destination> _buildDestinations(AppLocalizations localizations) {
    return [
      Destination(icon: Icons.update, label: localizations.exercise(2)),
      Destination(icon: Icons.map, label: localizations.mapTab),
      Destination(icon: Icons.badge, label: localizations.rosterTab),
    ];
  }

  Widget? _buildBottomChrome(
    BuildContext context,
    AppLocalizations localizations,
    bool useRail,
  ) {
    if (useRail) {
      return _buildNavBar(localizations, useRail);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (ExerciseService().isStarted)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: DrillMiniPlayer(onOpen: () => _openDrillPlayer(context)),
            ),
          ),
        _buildNavBar(localizations, useRail)!,
      ],
    );
  }

  void _openDrillPlayer(BuildContext context) {
    final last = ExerciseService().last;
    if (last == null) return;
    showDrillPlayerSheet<void>(
      context: context,
      builder: (_) => CoordinatorScreen(uuid: last.exercise.uuid),
    );
  }

  Widget? _buildNavBar(AppLocalizations localizations, bool useRail) {
    if (useRail) return null;
    return NavigationBar(
      selectedIndex: _currentTab,
      onDestinationSelected: _onDestinationSelected,
      destinations: _buildDestinations(localizations)
          .map<NavigationDestination>((d) {
            return NavigationDestination(icon: Icon(d.icon), label: d.label);
          })
          .toList(),
    );
  }

  /// Panel tone for the NavigationRail body in the wide layout. The rail
  /// reads as a distinct sidebar surface; the selected tab's indicator
  /// pill ([_masterAccent]) "extends" into the master pane.
  Color _panelColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? RingDrillColors.panelDark
        : RingDrillColors.panelLight;
  }

  /// Active-surface tone shared by the rail selection indicator, the
  /// master pane background and the master AppBar. Visually links the
  /// selected tab to the master content so the active section reads as
  /// one connected block.
  Color _masterAccent(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? RingDrillColors.masterAccentDark
        : RingDrillColors.masterAccentLight;
  }

  Widget _removePadding({
    required BuildContext context,
    required Widget child,
    double paddingLeft = 12,
  }) {
    final mq = MediaQuery.of(context);
    final isLandscape = mq.orientation == Orientation.landscape;
    final isCupertino = Theme.of(context).platform == TargetPlatform.iOS;

    final removeForRail = isCupertino && isLandscape;
    return MediaQuery.removePadding(
      context: context,
      removeTop: false,
      removeBottom: false,
      removeLeft: removeForRail,
      removeRight: removeForRail,
      child: ColoredBox(
        color: _panelColor(context), // rail bg, continuous with master pane
        child: Padding(
          padding: removeForRail
              ? EdgeInsets.only(left: paddingLeft)
              : EdgeInsets.zero,
          child: child,
        ),
      ),
    );
  }

  Widget _buildNavRail(
    BuildContext context,
    BoxConstraints constraints,
    AppLocalizations localizations,
    PageWidget page,
    WindowSizeClass windowSizeClass,
  ) {
    final fab = page.controller.buildFAB(context, constraints);
    final panelColor = _panelColor(context);
    final masterAccent = _masterAccent(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Explicit rail icon colours so the selected icon stays legible on
    // the `masterAccent` indicator pill (which is a light eggshell in
    // light mode, where M3's auto-derived `onSecondaryContainer` was
    // landing too close to the indicator background). In dark mode the
    // default white still works.
    final selectedIconColor = isDark
        ? Colors.white
        : RingDrillColors.lightOnSurface;
    final unselectedIconColor = isDark
        ? RingDrillColors.darkOnSurfaceVariant
        : RingDrillColors.lightOnSurfaceVariant;
    final rail = _removePadding(
      context: context,
      child: NavigationRail(
        // Explicit so the rail body paints with the same tone as the
        // surrounding ColoredBox in `_removePadding`. The selection
        // indicator picks up `masterAccent` so the selected tab visually
        // extends into the master pane on the right.
        backgroundColor: panelColor,
        indicatorColor: masterAccent,
        selectedIconTheme: IconThemeData(color: selectedIconColor),
        unselectedIconTheme: IconThemeData(color: unselectedIconColor),
        selectedIndex: _currentTab,
        onDestinationSelected: _onDestinationSelected,
        leading: Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: IconButton(
            // Hamburger doesn't sit on the indicator pill but it lives
            // on the same rail panel, so it uses the unselected tone.
            icon: Icon(Icons.menu, color: unselectedIconColor),
            tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
        ),
        destinations: _buildDestinations(localizations)
            .map<NavigationRailDestination>((d) {
              return NavigationRailDestination(
                icon: Icon(d.icon),
                label: Text(d.label),
                padding: EdgeInsets.symmetric(vertical: 8),
              );
            })
            .toList(),
        // The exercises FAB no longer lives in the rail trailing slot — in
        // the wide layout it floats at the bottom-right of the master pane
        // (see the Stack below). The rail just keeps a little bottom padding.
        trailing: const SizedBox(height: 16),
      ),
    );

    final masterWidth = windowSizeClass == WindowSizeClass.expanded
        ? 420.0
        : 320.0;
    const railWidth = 72.0;
    // The build() gate (`useRail`) guarantees we only reach the rail layout
    // when there is room for a usable detail pane. Narrower widths render the
    // compact narrow layout instead, so there is no longer a "rail without
    // detail" branch here.
    if (_currentTab == 1) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          rail,
          Expanded(child: _buildIndexedTabs()),
        ],
      );
    }

    return MasterDetailScope(
      target: _contextSheetController.targetNotifier,
      emptyPaneBuilder: _emptyPaneBuilderForCurrentTab,
      child: Row(
        children: [
          // Left region: navigation rail + master pane stacked above the
          // mini player. The mini player docks at the bottom of this region,
          // spanning under the rail and the master view but NOT the detail
          // pane — the same shape as Spotify's now-playing bar sitting over
          // the left columns while the main view runs full height beside it.
          SizedBox(
            width: railWidth + masterWidth,
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      rail,
                      // Master pane is painted with the master-accent tone so
                      // the selected rail indicator pill, the master AppBar
                      // and the master body all share a single colour and read
                      // as one connected "active section". The detail pane
                      // keeps the scaffold background. Cards inside the master
                      // list use `*Surface` which stays distinct against the
                      // accent.
                      Expanded(
                        child: ColoredBox(
                          color: masterAccent,
                          // In dark + rail, override `cardTheme.color` to
                          // `brandDeep` so cards in the master list sit one
                          // tone darker than `masterAccentDark` and clearly
                          // pop out as content tiles. Without this override
                          // cards default to `darkSurface` which is nearly
                          // the same lightness as the master accent. The
                          // narrow (no-rail) layout keeps the default
                          // `darkSurface` cards on the `brandDeep` scaffold.
                          child: Theme(
                            data: isDark
                                ? Theme.of(context).copyWith(
                                    cardTheme: Theme.of(context).cardTheme
                                        .copyWith(
                                          color: RingDrillColors.brandDeep,
                                        ),
                                  )
                                : Theme.of(context),
                            child: Column(
                              children: [
                                _buildAppBar(
                                  context,
                                  constraints,
                                  page,
                                  hasRail: true,
                                ),
                                // Stack so the active tab's FAB (only the
                                // exercises tab has one) floats at the
                                // bottom-right of the master pane, above the
                                // docked mini player which sits below this
                                // region in the outer Column.
                                Expanded(
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: _buildIndexedTabs(),
                                      ),
                                      if (fab != null)
                                        Positioned(
                                          right: 16,
                                          bottom: 16,
                                          child: fab,
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Mini player spans the left region (rail + master) and is
                // pinned to the bottom. It deliberately does not extend into
                // the detail pane.
                ValueListenableBuilder<ContextSheetTarget?>(
                  valueListenable: _contextSheetController.targetNotifier,
                  builder: (context, target, _) {
                    // Resolve the exercise for the idle (not-yet-started)
                    // mini player. Null when target isn't an exercise or
                    // the exercise isn't found.
                    final idleExercise = target is ExerciseSheetTarget
                        ? ProgramService().getExercise(target.exerciseUuid)
                        : null;
                    if (ExerciseService().isStarted || idleExercise != null) {
                      // No rounded corners in the wide/extended layout — the
                      // mini player is a flush bottom bar docked under the rail
                      // + master. Rounded corners are reserved for the narrow
                      // (portrait/mobile) floating mini bar in
                      // [_buildBottomChrome]. SafeArea honours any bottom inset
                      // (no extra padding, so the bar stays flush against the
                      // edge rather than leaving a mismatched gap below it).
                      return SafeArea(
                        top: false,
                        child: DrillMiniPlayer(
                          // Taller than the narrow floating bar (48) so the
                          // docked wide bar has more breathing room.
                          height: 64,
                          exercise: idleExercise,
                          onPlay: idleExercise == null
                              ? null
                              : () {
                                  unawaited(HapticFeedback.mediumImpact());
                                  ExerciseService().start(idleExercise);
                                  // Clear the detail target so the master/detail
                                  // pane empties once the exercise goes live —
                                  // the running exercise lives in the fullscreen
                                  // drill player, not the detail pane. Without
                                  // this the started exercise's coordinator stays
                                  // pinned in the detail pane after the player is
                                  // closed, until another item is selected.
                                  _contextSheetController.close();
                                  _openDrillPlayer(context);
                                },
                          onOpen: () => _openDrillPlayer(context),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
          const Expanded(child: MasterDetailPane()),
        ],
      ),
    );
  }

  Widget _buildIndexedTabs() {
    return IndexedStack(
      key: _indexedTabsKey,
      index: _currentTab,
      children: _pages,
    );
  }

  Widget _emptyPaneBuilderForCurrentTab(BuildContext context) {
    return switch (_currentTab) {
      0 => ValueListenableBuilder<ProgramSegment>(
        valueListenable: _programPageController.activeSegment,
        builder: (context, segment, _) => switch (segment) {
          ProgramSegment.exercises => const ExerciseDetailEmpty(),
          ProgramSegment.stations => const StationDetailEmpty(),
          ProgramSegment.script => const RolePlayDetailEmpty(),
          ProgramSegment.teams => const TeamDetailEmpty(),
        },
      ),
      2 => const RosterDetailEmpty(),
      _ => const SizedBox.shrink(),
    };
  }

  void _showConsentDialog() {
    Future.microtask(() async {
      if (mounted) {
        final localizations = AppLocalizations.of(context)!;
        // Show a dialog asking the user to provide consent
        final consent =
            await showAdaptiveDialog(
                  context: context,
                  // Prevent closing without taking action
                  barrierDismissible: false,
                  builder: (context) => AlertDialog(
                    title: Text(localizations.appAnalyticsConsent),
                    content: Text(
                      [
                        localizations.appAnalyticsConsentMessage,
                        localizations.appAnalyticsConsentOptIn,
                      ].join('. '),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(context, false);
                        },
                        child: Text(localizations.decline),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context, true);
                        },
                        child: Text(localizations.allow),
                      ),
                    ],
                  ),
                )
                as bool;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(AppConfig.keyAnalyticsConsent, consent);

        if (consent) {
          await SentryFlutter.init(SentryConfig.apply);
        }
      }
    });
  }

  /// Passive notice that the auto-stop fired. The persistent
  /// notification produced by `NotificationService` is what the user
  /// actually has to acknowledge; this snackbar is the in-app
  /// equivalent for whoever is staring at the running app when the
  /// timer expires.
  void _showAutoStoppedSnackBar(ExerciseEvent event) {
    final localizations = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          showCloseIcon: true,
          // endToStart swipe matches the migration snackbar above and
          // mirrors the swipe gesture the notification supports, so
          // the dismissal idiom is consistent.
          dismissDirection: DismissDirection.endToStart,
          content: Text(
            localizations.exerciseAutoStoppedSnack(event.exercise.name),
          ),
        ),
      );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _showMigrationSnackBarOnce() {
    if (_migrationSnackBarChecked) return;
    _migrationSnackBarChecked = true;
    if (!ProgramService().librarySchemaJustMigrated) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final localizations = AppLocalizations.of(context)!;
      final messenger = ScaffoldMessenger.of(context);
      messenger
          .showSnackBar(
            SnackBar(
              showCloseIcon: true,
              content: Text(localizations.libraryMigrationNotice),
              dismissDirection: DismissDirection.endToStart,
            ),
          )
          .closed
          .then((_) => ProgramService().clearLibrarySchemaJustMigrated());
    });
  }
}
