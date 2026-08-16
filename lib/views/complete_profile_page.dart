import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/services/auth_service.dart';
import 'package:ringdrill/views/widgets/inline_message.dart';

/// Asked once, after the first sign-in, for the two names the app cannot
/// invent (DESIGN-015 §3.7).
///
/// **Neither can be derived, which is why this screen exists.** A provider
/// gives a full name or nothing; the code flow gives only an address. Guessing
/// a nickname from either produces "Kenneth" for a team with two of them, or
/// the local part of an email for anybody who typed a code. A plan that prints
/// the wrong name on a station board is worse than one that asked.
///
/// It appears after the first sign-in and after a first provider link, and
/// then never again — [AuthUser.needsNames] is false the moment both are set,
/// so this is a step, not a recurring nag.
///
/// **Skippable.** DESIGN-015 §5.1 is emphatic that an account is optional and
/// that nobody should be made to feel they broke something by arriving here.
/// A hard gate would also strand anyone who signed in mid-exercise to fetch a
/// plan. Skipping leaves the names unset and the account page carries the same
/// fields, so nothing is lost but the prompt.
class CompleteProfilePage extends StatefulWidget {
  const CompleteProfilePage({super.key, this.onDone});

  /// Called once the person is finished — saved or skipped. Lets the caller
  /// resume whatever the sign-in interrupted.
  final VoidCallback? onDone;

  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  final _full = TextEditingController();
  final _nickname = TextEditingController();

  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = AuthService.isInstalled
        ? AuthService.instance.state.user
        : null;
    // The address is the fallback account creation uses when a provider gave
    // no name. Pre-filling the box with it would make "enter your name" look
    // answered, so it starts empty.
    final display = user?.displayName ?? '';
    _full.text = (display == user?.email) ? '' : display;
    _nickname.text = user?.nickname ?? '';
  }

  @override
  void dispose() {
    _full.dispose();
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _save(AppLocalizations l) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthService.instance.updateNames(
        displayName: _full.text.trim(),
        nickname: _nickname.text.trim(),
      );
      if (!mounted) return;
      widget.onDone?.call();
      Navigator.of(context).maybePop();
    } catch (_) {
      if (mounted) setState(() => _error = l.accountActionFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final ready =
        _full.text.trim().isNotEmpty && _nickname.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.profileCompleteTitle),
        // Saving is an AppBar action, as on every other form in the app.
        actions: [
          FilledButton(
            onPressed: (!ready || _busy) ? null : () => _save(l),
            child: _busy
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l.save),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l.profileCompleteLead,
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 24),
                      // The same shape as the account page's, and the same bare
                      // decoration the form screens elsewhere use — this screen and
                      // that section ask for the identical two things, so looking
                      // different would be the odd part.
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _full,
                              enabled: !_busy,
                              autofocus: true,
                              textCapitalization: TextCapitalization.words,
                              decoration: InputDecoration(
                                labelText: l.accountFullNameLabel,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _nickname,
                              enabled: !_busy,
                              textCapitalization: TextCapitalization.words,
                              decoration: InputDecoration(
                                labelText: l.accountNicknameLabel,
                              ),
                              onChanged: (_) => setState(() {}),
                              onFieldSubmitted: (_) =>
                                  ready && !_busy ? _save(l) : null,
                            ),
                          ),
                        ],
                      ),
                      // Below the fields, as on the account page: a note on what
                      // was just asked for rather than a preamble to it.
                      const SizedBox(height: 12),
                      Text(
                        l.accountNamesHint,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        InlineMessage(message: _error!),
                      ],
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () {
                                widget.onDone?.call();
                                Navigator.of(context).maybePop();
                              },
                        child: Text(l.profileCompleteLater),
                      ),
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

/// Show [CompleteProfilePage] if this person still has names to fill in.
///
/// One helper rather than the check repeated at each success path, because
/// there are three ways to arrive signed in — the code, a provider, and the
/// emailed link — and a prompt that appeared after two of them would look like
/// a bug in the third.
///
/// Safe to call unconditionally: it returns immediately when the names are
/// already set, which is every sign-in after the first.
Future<void> promptForNamesIfNeeded(BuildContext context) async {
  if (!AuthService.isInstalled) return;
  final user = AuthService.instance.state.user;
  if (user == null || !user.needsNames) return;
  if (!context.mounted) return;
  await Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const CompleteProfilePage()));
}
