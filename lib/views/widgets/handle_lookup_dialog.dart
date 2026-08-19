import 'package:flutter/material.dart';
import 'package:ringdrill/data/auth_client.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/services/auth_service.dart';
import 'package:ringdrill/views/account_page.dart' show buildAuthClient;
import 'package:ringdrill/views/widgets/inline_message.dart';

/// Name an account by its handle.
///
/// **The only way to reach an account you are not a member of.** A picker can
/// list the accounts you belong to and no others, so sharing a plan outward —
/// with the neighbouring team, with a district — has to go through a name the
/// other side can give you. That name is the handle, which the account page
/// now shows and offers to copy.
///
/// Handles are typed and ids are stored (ADR-0074): a handle can be changed by
/// its owner and an id never moves, so the lookup resolves one to the other
/// here rather than writing a name that may stop resolving. When the two
/// differ — somebody typed a name the account has since changed — it says so
/// rather than silently granting to something they did not name.
Future<AccountMembership?> showHandleLookupDialog(BuildContext context) {
  return showAdaptiveDialog<AccountMembership>(
    context: context,
    builder: (_) => const _HandleLookupDialog(),
  );
}

class _HandleLookupDialog extends StatefulWidget {
  const _HandleLookupDialog();

  @override
  State<_HandleLookupDialog> createState() => _HandleLookupDialogState();
}

class _HandleLookupDialogState extends State<_HandleLookupDialog> {
  final _controller = TextEditingController();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _lookUp() async {
    final l = AppLocalizations.of(context)!;
    final handle = _controller.text.trim();
    if (handle.isEmpty) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final token = AuthService.isInstalled
          ? await AuthService.instance.accessToken()
          : null;
      if (token == null) return;
      final account = await buildAuthClient().lookupHandle(
        handle,
        token: token,
      );
      if (!mounted) return;
      if (account == null) {
        setState(() => _error = l.publishSharedNotFound);
        return;
      }
      Navigator.of(context).pop(account);
    } catch (_) {
      // A lookup that failed and a name that does not exist are the same
      // answer to the person typing: nothing was found, try again.
      if (mounted) setState(() => _error = l.publishSharedNotFound);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    // Plain AlertDialog, not the adaptive one: on Apple platforms that renders
    // a CupertinoAlertDialog, which provides no Material ancestor for the text
    // field below.
    return AlertDialog(
      title: Text(l.publishSharedByHandle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            enabled: !_busy,
            decoration: InputDecoration(
              labelText: l.publishSharedHandleLabel,
              hintText: l.publishSharedHandleHelper,
            ),
            onSubmitted: (_) => _busy ? null : _lookUp(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            InlineMessage(message: _error!),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: _busy ? null : _lookUp,
          child: _busy
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l.publishSharedAdd),
        ),
      ],
    );
  }
}
