import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/theme.dart';
import 'package:ringdrill/views/about_page.dart';
import 'package:ringdrill/views/active_plan_actions.dart' as active_actions;
import 'package:ringdrill/views/feedback.dart';
import 'package:ringdrill/views/program_view.dart';
import 'package:ringdrill/views/shell/open_form_surface.dart';

/// Navigation drawer for the app shell. Owns its own tile list and all
/// "active plan" actions; the host shell only mounts it as
/// `Scaffold.drawer`. State queries (active program, exercise service)
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
        _DrawerTile(
          icon: Icons.folder_open,
          title: localizations.openPlan,
          onTap: () async {
            Navigator.pop(context);
            await active_actions.openPlan(context);
          },
        ),
        _DrawerTile(
          icon: Icons.add_circle_outline,
          title: localizations.newPlanAction,
          enabled: hasActivePlan,
          disabledTooltip: localizations.requiresActivePlan,
          onTap: () async {
            Navigator.pop(context);
            await active_actions.createNewPlan(context);
          },
        ),
        _DrawerTile(
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
        _DrawerTile(
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
          _DrawerTile(
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
          _DrawerTile(
            icon: Icons.download,
            title: localizations.exportAsDrill,
            enabled: hasActivePlan,
            disabledTooltip: localizations.requiresActivePlan,
            onTap: () async {
              Navigator.pop(context);
              await active_actions.exportActivePlan(context);
            },
          ),
        _DrawerTile(
          icon: Icons.cloud_upload_outlined,
          title: localizations.publishActivePlan,
          enabled: hasActivePlan,
          disabledTooltip: localizations.requiresActivePlan,
          onTap: () async {
            Navigator.pop(context);
            await active_actions.publishActivePlan(context);
          },
        ),
        _DrawerTile(
          icon: Icons.cloud_sync_outlined,
          title: localizations.publishAsActivePlan,
          enabled: hasActivePlan,
          disabledTooltip: localizations.requiresActivePlan,
          onTap: () async {
            Navigator.pop(context);
            await active_actions.publishAsActivePlan(context);
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
            Navigator.pop(context);
            await active_actions.refreshActivePlanFromCatalog(context);
          },
        ),
        _DrawerTile(
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
