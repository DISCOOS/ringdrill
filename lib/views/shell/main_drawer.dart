import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/services/auth_service.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/theme.dart';
import 'package:ringdrill/views/about_page.dart';
import 'package:ringdrill/views/account_page.dart';
import 'package:ringdrill/views/active_plan_actions.dart' as active_actions;
import 'package:ringdrill/views/feedback.dart';
import 'package:ringdrill/views/migration_page.dart';
import 'package:ringdrill/views/plan_view.dart';
import 'package:ringdrill/views/shell/open_form_surface.dart';
import 'package:ringdrill/views/sign_in_page.dart';
import 'package:ringdrill/views/widgets/account_switcher.dart';
import 'package:ringdrill/views/widgets/app_user_role_selector.dart';
import 'package:ringdrill/web/install_actions.dart'
    if (dart.library.io) 'package:ringdrill/views/install_actions_io.dart';
import 'package:ringdrill/web/legacy_host_web.dart'
    if (dart.library.io) 'package:ringdrill/web/legacy_host_stub.dart';

/// Navigation drawer for the app shell. Owns its own tile list and all
/// "active plan" actions; the host shell only mounts it as
/// `Scaffold.drawer`. State queries (active plan, exercise service)
/// go through singletons, so the only thing the host has to wire is the
/// "open settings" action — kept as a callback so this widget doesn't
/// import its host.
class MainDrawer extends StatelessWidget {
  const MainDrawer({
    super.key,
    required this.localizations,
    required this.onOpenSettings,
  });

  final AppLocalizations localizations;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final activePlan = PlanService().activePlan;
    final hasActivePlan = activePlan != null;
    final isCatalogActive =
        activePlan != null && active_actions.isCatalogPlan(activePlan);
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
              const Spacer(),
              // The role lives in the header rather than among the tiles below:
              // it is "who am I", not another action, and it now decides what
              // this device may edit (ADR-0057) — so it belongs where it is
              // visible whenever the drawer is open. Explicit white, because the
              // header paints a fixed brand tone rather than a themed surface.
              const AppUserRoleButton(foregroundColor: Colors.white),
            ],
          ),
        ),
        const SizedBox(height: 16.0),
        _DrawerTile(
          icon: Icons.folder_open,
          title: localizations.openPlanAction,
          onTap: () async {
            // Popping the drawer unmounts this tile's BuildContext. The plan
            // actions await user input (dialogs, file pickers) and then check
            // `context.mounted`, so handing them the dead drawer context made
            // them abort silently. Capture the root navigator's context, which
            // outlives the drawer, and pass that instead.
            final actionContext = Navigator.of(
              context,
              rootNavigator: true,
            ).context;
            Navigator.pop(context);
            await active_actions.openPlan(actionContext);
          },
        ),
        _DrawerTile(
          icon: Icons.add_circle_outline,
          title: localizations.newPlanAction,
          enabled: hasActivePlan,
          disabledTooltip: localizations.requiresActivePlan,
          onTap: () async {
            final actionContext = Navigator.of(
              context,
              rootNavigator: true,
            ).context;
            Navigator.pop(context);
            await active_actions.createNewPlan(actionContext);
          },
        ),
        if (PlanPageController.canSaveDrillFile)
          _DrawerTile(
            icon: Icons.download,
            title: localizations.libraryDownloadAction,
            enabled: hasActivePlan,
            disabledTooltip: localizations.requiresActivePlan,
            onTap: () async {
              final actionContext = Navigator.of(
                context,
                rootNavigator: true,
              ).context;
              Navigator.pop(context);
              await active_actions.downloadActivePlan(actionContext);
            },
          ),
        _DrawerTile(
          icon: Icons.playlist_add,
          title: localizations.addExercisesAction,
          enabled: hasActivePlan,
          disabledTooltip: localizations.requiresActivePlan,
          onTap: () async {
            final actionContext = Navigator.of(
              context,
              rootNavigator: true,
            ).context;
            Navigator.pop(context);
            await active_actions.addExercises(actionContext);
          },
        ),
        const Divider(),
        _DrawerTile(
          icon: Icons.link,
          title: localizations.shareActivePlan,
          enabled: isCatalogActive,
          disabledTooltip: hasActivePlan
              ? localizations.planStatusLocalTooltip
              : localizations.requiresActivePlan,
          onTap: () async {
            final actionContext = Navigator.of(
              context,
              rootNavigator: true,
            ).context;
            Navigator.pop(context);
            await active_actions.shareActivePlan(actionContext);
          },
        ),
        if (PlanPageController.canSendDrillFile)
          _DrawerTile(
            icon: Icons.send,
            title: localizations.sendToAction,
            enabled: hasActivePlan,
            disabledTooltip: localizations.requiresActivePlan,
            onTap: () async {
              final actionContext = Navigator.of(
                context,
                rootNavigator: true,
              ).context;
              Navigator.pop(context);
              await active_actions.sendActivePlanTo(actionContext);
            },
          ),
        _DrawerTile(
          icon: Icons.cloud_upload_outlined,
          title: localizations.publishActivePlan,
          enabled: hasActivePlan,
          disabledTooltip: localizations.requiresActivePlan,
          onTap: () async {
            final actionContext = Navigator.of(
              context,
              rootNavigator: true,
            ).context;
            Navigator.pop(context);
            await active_actions.publishActivePlan(actionContext);
          },
        ),
        _DrawerTile(
          icon: Icons.cloud_sync_outlined,
          title: localizations.publishAsActivePlan,
          enabled: hasActivePlan,
          disabledTooltip: localizations.requiresActivePlan,
          onTap: () async {
            final actionContext = Navigator.of(
              context,
              rootNavigator: true,
            ).context;
            Navigator.pop(context);
            await active_actions.publishAsActivePlan(actionContext);
          },
        ),
        _DrawerTile(
          icon: Icons.refresh,
          title: localizations.libraryRefresh,
          enabled: isCatalogActive,
          disabledTooltip: hasActivePlan
              ? localizations.planStatusLocalTooltip
              : localizations.requiresActivePlan,
          onTap: () async {
            final actionContext = Navigator.of(
              context,
              rootNavigator: true,
            ).context;
            Navigator.pop(context);
            await active_actions.refreshActivePlanFromCatalogViaIndicator(
              actionContext,
            );
          },
        ),
        const Divider(),
        if (canShowInstallEntry)
          _DrawerTile(
            icon: Icons.install_mobile,
            title: localizations.installGuideEntry,
            onTap: () {
              Navigator.pop(context);
              openInstallGuide(context);
            },
          ),
        if (isLegacyHost())
          _DrawerTile(
            icon: Icons.swap_horiz,
            title: localizations.migrationSettingsEntry,
            onTap: () {
              Navigator.pop(context);
              // Same surface treatment as About: modal dialog on wide,
              // full-page push on narrow. Direct URL visits to `/migrate`
              // continue to resolve as a full page via app_router.dart,
              // so shareable links remain intact.
              openFormSurface<void>(
                context,
                builder: (_) => const MigrationPage(),
              );
            },
          ),
        // Close the install/migrate action group with a divider (only when
        // at least one of the two entries is present).
        if (canShowInstallEntry || isLegacyHost()) const Divider(),
        // Sign in / sign out. Plain, and never decorated: DESIGN-015 §5.1
        // rules out a badge or a "complete your setup" nudge, because no
        // account is the normal state of an install rather than a step on the
        // way to a real one.
        if (AuthService.isInstalled)
          ListenableBuilder(
            listenable: AuthService.instance,
            builder: (context, _) {
              final user = AuthService.instance.state.user;
              if (user == null) {
                // **Absent, not disabled, under AUTH_MODE=off** (ADR-0073).
                // The rollback switch makes every auth route answer 503, so
                // this entry leads nowhere — and a greyed-out row invites the
                // question "why can I not sign in?", which is a support
                // conversation about a server setting nobody can see.
                return ValueListenableBuilder<bool>(
                  valueListenable: AuthService.instance.authAvailability,
                  builder: (context, available, _) => available
                      ? _DrawerTile(
                          icon: Icons.login,
                          title: localizations.signInEntry,
                          onTap: () {
                            Navigator.pop(context);
                            openFormSurface<void>(
                              context,
                              builder: (_) => const SignInPage(),
                            );
                          },
                        )
                      : const SizedBox.shrink(),
                );
              }
              final account = AuthService.instance.state.activeAccount;
              // **The identity, then the account it acts in.** Both lines are
              // clamped: a drawer is narrow, and an email address is long
              // enough that an unclamped title wraps to three lines and breaks
              // mid-word.
              //
              // The subtitle used to be the account's name unconditionally,
              // which read as a stutter for most people: a personal account is
              // created with the user's own display name, and that display name
              // is the email address when the provider gave no better one. So
              // the row said the same address twice.
              //
              // It now always says the thing the name cannot: "Personal
              // account", or the organisation's handle. See [accountSubtitle]
              // for why the handle is the useful line for an organisation. A
              // conditional fallback was not enough — two organisations whose
              // display names read alike left this row unable to say which one
              // a publish would land in, which is the only question it is here
              // to answer.
              final subtitle = account == null
                  ? localizations.accountTitle
                  : accountSubtitle(localizations, account);
              return ListTile(
                leading: const Icon(Icons.account_circle),
                // Two lines, not one: an email address is the display name
                // whenever the provider gave no better one, and clamping it to
                // a single line elides before the `@` — "kenneth.gulbrands…"
                // does not tell you which identity you are signed in as. Two
                // lines fit a normal address whole and still cannot run away.
                title: Text(
                  user.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // Tapping opens the account; signing out is the trailing
                // action rather than the whole row's job. Making the row
                // itself sign out would put a destructive-feeling action
                // where people expect navigation.
                onTap: account == null
                    ? null
                    : () {
                        Navigator.pop(context);
                        openFormSurface<void>(
                          context,
                          builder: (_) => AccountPage(account: account),
                        );
                      },
                trailing: IconButton(
                  icon: const Icon(Icons.logout),
                  tooltip: localizations.signOutAction,
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    if (await confirmSignOut(context)) {
                      await AuthService.instance.signOut();
                    }
                    navigator.maybePop();
                  },
                ),
              );
            },
          ),
        // **A row of its own, and only when there is a choice.** Switching
        // account changes where a publish lands and whose plans the library
        // lists, so it is a navigation-weight decision rather than a detail on
        // somebody's name. Crowding it into the account row as a second
        // trailing icon would put it beside sign-out, where a mis-tap is
        // expensive.
        if (AuthService.isInstalled)
          ListenableBuilder(
            listenable: AuthService.instance,
            builder: (context, _) {
              if (AuthService.instance.state.accounts.length < 2) {
                return const SizedBox.shrink();
              }
              return _DrawerTile(
                icon: Icons.swap_horiz,
                title: localizations.accountSwitchTitle,
                onTap: () async {
                  // The drawer stays open: switching is often followed by
                  // going somewhere with the new account, and closing it would
                  // make that two gestures.
                  await showAccountSwitcher(context);
                },
              );
            },
          ),
        _DrawerTile(
          icon: Icons.settings,
          title: localizations.settings,
          onTap: onOpenSettings,
        ),
        _DrawerTile(
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
        _DrawerTile(
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
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.enabled = true,
    this.disabledTooltip,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool enabled;
  final String? disabledTooltip;

  @override
  Widget build(BuildContext context) {
    final tile = ListTile(
      leading: Icon(icon),
      title: Text(title),
      enabled: enabled,
      onTap: enabled ? onTap : null,
    );
    if (enabled || disabledTooltip == null) return tile;
    return Tooltip(message: disabledTooltip, child: tile);
  }
}
