// GoRouter setup for the app shell. Lives next to `app_routes.dart` (path
// constants) so the routing layer is one cohesive piece, and out of
// `main_screen.dart` which now only owns the shell widget.
//
// Public entry points:
//   - [buildRouter] — the only call main.dart needs
//   - [legacyPlanRedirect] — `@visibleForTesting` for the redirect
//     mapping table tests

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as path;
import 'package:ringdrill/data/drill_file.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/views/app_routes.dart';
import 'package:ringdrill/views/concept_primer_screen.dart';
import 'package:ringdrill/views/install_link_handler.dart';
import 'package:ringdrill/views/library_view.dart';
import 'package:ringdrill/views/migration_page.dart';
import 'package:ringdrill/web/install_guide_page.dart'
    if (dart.library.io) 'package:ringdrill/views/install_guide_page_io.dart';
import 'package:ringdrill/views/main_screen.dart';
import 'package:ringdrill/views/open_file_widget.dart';
import 'package:ringdrill/views/shell/deep_link_launchers.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';
import 'package:ringdrill/web/platform_widget.dart'
    if (dart.library.io) 'package:ringdrill/views/platform_widget.dart';
import 'package:universal_io/io.dart';

String _activePlanPath() {
  final uuid = PlanService().activePlanUuid;
  return uuid == null ? routePlan : planPath(uuid);
}

@visibleForTesting
String? legacyPlanRedirect(String location) {
  final segments = Uri.parse(location).pathSegments;
  final service = PlanService();
  final activeUuid = service.activePlanUuid;
  if (activeUuid == null) return null;

  if (segments.isEmpty) return planPath(activeUuid);
  if (segments.length == 1) {
    return switch (segments.first) {
      'plan' => planPath(activeUuid),
      'map' => planMapPath(activeUuid),
      'roster' => planRosterPath(activeUuid),
      'stations' || 'teams' || 'roleplays' => planPath(activeUuid),
      _ => null,
    };
  }
  if (segments.first == 'plan' &&
      service.loadPlan(segments[1]) == null &&
      service.getExercise(segments[1]) != null) {
    if (segments.length == 2) {
      return planExercisePath(activeUuid, segments[1]);
    }
    if (segments.length == 4 && segments[2] == 'station') {
      final stationIndex = int.tryParse(segments[3]);
      return stationIndex == null
          ? null
          : planStationPath(activeUuid, segments[1], stationIndex);
    }
    if (segments.length == 4 && segments[2] == 'team') {
      final teamIndex = int.tryParse(segments[3]);
      return teamIndex == null ? null : planTeamPath(activeUuid, teamIndex);
    }
  }
  if (segments.first == 'stations' && segments.length == 3) {
    final stationIndex = int.tryParse(segments[2]);
    return stationIndex == null
        ? null
        : planStationPath(activeUuid, segments[1], stationIndex);
  }
  if (segments.first == 'teams' && segments.length == 2) {
    final teamIndex = int.tryParse(segments[1]);
    return teamIndex == null ? null : planTeamPath(activeUuid, teamIndex);
  }
  if (segments.first == 'roleplays' && segments.length == 2) {
    return planRolePlayPath(activeUuid, segments[1]);
  }
  if (segments.first == 'brief') {
    if (segments.length == 3 && segments[1] == 'plan') {
      return planBriefPath(segments[2]);
    }
    if (segments.length == 2) {
      return planExerciseBriefPath(activeUuid, segments[1]);
    }
  }
  return null;
}

String? _activateCanonicalPlanPath(String location) {
  final segments = Uri.parse(location).pathSegments;
  if (segments.length < 2 || segments.first != 'plan') return null;

  final candidateUuid = segments[1];
  final service = PlanService();
  if (service.loadPlan(candidateUuid) == null) {
    return _activePlanPath();
  }
  // Activation is a side effect, not a routing decision. Awaiting setActive
  // inside the redirect mutated PlanService and rebuilt the shell during
  // SchedulerPhase.midFrameMicrotasks, which tripped
  // RenderParagraph._scheduleSystemFontsUpdate ("called during
  // SchedulerPhase.midFrameMicrotasks"). Defer it to a post-frame callback so
  // setActive's listeners fire when the scheduler is idle: the page renders
  // against the current active plan for one frame, then the activation
  // triggers a clean rebuild. The redirect itself stays synchronous and pure.
  if (service.activePlanUuid != candidateUuid) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final s = PlanService();
      // Re-check inside the callback: the active plan may have changed
      // (or the plan been removed) between scheduling and the frame.
      if (s.activePlanUuid != candidateUuid &&
          s.loadPlan(candidateUuid) != null) {
        await s.setActive(candidateUuid);
      }
    });
  }
  // Bare `/plan/:uuid` has no canonical landing — promote it to the
  // default segment so every Plan-tab view has a stable URL (ADR-0032
  // *Canonical scheme*). MainScreen reads the segment back out of the URL
  // in `_initTab` and writes it to `PlanPageController.activeSegment`,
  // so segment selection flows URL → state, never the other way around.
  if (segments.length == 2) {
    return planSegmentPath(candidateUuid, planSegmentDefaultSlug);
  }
  return null;
}

GoRouter buildRouter(bool isFirstLaunch, bool isOnboardingSeen) {
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
        return _activePlanPath();
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
              location: _activePlanPath(),
            );
          }
        });
        // OpenFileWidget requires a
        // PlanPageController instance
        // to exist in widget tree. Always
        // redirect to plans page!
        return _activePlanPath();
      }
      // `?import=guide` (ADR-0045): the /migrate exporter sends users here
      // after downloading their library bundle. Web-only, same as /install
      // and /migrate below — the migration/import flow is a web concern.
      if (kIsWeb && state.uri.queryParameters['import'] == 'guide') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final context = key.currentContext;
          if (context != null) {
            showOpenPlanDialog(context, initialTab: LibraryTab.fromFile);
          }
        });
        return _activePlanPath();
      }
      // Primer gate: redirect root path to /welcome on first launch, before
      // the legacy redirect can absorb '/' → planPath(uuid).
      if (!isOnboardingSeen && location == '/') {
        return '/welcome';
      }
      final legacyRedirect = legacyPlanRedirect(location);
      if (legacyRedirect != null && legacyRedirect != location) {
        return legacyRedirect;
      }
      return _activateCanonicalPlanPath(location);
    },
    routes: [
      GoRoute(path: '/i/:slug', redirect: (_, _) => _activePlanPath()),
      // Concept primer — shown once on first launch when the onboarding seen
      // flag is unset. Lives over the root navigator (parentNavigatorKey: key)
      // so it does not fight the IndexedStack shell.
      GoRoute(
        path: '/welcome',
        parentNavigatorKey: key,
        builder: (context, state) =>
            ConceptPrimerScreen(isFirstLaunch: isFirstLaunch),
      ),
      // Web-only shareable routes. Both are pushed over the root navigator
      // so they render as full pages rather than shell tabs. They only make
      // sense on the web (install/migration are web concerns), so they are
      // not registered on native builds at all.
      if (kIsWeb) ...[
        // Shareable install guide.
        GoRoute(
          path: '/install',
          parentNavigatorKey: key,
          builder: (context, state) => const InstallGuidePage(),
        ),
        // Shareable migration explainer (legacy apex → new web app). Handy
        // to hand to a stuck user as a direct link.
        GoRoute(
          path: '/migrate',
          parentNavigatorKey: key,
          builder: (context, state) => const MigrationPage(),
        ),
      ],
      // Brief routes — not tabs; pushed over the root navigator as a
      // fullscreen modal bottom sheet. The plan variant is listed first so
      // go_router matches the more specific `plan/` path before the bare
      // `:exerciseUuid` catch-all.
      GoRoute(
        path: '$routeBrief/plan/:planUuid',
        parentNavigatorKey: key,
        pageBuilder: (BuildContext context, GoRouterState state) =>
            CustomTransitionPage(
              opaque: false,
              barrierColor: Colors.transparent,
              transitionsBuilder: (_, _, _, child) => child,
              child: BriefDeepLinkLauncher(
                target: BriefSheetTarget(
                  planUuid: state.pathParameters['planUuid']!,
                ),
                fallbackRoute: routePlan,
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
              child: BriefDeepLinkLauncher(
                target: BriefSheetTarget(
                  exerciseUuid: state.pathParameters['exerciseUuid']!,
                ),
                fallbackRoute: routePlan,
              ),
            ),
      ),
      ShellRoute(
        navigatorKey: shellNavigatorKey,
        builder: (BuildContext context, GoRouterState state, Widget child) {
          return PlatformWidget(
            child: MainScreen(
              navigatorKey: key,
              router: GoRouter.of(context),
              location: state.matchedLocation,
              routes: [routePlan, routeMap, routeRoster],
              // The shell's nested Navigator (identified by
              // [shellNavigatorKey]). MainScreen mounts it offstage so the
              // GlobalKey gets attached — see the comment on
              // [shellNavigatorKey] above for why this matters on Android.
              shellChild: child,
            ),
          );
        },
        routes: [
          GoRoute(path: '/', redirect: (_, _) => _activePlanPath()),
          GoRoute(
            path: routePlan,
            // ShellRoute's child is ignored by MainScreen (IndexedStack).
            // Stub builder avoids constructing a second PlanPageController
            // that would only ever be mounted inside the offstage shell
            // sentinel and would double-subscribe to PlanService events.
            builder: (BuildContext context, GoRouterState state) =>
                const SizedBox.shrink(),
            routes: [
              GoRoute(
                path: ':planUuid',
                builder: (BuildContext context, GoRouterState state) =>
                    const SizedBox.shrink(),
                routes: [
                  // Plan-tab segments (ADR-0032 *Canonical scheme*). The
                  // visible UI is the IndexedStack in MainScreen, so the
                  // builders return a stub — MainScreen reads the segment slug
                  // out of `state.matchedLocation` and writes it to
                  // `PlanPageController.activeSegment` in `_initTab`.
                  GoRoute(
                    path: planSegmentExercisesSlug,
                    builder: (BuildContext context, GoRouterState state) =>
                        const SizedBox.shrink(),
                  ),
                  GoRoute(
                    path: planSegmentStationsSlug,
                    builder: (BuildContext context, GoRouterState state) =>
                        const SizedBox.shrink(),
                  ),
                  GoRoute(
                    path: planSegmentScriptSlug,
                    builder: (BuildContext context, GoRouterState state) =>
                        const SizedBox.shrink(),
                  ),
                  GoRoute(
                    path: planSegmentTeamsSlug,
                    builder: (BuildContext context, GoRouterState state) =>
                        const SizedBox.shrink(),
                  ),
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
                          child: BriefDeepLinkLauncher(
                            target: BriefSheetTarget(
                              planUuid: state.pathParameters['planUuid']!,
                            ),
                            fallbackRoute: planPath(
                              state.pathParameters['planUuid']!,
                            ),
                          ),
                        ),
                  ),
                  GoRoute(
                    path: 'exercise/:exerciseId/station/:stationIndex',
                    parentNavigatorKey: key,
                    builder: (BuildContext context, GoRouterState state) =>
                        ContextSheetDeepLinkLauncher(
                          target: StationSheetTarget(
                            exerciseUuid: state.pathParameters['exerciseId']!,
                            stationIndex: int.parse(
                              state.pathParameters['stationIndex']!,
                            ),
                          ),
                          fallbackRoute: planPath(
                            state.pathParameters['planUuid']!,
                          ),
                        ),
                  ),
                  GoRoute(
                    path: 'exercise/:exerciseId/team/:teamIndex',
                    redirect: (context, state) => planTeamPath(
                      state.pathParameters['planUuid']!,
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
                          child: BriefDeepLinkLauncher(
                            target: BriefSheetTarget(
                              exerciseUuid: state.pathParameters['exerciseId']!,
                            ),
                            fallbackRoute: planPath(
                              state.pathParameters['planUuid']!,
                            ),
                          ),
                        ),
                  ),
                  GoRoute(
                    path: 'exercise/:exerciseId',
                    parentNavigatorKey: key,
                    builder: (BuildContext context, GoRouterState state) =>
                        ContextSheetDeepLinkLauncher(
                          target: ExerciseSheetTarget(
                            exerciseUuid: state.pathParameters['exerciseId']!,
                          ),
                          fallbackRoute: planPath(
                            state.pathParameters['planUuid']!,
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
                      if (PlanService().getTeam(teamIndex) == null) {
                        return const SizedBox.shrink();
                      }
                      // Open the cross-exercise team overview, not a single
                      // exercise's player view. TeamScreen highlights the live
                      // exercise itself, so no running/first guess is needed.
                      return ContextSheetDeepLinkLauncher(
                        target: TeamOverviewSheetTarget(teamIndex: teamIndex),
                        fallbackRoute: planPath(
                          state.pathParameters['planUuid']!,
                        ),
                      );
                    },
                  ),
                  GoRoute(
                    path: 'roleplay/:roleUuid',
                    parentNavigatorKey: key,
                    builder: (BuildContext context, GoRouterState state) =>
                        ContextSheetDeepLinkLauncher(
                          target: RoleSheetTarget(
                            rolePlayUuid: state.pathParameters['roleUuid']!,
                          ),
                          fallbackRoute: planPath(
                            state.pathParameters['planUuid']!,
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
                    ContextSheetDeepLinkLauncher(
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
                  if (PlanService().getTeam(teamIndex) == null) {
                    return const SizedBox.shrink();
                  }
                  // Open the cross-exercise team overview (TeamScreen), which
                  // shows every exercise the team is in and highlights the live
                  // one. No running/first-exercise guess.
                  return ContextSheetDeepLinkLauncher(
                    target: TeamOverviewSheetTarget(teamIndex: teamIndex),
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
                    ContextSheetDeepLinkLauncher(
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
  // REMEMBER! OpenFileWidget requires a PlanPageController instance to
  // exist in the widget tree.
  showOpenFileBottomSheet(
    context,
    OpenFileWidget(
      fileName: path.basename(filePath),
      loadFile: () async => DrillFile.fromFile(File(filePath)),
      openPlan: (file) =>
          PlanService().installFromFile(file, activate: true),
      location: location,
      isOnline: false,
    ),
  );
}
