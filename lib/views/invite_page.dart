import 'package:flutter/material.dart';
import 'package:ringdrill/data/auth_client.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/services/auth_service.dart';
import 'package:ringdrill/views/widgets/inline_message.dart';
import 'package:ringdrill/views/account_page.dart'
    show buildAuthClient, roleLabel;
import 'package:ringdrill/views/sign_in_page.dart';

/// Answering an invitation (DESIGN-015 §6.4).
///
/// The page renders **five** states that are not the happy path, and each gets
/// its own sentence: already accepted, withdrawn, expired, the organisation
/// was deleted, and signed in as the wrong person. Collapsing them into one
/// failure message would leave every one of them with the same non-answer,
/// when the right next step differs for each.
///
/// Reading the invitation deliberately works **signed out** — the page has to
/// be able to say "sign in as ola@example.com" before anyone has signed in.
/// The link is not a credential: it identifies which invitation is being
/// answered and grants nothing. Accepting requires a verified identity for the
/// invited address, which is what stops a forwarded email becoming account
/// access.
class InvitePage extends StatefulWidget {
  const InvitePage({super.key, required this.token});

  final String token;

  @override
  State<InvitePage> createState() => _InvitePageState();
}

class _InvitePageState extends State<InvitePage> {
  final _client = buildAuthClient();
  late Future<InvitationInfo> _invitation;

  bool _busy = false;

  /// Set when the server refused because the signed-in user does not hold the
  /// invited address. Kept separate from the invitation's own state: the
  /// invitation is still perfectly valid, it is the *person* that is wrong.
  bool _wrongIdentity = false;
  String? _joined;

  @override
  void initState() {
    super.initState();
    _invitation = _client.invitation(widget.token);
  }

  Future<void> _accept(InvitationInfo invitation) async {
    final l = AppLocalizations.of(context)!;
    setState(() {
      _busy = true;
      _wrongIdentity = false;
    });
    try {
      final token = await AuthService.instance.accessToken();
      if (token == null) return;
      await _client.acceptInvitation(widget.token, token: token);
      if (mounted) {
        setState(() => _joined = invitation.organisation ?? '');
      }
    } on AuthApiException catch (e) {
      if (!mounted) return;
      if (e.reason == 'wrong_identity') {
        setState(() => _wrongIdentity = true);
      } else {
        // Any other refusal changed the invitation's state underneath us —
        // withdrawn while the page was open, say. Re-read rather than
        // guessing, so the message matches what is now true.
        setState(() => _invitation = _client.invitation(widget.token));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.accountActionFailed)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l.inviteTitle)),
      body: FutureBuilder<InvitationInfo>(
        future: _invitation,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _message(context, l.inviteStateNotFound);
          }
          return _body(context, l, snapshot.data!);
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    AppLocalizations l,
    InvitationInfo invitation,
  ) {
    if (_joined != null) {
      return _message(context, l.inviteAccepted(_joined!));
    }

    // Every non-pending state named individually. "Withdrawn" reported as
    // "expired" would send the invitee to ask for a fresh link that is never
    // coming; "expired" reported as "withdrawn" would make them think they
    // were dropped.
    if (!invitation.isPending) {
      return _message(context, switch (invitation.state) {
        'accepted' => l.inviteStateAccepted,
        'withdrawn' => l.inviteStateWithdrawn,
        'expired' => l.inviteStateExpired,
        'organisation_deleted' => l.inviteStateOrganisationDeleted,
        _ => l.inviteStateNotFound,
      });
    }

    final signedIn = AuthService.isInstalled && AuthService.instance.isSignedIn;
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          l.inviteJoinPrompt(
            invitation.inviterName ?? '',
            invitation.organisation ?? '',
            roleLabel(l, invitation.role),
          ),
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),

        if (_wrongIdentity) ...[
          // Both remedies, because the invitee can act on either and neither
          // is obvious from the refusal alone.
          Text(
            l.inviteWrongIdentity(
              invitation.email,
              invitation.organisation ?? '',
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 16),
        ],

        if (!signedIn) ...[
          // Naming the address is what makes this actionable — "sign in to
          // accept" alone leaves the recipient guessing which of their
          // addresses was invited.
          Text(l.inviteSignInToAccept(invitation.email)),
          const SizedBox(height: 16),
          // **Said, not hidden.** Everywhere else an unavailable sign-in is
          // simply absent, but somebody here followed an invitation link and
          // is looking for the button. Removing it would read as the
          // invitation being broken, which is the one thing it is not.
          if (AuthService.isInstalled && !AuthService.instance.authAvailable)
            InlineMessage(
              message: AppLocalizations.of(context)!.signInUnavailable,
              tone: MessageTone.info,
            )
          else
            FilledButton(
              onPressed: AuthService.isInstalled
                  ? () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => SignInPage(
                          // Coming back to a page that still says "sign in to
                          // accept" would be the wrong answer to a completed
                          // sign-in.
                          onSignedIn: () => setState(() {}),
                        ),
                      ),
                    )
                  : null,
              child: Text(AppLocalizations.of(context)!.signInEntry),
            ),
        ] else
          FilledButton(
            onPressed: _busy ? null : () => _accept(invitation),
            child: _busy
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l.inviteAcceptAction),
          ),
      ],
    );
  }

  Widget _message(BuildContext context, String text) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );
}
