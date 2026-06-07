import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ringdrill/utils/app_config.dart';
import 'package:ringdrill/views/app_routes.dart';
import 'package:ringdrill/views/widgets/concept_primer_content.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Full-screen wrapper for [ConceptPrimerContent], shown once on first launch.
///
/// Writes [AppConfig.keyOnboardingSeen] on any CTA dismissal so the primer
/// does not re-show on subsequent launches. [ConceptPrimerContent] is the
/// reusable body — stage 5 (Help) mounts it directly in a different chrome.
class ConceptPrimerScreen extends StatelessWidget {
  const ConceptPrimerScreen({super.key});

  Future<void> _dismiss(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConfig.keyOnboardingSeen, true);
    if (!context.mounted) return;
    context.go(routeProgram);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ConceptPrimerContent(
          onSkip: () => _dismiss(context),
          onStartEmpty: () => _dismiss(context),
          onOpenExample: () {
            // TODO(DESIGN-007 stage 3): import bundled example plan, then navigate to the active program.
            _dismiss(context);
          },
        ),
      ),
    );
  }
}
