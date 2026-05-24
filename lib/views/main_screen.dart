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
import 'package:ringdrill/views/station_list_view.dart';
import 'package:ringdrill/views/station_screen.dart';
import 'package:ringdrill/views/stations_view.dart';
import 'package:ringdrill/views/team_exercise_screen.dart';
import 'package:ringdrill/views/team_screen.dart';
import 'package:ringdrill/views/teams_view.dart';
import 'package:ringdrill/web/platform_widget.dart'
    if (dart.library.io) 'package:ringdrill/views/platform_widget.dart';
import 'package:ringdrill/web/settings_page.dart'
    if (dart.library.io) 'package:ringdrill/views/settings_page.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_io/io.dart';

GoRouter buildRouter(bool isFirstLaunch) {
  final key = GlobalKey<NavigatorState>();
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
      ShellRoute(
        builder: (BuildContext context, GoRouterState state, Widget child) {
          return PlatformWidget(
            child: MainScreen(
              navigatorKey: key,
              isFirstLaunch: isFirstLaunch,
              router: GoRouter.of(context),
              location: state.matchedLocation,
              routes: [routeProgram, routeMap, routeStations, routeRolePlays, routeTeams],
            ),
          );
        },
        routes: [
          GoRoute(path: '/', redirect: (_, _) => routeProgram),
          GoRoute(
            path: routeProgram,
            builder: (BuildContext context, GoRouterState state) => PageWidget(
              controller: ProgramPageController(),
              child: const ProgramView(),
            ),
            routes: [
              GoRoute(
                path: ':exerciseId',
                parentNavigatorKey: key,
                builder: (BuildContext context, GoRouterState state) =>
                    CoordinatorScreen(
                      uuid: state.pathParameters['exerciseId']!,
                    ),
                routes: [
                  GoRoute(
                    path: 'station/:stationIndex',
                    parentNavigatorKey: key,
                    builder: (BuildContext context, GoRouterState state) =>
                        StationExerciseScreen(
                          uuid: state.pathParameters['exerciseId']!,
                          stationIndex: int.parse(
                            state.pathParameters['stationIndex']!,
                          ),
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
                      return TeamExerciseScreen(
                        teamIndex: teamIndex,
                        exercise: exercise,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: routeMap,
            builder: (BuildContext context, GoRouterState state) =>
                const PageWidget(
                  controller: StationsPageController(),
                  child: StationsView(),
                ),
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
                    StationExerciseScreen(
                      uuid: state.pathParameters['exerciseId']!,
                      stationIndex: int.parse(
                        state.pathParameters['stationIndex']!,
                      ),
                    ),
              ),
            ],
          ),
          GoRoute(
            path: routeTeams,
            builder: (BuildContext context, GoRouterState state) =>
                const PageWidget(
                  controller: TeamsPageController(),
                  child: TeamsView(),
                ),
            routes: [
              GoRoute(
                path: ':teamIndex',
                parentNavigatorKey: key,
                builder: (BuildContext context, GoRouterState state) =>
                    TeamScreen(
                      teamIndex: int.parse(state.pathParameters['teamIndex']!),
                    ),
              ),
            ],
          ),
          GoRoute(
            path: routeRolePlays,
            // ShellRoute's child is ignored by MainScreen (IndexedStack).
            // Stub builder avoids constructing an extra RolePlaysController.
            builder: (BuildContext context, GoRouterState state) =>
                const SizedBox.shrink(),
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
  showModalBottomSheet(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true, // Allows the bottom sheet to resize properly
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
    ),
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
  });

  final GoRouter router;
  final String location;
  final bool isFirstLaunch;
  final List<String> routes;
  final GlobalKey<NavigatorState> navigatorKey;

  static void showSettings(BuildContext context, [bool pop = false]) {
    if (pop) Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsPage()),
    );
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
  bool _wideScreen = false;
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

    final double width = MediaQuery.sizeOf(context).width;
    _wideScreen = width > 600;
    _showMigrationSnackBarOnce();
  }

  @override
  void dispose() {
    super.dispose();
    _stationListController.dispose();
    for (var e in _subscriptions) {
      e.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final page = _pages[_currentTab];
    return LayoutBuilder(
      builder: (context, constraints) {
        return Scaffold(
          key: _scaffoldKey,
          extendBody: true,
          extendBodyBehindAppBar: true,
          drawerEnableOpenDragGesture: true,
          appBar: _wideScreen ? null : _buildAppBar(context, constraints, page),
          drawer: _buildDrawer(context, localizations),
          body: _wideScreen
              ? _buildNavRail(context, constraints, localizations, page)
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
          floatingActionButton: _wideScreen
              ? null
              : page.controller.buildFAB(context, constraints),
          bottomNavigationBar: _buildNavBar(localizations),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    BoxConstraints constraints,
    PageWidget<ScreenController> page,
  ) {
    final isCupertino = Theme.of(context).platform == TargetPlatform.iOS;
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: _removePadding(
        context: context,
        paddingLeft: 0,
        child: AppBar(
          title: _buildAppBarTitle(context, page),
          leadingWidth: _wideScreen ? 84 : null,
          leading: _wideScreen
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
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AboutPage()),
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

  Widget? _buildNavBar(AppLocalizations localizations) {
    if (_wideScreen) return null;
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildAppBar(context, constraints, page),
        Expanded(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              rail,
              Expanded(
                child:
                    // Keep all tabs in memory allowing
                    // state to persist between tab switches
                    IndexedStack(
                      key: _indexedTabsKey,
                      index: _currentTab,
                      children: _pages,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
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
