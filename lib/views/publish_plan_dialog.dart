import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ringdrill/data/auth_client.dart';
import 'package:ringdrill/data/drill_client.dart';
import 'package:ringdrill/data/drill_file.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/services/auth_service.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/views/catalog_conflict_dialog.dart';
import 'package:ringdrill/views/shell/open_form_surface.dart';
import 'package:ringdrill/views/sign_in_page.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Modes the publish dialog adapts to. The dialog itself behaves the same in
/// both cases (slug + tags input). The mode picks the title and body copy.
enum PublishDialogMode {
  /// First-time publish of a local or imported plan.
  firstTime,

  /// "Publish as…" — explicit dialog flow, may produce a fork on an already
  /// published plan if the user changes the slug.
  publishAs,
}

/// How a plan is shared once published (ADR-0025's `accessPolicy`).
///
/// Named for the *consequence* rather than the policy, matching the labels the
/// dialog shows: DESIGN-015 §5.8 requires the options be phrased as what
/// happens, not as a vocabulary the user has to learn.
enum PublishSharing {
  /// `account` — only the owning account's members may publish it.
  accountOnly,

  /// `shared` — named grantee accounts too. The list is chosen afterwards,
  /// because the server refuses `shared` with no accounts named rather than
  /// storing something that reads as shared and behaves as account-only.
  shared,

  /// `public` — the wiki model: anyone may overwrite it, signed in or not.
  /// The only option available signed out, and a first-class one.
  public;

  /// The wire value, or null when nothing should be sent.
  ///
  /// [shared] sends `account` on the publish itself: it is the protective
  /// half of what the user asked for, and the grantees follow in a separate
  /// call. Sending `shared` here would be refused.
  String? get wireValue => switch (this) {
    PublishSharing.accountOnly => 'account',
    PublishSharing.shared => 'account',
    PublishSharing.public => 'public',
  };
}

/// Result returned by [showPublishPlanDialog].
class PublishPlanInput {
  const PublishPlanInput({
    required this.slug,
    this.sharing = PublishSharing.public,
    this.accountId,
  });

  final String slug;

  /// How the plan should be shared. Only applies to a **new** plan — the
  /// server keeps an existing plan's policy, so an ordinary update can never
  /// widen access as a side effect.
  final PublishSharing sharing;

  /// The account the publish lands in, or null when signed out.
  final String? accountId;

  /// True when the user asked for `shared`, which needs a follow-up choice of
  /// grantee accounts.
  bool get needsGrantees => sharing == PublishSharing.shared;
}

/// Shows the publish-to-catalog dialog and returns the user's input.
///
/// Returns `null` if the user cancels. The slug field is always editable; the
/// initial value is derived from [plan]'s current catalog slug if it has
/// one, otherwise from its name.
Future<PublishPlanInput?> showPublishPlanDialog(
  BuildContext context, {
  required Plan plan,
  required PublishDialogMode mode,
}) {
  final initialSlug =
      plan.source.whenOrNull(
        catalog: (slug, latestEtag, installedAt, latestVersion) => slug,
      ) ??
      sanitizeSlug(plan.name);

  return showAdaptiveDialog<PublishPlanInput>(
    context: context,
    builder: (context) =>
        _PublishPlanDialog(mode: mode, initialSlug: initialSlug),
  );
}

class _PublishPlanDialog extends StatefulWidget {
  const _PublishPlanDialog({required this.mode, required this.initialSlug});

  final PublishDialogMode mode;
  final String initialSlug;

  @override
  State<_PublishPlanDialog> createState() => _PublishPlanDialogState();
}

class _PublishPlanDialogState extends State<_PublishPlanDialog> {
  late final TextEditingController _slugController;
  String _sanitizedSlug = '';

  /// Defaults to the protective option when signed in, and is forced to
  /// [PublishSharing.public] when signed out — the only thing an anonymous
  /// publish can be.
  late PublishSharing _sharing;

  @override
  void initState() {
    super.initState();
    _slugController = TextEditingController(text: widget.initialSlug);
    _sanitizedSlug = sanitizeSlug(widget.initialSlug);
    _slugController.addListener(_onSlugChanged);
    _sharing = _account == null
        ? PublishSharing.public
        : PublishSharing.accountOnly;
  }

  /// The account a publish would land in, or null when signed out.
  AccountMembership? get _account =>
      AuthService.isInstalled ? AuthService.instance.state.activeAccount : null;

  void _onSlugChanged() {
    final next = sanitizeSlug(_slugController.text);
    if (next != _sanitizedSlug) {
      setState(() => _sanitizedSlug = next);
    }
  }

  @override
  void dispose() {
    _slugController.removeListener(_onSlugChanged);
    _slugController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final title = switch (widget.mode) {
      PublishDialogMode.firstTime => localizations.libraryPublishTitle,
      PublishDialogMode.publishAs => localizations.libraryPublishAsTitle,
    };
    final body = switch (widget.mode) {
      PublishDialogMode.firstTime => localizations.libraryPublishBody,
      PublishDialogMode.publishAs => localizations.libraryPublishAsBody,
    };
    final canSubmit = _sanitizedSlug.isNotEmpty;
    return AlertDialog(
      title: Text(title),
      // Scrollable, because the content grew past a phone's dialog height
      // once the account line and the sharing options landed — and an
      // AlertDialog does not scroll its content for you. Caught by a widget
      // test overflowing rather than in review.
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(body),
              const SizedBox(height: 16),
              TextField(
                controller: _slugController,
                decoration: InputDecoration(
                  labelText: localizations.libraryPublishSlugLabel,
                  helperText: localizations.libraryPublishSlugHelper,
                  border: const OutlineInputBorder(),
                ),
                autocorrect: false,
                enableSuggestions: false,
              ),
              ..._buildAccountAndSharing(context, localizations),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(localizations.cancel),
        ),
        // Publish stays the primary action when signed out; "Sign in first"
        // sits below it as the alternative (DESIGN-015 §5.8 decision 1).
        // Reversing them would make anonymous publishing look like the
        // degraded path, and it is not.
        FilledButton(
          onPressed: canSubmit
              ? () => Navigator.pop(
                  context,
                  PublishPlanInput(
                    slug: _sanitizedSlug,
                    sharing: _sharing,
                    accountId: _account?.accountId,
                  ),
                )
              : null,
          child: Text(localizations.libraryPublishSubmit),
        ),
      ],
    );
  }

  /// The account line and the sharing choice.
  ///
  /// Both live here rather than on a second screen because they are decisions
  /// about the same act: which account owns this, and who can see it.
  List<Widget> _buildAccountAndSharing(
    BuildContext context,
    AppLocalizations localizations,
  ) {
    final theme = Theme.of(context);
    final account = _account;
    final subtle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return [
      const SizedBox(height: 20),

      if (account != null) ...[
        // Naming the destination is the whole point: someone who publishes to
        // the wrong account otherwise finds out afterwards.
        Text(
          localizations.publishPublishesTo,
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.account_circle_outlined, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(account.displayName)),
            if (AuthService.instance.state.accounts.length > 1)
              TextButton(
                onPressed: () => _pickAccount(context),
                child: Text(localizations.publishSwitchAccount),
              ),
          ],
        ),
        const SizedBox(height: 16),
      ],

      // "Sharing", never "Access": §7 reserves that word for a person's
      // standing in an account, and one word for both would conflate a plan's
      // write policy with a member's role.
      Text(
        localizations.publishSharingLabel,
        style: theme.textTheme.labelLarge,
      ),

      if (account == null) ...[
        const SizedBox(height: 4),
        // One plain line. No warning colour, no lock icon, no interstitial.
        Text(localizations.publishAnonymousExplanation, style: subtle),
        // The offer, not a gate: Publish stays the primary action in the
        // button row below, and this sits under the explanation as the
        // alternative. Absent entirely when there is no session to sign into.
        // Absent under AUTH_MODE=off too (ADR-0073): the switch makes every
        // auth route answer 503, so the offer leads to a screen that cannot
        // finish.
        if (AuthService.isInstalled && AuthService.instance.authAvailable)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () {
                // Closes the dialog: the user is leaving to do something else
                // and will publish afterwards. Keeping it open behind a
                // sign-in screen would strand a stale slug field.
                Navigator.pop(context);
                openFormSurface<void>(
                  context,
                  builder: (_) => const SignInPage(),
                );
              },
              child: Text(localizations.publishSignInFirst),
            ),
          ),
      ] else
        ...PublishSharing.values.map(
          (option) => RadioListTile<PublishSharing>(
            value: option,
            // ignore: deprecated_member_use
            groupValue: _sharing,
            // ignore: deprecated_member_use
            onChanged: (v) => setState(() => _sharing = v ?? _sharing),
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(_sharingLabel(localizations, option, account)),
            subtitle: option == PublishSharing.shared
                ? Text(localizations.publishSharingSharedHint, style: subtle)
                : null,
          ),
        ),

      const SizedBox(height: 16),
      // This line belongs on this screen and nowhere else: publishing is the
      // exact moment somebody wonders whether the phone numbers they typed
      // are about to become public.
      Text(localizations.publishStaffNeverPublished, style: subtle),
      if (account != null && account.isOrganisation) ...[
        const SizedBox(height: 4),
        // The half people get wrong (ADR-0072).
        Text(
          localizations.publishRosterStaysInside(account.displayName),
          style: subtle,
        ),
      ],
    ];
  }

  /// Phrased as the consequence, not the policy name.
  String _sharingLabel(
    AppLocalizations localizations,
    PublishSharing option,
    AccountMembership account,
  ) => switch (option) {
    // An organisation is named, because "only my account" is meaningless for
    // one shared with colleagues.
    PublishSharing.accountOnly =>
      account.isOrganisation
          ? localizations.publishSharingOrgOnly(account.displayName)
          : localizations.publishSharingAccountOnly,
    PublishSharing.shared => localizations.publishSharingShared,
    PublishSharing.public => localizations.publishSharingPublic,
  };

  Future<void> _pickAccount(BuildContext context) async {
    final accounts = AuthService.instance.state.accounts;
    final chosen = await showAdaptiveDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(AppLocalizations.of(context)!.publishPublishesTo),
        children: accounts
            .map(
              (a) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, a.accountId),
                child: Text(a.displayName),
              ),
            )
            .toList(),
      ),
    );
    if (chosen == null) return;
    await AuthService.instance.setActiveAccount(chosen);
    if (mounted) {
      // The label for accountOnly names the account, so a switch between a
      // personal account and an organisation changes what the selected option
      // says. Re-read rather than leaving a stale label next to a live radio.
      setState(() {});
    }
  }
}

/// Publish [planUuid] under its current slug (or [slug] for first-time
/// publish) and show a snackbar describing the outcome.
///
/// On 412 (stale view) the function triggers a catalog refresh, shows the
/// conflict dialog so the user can see the diff between their local edits
/// and the new remote state, and acts on their choice (publish anyway,
/// overwrite local, fork, or cancel). The caller therefore never has to
/// handle 412 itself.
Future<Plan?> runPublishPlan(
  BuildContext context, {
  required String planUuid,
  required String slug,
  required DrillClient client,
  String? accessPolicy,
}) {
  return _runUpload(
    context,
    slug: slug,
    planUuid: planUuid,
    client: client,
    upload: () => PlanService().publishPlan(
      planUuid,
      slug: slug,
      client: client,
      accessPolicy: accessPolicy,
    ),
  );
}

/// Publish [planUuid] at [slug], forking the local plan if the slug differs
/// from the plan's current catalog slug. Shows a snackbar describing the
/// outcome.
Future<Plan?> runPublishPlanAs(
  BuildContext context, {
  required String planUuid,
  required String slug,
  required DrillClient client,
  String? accessPolicy,
}) {
  return _runUpload(
    context,
    slug: slug,
    planUuid: planUuid,
    client: client,
    upload: () => PlanService().publishPlanAs(
      planUuid,
      slug: slug,
      client: client,
      accessPolicy: accessPolicy,
    ),
  );
}

Future<Plan?> _runUpload(
  BuildContext context, {
  required Future<({Plan plan, bool notModified})> Function() upload,
  required String slug,
  required String planUuid,
  required DrillClient client,
}) async {
  final localizations = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  try {
    final result = await upload();
    final message = result.notModified
        ? localizations.libraryPublishNoChange
        : localizations.libraryPublishSuccess(result.plan.name);
    messenger.showSnackBar(
      SnackBar(
        showCloseIcon: true,
        dismissDirection: DismissDirection.endToStart,
        content: Text(message),
      ),
    );
    return result.plan;
  } on DrillApiException catch (e, stackTrace) {
    if (e.status == 412 && context.mounted) {
      // Stale view — hand off to the catalog-conflict flow so the user can
      // see the diff between their edits and the new remote state and pick
      // overwrite / fork / publish-anyway / cancel.
      return await _resolvePublishConflict(
        context,
        planUuid: planUuid,
        client: client,
      );
    }
    final message = switch ((e.status, e.conflictKind)) {
      (409, 'version') => localizations.libraryPublishConflict,
      (409, _) => localizations.libraryPublishSlugTaken(slug),
      _ => localizations.libraryPublishFailed,
    };
    messenger.showSnackBar(
      SnackBar(
        showCloseIcon: true,
        dismissDirection: DismissDirection.endToStart,
        content: Text(message),
      ),
    );
    if (e.status == null || e.status! >= 500) {
      unawaited(Sentry.captureException(e, stackTrace: stackTrace));
    }
    return null;
  } catch (e, stackTrace) {
    messenger.showSnackBar(
      SnackBar(
        showCloseIcon: true,
        dismissDirection: DismissDirection.endToStart,
        content: Text(localizations.libraryPublishFailed),
      ),
    );
    unawaited(Sentry.captureException(e, stackTrace: stackTrace));
    return null;
  }
}

/// Triggered after the upload returned 412. Refreshes the catalog state,
/// shows the conflict dialog with a diff against the fresh remote, and acts
/// on the user's choice. The refresh flow is the same one used by
/// "Refresh from catalog" — the only difference is that we got here because
/// the user already attempted to publish, so [CatalogConflictChoice
/// .publishMyChanges] re-runs the upload with the fresh etag.
Future<Plan?> _resolvePublishConflict(
  BuildContext context, {
  required String planUuid,
  required DrillClient client,
}) async {
  final localizations = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  try {
    final outcome = await PlanService().refreshCatalogItem(
      planUuid,
      client,
      onConflict:
          (
            diff, {
            required ownedSlug,
            required remoteUnchanged,
            required localVersion,
            required catalogVersion,
          }) => showCatalogConflictDialog(
            context,
            diff: diff,
            ownedSlug: ownedSlug,
            remoteUnchanged: remoteUnchanged,
            localVersion: localVersion,
            catalogVersion: catalogVersion,
          ),
    );
    if (outcome.kind == CatalogRefreshKind.published) {
      final published = PlanService().loadPlan(outcome.planUuid);
      if (published != null) {
        messenger.showSnackBar(
          SnackBar(
            showCloseIcon: true,
            dismissDirection: DismissDirection.endToStart,
            content: Text(localizations.libraryPublishSuccess(published.name)),
          ),
        );
      }
      return published;
    }
    // cancelled, overwriteLocal, fork, upToDate, failed — the dialog (or
    // silent refresh) is the user-visible feedback; we don't add a snackbar
    // on top.
    return null;
  } catch (e, stackTrace) {
    messenger.showSnackBar(
      SnackBar(
        showCloseIcon: true,
        dismissDirection: DismissDirection.endToStart,
        content: Text(localizations.libraryPublishFailed),
      ),
    );
    unawaited(Sentry.captureException(e, stackTrace: stackTrace));
    return null;
  }
}
