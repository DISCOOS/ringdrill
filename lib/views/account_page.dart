import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ringdrill/data/auth_client.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/services/auth_service.dart';
import 'package:ringdrill/utils/phone_format.dart';
import 'package:ringdrill/views/shell/window_size_class.dart';
import 'package:ringdrill/views/widgets/account_switcher.dart';
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

  /// The name fields live here rather than in `_OwnerSection` because saving
  /// is an AppBar action, and the AppBar belongs to the page.
  final _fullName = TextEditingController();
  final _nickname = TextEditingController();
  final _phone = TextEditingController();
  bool _namesDirty = false;
  bool _savingNames = false;

  /// Whether the owner shown is the person reading, which is the only case
  /// where the names are editable — `PATCH /api/auth/me` renames the caller
  /// and nobody else.
  bool _isSelf(AccountMember? owner) {
    if (!AuthService.isInstalled) return false;
    final me = AuthService.instance.state.user?.id;
    return me != null && me == owner?.userId;
  }

  /// Whether the owner section is showing its fields. Set when the roster
  /// resolves, because until then the page does not know whose account this is
  /// — and an AppBar action that appears a beat after the page would be worse
  /// than one that waits.
  bool _showNameFields = false;

  bool get _canSaveNames =>
      _namesDirty &&
      !_savingNames &&
      _fullName.text.trim().isNotEmpty &&
      // A number nobody can dial is worse than none: it is on the roster, it
      // looks answered, and it fails on the day somebody needs it.
      isDialablePhone(_phone.text);

  Future<void> _saveNames() async {
    final l = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _savingNames = true);
    try {
      await AuthService.instance.updateNames(
        displayName: _fullName.text.trim(),
        nickname: _nickname.text.trim(),
        phone: _phone.text.trim(),
      );
      if (!mounted) return;
      setState(() => _namesDirty = false);
      _reload();
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.accountActionFailed)));
    } finally {
      if (mounted) setState(() => _savingNames = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _roster = _load();
    final user = AuthService.isInstalled
        ? AuthService.instance.state.user
        : null;
    // The address is the fallback account creation uses when a provider gave
    // no name. Pre-filling the box with it would make "enter your name" look
    // answered, so it starts empty.
    final display = user?.displayName ?? '';
    _fullName.text = (display == user?.email) ? '' : display;
    _nickname.text = user?.nickname ?? '';
    _phone.text = user?.phone ?? '';
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
  void dispose() {
    _fullName.dispose();
    _nickname.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      // "My account" for the personal one, the organisation's own name
      // otherwise. A personal account is created carrying the user's display
      // name, which is their email address until they set one — an address in
      // the title bar tells the reader nothing about where they are, and this
      // page is the only "your account" screen there is.
      appBar: AppBar(
        title: Text(accountTitle(l, widget.account)),
        // Saving is an AppBar action here as it is on every other form in the
        // app (see person_form_screen), rather than a button buried in the
        // middle of a scrolling list where it can be scrolled out of sight.
        // Only rendered when there is something editable to save.
        actions: [
          if (_showNameFields) ...[
            FilledButton(
              onPressed: _canSaveNames ? _saveNames : null,
              child: _savingNames
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l.save),
            ),
            const SizedBox(width: 16),
          ],
        ],
      ),
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
          final editable = _isSelf(_owner(roster));
          if (editable != _showNameFields) {
            // After this frame, not during it: setState inside build is an
            // error, and the AppBar rebuilds with the rest of the page.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _showNameFields = editable);
            });
          }
          // **Two columns where there is room.** The page is two unrelated
          // subjects — who you are, and who else is here — and stacking them
          // put the members list below a fold on a desktop browser while the
          // space beside the name fields sat empty. The narrower column also
          // fixes the fields: three inputs across a 1400px dialog read as a
          // form somebody forgot to lay out.
          //
          // Devices and Delete stay full width below both: they belong to the
          // page rather than to either column.
          final wide = WindowSizeClass.of(context).hasMasterDetail;
          final me = <Widget>[
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
            // **The owner is not a row in the members list.** There is
            // exactly one today, and it is almost always the person reading
            // the screen — putting them in a list of one, above a second
            // list, made the page read as though the owner were simply the
            // first member. This is also where the names live, because "who
            // am I here" and "what am I called" are the same question.
            _OwnerSection(
              account: widget.account,
              owner: _owner(roster),
              editable: _showNameFields,
              fullName: _fullName,
              nickname: _nickname,
              phone: _phone,
              busy: _savingNames,
              onChanged: () => setState(() => _namesDirty = true),
            ),
          ];

          // **The section renders even with nobody in it**, because it is
          // where inviting lives. Hiding it when empty left an owner with no
          // way to add the first person, and left the page showing two
          // adjacent dividers with nothing between them.
          final members = <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.accountMembersTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  // In the section it belongs to, rather than a floating
                  // button over the page: it acts on this list and on
                  // nothing else, and as a FAB it also sat on top of
                  // "Delete account".
                  if (_isOwner)
                    TextButton.icon(
                      onPressed: _invite,
                      icon: const Icon(Icons.person_add_alt, size: 20),
                      label: Text(l.accountInviteAction),
                    ),
                ],
              ),
            ),
            if (_others(roster).isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  l.accountMembersEmpty,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              ..._others(roster).map((m) => _memberTile(context, l, m)),
          ];

          return ListView(
            children: [
              if (wide)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: me,
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: members,
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                ...me,
                const Divider(height: 32),
                ...members,
              ],
              // Devices belong to the *user*, not to an account, so they
              // appear once — on the personal account, which is the "your
              // account" page. Every user has one (ADR-0024 creates it at
              // first sign-in), so this is never nowhere.
              if (!widget.account.isOrganisation) _DevicesSection(),
              // Owner-only, and last: it is the one action here with no undo,
              // so it does not sit next to the everyday ones.
              if (_isOwner) ...[
                const Divider(height: 32),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: OutlinedButton.icon(
                    onPressed: _confirmDelete,
                    icon: const Icon(Icons.delete_outline),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                    label: Text(
                      widget.account.isOrganisation
                          ? l.accountDeleteOrgAction
                          : l.accountDeleteAction,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }

  /// The single owner, or null for an account whose owner row has not
  /// arrived — an organisation somebody is a plain member of, say.
  AccountMember? _owner(AccountRoster roster) {
    for (final m in roster.members) {
      if (m.role == 'owner' && !m.isPending) return m;
    }
    return null;
  }

  /// Everyone the owner section does not already show.
  List<AccountMember> _others(AccountRoster roster) {
    final owner = _owner(roster);
    return [
      for (final m in roster.members)
        if (m != owner) m,
    ];
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

  /// Confirm, then delete.
  ///
  /// The confirm's job is to correct one specific wrong expectation: "delete
  /// my account" reasonably sounds like it should unpublish, and it does not
  /// (DESIGN-015 §5.1). Saying so after the fact would be too late, so the
  /// dialog says what stays as plainly as what goes.
  Future<void> _confirmDelete() async {
    final l = AppLocalizations.of(context)!;
    final choice = await showAdaptiveDialog<bool>(
      context: context,
      builder: (context) => _DeleteAccountDialog(account: widget.account),
    );
    if (choice == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final token = await AuthService.instance.accessToken();
      if (token == null) return;
      await _client.deleteAccount(
        widget.account.accountId,
        token: token,
        publishUnpublished: choice,
      );

      // Deleting the personal account destroyed the user behind this session,
      // so the local one has to go too — otherwise the app keeps a token for
      // somebody who no longer exists.
      if (!widget.account.isOrganisation) {
        await AuthService.instance.signOut();
      } else {
        await AuthService.instance.refreshAccounts();
      }
      messenger.showSnackBar(SnackBar(content: Text(l.accountDeleted)));
      navigator.maybePop();
    } on AuthApiException catch (e) {
      final organisations = e.reason == 'sole_owner_of_organisation'
          ? l.accountDeleteSoleOwner(e.detail ?? '')
          : l.accountActionFailed;
      messenger.showSnackBar(SnackBar(content: Text(organisations)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.accountActionFailed)));
    }
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

/// A typed confirmation, not a second button.
///
/// This is the only action in the app with no undo, so a misplaced tap must
/// not be able to reach it.
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({required this.account});

  final AccountMembership account;

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _controller = TextEditingController();

  /// What happens to plans nobody else relies on. Deleting is the default,
  /// because publishing is an act with consequences the user will not be
  /// around to reverse.
  bool _publishDrafts = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final word = l.accountDeleteConfirmWord;
    final armed = _controller.text.trim().toUpperCase() == word;

    // **Not `AlertDialog.adaptive`.** On Apple platforms that renders a
    // `CupertinoAlertDialog`, which provides no `Material` ancestor — and this
    // dialog's content is Material through and through: two `RadioListTile`s
    // and a `TextField`. They threw, and the whole choice-and-confirm section
    // rendered as a red error box, leaving a destructive dialog whose only
    // remaining controls were Cancel and a permanently disabled Delete.
    //
    // `confirmDestructive` in dialog_widgets.dart is the house shape and is
    // plain `AlertDialog` for the same reason. This one cannot call it —
    // that helper takes a message, and this needs a radio group and a typed
    // confirmation — but it matches its chrome.
    return AlertDialog(
      title: Text(l.accountDeleteTitle(widget.account.displayName)),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.account.isOrganisation
                    ? l.accountDeleteOrgBody
                    : l.accountDeleteBody,
              ),
              const SizedBox(height: 12),
              // People fear losing their work more than losing the account.
              Text(
                l.accountDeleteKeepsLocal,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              // The one choice here. Published plans are not offered as a
              // choice: they stay, because other people have installed them.
              Text(
                l.accountDeleteDraftsTitle,
                style: theme.textTheme.labelLarge,
              ),
              RadioListTile<bool>(
                value: false,
                // ignore: deprecated_member_use
                groupValue: _publishDrafts,
                // ignore: deprecated_member_use
                onChanged: (v) => setState(() => _publishDrafts = v ?? false),
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(l.accountDeleteDraftsDelete),
              ),
              RadioListTile<bool>(
                value: true,
                // ignore: deprecated_member_use
                groupValue: _publishDrafts,
                // ignore: deprecated_member_use
                onChanged: (v) => setState(() => _publishDrafts = v ?? false),
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(l.accountDeleteDraftsPublish),
                subtitle: Text(
                  l.accountDeleteDraftsPublishHint,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                autofocus: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: l.accountDeleteConfirmLabel(word),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          // null, not false: false now means "delete the drafts", so cancel
          // needs a value of its own or it would silently confirm.
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: armed
              ? () => Navigator.pop(context, _publishDrafts)
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
          child: Text(
            widget.account.isOrganisation
                ? l.accountDeleteOrgAction
                : l.accountDeleteAction,
          ),
        ),
      ],
    );
  }
}

/// Who you are in this account, and what you are called.
///
/// The owner sits here rather than in the members list: there is exactly one
/// today, it is almost always the person reading the screen, and a list of one
/// above a second list read as though the owner were merely the first member.
///
/// The names live here for the same reason — "who am I in this account" and
/// "what am I called" are one question, and answering it in two places would
/// mean two places to keep them in step.
///
/// **Only your own names are editable.** Viewing somebody else's account as a
/// member shows the owner without the fields, because `PATCH /api/auth/me`
/// only ever renames the caller.
/// Who you are in this account, and what you are called.
///
/// The owner sits here rather than in the members list: there is exactly one
/// today, it is almost always the person reading the screen, and a list of one
/// above a second list read as though the owner were merely the first member.
///
/// The names live here for the same reason — "who am I in this account" and
/// "what am I called" are one question, and answering it in two places would
/// mean two places to keep them in step.
///
/// **Stateless, and the controllers belong to the page.** Saving is an AppBar
/// action, as it is on every other form in the app, and an AppBar belongs to
/// the page rather than to a section inside its list. Keeping the text here
/// would have meant a section reaching up to enable a button above it.
///
/// **Only your own names are editable.** Viewing somebody else's account as a
/// member shows the owner without the fields, because `PATCH /api/auth/me`
/// only ever renames the caller.
class _OwnerSection extends StatelessWidget {
  const _OwnerSection({
    required this.account,
    required this.owner,
    required this.editable,
    required this.fullName,
    required this.nickname,
    required this.phone,
    required this.busy,
    required this.onChanged,
  });

  final AccountMembership account;
  final AccountMember? owner;
  final bool editable;
  final TextEditingController fullName;
  final TextEditingController nickname;

  /// The number fellow members see (ADR-0072's logic: an account is people
  /// already running the exercise together, and a roster exists so they can
  /// reach each other). Its own row rather than a third column — a phone
  /// number needs the width, and two names plus a number in one row is three
  /// cramped boxes.
  final TextEditingController phone;
  final bool busy;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // No heading on a personal account: the title bar already says "My
        // account", and a "You" above your own name is the same word twice.
        // An organisation keeps one, where the owner may be somebody else.
        if (account.isOrganisation)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              l.accountOwnerTitle,
              style: theme.textTheme.titleMedium,
            ),
          ),
        if (owner != null)
          ListTile(
            leading: const Icon(Icons.person),
            title: Text(
              owner!.displayName?.isNotEmpty == true
                  ? owner!.displayName!
                  : (owner!.email ?? ''),
            ),
            subtitle: Text(roleLabel(l, owner!.role)),
          ),
        // **The handle, where somebody can find it.** It is how another
        // account names this one when sharing a plan with it, and until now it
        // appeared nowhere in the app — leaving "share with my organisation"
        // as a request to type something the person had never seen. Copyable
        // rather than merely shown, because the next thing anyone does with it
        // is paste it into a message.
        if (account.handle != null && account.handle!.isNotEmpty)
          ListTile(
            leading: const Icon(Icons.alternate_email),
            title: Text(account.handle!),
            subtitle: Text(l.accountHandleHint),
            trailing: IconButton(
              icon: const Icon(Icons.copy),
              tooltip: l.copy,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: account.handle!));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l.accountHandleCopied)),
                  );
                }
              },
            ),
          ),
        if (editable) ...[
          // One row, and no explicit border: the form screens elsewhere
          // (exercise, person, location) use a bare `InputDecoration` and let
          // the theme draw the field. Two stacked full-width boxes made two
          // short names look like a form of its own.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: fullName,
                    enabled: !busy,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: l.accountFullNameLabel,
                    ),
                    onChanged: (_) => onChanged(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: nickname,
                    enabled: !busy,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: l.accountNicknameLabel,
                    ),
                    onChanged: (_) => onChanged(),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextFormField(
              controller: phone,
              enabled: !busy,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: l.accountPhoneLabel,
                // Shown as it is typed rather than on submit: Save is an
                // AppBar action here, so there is no submit to attach an
                // error to, and a disabled Save with no reason is a puzzle.
                errorText: isDialablePhone(phone.text) ? null : l.phoneInvalid,
              ),
              onChanged: (_) => onChanged(),
            ),
          ),
          // **Below the fields, not above them.** It reads better as a note on
          // what was just asked for than as a preamble to it, and it does a
          // second job down here: a field's underline followed straight by the
          // section divider is two rules a few pixels apart, which looks like
          // a mistake. The text separates them.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              l.accountNamesHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
        // No trailing rule. **Every section here draws its own leading
        // divider** — members, devices, delete — so one at the end of this one
        // met the next section's and drew two lines with a gap between them.
      ],
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
    // Plain `AlertDialog`, not `.adaptive`, for the reason spelled out on the
    // delete dialog above: the Cupertino variant provides no `Material`
    // ancestor and the `TextField` below needs one.
    return AlertDialog(
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
    // Plain `AlertDialog` — `_RoleOptions` is a column of `RadioListTile`s,
    // and the Cupertino variant gives them no `Material` ancestor. Same fault
    // as the delete dialog above.
    return AlertDialog(
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
