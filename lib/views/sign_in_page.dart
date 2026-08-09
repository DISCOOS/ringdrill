import 'package:flutter/material.dart';
import 'package:ringdrill/data/auth_client.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/services/auth_service.dart';

/// Signing in (DESIGN-015 §3.3, §5.1).
///
/// Two rules from the design shape everything here:
///
/// * **Signing in *is* getting an account.** ADR-0024 creates the personal
///   account at first sign-in, so this screen must never offer "sign in" and
///   "create an account" as separate choices — but it must *say* that an
///   account is being created. A thing made silently on your behalf is worse
///   than a thing you were told about, which is why the disclosure is on the
///   screen rather than in a help page.
/// * **An account is optional and stays optional.** Somebody who opened this
///   by accident must be able to leave believing nothing is wrong, so the
///   screen says so outright instead of implying a missing setup step.
///
/// The link and the code are the *same* challenge, redeemable either way
/// (§3.3). The copy avoids suggesting that using one forfeits the other,
/// because a person who taps the link on their phone and then types the code
/// on their laptop is doing something supported.
class SignInPage extends StatefulWidget {
  const SignInPage({super.key, this.onSignedIn});

  /// Invoked after a successful sign-in, before this page is popped. Lets a
  /// caller resume what the user was doing — accepting an invitation, say —
  /// rather than dropping them back on a screen with no explanation.
  final VoidCallback? onSignedIn;

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();

  /// Set once a challenge exists. Its presence is what moves the screen from
  /// "enter your address" to "enter the code" — a single field rather than a
  /// step counter, because there are only ever two steps.
  EmailChallenge? _challenge;
  String? _sentTo;

  bool _busy = false;
  String? _error;

  /// Discovered once when the screen opens. An empty list is the normal
  /// answer for a deployment with no providers configured, and renders as
  /// nothing at all — not as an empty section with a heading.
  late final Future<List<AuthProvider>> _providers = AuthService.isInstalled
      ? AuthService.instance.providers().catchError(
          // A discovery failure must not take the email path down with it.
          (_) => <AuthProvider>[],
        )
      : Future.value(const <AuthProvider>[]);

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  /// Map a server reason onto something a person can act on.
  ///
  /// Every branch here is a different remedy — wait, retype, ask for a new
  /// code, check the network. Collapsing them into one message would leave
  /// the user guessing which.
  String _messageFor(Object error, AppLocalizations l) {
    if (error is AuthApiException) {
      return switch (error.reason) {
        'expired' => l.signInCodeExpired,
        'too_many_attempts' => l.signInTooManyAttempts,
        'bad_code' => l.signInFailed,
        _ => error.status == null ? l.signInNetworkError : l.signInFailed,
      };
    }
    return l.signInNetworkError;
  }

  Future<void> _run(Future<void> Function() action, AppLocalizations l) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = _messageFor(e, l));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _start(AppLocalizations l) {
    final email = _emailController.text.trim();
    if (!email.contains('@') || email.length < 3) {
      setState(() => _error = l.signInEmailInvalid);
      return Future.value();
    }
    return _run(() async {
      final challenge = await AuthService.instance.startEmailSignIn(
        email,
        locale: Localizations.localeOf(context).languageCode == 'nb'
            ? 'nb'
            : 'en',
      );
      if (!mounted) return;
      setState(() {
        _challenge = challenge;
        _sentTo = email;
        // Under AUTH_MODE=mock the server returns the code, so a developer
        // can complete the flow with no mail provider. It is null in live —
        // there the response would be the credential.
        if (challenge.devCode != null) {
          _codeController.text = challenge.devCode!;
        }
      });
    }, l);
  }

  Future<void> _signInWith(AuthProvider provider, AppLocalizations l) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthService.instance.signInWithProvider(provider);
      if (!mounted) return;
      widget.onSignedIn?.call();
      Navigator.of(context).maybePop();
    } on SignInCancelled {
      // Closing the browser is an ordinary thing to do. Showing an error for
      // it would tell somebody they failed at deciding not to.
    } catch (e) {
      if (mounted) {
        // A reason means the *server* refused and said why — the callback
        // bounced back with it. No reason means we never got that far, which
        // is a network problem and a different thing to tell somebody.
        setState(
          () => _error = e is AuthApiException && e.reason != null
              ? l.signInProviderFailed
              : l.signInNetworkError,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify(AppLocalizations l) {
    final challenge = _challenge;
    if (challenge == null) return Future.value();
    return _run(() async {
      await AuthService.instance.completeSignIn(
        challengeId: challenge.challengeId,
        code: _codeController.text.trim(),
      );
      if (!mounted) return;
      widget.onSignedIn?.call();
      Navigator.of(context).maybePop();
    }, l);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final sent = _challenge != null;

    return Scaffold(
      appBar: AppBar(title: Text(l.signInTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // The disclosure sits above the field, not below the button: it
            // has to be read before the decision, not after it.
            Text(l.signInWhatYouGet, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 12),
            Text(
              l.signInOptional,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),

            // Providers first, email below: for most people the button they
            // recognise is the fast path, and DESIGN-015 §3.2 caps the list at
            // four so it stays a choice rather than a wall.
            FutureBuilder<List<AuthProvider>>(
              future: _providers,
              builder: (context, snapshot) {
                final providers = snapshot.data ?? const <AuthProvider>[];
                if (providers.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final provider in providers)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => _signInWith(provider, l),
                          child: Text(l.signInWithProvider(provider.label)),
                        ),
                      ),
                    const SizedBox(height: 8),
                    // Unemphatic on purpose: email is one option among
                    // several, not the fallback for people who failed at the
                    // real ones.
                    Text(
                      l.signInOrEmail,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),

            TextField(
              controller: _emailController,
              enabled: !sent && !_busy,
              autofocus: !sent,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: InputDecoration(
                labelText: l.signInEmailLabel,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => sent ? null : _start(l),
            ),

            if (sent) ...[
              const SizedBox(height: 16),
              Text(
                l.signInCodeSent(_sentTo ?? ''),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _codeController,
                enabled: !_busy,
                autofocus: true,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                decoration: InputDecoration(
                  labelText: l.signInCodeLabel,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _verify(l),
              ),
            ],

            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],

            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : () => sent ? _verify(l) : _start(l),
              child: _busy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(sent ? l.signInVerify : l.signInSendCode),
            ),

            if (sent)
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _challenge = null;
                        _codeController.clear();
                        _error = null;
                      }),
                child: Text(l.signInUseAnotherEmail),
              ),
          ],
        ),
      ),
    );
  }
}

/// Confirm before signing out.
///
/// The confirm exists to say what *stays*: signing out is not deleting an
/// account and not losing local plans (DESIGN-015 §5.1), and people reasonably
/// fear both.
Future<bool> confirmSignOut(BuildContext context) async {
  final l = AppLocalizations.of(context)!;
  final ok = await showAdaptiveDialog<bool>(
    context: context,
    builder: (context) => AlertDialog.adaptive(
      title: Text(l.signOutConfirmTitle),
      content: Text(l.signOutConfirmBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l.signOutAction),
        ),
      ],
    ),
  );
  return ok ?? false;
}
