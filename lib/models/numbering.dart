import 'package:freezed_annotation/freezed_annotation.dart';

/// How a station/markør label combines the exercise number with the
/// sub-index. Add a value plus a `switch` arm in [Numbering.station] to
/// introduce a new format — that is the whole extension surface.
enum StationNumberFormat {
  @JsonValue('dotted')
  dotted, // "1.2"
  @JsonValue('alpha')
  alpha, // "1a"
}

/// How a standalone exercise number renders. Only [hash] exists today.
enum ExerciseNumberFormat {
  @JsonValue('hash')
  hash, // "#1"
}

class Numbering {
  const Numbering._();

  static String exercise(ExerciseNumberFormat f, int number) => switch (f) {
    ExerciseNumberFormat.hash => '#$number',
  };

  static String station(
    StationNumberFormat f, {
    required int exerciseNumber,
    required int stationIndex, // 0-based
  }) => switch (f) {
    StationNumberFormat.dotted => '$exerciseNumber.${stationIndex + 1}',
    StationNumberFormat.alpha => '$exerciseNumber${alpha(stationIndex)}',
  };

  /// Bijective base-26: 0 -> a, 25 -> z, 26 -> aa, 27 -> ab, ...
  /// Fixes the overflow past 'z' that the old per-brief letter helper had.
  static String alpha(int index) {
    var i = index;
    final buf = StringBuffer();
    while (i >= 0) {
      buf.write(String.fromCharCode('a'.codeUnitAt(0) + i % 26));
      i = i ~/ 26 - 1;
    }
    return buf.toString().split('').reversed.join();
  }
}
