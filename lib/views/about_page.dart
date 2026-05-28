import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/utils/app_build_info.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:url_launcher/url_launcher.dart';

const String projectUrl = 'https://www.discoos.org/projects/ringdrill';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String appVersion = 'Loading...';
  String buildNumber = 'Loading...';
  String patchNumber = 'Loading...';
  UpdateStatus patchStatus = UpdateStatus.unavailable;
  final updater = ShorebirdUpdater();

  @override
  void initState() {
    super.initState();
    unawaited(_getAppInfo());
  }

  Future<void> _getAppInfo() async {
    // Use package_info_plus to get app version and build number
    final packageInfo = await PackageInfo.fromPlatform();
    // Checks for an available patch on [track] (or [UpdateTrack.stable] if no
    // track is specified) and returns the [UpdateStatus].
    patchStatus = await updater.checkForUpdate();
    Patch? patch;
    try {
      // Returns information about the most recently downloaded patch.
      // Returns the same patch as [readCurrentPatch] if no new patch has been
      // downloaded.
      patch = await updater.readCurrentPatch();
    } on ReadPatchException catch (e, stackTrace) {
      unawaited(Sentry.captureException(e, stackTrace: stackTrace));
    }
    setState(() {
      appVersion = packageInfo.version;
      buildNumber = packageInfo.buildNumber;
      patchNumber = patch?.number.toString() ?? (kDebugMode ? '<debug>' : '0');
    });
  }

  Future<void> update() async {
    // Perform the update
    await updater.update();
    patchStatus = await updater.checkForUpdate();
    final patch = await updater.readCurrentPatch();
    if (mounted) {
      setState(() {
        patchNumber =
            patch?.number.toString() ?? (kDebugMode ? '<debug>' : '0');
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          showCloseIcon: true,
          dismissDirection: DismissDirection.endToStart,
          content: Text(
            AppLocalizations.of(context)!.appUpdatedPleaseCloseAndOpen,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: localizations.cancel,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(localizations.about),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // App Name and Icon
              Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 40,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 16.0),
                  Text(
                    localizations.appName,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16.0),

              // App Purpose or Description
              Text(
                localizations.appDescription,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24.0),

              // App Details Section
              const Divider(),
              ListTile(
                leading: const Icon(Icons.verified_outlined),
                title: Text(localizations.version),
                subtitle: switch (patchStatus) {
                  UpdateStatus.upToDate => Text(
                    '$appVersion (Build $buildNumber, Patch $patchNumber)',
                  ),
                  UpdateStatus.outdated => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$appVersion (Build $buildNumber, Patch $patchNumber)',
                      ),
                      SizedBox(height: 8),
                      Text(localizations.newPatchIsAvailable),
                    ],
                  ),
                  UpdateStatus.restartRequired => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$appVersion (Build $buildNumber, Patch $patchNumber)',
                      ),
                      SizedBox(height: 8),
                      Text(localizations.restartAppToApplyNewPatch),
                    ],
                  ),
                  UpdateStatus.unavailable => Text(
                    '$appVersion (Build $buildNumber)',
                  ),
                },
                trailing: UpdateStatus.outdated == patchStatus
                    ? IconButton(onPressed: update, icon: Icon(Icons.update))
                    : null,
              ),
              // Commit row. Always visible so the user can see which
              // source tree produced the binary; the GitHub link is
              // only wired up when --dart-define=GIT_COMMIT=... was
              // passed at build time. On a bare `flutter run` the
              // subtitle reads `dev` and the row is non-interactive.
              const Divider(),
              ListTile(
                leading: const Icon(Icons.commit),
                title: Text(localizations.commit),
                subtitle: Text(AppBuildInfo.commitShort),
                trailing: AppBuildInfo.hasCommit
                    ? const Icon(Icons.open_in_new, size: 18)
                    : null,
                enabled: AppBuildInfo.hasCommit,
                onTap: AppBuildInfo.hasCommit
                    ? () async {
                        final url = AppBuildInfo.commitUrl;
                        if (url == null) return;
                        if (!await launchUrl(Uri.parse(url))) {
                          Sentry.captureException(
                            Exception('Could not launch $url'),
                          );
                        }
                      }
                    : null,
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(localizations.developedBy),
                subtitle: const Text('DISCO Open Source'), // Your credits here
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.link_outlined),
                title: Text(localizations.website),
                subtitle: const Text(projectUrl), // Your website URL
                onTap: () async {
                  if (!await launchUrl(Uri.parse(projectUrl))) {
                    Sentry.captureException(
                      Exception('Could not launch $projectUrl'),
                    );
                  }
                },
                trailing: const Icon(Icons.open_in_new, size: 18),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.link_outlined),
                title: Text(localizations.privacyPolicy),
                subtitle: const Text(
                  '$projectUrl/privacy/',
                ), // Your website URL
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () async {
                  if (!await launchUrl(Uri.parse('$projectUrl/privacy/'))) {
                    Sentry.captureException(
                      Exception('Could not launch $projectUrl/privacy/'),
                    );
                  }
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.link_outlined),
                title: Text(localizations.termsOfService),
                subtitle: const Text('$projectUrl/tos/'), // Your website URL
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () async {
                  if (!await launchUrl(Uri.parse('$projectUrl/tos/'))) {
                    Sentry.captureException(
                      Exception('Could not launch $projectUrl/tos/'),
                    );
                  }
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.mail_outline),
                title: Text(localizations.contactSupport),
                subtitle: const Text('support@discoos.org'),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () async {
                  if (!await launchUrl(
                    Uri.parse(
                      'mailto:support@discoos.org?subject=RingDrill Feedback',
                    ),
                  )) {
                    Sentry.captureException(
                      Exception('Could not open email client'),
                    );
                  }
                },
              ),
              const Divider(),
            ],
          ),
        ),
      ),
    );
  }
}
