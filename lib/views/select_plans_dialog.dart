import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/views/dialog_widgets.dart';

/// Multi-select picker for choosing which plans go into a drill-library
/// download. Mirrors [ProgramPageControllerBase.selectExercises] in
/// `program_view.dart`: every plan starts checked, a "VELG ALLE"/"VELG
/// INGEN" row plus a "N av M valgt" counter sit above the list, and the
/// primary button is disabled until at least one plan is checked.
///
/// Returns the selected UUIDs, or `null` if the user cancels.
Future<List<String>?> showSelectPlansDialog(
  BuildContext context, {
  required List<Program> programs,
  required AppLocalizations localizations,
  required String title,
  required String actionLabel,
}) {
  final allUuids = programs.map((p) => p.uuid).toList();
  final selected = List<String>.from(allUuids);

  return showResponsiveSheetOrDialog<List<String>>(
    context,
    maximizeHeight: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          final headerLabelStyle = Theme.of(context).textTheme.titleSmall
              ?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              );
          return Padding(
            padding: EdgeInsets.only(
              left: 20.0,
              right: 20.0,
              top: 8.0,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20.0,
            ),
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 8.0),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          localizations.selectedOfTotal(
                            selected.length,
                            programs.length,
                          ),
                          style: headerLabelStyle,
                        ),
                      ),
                      TextButton(
                        onPressed: selected.length == programs.length
                            ? null
                            : () {
                                setState(() {
                                  selected
                                    ..clear()
                                    ..addAll(allUuids);
                                });
                              },
                        child: Text(localizations.selectAll),
                      ),
                      TextButton(
                        onPressed: selected.isEmpty
                            ? null
                            : () {
                                setState(() => selected.clear());
                              },
                        child: Text(localizations.selectNone),
                      ),
                    ],
                  ),
                  const Divider(height: 16.0),
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: programs.length,
                      itemBuilder: (context, index) {
                        final program = programs[index];
                        final uuid = program.uuid;
                        final checked = selected.contains(uuid);
                        void toggle() {
                          setState(() {
                            if (checked) {
                              selected.remove(uuid);
                            } else {
                              selected.add(uuid);
                            }
                          });
                        }

                        return ListTile(
                          leading: Switch.adaptive(
                            value: checked,
                            onChanged: (_) => toggle(),
                          ),
                          title: Text(program.name),
                          subtitle: Text(
                            '${program.exercises.length} '
                            '${localizations.exercise(program.exercises.length).toLowerCase()}',
                          ),
                          onTap: toggle,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20.0),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: headerLabelStyle,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(width: 12.0),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(localizations.cancel),
                      ),
                      const SizedBox(width: 8.0),
                      FilledButton(
                        onPressed: selected.isEmpty
                            ? null
                            : () => Navigator.pop(
                                context,
                                List<String>.from(selected),
                              ),
                        child: Text(actionLabel),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8.0),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
