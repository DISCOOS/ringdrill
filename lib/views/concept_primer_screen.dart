import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ringdrill/data/drill_file.dart';
import 'package:ringdrill/services/program_service.dart';
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

  Future<void> _openExample(BuildContext context) async {
    try {
      final langCode = Intl.getCurrentLocale().split('_').first;
      final locale = langCode == 'nb' ? 'nb' : 'en';
      final assetName = 'onboarding-example.$locale.drill';
      final assetPath = 'assets/example/$assetName';

      final data = await rootBundle.load(assetPath);
      final file = DrillFile.fromBytes(assetName, data.buffer.asUint8List());
      await ProgramService().installFromFile(file, activate: true);
    } catch (e, st) {
      // Degraded silently — a first-run user should never see a crash.
      // ignore: avoid_print
      debugPrint('onboarding: example install failed, falling back. $e\n$st');
    }
    if (!context.mounted) return;
    await _dismiss(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ConceptPrimerContent(
          onSkip: () => _dismiss(context),
          onStartEmpty: () => _dismiss(context),
          onOpenExample: () => _openExample(context),
        ),
      ),
    );
  }
}
