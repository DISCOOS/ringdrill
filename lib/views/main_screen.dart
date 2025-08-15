import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/services/notification_service.dart';
import 'package:ringdrill/utils/app_config.dart';
import 'package:ringdrill/utils/sentry_config.dart';
import 'package:ringdrill/views/about_page.dart';
import 'package:ringdrill/views/page_widget.dart';
import 'package:ringdrill/views/program_view.dart';
import 'package:ringdrill/views/stations_view.dart';
import 'package:ringdrill/views/teams_view.dart';
import 'package:ringdrill/web/platform_widget.dart'
    if (dart.library.io) 'package:ringdrill/views/platform_widget.dart';
import 'package:ringdrill/web/settings_page.dart'
    if (dart.library.io) 'package:ringdrill/views/settings_page.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

GoRouter buildRouter(bool isFirstLaunch) {
  return GoRouter(
    initialLocation: '/program', // The default tab
    routes: [
      ShellRoute(
        builder: (BuildContext context, GoRouterState state, Widget child) {
          return PlatformWidget(
            child: MainScreen(
              isFirstLaunch: isFirstLaunch,
              router: GoRouter.of(context),
              routes: ['/program', '/stations', '/teams'],
            ),
          );
        },
        routes: [
          GoRoute(
            path: '/program',
            builder: (BuildContext context, GoRouterState state) => PageWidget(
              controller: ProgramPageController(),
              child: const ProgramView(),
            ),
          ),
          GoRoute(
            path: '/stations',
            builder: (BuildContext context, GoRouterState state) =>
                const PageWidget(
                  controller: StationsPageController(),
                  child: StationsView(),
                ),
          ),
          GoRoute(
            path: '/teams',
            builder: (BuildContext context, GoRouterState state) =>
                const PageWidget(
                  controller: TeamsPageController(),
                  child: TeamsView(),
                ),
          ),
        ],
      ),
    ],
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
    required this.isFirstLaunch,
  });

  final bool isFirstLaunch;
  final GoRouter router;
  final List<String> routes;

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
  final List<PageWidget> _pages = [
    PageWidget(controller: ProgramPageController(), child: ProgramView()),
    PageWidget(controller: StationsPageController(), child: StationsView()),
    PageWidget(controller: TeamsPageController(), child: TeamsView()),
    //TeamsPage(),
  ];

  int _currentTab = 0;
  bool _wideScreen = false;

  @override
  void initState() {
    super.initState();
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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final double width = MediaQuery.sizeOf(context).width;
    _wideScreen = width > 600;
  }

  @override
  void dispose() {
    super.dispose();
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
          title: Text(page.controller.title(context)),
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
          actions: page.controller.buildActions(context, constraints),
          actionsPadding: EdgeInsets.only(right: 16.0),
        ),
      ),
    );
  }

  Widget? _buildDrawer(BuildContext context, AppLocalizations localizations) {
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
        ListTile(
          leading: const Icon(Icons.settings),
          title: Text(localizations.settings),
          onTap: () {
            MainScreen.showSettings(context, true);
          },
        ),
        ListTile(
          leading: const Icon(Icons.info),
          title: Text(localizations.about),
          onTap: () {
            Navigator.pop(context); // Close the drawer
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AboutPage()),
            );
          },
        ),
      ],
    );
  }

  void _onDestinationSelected(int tab) {
    setState(() {
      _currentTab = tab;
    });
    widget.router.go(widget.routes[tab]);
  }

  List<Destination> _buildDestinations(AppLocalizations localizations) {
    return [
      Destination(icon: Icons.fitness_center, label: localizations.exercise(2)),
      Destination(icon: Icons.location_on, label: localizations.station(2)),
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
}
