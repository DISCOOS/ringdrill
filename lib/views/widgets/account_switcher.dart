import 'package:flutter/material.dart';
import 'package:ringdrill/data/auth_client.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/services/auth_service.dart';
import 'package:ringdrill/views/widgets/ringdrill_picker.dart';

/// What to say beneath an account's name so a person can tell which one they
/// are acting in.
///
/// **The name is the wrong answer here**, which is why this exists. A personal
/// account is created carrying the user's own display name, so repeating it
/// under their name says the same thing twice — and when a provider gave no
/// better name, that name is their email address, so the row showed one
/// address stacked on itself.
///
/// So: a personal account says what *kind* it is, and an organisation says its
/// handle. The handle is the useful line for an organisation because it is the
/// name that is unique, the one another account uses to share a plan with this
/// one, and the one that distinguishes two teams whose display names read
/// alike. An organisation with no handle falls back to its name, which is
/// still better than nothing.
String accountSubtitle(AppLocalizations l, AccountMembership account) {
  if (!account.isOrganisation) return l.accountKindPersonal;
  final handle = account.handle;
  return (handle != null && handle.isNotEmpty) ? handle : account.displayName;
}

/// How an account names itself at the top of its own page.
///
/// The same vocabulary as [accountSubtitle], one register up: "Personal
/// account", or "Organisation account (handle)". The page used to say "My
/// account" for a personal one and the bare display name for an organisation,
/// which meant three surfaces identified the same account three ways — and the
/// display name is the one of the three that two organisations can share.
String accountTitle(AppLocalizations l, AccountMembership account) {
  if (!account.isOrganisation) return l.accountKindPersonal;
  final handle = account.handle;
  return (handle != null && handle.isNotEmpty)
      ? l.accountTitleOrganisation(handle)
      : account.displayName;
}

/// Choose which account this device acts in.
///
/// Returns true when the active account changed, so a caller holding a stale
/// label can rebuild.
///
/// Shared by the drawer and the publish dialog rather than written twice: both
/// ask the identical question, and a switcher that behaves differently
/// depending on where it was opened is a switcher people stop trusting.
Future<bool> showAccountSwitcher(BuildContext context) async {
  if (!AuthService.isInstalled) return false;
  final l = AppLocalizations.of(context)!;
  final accounts = AuthService.instance.state.accounts;
  final active = AuthService.instance.state.activeAccount?.accountId;

  final chosen = await showRingdrillPicker<AccountMembership>(
    context: context,
    title: l.accountSwitchTitle,
    items: accounts,
    itemBuilder: (context, account, onTap) {
      final selected = account.accountId == active;
      return ListTile(
        selected: selected,
        // The current one is ticked rather than hidden: "which am I in" is
        // the question that brought somebody here, and a list that omits the
        // answer makes them count the rows.
        leading: Icon(
          selected
              ? Icons.check
              : (account.isOrganisation ? Icons.groups : Icons.person),
        ),
        title: Text(account.displayName),
        subtitle: Text(accountSubtitle(l, account)),
        onTap: onTap,
      );
    },
    searchText: (account) => '${account.displayName} ${account.handle ?? ''}',
  );

  if (chosen == null || chosen.accountId == active) return false;
  await AuthService.instance.setActiveAccount(chosen.accountId);
  return true;
}
