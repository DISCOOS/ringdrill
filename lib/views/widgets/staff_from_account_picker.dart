import 'package:flutter/material.dart';
import 'package:ringdrill/data/auth_client.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/staff.dart';
import 'package:ringdrill/services/auth_service.dart';
import 'package:ringdrill/views/account_page.dart' show buildAuthClient;
import 'package:ringdrill/views/widgets/ringdrill_picker.dart';

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
    this.phone,
    this.email,
    this.isSelf = false,
    this.alreadyOnRoster = false,
  });

  final String userId;
  final String name;

  /// How the director reaches them. Both carried, because the two are for
  /// different moments: material and a plan link go out days ahead in writing,
  /// the phone is for the day itself.
  final String? phone;
  final String? email;

  final bool isSelf;

  /// Matched on [Staff.userId], never on the name. Two people called "Kari
  /// Nordmann" are two people, and one person who typed their own name before
  /// signing in is not yet linked to anything.
  final bool alreadyOnRoster;
}

/// The account member a hand-typed row is probably meant to be.
///
/// **A nudge, never a merge.** The link is matched on the id and never on the
/// name, because two people called Kari Nordmann are two people and a wrong
/// merge puts one person's phone number against another's name on a station
/// board. But a coordinator who typed "kenneth gulbrandsøy" before signing in
/// is looking at their own account name in the same list, and making them
/// notice that unaided is a poor trade for the safety.
///
/// So the comparison that is too weak to decide is strong enough to *ask*:
/// case and whitespace folded, exact otherwise — no initials, no fuzzy
/// distance, nothing that would suggest a colleague who merely shares a first
/// name. Ambiguity is silence: two members matching one row means no
/// suggestion, because the one thing worse than no nudge is a confident wrong
/// one.
StaffCandidate? suggestedLinkFor(
  Staff member,
  List<StaffCandidate> candidates,
) {
  if (member.userId != null) return null;
  final typed = _fold(member.realName);
  if (typed.isEmpty) return null;

  final matches = candidates
      .where((c) => !c.alreadyOnRoster && _fold(c.name) == typed)
      .toList();
  return matches.length == 1 ? matches.single : null;
}

String _fold(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// You, resolved with no network at all.
///
/// The picker opens on this and fills in the account's members when they
/// arrive. Adding yourself is the common case and must work on a hill with no
/// signal; waiting on a round trip to show a list that already has its most
/// likely answer in it is the wrong trade twice over.
List<StaffCandidate> selfCandidateOnly({required List<Staff> roster}) {
  if (!AuthService.isInstalled) return const [];
  final user = AuthService.instance.state.user;
  if (user == null) return const [];
  return buildStaffCandidates(user: user, members: const [], roster: roster);
}

/// Load the people who could be added: you, and the account's members.
///
/// **You are resolved without the network, the members are not.** Adding
/// yourself is the common case and has to work on a hill with no signal, so a
/// failure to reach the account degrades to "just you" rather than to an error
/// — `failed` says so, and the caller shows it once rather than replacing the
/// list.
Future<({List<StaffCandidate> candidates, bool failed})> loadStaffCandidates({
  required List<Staff> roster,
}) async {
  if (!AuthService.isInstalled) {
    return (candidates: const <StaffCandidate>[], failed: false);
  }
  final state = AuthService.instance.state;
  final user = state.user;
  if (user == null) {
    return (candidates: const <StaffCandidate>[], failed: false);
  }

  final account = state.activeAccount;
  if (account == null) {
    return (
      candidates: buildStaffCandidates(
        user: user,
        members: const [],
        roster: roster,
      ),
      failed: false,
    );
  }

  try {
    final token = await AuthService.instance.accessToken();
    final members = token == null
        ? const <AccountMember>[]
        : (await buildAuthClient().members(
            account.accountId,
            token: token,
          )).members;
    return (
      candidates: buildStaffCandidates(
        user: user,
        members: members,
        roster: roster,
      ),
      failed: false,
    );
  } catch (_) {
    return (
      candidates: buildStaffCandidates(
        user: user,
        members: const [],
        roster: roster,
      ),
      failed: true,
    );
  }
}

/// Pick somebody from the account to add to the roster, or to link an existing
/// row to.
///
/// **Why an account can populate a roster at all**: ADR-0072 put the privacy
/// boundary at the catalog, not the device. A plan owned by an account is
/// stored whole, roster included, because the co-coordinator running the same
/// exercise needs the same phone list — it is only the public catalog path
/// that strips `staff/`. So the people in an account are exactly the people
/// likely to be staffing its exercises.
///
/// Routed through [showRingdrillPicker] (ADR-0049), which is a sheet on
/// compact and a dialog on medium/expanded. A raw `showModalBottomSheet` here
/// slid a drawer out of the bottom-right corner of a master/detail layout,
/// which is exactly the ad-hoc surface choice that ADR left behind.
Future<StaffCandidate?> pickStaffFromAccount(
  BuildContext context, {
  required List<StaffCandidate> candidates,
  Future<List<StaffCandidate>>? pending,
  required String title,
}) {
  final theme = Theme.of(context);
  final l = AppLocalizations.of(context)!;
  return showRingdrillPicker<StaffCandidate>(
    context: context,
    title: title,
    items: candidates,
    itemsFuture: pending,
    itemBuilder: (context, candidate, onTap) => ListTile(
      leading: Icon(candidate.isSelf ? Icons.person : Icons.face),
      title: Text(candidate.name),
      subtitle: candidate.isSelf ? Text(l.staffFromAccountYou) : null,
      // Ticked rather than dropped: a name missing from the list reads as an
      // account problem, where a tick answers the question the person came
      // here to ask.
      trailing: candidate.alreadyOnRoster
          ? Icon(Icons.check, color: theme.colorScheme.primary)
          : null,
      enabled: !candidate.alreadyOnRoster,
      onTap: candidate.alreadyOnRoster ? null : onTap,
    ),
    searchText: (candidate) => candidate.name,
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
      phone: user.phone.isEmpty ? null : user.phone,
      email: user.email,
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
          phone: member.phone,
          email: member.email,
          alreadyOnRoster: linked.contains(member.userId),
        ),
  ];
}
