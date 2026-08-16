import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ringdrill/data/auth_client.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/services/auth_service.dart';
import 'package:ringdrill/views/complete_profile_page.dart';
import 'package:ringdrill/views/widgets/inline_message.dart';

/// Signing in from the link in the email (ADR-0080).
///
/// The link and the six-digit code are the **same challenge**, so this is the
/// other way to spend it. Whichever is used first wins and the other stops
/// working — a person who taps the link on their phone and then types the code
/// on their laptop will find the second attempt refused, and that is correct
/// rather than a bug.
///
/// **Whether it redeems on open depends on the surface, not on the code.**
///
/// * **Native app** — it redeems immediately. A universal link only resolves to
///   an installed app because a human tapped it; no mail scanner opens an iOS
///   app. Asking for a second confirmation would be ceremony protecting against
///   nothing.
/// * **Browser** — it waits for a button. Corporate mail security and
///   link-preview generators fetch URLs before anybody sees them, and a
///   challenge is single-use: redeeming on load hands the sign-in to the
///   scanner, and the person is told their link is "unknown or used". That
///   failure cannot be reproduced here, happens only to users at organisations
///   that scan their mail, and reads as a bug in RingDrill rather than a
///   property of their mail provider.
///
/// The asymmetry is the part most likely to be "tidied" into consistency later.
/// It is deliberate: the two surfaces have different adversaries.
class SignInLinkPage extends StatefulWidget {
  const SignInLinkPage({
    super.key,
    required this.challengeId,
    required this.code,
  });

  final String challengeId;
  final String code;

  @override
  State<SignInLinkPage> createState() => _SignInLinkPageState();
}

class _SignInLinkPageState extends State<SignInLinkPage> {
  bool _busy = false;
  bool _done = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // See the class comment: native redeems on open, the browser waits.
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _redeem());
    }
  }

  /// Map a server reason onto something a person can act on. Mirrors
  /// `SignInPage._messageFor`, because arriving by link does not change what
  /// went wrong or what to do about it.
  String _messageFor(Object error, AppLocalizations l) {
    if (error is AuthApiException) {
      return switch (error.reason) {
        'expired' => l.signInCodeExpired,
        'too_many_attempts' => l.signInTooManyAttempts,
        // The link was already spent — most often by the code having been
        // typed, or by the same link opened twice.
        'unknown_or_used' => l.signInLinkUsed,
        'bad_code' => l.signInCodeWrong,
        _ => error.status == null ? l.signInNetworkError : l.signInFailed,
      };
    }
    return l.signInNetworkError;
  }

  Future<void> _redeem() async {
    if (!AuthService.isInstalled) return;
    final l = AppLocalizations.of(context)!;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthService.instance.completeSignIn(
        challengeId: widget.challengeId,
        code: widget.code,
      );
      if (!mounted) return;
      setState(() => _done = true);
      await promptForNamesIfNeeded(context);
    } catch (e) {
      if (mounted) setState(() => _error = _messageFor(e, l));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l.signInLinkTitle)),
      body: SafeArea(
        child: Center(
          // Scrollable rather than a plain Column, so a short viewport — a
          // phone in landscape, a browser with the address bar showing — can
          // still reach the button rather than overflowing behind it.
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              // A card, as everywhere else a screen holds one short piece of
              // business. On a desktop-width browser the alternative is a
              // sentence and a button floating on an empty background, with
              // nothing to say where the content begins and the page ends.
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_done) ...[
                        Text(
                          l.signInLinkDone,
                          style: theme.textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: () => context.go('/'),
                          child: Text(l.signInLinkContinue),
                        ),
                      ] else ...[
                        Text(
                          l.signInLinkPrompt,
                          style: theme.textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _busy ? null : _redeem,
                          child: _busy
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(l.signInLinkAction),
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        InlineMessage(message: _error!),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
