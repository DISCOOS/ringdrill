import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';

class EditSectionHint extends StatelessWidget {
  const EditSectionHint({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Icon(
          Icons.edit,
          size: 13,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 5),
        Text(
          l10n.tapSectionToEditHint,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
