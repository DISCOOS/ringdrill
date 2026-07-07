import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/models/lat_lng_converter.dart';

part 'role_play.freezed.dart';
part 'role_play.g.dart';

@freezed
sealed class RolePlay with _$RolePlay {
  const factory RolePlay({
    required String uuid,
    required int index,
    required String exerciseUuid,
    required String name,
    int? age,
    String? gender,
    String? signalement,
    @JsonKey(includeFromJson: false, includeToJson: false) String? background,
    @JsonKey(includeFromJson: false, includeToJson: false) String? behavior,
    int? stationIndex,
    @NullableLatLngJsonConverter() LatLng? position,
    String? actorUuid,
    /// Slug of a [Person] on this roleplay's station (ADR-0047,
    /// DESIGN-009). Nullable on the wire: "mandatory" is an editor-level
    /// invariant for newly authored/edited roleplays, not a wire
    /// constraint — a legacy roleplay with `personRef == null` still
    /// loads and renders from its own identity fields above, which are
    /// never emptied when a personRef is set (they hold the effective,
    /// denormalized identity).
    String? personRef,
    // Markdown brief fields — stored as roleplays/<uuid>/<field>.md, not in JSON.
    @JsonKey(includeFromJson: false, includeToJson: false) String? propsMd,
  }) = _RolePlay;

  factory RolePlay.fromJson(Map<String, dynamic> json) =>
      _$RolePlayFromJson(json);
}
