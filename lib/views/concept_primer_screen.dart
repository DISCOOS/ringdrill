import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ringdrill/data/drill_file.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/utils/app_config.dart';
import 'package:ringdrill/views/app_routes.dart';
import 'package:ringdrill/views/widgets/analytics_consent_dialog.dart';
import 'package:ringdrill/views/widgets/concept_primer_content.dart';
import 'package:ringdrill/views/widgets/notification_consent_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Full-screen wrapper for [ConceptPrimerContent], shown once on first launch.
///
/// Writes [AppConfig.keyOnboardingSeen] on any CTA dismissal so the primer
/// does not re-show on subsequent launches. [ConceptPrimerContent] is the
/// reusable body — stage 5 (Help) mounts it directly in a different chrome.
///
/// When [isFirstLaunch] is true, the analytics consent dialog is shown
/// as a modal barrier on top of the primer before the user can interact
/// with it. The dialog used to live in `MainScreen.initState`, which
/// meant the user finished the entire welcome flow before being asked
/// — putting it here gates Sentry on/off before any onboarding action
/// reaches the network.
class ConceptPrimerScreen extends StatefulWidget {
  const ConceptPrimerScreen({super.key, this.isFirstLaunch = false});

  final bool isFirstLaunch;

  @override
  State<ConceptPrimerScreen> createState() => _ConceptPrimerScreenState();
}

class _ConceptPrimerScreenState extends State<ConceptPrimerScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.isFirstLaunch) {
      // Microtask so the surrounding Scaffold is built first — both
      // dialogs need an attached `Overlay` to mount into. Analytics
      // consent runs first; notification consent follows so the iOS
      // system prompt fires only after the user has read RingDrill's
      // own rationale (ADR-0038).
      Future.microtask(() async {
        if (!mounted) return;
        await showAnalyticsConsentDialog(context);
        if (!mounted) return;
        await maybeShowNotificationConsentPrompt(context);
      });
    }
  }

  Future<void> _dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConfig.keyOnboardingSeen, true);
    if (!mounted) return;
    context.go(routeProgram);
  }

  Future<void> _openExample() async {
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
    if (!mounted) return;
    await _dismiss();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ConceptPrimerContent(
          onSkip: _dismiss,
          onStartEmpty: _dismiss,
          onOpenExample: _openExample,
        ),
      ),
    );
  }
}
