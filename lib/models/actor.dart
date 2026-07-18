import 'package:freezed_annotation/freezed_annotation.dart';

part 'actor.freezed.dart';
part 'actor.g.dart';

@freezed
sealed class Actor with _$Actor {
  const factory Actor({
    required String uuid,
    required String realName,
    String? phone,
    @JsonKey(includeFromJson: false, includeToJson: false) String? notes,
  }) = _Actor;

  factory Actor.fromJson(Map<String, dynamic> json) => _$ActorFromJson(json);
}

extension ActorName on Actor {
  /// The actor's first name — the first whitespace-delimited token of
  /// [realName] — used where a compact marker label is wanted (the Spill
  /// tile/identity card's collapsed "(Fornavn)" parenthesis). Falls back to
  /// the full [realName] when it has no internal whitespace.
  String get firstName {
    final trimmed = realName.trim();
    final match = RegExp(r'\s').firstMatch(trimmed);
    return match == null ? trimmed : trimmed.substring(0, match.start);
  }
}
