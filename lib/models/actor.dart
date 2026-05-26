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
