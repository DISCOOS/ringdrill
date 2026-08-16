import 'package:flutter/material.dart';
import 'package:ringdrill/data/auth_client.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/staff.dart';
import 'package:ringdrill/services/auth_service.dart';
import 'package:ringdrill/views/account_page.dart' show buildAuthClient;
import 'package:ringdrill/views/widgets/inline_message.dart';

/// Someone who could be put on the roster: you, or a member of the account
/// that owns the plan.
///
/// A candidate is not a [Staff] yet, and deliberately stops short of becoming
/// one. A roster row needs a role — mandatory on create, and unguessable from
/// an account, which knows who may publish and nothing about who is running
/// which post. So picking a candidate opens the staff form with the name
/// filled in, rather than writing a row nobody chose the role for.
class StaffCandidate {
  const StaffCandidate({
    required this.userId,
    required this.name,
    this.isSelf = false,
    this.alreadyOnRoster = false,
  });

  final String userId;
  final String name;
  final bool isSelf;

  /// Matched on [Staff.userId], never on the name. Two people called "Kari
  /// Nordmann" are two people, and one person who typed their own name before
  /// signing in is not yet linked to anything.
  final bool alreadyOnRoster;
}

/// Pick somebody from the account to add to the roster.
///
/// **Why an account can populate a roster at all**: ADR-0072 put the privacy
/// boundary at the catalog, not the device. A plan owned by an account is
/// stored whole, roster included, because the co-coordinator running the same
/// exercise needs the same phone list — it is only the public catalog path
/// that strips `staff/`. So the people in an account are exactly the people
/// likely to be staffing its exercises.
///
/// Returns the chosen candidate, or null if the sheet was dismissed.
Future<StaffCandidate?> pickStaffFromAccount(
  BuildContext context, {
  required List<Staff> roster,
}) {
  return showModalBottomSheet<StaffCandidate>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _StaffFromAccountSheet(roster: roster),
  );
}

/// Who to offer, given who you are, who is in the account, and who is already
/// on the roster.
///
/// Pure, and separate from the sheet, because every rule here is a judgement
/// rather than a rendering detail — and each is a distinct way to get this
/// subtly wrong: offering a second copy of somebody, offering an invitation
/// nobody has accepted, or showing a user id where a name should be.
List<StaffCandidate> buildStaffCandidates({
  required AuthUser user,
  required List<AccountMember> members,
  required List<Staff> roster,
}) {
  // Matched on the link, never on the name. Two people called "Kari Nordmann"
  // are two people — and somebody who typed their own name in before signing
  // in is not linked to anything, so they will be offered and end up with two
  // rows. That is the honest outcome: nothing here can prove the row they
  // typed is them.
  final linked = {
    for (final member in roster)
      if (member.userId != null) member.userId!,
  };

  return [
    StaffCandidate(
      userId: user.id,
      // The nickname is what fits a station board; a roster wants the name a
      // coordinator will recognise on a phone list.
      name: user.displayName,
      isSelf: true,
      alreadyOnRoster: linked.contains(user.id),
    ),
    for (final member in members)
      // A pending invitation is mail sent to an address, not somebody who has
      // agreed to anything — and it has no user id to link on. Your own
      // membership is the self row above, not a second entry.
      if (!member.isPending &&
          member.userId != null &&
          member.userId != user.id)
        StaffCandidate(
          userId: member.userId!,
          // A member who has never set a name is shown by address: it is what
          // their colleagues will recognise, and a user id is not a name by
          // any reading.
          name: member.displayName?.trim().isNotEmpty == true
              ? member.displayName!.trim()
              : member.email ?? member.userId!,
          alreadyOnRoster: linked.contains(member.userId),
        ),
  ];
}

class _StaffFromAccountSheet extends StatefulWidget {
  const _StaffFromAccountSheet({required this.roster});

  final List<Staff> roster;

  @override
  State<_StaffFromAccountSheet> createState() => _StaffFromAccountSheetState();
}

class _StaffFromAccountSheetState extends State<_StaffFromAccountSheet> {
  final _client = buildAuthClient();

  late final Future<List<StaffCandidate>> _candidates = _load();

  Future<List<StaffCandidate>> _load() async {
    if (!AuthService.isInstalled) return const [];
    final state = AuthService.instance.state;
    final user = state.user;
    if (user == null) return const [];

    final account = state.activeAccount;
    // **Yourself first, and without the network.** Adding yourself is the
    // common case and must work on a hill with no signal; the member list is
    // the extra that needs a round trip. A failure here therefore degrades to
    // "just you" rather than to an error screen.
    final token = account == null
        ? null
        : await AuthService.instance.accessToken();
    final members = token == null
        ? const <AccountMember>[]
        : (await _client.members(account!.accountId, token: token)).members;

    return buildStaffCandidates(
      user: user,
      members: members,
      roster: widget.roster,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: FutureBuilder<List<StaffCandidate>>(
          future: _candidates,
          builder: (context, snapshot) {
            final children = <Widget>[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l.staffFromAccountTitle,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 12),
            ];

            if (snapshot.connectionState != ConnectionState.done) {
              children.add(
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            } else if (snapshot.hasError) {
              // Only the member list can fail — see _load. Saying so beats a
              // spinner that never resolves, and the form is still reachable.
              children.add(InlineMessage(message: l.staffFromAccountFailed));
            } else {
              final candidates = snapshot.data ?? const <StaffCandidate>[];
              if (candidates.isEmpty) {
                children.add(
                  InlineMessage(
                    message: l.staffFromAccountSignedOut,
                    tone: MessageTone.info,
                  ),
                );
              }
              for (final candidate in candidates) {
                children.add(
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(candidate.isSelf ? Icons.person : Icons.face),
                    title: Text(candidate.name),
                    subtitle: candidate.isSelf
                        ? Text(l.staffFromAccountYou)
                        : null,
                    // Done rather than absent: a name missing from the list
                    // reads as an account problem, where a tick answers the
                    // question the person came here to ask.
                    trailing: candidate.alreadyOnRoster
                        ? Icon(Icons.check, color: theme.colorScheme.primary)
                        : null,
                    enabled: !candidate.alreadyOnRoster,
                    onTap: candidate.alreadyOnRoster
                        ? null
                        : () => Navigator.of(context).pop(candidate),
                  ),
                );
              }
            }

            return Column(mainAxisSize: MainAxisSize.min, children: children);
          },
        ),
      ),
    );
  }
}
