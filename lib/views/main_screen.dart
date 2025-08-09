import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/services/notification_service.dart';
import 'package:ringdrill/utils/app_config.dart';
import 'package:ringdrill/utils/sentry_config.dart';
import 'package:ringdrill/views/about_page.dart';
import 'package:ringdrill/views/page_widget.dart';
import 'package:ringdrill/views/program_view.dart';
import 'package:ringdrill/views/settings_page.dart';
import 'package:ringdrill/views/stations_view.dart';
import 'package:ringdrill/views/teams_view.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key, required this.isFirstLaunch});
  final bool isFirstLaunch;

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
  int _currentTab = 0;
  final List<PageWidget> _pages = [
    PageWidget(controller: ProgramPageController(), child: ProgramView()),
    PageWidget(controller: StationsPageController(), child: StationsView()),
    PageWidget(controller: TeamsPageController(), child: TeamsView()),
    //TeamsPage(),
  ];
  final List<StreamSubscription> _subscriptions = [];

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
          appBar: AppBar(
            title: Text(page.controller.title(context)),
            actions: page.controller.buildActions.call(context, constraints),
          ),
          drawer: Drawer(
            child: SafeArea(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  Container(
                    color: Theme.of(context).appBarTheme.backgroundColor,
                    padding: const EdgeInsets.symmetric(
                      vertical: 15.0,
                      horizontal: 16.0,
                    ),
                    child: Row(
                      children: [
                        Text(
                          localizations.appName,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize:
                                20.0, // Smaller font size than DrawerHeader
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
                        MaterialPageRoute(
                          builder: (context) => const AboutPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          body: _pages[_currentTab],
          floatingActionButton: page.controller.buildFAB.call(
            context,
            constraints,
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentTab,
            onTap: _onBottomNavTapped,
            items: [
              BottomNavigationBarItem(
                icon: Icon(Icons.fitness_center),
                label: localizations.exercise(2),
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.location_on),
                label: localizations.station(2),
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.group),
                label: localizations.team(2),
              ),
            ],
          ),
        );
      },
    );
  }

  void _onBottomNavTapped(int tab) {
    setState(() {
      _currentTab = tab;
    });
  }

  void _showConsentDialog() {
    Future.microtask(() async {
      if (mounted) {
        final localizations = AppLocalizations.of(context)!;
        // Show a dialog asking the user to provide consent
        final consent =
            await showDialog(
                  context: context,
                  barrierDismissible:
                      false, // Prevent closing without taking action
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
