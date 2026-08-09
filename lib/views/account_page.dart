import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ringdrill/data/auth_client.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/services/auth_service.dart';
import 'package:ringdrill/utils/app_config.dart';

/// Managing an account's members (DESIGN-015 §6).
///
/// Three rules from the design are enforced in the UI as well as on the
/// server, because a screen that offers an action the server will refuse is
/// worse than one that never offered it:
///
/// * **Only an owner administers.** Every member publishes — the account
///   protects a plan from *strangers*, and somebody the account deliberately
///   added is not a stranger. So `owner` does not mean "can do more with
///   plans", it means "can decide who else is here".
/// * **`guest` is a personal-data tier, not a capability tier.** A guest works
///   on the plans and does not see the staff roster. That is its whole reason
///   to exist: one question, one answer, nothing to misremember.
/// * **Invited is a state, not a role.** The role is chosen at invite time and
///   confers nothing until the invitation is accepted, so a pending row shows
///   the role it *will* have, marked as pending.
class AccountPage extends StatefulWidget {
  const AccountPage({super.key, required this.account});

  final AccountMembership account;

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  late Future<AccountRoster> _roster;
  final _client = buildAuthClient();

  bool get _isOwner => widget.account.isOwner;

  @override
  void initState() {
    super.initState();
    _roster = _load();
  }

  Future<AccountRoster> _load() async {
    final token = await AuthService.instance.accessToken();
    if (token == null) throw AuthApiException('signed_out', status: 401);
    return _client.members(widget.account.accountId, token: token);
  }

  void _reload() => setState(() => _roster = _load());

  /// Run an administrative action and reload.
  ///
  /// Every failure is reported by its server reason rather than as a generic
  /// error, because the two that actually happen — last owner, not an owner —
  /// each tell the user something different about what to do next.
  Future<void> _act(Future<void> Function(String token) action) async {
    final l = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final token = await AuthService.instance.accessToken();
      if (token == null) return;
      await action(token);
      _reload();
    } on AuthApiException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(switch (e.reason) {
            'last_owner' => l.accountLastOwnerRefused,
            'owner_role_required' => l.accountOwnerOnly,
            _ => l.accountActionFailed,
          }),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.accountActionFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(widget.account.displayName)),
      floatingActionButton: _isOwner
          ? FloatingActionButton.extended(
              onPressed: _invite,
              icon: const Icon(Icons.person_add_alt),
              label: Text(l.accountInviteAction),
            )
          : null,
      body: FutureBuilder<AccountRoster>(
        future: _roster,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l.accountActionFailed),
              ),
            );
          }
          final roster = snapshot.data!;
          return ListView(
            children: [
              // Prevention, not recovery: an organisation whose sole owner
              // cannot sign in is unrecoverable without support intervention
              // (§4.4). Low-key and non-blocking on purpose — a modal here
              // would punish the normal case of a new organisation.
              if (roster.singleOwner && widget.account.isOrganisation)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l.accountSingleOwnerAdvisory,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  l.accountMembersTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ...roster.members.map((m) => _memberTile(context, l, m)),
              // Devices belong to the *user*, not to an account, so they
              // appear once — on the personal account, which is the "your
              // account" page. Every user has one (ADR-0024 creates it at
              // first sign-in), so this is never nowhere.
              if (!widget.account.isOrganisation) _DevicesSection(),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }

  Widget _memberTile(
    BuildContext context,
    AppLocalizations l,
    AccountMember member,
  ) {
    final isSelf = member.userId == AuthService.instance.state.user?.id;
    final subtitle = [
      roleLabel(l, member.role),
      // The state rides on the row rather than replacing the role, because
      // the role is already decided — it just has not taken effect yet.
      if (member.state == 'invited') l.accountStateInvited,
      if (member.state == 'failed') l.accountStateFailed,
    ].join(' · ');

    return ListTile(
      leading: Icon(
        member.isPending ? Icons.mail_outline : Icons.person_outline,
      ),
      title: Text(member.displayName ?? member.email ?? member.userId ?? '—'),
      subtitle: Text(subtitle),
      // A member may always remove themselves, so the menu is not
      // owner-only — it just has fewer entries.
      trailing: (_isOwner || isSelf)
          ? PopupMenuButton<String>(
              onSelected: (value) => switch (value) {
                'role' => _changeRole(member),
                _ => _remove(member),
              },
              itemBuilder: (context) => [
                if (_isOwner && !member.isPending)
                  PopupMenuItem(
                    value: 'role',
                    child: Text(l.accountChangeRoleAction),
                  ),
                PopupMenuItem(
                  value: 'remove',
                  child: Text(
                    member.isPending
                        ? l.accountWithdrawAction
                        : (isSelf
                              ? l.accountLeaveAction
                              : l.accountRemoveAction),
                  ),
                ),
              ],
            )
          : null,
    );
  }

  Future<void> _invite() async {
    final l = AppLocalizations.of(context)!;
    final result = await showAdaptiveDialog<({String email, String role})>(
      context: context,
      builder: (context) => const _InviteDialog(),
    );
    if (result == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final locale = Localizations.localeOf(context).languageCode == 'nb'
        ? 'nb'
        : 'en';
    await _act((token) async {
      await _client.invite(
        widget.account.accountId,
        email: result.email,
        role: result.role,
        token: token,
        locale: locale,
      );
      messenger.showSnackBar(
        SnackBar(content: Text(l.accountInviteSent(result.email))),
      );
    });
  }

  Future<void> _changeRole(AccountMember member) async {
    final role = await showAdaptiveDialog<String>(
      context: context,
      builder: (context) => _RolePickerDialog(initial: member.role),
    );
    if (role == null || role == member.role) return;
    await _act(
      (token) => _client.changeRole(
        widget.account.accountId,
        member.pathId,
        role: role,
        token: token,
      ),
    );
  }

  Future<void> _remove(AccountMember member) => _act(
    (token) => _client.removeMember(
      widget.account.accountId,
      member.pathId,
      token: token,
    ),
  );
}

/// The signed-in devices, and the way to end one (DESIGN-015 §4.3).
///
/// This is the design's answer to "I lost the device that was signed in" and
/// to "my phone was stolen" — not a recovery flow, a list you can act on. It
/// is also the one place refresh-token rotation becomes visible: a session
/// ended by replay detection is kept server-side as a tombstone so it can be
/// shown as *ended, and why*, rather than silently disappearing.
class _DevicesSection extends StatefulWidget {
  @override
  State<_DevicesSection> createState() => _DevicesSectionState();
}

class _DevicesSectionState extends State<_DevicesSection> {
  late Future<List<AuthDevice>> _devices = AuthService.instance.devices();

  Future<void> _revoke(AuthDevice device) async {
    final l = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AuthService.instance.revokeSession(device.sessionId);
      messenger.showSnackBar(SnackBar(content: Text(l.accountDeviceSignedOut)));
      if (mounted) {
        setState(() => _devices = AuthService.instance.devices());
      }
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.accountActionFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final current = AuthService.instance.currentSessionId;

    return FutureBuilder<List<AuthDevice>>(
      future: _devices,
      builder: (context, snapshot) {
        // No spinner and no error row: this section is supplementary, and a
        // failure to load it must not make the members list above look broken.
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        final devices = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(height: 32),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                l.accountDevicesTitle,
                style: theme.textTheme.titleMedium,
              ),
            ),
            for (final device in devices)
              _deviceTile(context, l, theme, device, current),
          ],
        );
      },
    );
  }

  Widget _deviceTile(
    BuildContext context,
    AppLocalizations l,
    ThemeData theme,
    AuthDevice device,
    String? current,
  ) {
    final isCurrent = device.isCurrent(current);
    return ListTile(
      leading: Icon(
        device.isEnded
            ? Icons.gpp_maybe_outlined
            : (isCurrent ? Icons.phone_iphone : Icons.devices_other),
      ),
      title: Text(
        [
          device.label ?? l.accountDeviceUnknown,
          if (isCurrent) '· ${l.accountDeviceThis}',
        ].join(' '),
      ),
      subtitle: device.isEnded
          // Said in full rather than as a status word. "Ended" alone invites
          // the reading that RingDrill logged you out for no reason.
          ? Text(
              device.endedReason == 'replayed'
                  ? l.accountDeviceEndedReplay
                  : l.accountDeviceEnded,
              style: theme.textTheme.bodySmall,
            )
          : (device.lastUsedAt == null
                ? null
                : Text(
                    l.accountDeviceLastUsed(
                      MaterialLocalizations.of(
                        context,
                      ).formatShortDate(device.lastUsedAt!.toLocal()),
                    ),
                  )),
      // An ended session has nothing left to end.
      trailing: device.isEnded
          ? null
          : IconButton(
              icon: const Icon(Icons.logout),
              tooltip: l.accountDeviceSignOutThis,
              onPressed: () => _revoke(device),
            ),
    );
  }
}

/// The role's label. Kept as a function rather than an extension so the invite
/// dialog and the roster render the same words from one place.
String roleLabel(AppLocalizations l, String role) => switch (role) {
  'owner' => l.accountRoleOwner,
  'guest' => l.accountRoleGuest,
  _ => l.accountRoleMember,
};

String roleHint(AppLocalizations l, String role) => switch (role) {
  'owner' => l.accountRoleOwnerHint,
  'guest' => l.accountRoleGuestHint,
  _ => l.accountRoleMemberHint,
};

/// Address plus role, in one step.
///
/// Inviting an address with no account yet is the normal case, not an edge
/// one — the invitation is addressed to the email and binds when that person
/// signs in with a verified identity for it.
class _InviteDialog extends StatefulWidget {
  const _InviteDialog();

  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  final _controller = TextEditingController();
  String _role = 'member';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final valid = _controller.text.contains('@');
    return AlertDialog.adaptive(
      title: Text(l.accountInviteAction),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _controller,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: l.accountInviteEmailLabel,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              _RoleOptions(
                value: _role,
                onChanged: (r) => setState(() => _role = r),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: valid
              ? () => Navigator.pop(context, (
                  email: _controller.text.trim(),
                  role: _role,
                ))
              : null,
          child: Text(l.accountInviteAction),
        ),
      ],
    );
  }
}

class _RolePickerDialog extends StatefulWidget {
  const _RolePickerDialog({required this.initial});

  final String initial;

  @override
  State<_RolePickerDialog> createState() => _RolePickerDialogState();
}

class _RolePickerDialogState extends State<_RolePickerDialog> {
  late String _role = widget.initial;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AlertDialog.adaptive(
      title: Text(l.accountChangeRoleAction),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: _RoleOptions(
            value: _role,
            onChanged: (r) => setState(() => _role = r),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _role),
          child: Text(l.save),
        ),
      ],
    );
  }
}

/// The three roles, each with the consequence spelled out.
///
/// The lead line above them is load-bearing: without it the list reads as a
/// permission ladder, and it is not one. Every role publishes. What differs is
/// administration and whether the staff roster is visible — and the roster is
/// the part somebody has to actively decide about, because it is other
/// people's names and phone numbers.
class _RoleOptions extends StatelessWidget {
  const _RoleOptions({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.accountRolePickerLead,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        for (final role in const ['owner', 'member', 'guest'])
          RadioListTile<String>(
            value: role,
            // ignore: deprecated_member_use
            groupValue: value,
            // ignore: deprecated_member_use
            onChanged: (v) => onChanged(v ?? value),
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(roleLabel(l, role)),
            subtitle: Text(roleHint(l, role)),
          ),
      ],
    );
  }
}

/// One construction recipe, matching `buildCatalogClient()` — the two clients
/// must always point at the same origin, or a signed-in session would be
/// talking to a different backend than the plans it publishes.
AuthClient buildAuthClient() {
  final baseUrl = AppConfig.catalogBaseUrl(
    isWeb: kIsWeb,
    isRelease: kReleaseMode,
    isDebug: kDebugMode,
  );
  return AuthClient(
    baseUrl: baseUrl,
    functionsBasePath: AppConfig.functionsBasePathFor(baseUrl),
  );
}
