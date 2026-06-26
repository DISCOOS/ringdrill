import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ringdrill/data/drill_file.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/services/notification_service.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/utils/app_config.dart';
import 'package:ringdrill/utils/sentry_config.dart';
import 'package:ringdrill/views/app_routes.dart';
import 'package:ringdrill/views/widgets/onboarding/analytics_consent_stage.dart';
import 'package:ringdrill/views/widgets/onboarding/notification_consent_stage.dart';
import 'package:ringdrill/views/widgets/onboarding/start_stage.dart';
import 'package:ringdrill/views/widgets/onboarding/welcome_stage.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Hosts the first-launch onboarding as a forward-only `PageView`.
///
/// Mounts a four-stage flow on first launch (welcome → analytics
/// consent → notification consent → start) and a two-stage flow when
/// consent has already been captured (welcome → start). Stages are
/// pushed onto the page controller in order; the user advances by
/// tapping a footer button on each stage. There is no swipe-back,
/// no system-back, and no global Skip — every choice on every stage
/// is an active tap. See [ADR-0038].
///
/// Persistence and side-effects live here, not in the stage widgets:
/// * Analytics consent writes [AppConfig.keyAnalyticsConsent] and,
///   on opt-in, calls `SentryFlutter.init` so this same boot starts
///   capturing.
/// * Notification consent writes
///   [AppConfig.keyNotificationConsentAsked] and, on opt-in,
///   re-runs `NotificationService.initFromPrefs` with
///   `requestPermissions: true` — that re-init is what triggers the
///   iOS/Android system dialog.
/// * The final stage writes [AppConfig.keyOnboardingSeen] and
///   navigates to [routeProgram], optionally installing the bundled
///   example plan first.
class ConceptPrimerScreen extends StatefulWidget {
  const ConceptPrimerScreen({super.key, this.isFirstLaunch = false});

  /// Boot-time value forwarded from `main.dart`. When `true`, the
  /// consent stages are inserted between welcome and start; when
  /// `false`, only welcome and start are shown — typically because
  /// the user has already been through onboarding on this device.
  final bool isFirstLaunch;

  @override
  State<ConceptPrimerScreen> createState() => _ConceptPrimerScreenState();
}

class _ConceptPrimerScreenState extends State<ConceptPrimerScreen> {
  final PageController _controller = PageController();
  late final int _total;

  @override
  void initState() {
    super.initState();
    _total = widget.isFirstLaunch ? 4 : 2;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _advance() {
    if (!_controller.hasClients) return;
    _controller.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _onAnalytics(bool consented) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConfig.keyAnalyticsConsent, consented);
    if (consented) {
      // Initialise Sentry inline so events that fire later in the
      // boot (notification permission flow, first program load) are
      // captured with the same release/commit tags as everything
      // else from this boot session.
      await SentryFlutter.init(SentryConfig.apply);
    }
    if (!mounted) return;
    _advance();
  }

  Future<void> _onNotifications(bool consented) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConfig.keyNotificationConsentAsked, true);
    if (consented) {
      // Re-run init with the permission request enabled. This is
      // the call that fires the OS system dialog — deliberately
      // gated behind the user's in-app Allow tap so iOS does not
      // record a permanent denial that only the OS Settings app
      // can reverse (see ADR-0038).
      await NotificationService().initFromPrefs(prefs);
    }
    if (!mounted) return;
    _advance();
  }

  Future<void> _dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConfig.keyOnboardingSeen, true);
    if (!mounted) return;
    // Guarantee an active plan exists before the user lands on
    // `/program`. The Open-example path has already activated the
    // installed plan via `installFromFile(activate: true)`, so
    // `ensureActiveProgram` is a no-op there. For the Start-empty
    // path it creates the default plan up-front, so downstream
    // surfaces (AppBar header, overview, form actions) never have
    // to defend against a null `activeProgram`.
    final l10n = AppLocalizations.of(context)!;
    await ProgramService().ensureActiveProgram(l10n);
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
    // Stage order is assembled per build so the indices passed to
    // each stage match the [PageView]'s actual page count. With
    // `isFirstLaunch == false`, consent stages are dropped entirely
    // and indices shift down by two.
    final stages = <Widget>[];
    var idx = 0;

    stages.add(
      WelcomeStage(
        stageIndex: idx++,
        totalStages: _total,
        onNext: _advance,
      ),
    );

    if (widget.isFirstLaunch) {
      stages.add(
        AnalyticsConsentStage(
          stageIndex: idx++,
          totalStages: _total,
          onChoice: _onAnalytics,
        ),
      );
      stages.add(
        NotificationConsentStage(
          stageIndex: idx++,
          totalStages: _total,
          onChoice: _onNotifications,
        ),
      );
    }

    stages.add(
      StartStage(
        stageIndex: idx++,
        totalStages: _total,
        onStartEmpty: _dismiss,
        onOpenExample: _openExample,
      ),
    );

    return Scaffold(
      body: SafeArea(
        child: PageView(
          controller: _controller,
          // Forward-only: never let the user swipe past the current
          // stage. Advancement happens via the stage's footer
          // buttons, which feed the next page through `_advance`.
          physics: const NeverScrollableScrollPhysics(),
          children: stages,
        ),
      ),
    );
  }
}
