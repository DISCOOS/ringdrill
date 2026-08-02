/// The parallel-group editor for `mode: split` (ADR-0062), mockup panels 7 and 7b.
///
/// Follows the section pattern the entity forms already use — `LocationsSection` and
/// `PersonsSection`: a card per item, "+ Ny …" to add, swipe-to-dismiss behind
/// `confirmDestructive` to remove, and presentation only. The caller owns the list and
/// persists it on save, which is what keeps the editor honest about a form that
/// rebuilds its exercise from its inputs.
///
/// Choosing a station and choosing a team both go through [showRingdrillPicker]
/// (ADR-0049), the app's one "pick from a list" surface. Nothing here is a new
/// control: a group is a card, a station is a row, a team is an `InputChip` with the
/// delete affordance Material already gives it.
///
/// The two rules from ADR-0062 are shown where they are broken rather than only at
/// build time, with the same wording `analyze` uses — a collision is an error, an
/// unplaced team a warning, and the difference is visible.
library;

import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/numbering.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/models/team.dart';
import 'package:ringdrill/views/dialog_widgets.dart';
import 'package:ringdrill/views/widgets/card_section_header.dart';
import 'package:ringdrill/views/widgets/ringdrill_picker.dart';

class ExerciseGroupsSection extends StatelessWidget {
  const ExerciseGroupsSection({
    super.key,
    required this.groups,
    required this.stations,
    required this.teams,
    required this.numberOfTeams,
    required this.exerciseNumber,
    required this.stationNumberFormat,
    required this.onChanged,
  });

  /// One entry per round, in order.
  final List<ExerciseGroup> groups;

  final List<Station> stations;

  /// The plan's teams, for their names. Shorter than [numberOfTeams] when the plan
  /// has not named them all, so a team beyond it is shown by its number.
  final List<Team> teams;

  final int numberOfTeams;
  final int exerciseNumber;
  final StationNumberFormat stationNumberFormat;

  final ValueChanged<List<ExerciseGroup>> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CardSectionHeader(
          icon: Icons.call_split,
          title: l10n.exerciseGroupsSection,
        ),
        if (groups.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
              l10n.exerciseGroupsEmpty,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        for (var g = 0; g < groups.length; g++) _groupCard(context, l10n, g),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: TextButton.icon(
            onPressed: () =>
                onChanged([...groups, const ExerciseGroup(stations: [])]),
            icon: const Icon(Icons.add),
            label: Text(l10n.exerciseGroupAdd),
          ),
        ),
      ],
    );
  }

  Widget _groupCard(BuildContext context, AppLocalizations l10n, int g) {
    final theme = Theme.of(context);
    final group = groups[g];
    final placed = _placement(group);

    return Dismissible(
      key: ValueKey('exercise-group-$g'),
      direction: DismissDirection.endToStart,
      background: ColoredBox(
        color: theme.colorScheme.errorContainer,
        child: const Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.delete_outline),
          ),
        ),
      ),
      confirmDismiss: (_) => confirmDestructive(
        context,
        title: l10n.exerciseGroupRemove,
        message: l10n.exerciseGroupRemoveMessage,
        confirmLabel: l10n.exerciseGroupRemove,
      ),
      onDismissed: (_) => onChanged([...groups]..removeAt(g)),
      child: Card(
        margin: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              dense: true,
              // A group *is* a round, which is the whole reason the round count is
              // derived in this mode.
              title: Text('${l10n.round(1)} ${g + 1}'),
              trailing: TextButton.icon(
                onPressed: () => _addStation(context, l10n, g),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.exerciseGroupAddStation),
              ),
            ),
            if (group.stations.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  l10n.exerciseGroupNoStations,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            for (var i = 0; i < group.stations.length; i++)
              _stationRow(context, l10n, g, i, placed),
            ..._diagnostics(context, l10n, group, placed),
          ],
        ),
      ),
    );
  }

  Widget _stationRow(
    BuildContext context,
    AppLocalizations l10n,
    int g,
    int i,
    Map<int, int> placed,
  ) {
    final theme = Theme.of(context);
    final slot = groups[g].stations[i];
    final station = _stationAt(slot.stationIndex);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                Numbering.station(
                  stationNumberFormat,
                  exerciseNumber: exerciseNumber,
                  stationIndex: slot.stationIndex,
                ),
                style: theme.textTheme.labelMedium?.copyWith(
                  fontFamily: 'monospace',
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  station?.name ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              IconButton(
                tooltip: l10n.delete,
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => _replaceGroup(
                  g,
                  ExerciseGroup(stations: [...groups[g].stations]..removeAt(i)),
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final team in slot.teams)
                InputChip(
                  label: Text(_teamName(l10n, team)),
                  // Marked where it is also somewhere else in this group: the
                  // stations run at once, so both placements are wrong together and
                  // the author is who knows which to drop.
                  isEnabled: true,
                  selected: false,
                  side: (placed[team] ?? 0) > 1
                      ? BorderSide(color: theme.colorScheme.error)
                      : null,
                  labelStyle: (placed[team] ?? 0) > 1
                      ? TextStyle(color: theme.colorScheme.error)
                      : null,
                  // Explicit rather than the theme's default glyph, so the
                  // affordance is the × the mockup draws and does not shift with the
                  // Material version.
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () => _replaceSlot(
                    g,
                    i,
                    GroupSlot(
                      stationIndex: slot.stationIndex,
                      teams: [...slot.teams]..remove(team),
                    ),
                  ),
                ),
              ActionChip(
                avatar: const Icon(Icons.add, size: 16),
                label: Text(l10n.exerciseGroupAddTeam),
                onPressed: () => _addTeam(context, l10n, g, i),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The two rules, said where they are broken (ADR-0062). Same wording as
  /// `analyze`, so the app and a hand-written document do not disagree about what is
  /// wrong.
  List<Widget> _diagnostics(
    BuildContext context,
    AppLocalizations l10n,
    ExerciseGroup group,
    Map<int, int> placed,
  ) {
    final theme = Theme.of(context);
    final collisions = placed.entries
        .where((e) => e.value > 1)
        .map((e) => e.key);
    final unplaced = [
      for (var team = 0; team < numberOfTeams; team++)
        if (!placed.containsKey(team)) team,
    ];
    return [
      for (final team in collisions)
        _note(
          theme,
          l10n.exerciseGroupTeamCollision(_teamName(l10n, team)),
          error: true,
        ),
      // A warning, not an error: holding a team back is legitimate, and with groups
      // of unequal size it is also easy to do by accident.
      if (unplaced.isNotEmpty && group.stations.isNotEmpty)
        _note(
          theme,
          l10n.exerciseGroupTeamsUnplaced(
            unplaced.map((t) => _teamName(l10n, t)).join(', '),
          ),
          error: false,
        ),
    ];
  }

  Widget _note(ThemeData theme, String text, {required bool error}) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          error ? Icons.error_outline : Icons.info_outline,
          size: 16,
          color: error ? theme.colorScheme.error : theme.colorScheme.tertiary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: error
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    ),
  );

  /// How many stations of [group] each team appears on. More than one is the
  /// collision; absent is the unplaced case.
  Map<int, int> _placement(ExerciseGroup group) {
    final counts = <int, int>{};
    for (final slot in group.stations) {
      for (final team in slot.teams) {
        counts[team] = (counts[team] ?? 0) + 1;
      }
    }
    return counts;
  }

  Station? _stationAt(int index) {
    for (final station in stations) {
      if (station.index == index) return station;
    }
    return null;
  }

  /// A team's name, or its number where the plan has not named it — the same
  /// fallback the rest of the app makes for a generated team.
  String _teamName(AppLocalizations l10n, int index) =>
      index < teams.length ? teams[index].name : '${l10n.team(1)} ${index + 1}';

  void _replaceGroup(int g, ExerciseGroup group) =>
      onChanged([...groups]..[g] = group);

  void _replaceSlot(int g, int i, GroupSlot slot) => _replaceGroup(
    g,
    ExerciseGroup(stations: [...groups[g].stations]..[i] = slot),
  );

  Future<void> _addStation(
    BuildContext context,
    AppLocalizations l10n,
    int g,
  ) async {
    // Only stations not already in this group: one station cannot run twice at once,
    // and offering it again would be offering a mistake.
    final taken = groups[g].stations.map((s) => s.stationIndex).toSet();
    final available = stations.where((s) => !taken.contains(s.index)).toList();
    if (available.isEmpty) return;
    final chosen = await showRingdrillPicker<Station>(
      context: context,
      title: l10n.exerciseGroupAddStation,
      items: available,
      itemBuilder: (context, station, onTap) => ListTile(
        title: Text(station.name),
        subtitle: Text(
          Numbering.station(
            stationNumberFormat,
            exerciseNumber: exerciseNumber,
            stationIndex: station.index,
          ),
        ),
        onTap: onTap,
      ),
      searchText: (station) => station.name,
    );
    if (chosen == null) return;
    _replaceGroup(
      g,
      ExerciseGroup(
        stations: [
          ...groups[g].stations,
          GroupSlot(stationIndex: chosen.index),
        ],
      ),
    );
  }

  Future<void> _addTeam(
    BuildContext context,
    AppLocalizations l10n,
    int g,
    int i,
  ) async {
    // Offer only teams not yet placed in this group, so the collision the rules
    // forbid is hard to make in the first place — the check stays because a document
    // can still be written by hand.
    final placed = _placement(groups[g]).keys.toSet();
    final available = [
      for (var team = 0; team < numberOfTeams; team++)
        if (!placed.contains(team)) team,
    ];
    if (available.isEmpty) return;
    final chosen = await showRingdrillPicker<int>(
      context: context,
      title: l10n.exerciseGroupAddTeam,
      items: available,
      itemBuilder: (context, team, onTap) =>
          ListTile(title: Text(_teamName(l10n, team)), onTap: onTap),
    );
    if (chosen == null) return;
    final slot = groups[g].stations[i];
    _replaceSlot(
      g,
      i,
      GroupSlot(
        stationIndex: slot.stationIndex,
        teams: [...slot.teams, chosen],
      ),
    );
  }
}
