/// Which of the drill player's three peer modes a surface is showing
/// (ADR-0056): the exercise itself, one of its stations, or one of its
/// roleplays.
///
/// One concept serves two jobs, which is why it is a type rather than a pair
/// of arguments:
/// - the mini bar renders the matching badge from it (`ExerciseNumberBadge` /
///   `StationNumberBadge` / `RoleNumberBadge`) in a single place, instead of
///   each host computing its own label, and
/// - the badge's picker scopes its contents to it — siblings of the current
///   mode's type, so the picker always lists the kind of thing the surface is
///   currently showing.
///
/// Sealed, so adding a fourth mode is a compile error at every place that has
/// to handle it rather than a silently-wrong default.
sealed class PlayerMode {
  const PlayerMode();
}

class ExercisePlayerMode extends PlayerMode {
  const ExercisePlayerMode();
}

class StationPlayerMode extends PlayerMode {
  const StationPlayerMode(this.stationIndex);

  /// 0-based, matching `Station.index` and `StationSheetTarget.stationIndex`.
  final int stationIndex;
}

class RolePlayerMode extends PlayerMode {
  const RolePlayerMode(this.rolePlayUuid);

  final String rolePlayUuid;
}
