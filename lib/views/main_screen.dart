import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/notification_service.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/utils/app_config.dart';
import 'package:ringdrill/utils/sentry_config.dart';
import 'package:ringdrill/views/about_page.dart';
import 'package:ringdrill/views/active_plan_actions.dart' as active_actions;
import 'package:ringdrill/views/app_routes.dart';
import 'package:ringdrill/views/coordinator_screen.dart';
import 'package:ringdrill/views/feedback.dart';
import 'package:ringdrill/views/install_link_handler.dart';
import 'package:ringdrill/views/open_file_widget.dart';
import 'package:ringdrill/views/page_widget.dart';
import 'package:ringdrill/views/plan_status_badge.dart';
import 'package:ringdrill/views/program_view.dart';
import 'package:ringdrill/views/roleplays_view.dart';
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
import 'package:ringdrill/web/platform_widget.dart'
    if (dart.library.io) 'package:ringdrill/views/platform_widget.dart';
import 'package:ringdrill/web/settings_page.dart'
    if (dart.library.io) 'package:ringdrill/views/settings_page.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_io/io.dart';

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
        return routeProgram;
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
              location: routeProgram,
            );
          }
        });
        // OpenFileWidget requires a
        // ProgramPageController instance
        // to exist in widget tree. Always
        // redirect to programs page!
        return routeProgram;
      }
      return null;
    },
    routes: [
      GoRoute(path: '/i/:slug', redirect: (_, _) => routeProgram),
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
              routes: [
                routeProgram,
                routeMap,
                routeStations,
                routeRolePlays,
                routeTeams,
              ],
              // The shell's nested Navigator (identified by
              // [shellNavigatorKey]). MainScreen mounts it offstage so the
              // GlobalKey gets attached — see the comment on
              // [shellNavigatorKey] above for why this matters on Android.
              shellChild: child,
            ),
          );
        },
        routes: [
          GoRoute(path: '/', redirect: (_, _) => routeProgram),
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
                path: ':exerciseId',
                parentNavigatorKey: key,
                builder: (BuildContext context, GoRouterState state) =>
                    _ContextSheetDeepLinkLauncher(
                      target: ExerciseSheetTarget(
                        exerciseUuid: state.pathParameters['exerciseId']!,
                      ),
                      fallbackRoute: routeProgram,
                    ),
                routes: [
                  GoRoute(
                    path: 'station/:stationIndex',
                    parentNavigatorKey: key,
                    builder: (BuildContext context, GoRouterState state) =>
                        _ContextSheetDeepLinkLauncher(
                          target: StationSheetTarget(
                            exerciseUuid: state.pathParameters['exerciseId']!,
                            stationIndex: int.parse(
                              state.pathParameters['stationIndex']!,
                            ),
                          ),
                          fallbackRoute: routeProgram,
                        ),
                  ),
                  GoRoute(
                    path: 'team/:teamIndex',
                    parentNavigatorKey: key,
                    builder: (BuildContext context, GoRouterState state) {
                      final uuid = state.pathParameters['exerciseId']!;
                      final teamIndex = int.parse(
                        state.pathParameters['teamIndex']!,
                      );
                      final exercise = ProgramService().getExercise(uuid);
                      if (exercise == null) {
                        return Scaffold(
                          appBar: AppBar(),
                          body: const Center(child: Text('Not found')),
                        );
                      }
                      return _ContextSheetDeepLinkLauncher(
                        target: TeamSheetTarget(
                          exerciseUuid: exercise.uuid,
                          teamIndex: teamIndex,
                        ),
                        fallbackRoute: routeProgram,
                      );
                    },
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
                  final exercise = ProgramService()
                      .loadExercises()
                      .where((e) => e.numberOfTeams > teamIndex)
                      .firstOrNull;
                  if (exercise == null) {
                    return const SizedBox.shrink();
                  }
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

class _MainScreenState extends State<MainScreen> {
  static final GlobalKey _indexedTabsKey = GlobalKey();
  static final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();

  final List<StreamSubscription> _subscriptions = [];

  // Held as a field so the page and the view can share the same
  // instance. Passing it through PageWidget's InheritedWidget only
  // works when the static type argument matches exactly, and that
  // gets erased to ScreenController by the List<PageWidget> context.
  // A direct constructor handoff sidesteps the inference issue.
  late final StationListController _stationListController =
      StationListController();

  late final RolePlaysController _rolePlaysController = RolePlaysController();
  late final ContextSheetController _contextSheetController =
      ContextSheetController();

  /// Order matches [routeProgram, routeMap, routeStations, routeRolePlays, routeTeams].
  /// Note: Map tab (StationsView) was previously at position 4; it moved to
  /// position 2 when RolePlays was added. See DESIGN-003.
  late final List<PageWidget> _pages = [
    PageWidget(controller: ProgramPageController(), child: ProgramView()),
    PageWidget(controller: StationsPageController(), child: StationsView()),
    PageWidget(
      controller: _stationListController,
      child: StationListView(controller: _stationListController),
    ),
    PageWidget(
      controller: _rolePlaysController,
      child: RolePlaysView(controller: _rolePlaysController),
    ),
    PageWidget(controller: TeamsPageController(), child: TeamsView()),
  ];

  int _currentTab = 0;
  bool _migrationSnackBarChecked = false;

  @override
  void initState() {
    super.initState();
    _initTab();
    if (widget.isFirstLaunch) _showConsentDialog();
    _subscriptions.add(
      NotificationService().events.listen((event) {
        if (event.action == NotificationAction.showSettings) {
          if (mounted) {
            MainScreen.showSettings(context);
          }
        }
      }),
    );
    _subscriptions.add(
      ProgramService().events.listen((event) {
        if (mounted) setState(() {});
      }),
    );
    // Rebuild bottom chrome when an exercise starts or stops so the floating
    // mini-bar appears/disappears without a manual state push. Also show a
    // passive snackbar when the service auto-stops the exercise (endTime or
    // totalTime reached) — the persistent notification handles the
    // "still has to be acknowledged" path.
    _subscriptions.add(
      ExerciseService().events.listen((event) {
        if (!mounted) return;
        setState(() {});
        if (event.isDone && event.autoStopped) {
          _showAutoStoppedSnackBar(event);
        }
      }),
    );
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
    // Match either an exact tab path (/program) or any nested
    // detail path (/program/<exerciseId>/...). This keeps the
    // correct tab selected when a detail screen is on top.
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
    _stationListController.dispose();
    for (var e in _subscriptions) {
      e.cancel();
    }
    super.dispose();
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
        return ContextSheet(
          controller: _contextSheetController,
          child: Scaffold(
            key: _scaffoldKey,
            extendBody: true,
            extendBodyBehindAppBar: true,
            drawerEnableOpenDragGesture: true,
            appBar: windowSizeClass.hasRail
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
            body: Stack(
              fit: StackFit.expand,
              children: [
                windowSizeClass.hasRail
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
            ),
            floatingActionButton: windowSizeClass.hasRail
                ? null
                : page.controller.buildFAB(context, constraints),
            bottomNavigationBar: _buildBottomChrome(
              context,
              localizations,
              windowSizeClass,
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
    final isCupertino = Theme.of(context).platform == TargetPlatform.iOS;
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: _removePadding(
        context: context,
        paddingLeft: 0,
        child: AppBar(
          title: _buildAppBarTitle(context, page),
          leadingWidth: hasRail ? 84 : null,
          leading: hasRail
              ? Padding(
                  padding: EdgeInsets.only(left: isCupertino ? 32.0 : 20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.menu),
                        onPressed: () {
                          _scaffoldKey.currentState?.openDrawer();
                        },
                      ),
                    ],
                  ),
                )
              : null,
          actions: [
            const PlanStatusBadge(),
            ...?page.controller.buildActions(context, constraints),
          ],
          actionsPadding: EdgeInsets.only(right: 16.0),
        ),
      ),
    );
  }

  Widget _buildAppBarTitle(
    BuildContext context,
    PageWidget<ScreenController> page,
  ) {
    final title = Text(page.controller.title(context));
    final controller = page.controller;
    if (controller is! ProgramPageControllerBase) return title;
    final localizations = AppLocalizations.of(context)!;
    return Tooltip(
      message: localizations.libraryRename,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () => active_actions.renameActivePlan(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: title,
        ),
      ),
    );
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
          color: Theme.of(context).appBarTheme.backgroundColor,
          padding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 16.0),
          child: Row(
            children: [
              Text(
                localizations.appName,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18.0, // Smaller font size than DrawerHeader
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
    widget.router.go(widget.routes[tab]);
    // The StationsView is kept alive inside the IndexedStack, so its map
    // does not re-fit on tab switch on its own. Nudge it via the reselect
    // tick whenever the Map tab is (re)activated.
    if (widget.routes[tab] == routeMap) {
      stationsTabReselectTick.value = stationsTabReselectTick.value + 1;
    }
  }

  List<Destination> _buildDestinations(AppLocalizations localizations) {
    return [
      Destination(icon: Icons.update, label: localizations.exercise(2)),
      Destination(icon: Icons.map, label: localizations.mapTab),
      Destination(icon: Icons.place, label: localizations.stationsTab),
      Destination(
        icon: Icons.theater_comedy,
        label: localizations.rolePlaysTab,
      ),
      Destination(icon: Icons.group, label: localizations.team(2)),
    ];
  }

  Widget? _buildBottomChrome(
    BuildContext context,
    AppLocalizations localizations,
    WindowSizeClass windowSizeClass,
  ) {
    if (windowSizeClass.hasRail) {
      return _buildNavBar(localizations, windowSizeClass);
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
        _buildNavBar(localizations, windowSizeClass)!,
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

  Widget? _buildNavBar(
    AppLocalizations localizations,
    WindowSizeClass windowSizeClass,
  ) {
    if (windowSizeClass.hasRail) return null;
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
        color: Theme.of(context).colorScheme.surface, // rail bg
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
    final rail = _removePadding(
      context: context,
      child: NavigationRail(
        selectedIndex: _currentTab,
        onDestinationSelected: _onDestinationSelected,
        destinations: _buildDestinations(localizations)
            .map<NavigationRailDestination>((d) {
              return NavigationRailDestination(
                icon: Icon(d.icon),
                label: Text(d.label),
                padding: EdgeInsets.symmetric(vertical: 8),
              );
            })
            .toList(),
        trailing: fab != null
            ? Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [fab, SizedBox(height: 16)],
                ),
              )
            : SizedBox(height: 16),
      ),
    );

    final masterWidth = windowSizeClass == WindowSizeClass.expanded
        ? 360.0
        : 280.0;
    const railWidth = 72.0;
    final detailWidth = constraints.maxWidth - railWidth - masterWidth;
    if (_currentTab == 1) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          rail,
          Expanded(child: _buildIndexedTabs()),
        ],
      );
    }
    if (detailWidth < 360) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildAppBar(context, constraints, page, hasRail: true),
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                rail,
                Expanded(child: _buildIndexedTabs()),
              ],
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        rail,
        Expanded(
          child: MasterDetailScope(
            target: _contextSheetController.targetNotifier,
            emptyPaneBuilder: _emptyPaneBuilderForCurrentTab,
            child: Row(
              children: [
                SizedBox(
                  width: masterWidth,
                  child: Column(
                    children: [
                      _buildAppBar(context, constraints, page, hasRail: true),
                      Expanded(child: _buildIndexedTabs()),
                      if (ExerciseService().isStarted)
                        SafeArea(
                          top: false,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                            child: DrillMiniPlayer(
                              onOpen: () => _openDrillPlayer(context),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const Expanded(child: MasterDetailPane()),
              ],
            ),
          ),
        ),
      ],
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
      0 => const ExerciseDetailEmpty(),
      2 => const StationDetailEmpty(),
      3 => const RolePlayDetailEmpty(),
      4 => const TeamDetailEmpty(),
      _ => const SizedBox.shrink(),
    };
  }

  void _showConsentDialog() {
    Future.microtask(() async {
      if (mounted) {
        final localizations = AppLocalizations.of(context)!;
        // Show a dialog asking the user to provide consent
        final consent =
            await showDialog(
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
