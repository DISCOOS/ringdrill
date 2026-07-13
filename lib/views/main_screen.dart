import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/services/catalog_refresh_indicator_registry.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/notification_service.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/theme.dart';
import 'package:ringdrill/utils/app_config.dart';
import 'package:ringdrill/utils/subscription_bag.dart';
import 'package:ringdrill/views/app_routes.dart';
import 'package:ringdrill/views/drill_player/drill_mini_player.dart';
import 'package:ringdrill/views/drill_player/drill_player_coordinator.dart';
import 'package:ringdrill/views/page_widget.dart';
import 'package:ringdrill/views/plan_status_badge.dart';
import 'package:ringdrill/views/program_form_screen.dart';
import 'package:ringdrill/views/program_view.dart';
import 'package:ringdrill/views/roleplays_view.dart';
import 'package:ringdrill/views/roster_view.dart';
import 'package:ringdrill/views/shell/detail_empty_pane.dart';
import 'package:ringdrill/views/shell/legacy_badge.dart';
import 'package:ringdrill/views/shell/main_drawer.dart';
import 'package:ringdrill/views/shell/master_detail_leading.dart';
import 'package:ringdrill/views/shell/migration_banner.dart';
import 'package:ringdrill/views/shell/open_form_surface.dart';
import 'package:ringdrill/views/shell/shell_chrome.dart';
import 'package:ringdrill/views/shell/shell_notifications.dart';
import 'package:ringdrill/views/shell/wide_shell.dart';
import 'package:ringdrill/views/shell/window_size_class.dart';
import 'package:ringdrill/views/station_list_view.dart';
import 'package:ringdrill/views/stations_view.dart';
import 'package:ringdrill/views/teams_view.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';
import 'package:ringdrill/views/widgets/plan_scope.dart';
import 'package:ringdrill/views/widgets/ringdrill_text.dart';
import 'package:ringdrill/views/widgets/sheet_title.dart';
import 'package:ringdrill/web/settings_page.dart'
    if (dart.library.io) 'package:ringdrill/views/settings_page.dart';
import 'package:ringdrill/web/legacy_host_web.dart'
    if (dart.library.io) 'package:ringdrill/web/legacy_host_stub.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({
    super.key,
    required this.router,
    required this.routes,
    required this.location,
    required this.navigatorKey,
    required this.shellChild,
  });

  final GoRouter router;
  final String location;
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

  // Let the drawer's "Oppdater fra katalog" entry reuse whichever tab's
  // pull-to-refresh RefreshIndicator is currently visible instead of running
  // the refresh with no visible progress at all — see
  // CatalogRefreshIndicatorRegistry and _activeRefreshIndicatorKey below.
  final _programRefreshIndicatorKey = GlobalKey<RefreshIndicatorState>();
  final _rosterRefreshIndicatorKey = GlobalKey<RefreshIndicatorState>();

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
        refreshIndicatorKey: _programRefreshIndicatorKey,
      ),
    ),
    PageWidget(controller: StationsPageController(), child: StationsView()),
    PageWidget(
      controller: _rosterController,
      child: RosterView(
        controller: _rosterController,
        refreshIndicatorKey: _rosterRefreshIndicatorKey,
      ),
    ),
  ];

  int _currentTab = 0;
  bool _migrationSnackBarChecked = false;
  final DrillPlayerCoordinator _drillPlayer = DrillPlayerCoordinator();

  // Wide-shell view preference (DESIGN-010 collapsible master pane):
  // whether the master (list) pane is collapsed so the detail pane fills
  // the width. Defaults to expanded until the async load below resolves.
  // Purely a wide-layout concern — the narrow layout never reads this.
  bool _masterCollapsed = false;

  @override
  void initState() {
    super.initState();
    _initTab();
    _loadMasterCollapsed();
    // Registered once — the closure reads `_currentTab` at call time, so
    // there is nothing to re-register when the user switches tabs.
    CatalogRefreshIndicatorRegistry().registerProvider(
      _activeRefreshIndicatorKey,
    );
    _programPageController.activeSegment.addListener(_onProgramSegmentChanged);
    // Switching segments (Øvelser/Poster/Spill/Lag) restores that segment's
    // remembered selection (or null, when it has none/no-longer-valid one) so
    // `build`'s auto-select check (see the `useRail && !isMapTab` branch)
    // falls back to the new segment's first item only when there is nothing
    // to restore, instead of unconditionally discarding the previous pick.
    _programPageController.activeSegment.addListener(
      _onActiveSegmentChangedForSelectionMemory,
    );
    // Remembers every target the wide detail pane ends up showing while on
    // the Program tab — explicit picks and auto-selected-first alike — so
    // the segment-switch restore above has something to read.
    _contextSheetController.targetNotifier.addListener(
      _onDetailTargetChangedForSelectionMemory,
    );
    // Rebuild when reorder mode toggles so the FAB (which is suppressed in
    // reorder mode) appears/disappears without waiting for another rebuild.
    _programPageController.exerciseReorderMode.addListener(
      _onProgramSegmentChanged,
    );
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
        showAutoStoppedSnackBar(context, event);
      }
      _drillPlayer.maybeUpgradeOnExerciseEvent(
        context: context,
        controller: _contextSheetController,
        event: event,
      );
    });
    // Defense-in-depth (ADR-0038): every path that lands on
    // [MainScreen] should have an active plan. The onboarding flow's
    // `_dismiss` does the heavy lifting — both Start-empty and
    // Open-example guarantee `activeProgram != null` before the
    // user arrives here. This post-frame fallback catches the rare
    // edge cases (catalog deep links that activate nothing, plan
    // deletion that bypassed the last-plan guard, a hot restart
    // landing here without going through onboarding) and creates
    // the default plan rather than letting the surface render with
    // a null plan.
    //
    // `ensureActiveProgram` is idempotent: it is a no-op whenever
    // `activeProgramUuid` is already set, so this is cheap.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
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
      // ADR-0032 *Activation contract*: segment selection flows URL → state.
      // The redirect gate promotes bare `/program/:uuid` to the default
      // segment path, so by the time we land here the third segment is the
      // segment slug. Detail paths (e.g. `team/:idx`) have a non-segment slug
      // in that slot; leave [activeSegment] alone so the backdrop keeps the
      // user's last choice.
      final segments = Uri.parse(loc).pathSegments;
      if (segments.length >= 3) {
        final segment = programSegmentFromSlug(segments[2]);
        if (segment != null) {
          _programPageController.activeSegment.value = segment;
        }
      }
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

    maybeShowLibraryMigrationSnackBar(
      context,
      hasChecked: _migrationSnackBarChecked,
      onChecked: () => _migrationSnackBarChecked = true,
      isStillMounted: () => mounted,
    );
  }

  /// The pull-to-refresh key for whichever tab is current, or null on tabs
  /// with no catalog refresh (e.g. Kart/Stations). Read the field at call
  /// time rather than closing over a snapshot, since this same closure stays
  /// registered across every tab switch for the life of [MainScreen].
  GlobalKey<RefreshIndicatorState>? _activeRefreshIndicatorKey() {
    return switch (_currentTab) {
      0 => _programRefreshIndicatorKey,
      2 => _rosterRefreshIndicatorKey,
      _ => null,
    };
  }

  @override
  void dispose() {
    CatalogRefreshIndicatorRegistry().unregisterProvider(
      _activeRefreshIndicatorKey,
    );
    _contextSheetController.targetNotifier.removeListener(
      _onDetailTargetChangedForSelectionMemory,
    );
    _contextSheetController.dispose();
    _programPageController.activeSegment.removeListener(
      _onProgramSegmentChanged,
    );
    _programPageController.activeSegment.removeListener(
      _onActiveSegmentChangedForSelectionMemory,
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

  /// Restores the newly-active segment's remembered selection — or null when
  /// it has none/no-longer-valid one — unless a modal (narrow) sheet is
  /// currently up, which this has nothing to do with. Leaving the shared
  /// target null (rather than clearing it unconditionally) lets `build`'s
  /// auto-select check pick the segment's first item only when there is
  /// nothing to restore, instead of always discarding the previous pick.
  void _onActiveSegmentChangedForSelectionMemory() {
    if (_contextSheetController.isModal) return;
    _contextSheetController.adoptWideSelection(
      _programPageController.rememberedTarget(
        _programPageController.activeSegment.value,
      ),
    );
  }

  /// Remembers whatever the wide detail pane ends up showing while the
  /// Program tab (segments live only there) is active, so a later segment
  /// switch away and back can restore it via
  /// [_onActiveSegmentChangedForSelectionMemory]. Fires for explicit picks
  /// and for auto-selected-first targets alike — re-remembering the latter is
  /// harmless.
  ///
  /// Also the authority for keeping master and detail in sync (design doc:
  /// `design-shell-master-detail-target-sync.md`): a redirect (`show`/
  /// `replace`/`MasterDetailScope.setTarget`) can change the target to a
  /// different entity kind than the active segment — e.g. the Spill viewer's
  /// post-context card opening its Post. In the wide layout, remember the new
  /// target under the segment that actually owns it (`segmentForTarget`)
  /// *before* switching `activeSegment`, so
  /// `_onActiveSegmentChangedForSelectionMemory`'s memory-restore reads back
  /// this same target instead of clobbering it or reverting on the next
  /// rebuild. Narrow layout has no master pane to sync, so a modal sheet only
  /// remembers under whichever segment is already active — the previous,
  /// simpler behavior.
  void _onDetailTargetChangedForSelectionMemory() {
    if (_currentTab != 0) return;
    final target = _contextSheetController.targetNotifier.value;
    if (target == null) return;
    if (_contextSheetController.isModal) {
      _programPageController.rememberSelection(target);
      return;
    }
    final owningSegment = segmentForTarget(target);
    if (owningSegment == null) return;
    _programPageController.rememberSelection(target, segment: owningSegment);
    if (_programPageController.activeSegment.value != owningSegment) {
      _programPageController.activeSegment.value = owningSegment;
    }
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
    return PlanScope(
      variables: ProgramService().activeProgram?.variables ?? const [],
      // The program-scoped route (ADR-0032): the active program is known
      // here, so this is where PlanScope's program facets (DESIGN-010's
      // resolve-context cascade) get their real values instead of null.
      programName: ProgramService().activeProgram?.name,
      programDescription: ProgramService().activeProgram?.description,
      child: LayoutBuilder(
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
          // this via [WideShell]'s `currentTab == 1` branch; mirror it here
          // for the compact layout so the bottom-nav Map tab also goes
          // chrome-free at the top. Every other tab keeps its AppBar.
          final isMapTab = _currentTab == 1;
          // Wide-layout auto-select (collapsible-master-pane proposal): the
          // detail's leading is the sidebar toggle rather than a close-X in
          // this layout, which only makes sense if the detail pane always
          // has something selected. Deferred to a post-frame callback since
          // `build` must not mutate the shared target notifier synchronously
          // (that would notify `MasterDetailPane`'s listener while this
          // ancestor build is still in progress). No-ops once something —
          // auto-selected or explicit — is already selected; the reset on
          // tab switch (`_onDestinationSelected`) and the remembered-or-null
          // restore on segment switch
          // (`_onActiveSegmentChangedForSelectionMemory`) are what let a
          // *new* first item win here instead of this being a no-op forever.
          if (useRail && !isMapTab) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              if (_contextSheetController.targetNotifier.value != null) {
                return;
              }
              final target = page.controller.firstDetailTarget(context);
              if (target != null) {
                _contextSheetController.adoptWideSelection(target);
              }
            });
          }
          final tabsStack = IndexedStack(
            key: _indexedTabsKey,
            index: _currentTab,
            children: _pages,
          );
          final scaffoldBody = Stack(
            fit: StackFit.expand,
            children: [
              useRail
                  ? WideShell(
                      constraints: constraints,
                      page: page,
                      windowSizeClass: windowSizeClass,
                      currentTab: _currentTab,
                      scaffoldKey: _scaffoldKey,
                      destinations: _buildDestinations(localizations),
                      onDestinationSelected: _onDestinationSelected,
                      tabs: tabsStack,
                      emptyPaneBuilder: _emptyPaneBuilderForCurrentTab,
                      masterAppBar: _buildAppBar(
                        context,
                        constraints,
                        page,
                        hasRail: true,
                      ),
                      contextSheetController: _contextSheetController,
                      drillPlayer: _drillPlayer,
                      masterCollapsed: _masterCollapsed,
                      onToggleMaster: _toggleMasterCollapsed,
                    )
                  : SafeArea(
                      child: Column(
                        children: [
                          const MigrationBanner(),
                          // Keep all tabs in memory allowing state to persist
                          // between tab switches.
                          Expanded(child: tabsStack),
                        ],
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
          return Stack(
            children: [
              Positioned.fill(
                child: ContextSheet(
                  controller: _contextSheetController,
                  child: Scaffold(
                    key: _scaffoldKey,
                    extendBody: true,
                    extendBodyBehindAppBar: true,
                    // On the rail (master/detail) layout, forms open as a Dialog
                    // (see openFormSurface) which handles its own keyboard inset.
                    // Letting the background scaffold also resize for that keyboard
                    // squeezes the fixed-height chrome (NavigationRail, program
                    // overview + segment switcher) and produces RenderFlex overflows.
                    // The dialog owns the inset here, so the background must not move.
                    resizeToAvoidBottomInset: !useRail,
                    drawerEnableOpenDragGesture:
                        Theme.of(context).platform != TargetPlatform.iOS,
                    appBar: (useRail || isMapTab)
                        ? null
                        : _buildAppBar(
                            context,
                            constraints,
                            page,
                            hasRail: false,
                          ),
                    drawer: MainDrawer(
                      localizations: localizations,
                      onOpenSettings: () =>
                          MainScreen.showSettings(context, true),
                    ),
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
                ),
              ),
              // Persistent legacy marker (ADR-0042). Mounted above the whole
              // app — like Flutter's debug banner — so the diagonal ribbon
              // sits in the top-right screen corner, clear of the migration
              // banner's controls below. Hidden off legacy apex via its own
              // `isLegacyHost()` gate. The AppBar nudges its actions left in
              // compact so the ribbon does not cover the plan status badge.
              const Positioned(top: 0, right: 0, child: LegacyBadge()),
            ],
          );
        },
      ),
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
    final appBarBackground = hasRail ? shellMasterAccent(context) : null;
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
      // On the compact layout the LegacyBadge ribbon sits in the top-right
      // screen corner (over this AppBar). Nudge the actions left on legacy
      // so the ribbon does not cover the plan status badge. The wide layout
      // is unaffected: its top-right corner is the detail pane, not this
      // (master) AppBar.
      actionsPadding: EdgeInsets.only(
        right: (!hasRail && isLegacyHost()) ? 60.0 : 16.0,
      ),
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
      child: wrapInRailPadding(context: context, paddingLeft: 0, child: appBar),
    );
  }

  Widget _buildAppBarTitle(
    BuildContext context,
    PageWidget<ScreenController> page, {
    required bool hasRail,
  }) {
    final pageTitle = page.controller.title(context);
    // Only the Program tab's title is ever the active plan name itself
    // (other tabs' `title()` is a fixed section label, e.g. "Kart",
    // "Bemanning") — used below to decide which titles need to resolve
    // `{{var.<name>}}` (DESIGN-008 follow-up 11) and which are plain.
    final planName = ProgramService().activeProgram?.name;
    final isPlanNameTitle = pageTitle == planName;
    // In master/detail mode, mirror the detail-screen `SheetTitle` pattern:
    // primary = tab title (e.g. "Markører"), secondary = active plan name.
    // The active plan was previously only visible via the tooltip on the
    // program tab title, which made cross-tab orientation invisible.
    final activePlanName = hasRail ? planName : null;
    // Suppress the secondary line when it would just repeat the primary.
    // The Program tab's title already is the active plan name, so without
    // this it printed the plan name twice. Other tabs (Map, Roster) keep
    // the plan name as orientation because their primary is a section name.
    final secondary = activePlanName == pageTitle ? null : activePlanName;
    // `SheetTitle` already resolves both its lines via `RingDrillText`
    // (DESIGN-008 follow-up 09); the compact title is a bare `Text` and
    // needs the same treatment, but only when it actually is the plan
    // name — a fixed section label never contains a token.
    final Widget titleChild = hasRail
        ? SheetTitle(primary: pageTitle, secondary: secondary)
        : (isPlanNameTitle ? RingDrillText(pageTitle) : Text(pageTitle));

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

  /// Reads the stored master-pane-collapsed preference. The `false`
  /// (expanded) default stays in effect until this resolves, mirroring
  /// `BriefScreen._loadStoredRole`.
  Future<void> _loadMasterCollapsed() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final stored = prefs.getBool(AppConfig.keyMasterPaneCollapsed);
    if (stored == null || stored == _masterCollapsed) return;
    setState(() => _masterCollapsed = stored);
  }

  /// Flips the wide shell's master-pane collapse state and persists it.
  /// Only ever wired up while `useRail` is active (see `build`) — the
  /// narrow layout has no collapse concept to toggle.
  Future<void> _toggleMasterCollapsed() async {
    final next = !_masterCollapsed;
    setState(() => _masterCollapsed = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConfig.keyMasterPaneCollapsed, next);
  }

  void _onDestinationSelected(int tab) {
    setState(() {
      _currentTab = tab;
    });
    _contextSheetController.close();
    // `close()` is a no-op once the target was set outside its own
    // show()/replace() bookkeeping (e.g. the wide-layout auto-select below
    // adopts the target directly) — clear it explicitly too so `build`'s
    // auto-select check picks the new tab's first item rather than leaving
    // the outgoing tab's target in place. Skipped while a narrow modal
    // sheet is still closing; that has its own target lifecycle.
    if (!_contextSheetController.isModal) {
      _contextSheetController.adoptWideSelection(null);
    }
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
      // Tab 0 preserves the currently-selected segment so switching to Map
      // and back lands on the same lens. The redirect gate handles bare
      // `/program/:uuid` as a fallback, so even if the controller has not
      // been initialised yet the URL still resolves.
      0 => programSegmentPath(
        activeUuid,
        _programPageController.activeSegment.value.urlSlug,
      ),
      1 => programMapPath(activeUuid),
      2 => programRosterPath(activeUuid),
      _ => widget.routes[tab],
    };
  }

  List<Destination> _buildDestinations(AppLocalizations localizations) {
    return [
      // The Program tab hosts the active training plan (the inner
      // segments are exercises, stations, markers, teams). Using
      // `exercise(2)` here used to land "Øvelser" both on the bottom
      // nav AND on the inner segment label, which read as the same
      // word at two levels of hierarchy and confused first-time
      // users. `programTab` ("Plan" / "Øvingsplan") describes the
      // tab as a whole.
      Destination(icon: Icons.update, label: localizations.programTab),
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
              child: DrillMiniPlayer(
                onOpen: () => _drillPlayer.openDrillPlayer(context),
              ),
            ),
          ),
        _buildNavBar(localizations, useRail)!,
      ],
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

  Widget _emptyPaneBuilderForCurrentTab(BuildContext context) {
    final content = switch (_currentTab) {
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
    // The wide empty pane carries the same leading as every other detail
    // screen (the sidebar toggle) so the placeholder is not the one place
    // in the detail pane missing it — there is nothing else to "close"
    // here, but a minimal top bar keeps the toggle reachable regardless of
    // whether anything is selected.
    return Column(
      children: [
        SizedBox(
          height: kRingdrillHeaderHeight,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: MasterDetailLeading(onClose: () {}),
          ),
        ),
        Expanded(child: content),
      ],
    );
  }

  /// Passive notice that the auto-stop fired. The persistent
}
