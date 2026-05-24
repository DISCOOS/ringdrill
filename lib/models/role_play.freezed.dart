// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'role_play.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RolePlay {

 String get uuid; int get index; String get exerciseUuid; String get name; int? get age; String? get signalement; String? get background; String? get behavior; int? get stationIndex;@NullableLatLngJsonConverter() LatLng? get position; String? get actorUuid;
/// Create a copy of RolePlay
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RolePlayCopyWith<RolePlay> get copyWith => _$RolePlayCopyWithImpl<RolePlay>(this as RolePlay, _$identity);

  /// Serializes this RolePlay to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RolePlay&&(identical(other.uuid, uuid) || other.uuid == uuid)&&(identical(other.index, index) || other.index == index)&&(identical(other.exerciseUuid, exerciseUuid) || other.exerciseUuid == exerciseUuid)&&(identical(other.name, name) || other.name == name)&&(identical(other.age, age) || other.age == age)&&(identical(other.signalement, signalement) || other.signalement == signalement)&&(identical(other.background, background) || other.background == background)&&(identical(other.behavior, behavior) || other.behavior == behavior)&&(identical(other.stationIndex, stationIndex) || other.stationIndex == stationIndex)&&(identical(other.position, position) || other.position == position)&&(identical(other.actorUuid, actorUuid) || other.actorUuid == actorUuid));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,uuid,index,exerciseUuid,name,age,signalement,background,behavior,stationIndex,position,actorUuid);

@override
String toString() {
  return 'RolePlay(uuid: $uuid, index: $index, exerciseUuid: $exerciseUuid, name: $name, age: $age, signalement: $signalement, background: $background, behavior: $behavior, stationIndex: $stationIndex, position: $position, actorUuid: $actorUuid)';
}


}

/// @nodoc
abstract mixin class $RolePlayCopyWith<$Res>  {
  factory $RolePlayCopyWith(RolePlay value, $Res Function(RolePlay) _then) = _$RolePlayCopyWithImpl;
@useResult
$Res call({
 String uuid, int index, String exerciseUuid, String name, int? age, String? signalement, String? background, String? behavior, int? stationIndex,@NullableLatLngJsonConverter() LatLng? position, String? actorUuid
});




}
/// @nodoc
class _$RolePlayCopyWithImpl<$Res>
    implements $RolePlayCopyWith<$Res> {
  _$RolePlayCopyWithImpl(this._self, this._then);

  final RolePlay _self;
  final $Res Function(RolePlay) _then;

/// Create a copy of RolePlay
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? uuid = null,Object? index = null,Object? exerciseUuid = null,Object? name = null,Object? age = freezed,Object? signalement = freezed,Object? background = freezed,Object? behavior = freezed,Object? stationIndex = freezed,Object? position = freezed,Object? actorUuid = freezed,}) {
  return _then(_self.copyWith(
uuid: null == uuid ? _self.uuid : uuid // ignore: cast_nullable_to_non_nullable
as String,index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,exerciseUuid: null == exerciseUuid ? _self.exerciseUuid : exerciseUuid // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,age: freezed == age ? _self.age : age // ignore: cast_nullable_to_non_nullable
as int?,signalement: freezed == signalement ? _self.signalement : signalement // ignore: cast_nullable_to_non_nullable
as String?,background: freezed == background ? _self.background : background // ignore: cast_nullable_to_non_nullable
as String?,behavior: freezed == behavior ? _self.behavior : behavior // ignore: cast_nullable_to_non_nullable
as String?,stationIndex: freezed == stationIndex ? _self.stationIndex : stationIndex // ignore: cast_nullable_to_non_nullable
as int?,position: freezed == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as LatLng?,actorUuid: freezed == actorUuid ? _self.actorUuid : actorUuid // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [RolePlay].
extension RolePlayPatterns on RolePlay {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RolePlay value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RolePlay() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RolePlay value)  $default,){
final _that = this;
switch (_that) {
case _RolePlay():
return $default(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RolePlay value)?  $default,){
final _that = this;
switch (_that) {
case _RolePlay() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String uuid,  int index,  String exerciseUuid,  String name,  int? age,  String? signalement,  String? background,  String? behavior,  int? stationIndex, @NullableLatLngJsonConverter()  LatLng? position,  String? actorUuid)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RolePlay() when $default != null:
return $default(_that.uuid,_that.index,_that.exerciseUuid,_that.name,_that.age,_that.signalement,_that.background,_that.behavior,_that.stationIndex,_that.position,_that.actorUuid);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String uuid,  int index,  String exerciseUuid,  String name,  int? age,  String? signalement,  String? background,  String? behavior,  int? stationIndex, @NullableLatLngJsonConverter()  LatLng? position,  String? actorUuid)  $default,) {final _that = this;
switch (_that) {
case _RolePlay():
return $default(_that.uuid,_that.index,_that.exerciseUuid,_that.name,_that.age,_that.signalement,_that.background,_that.behavior,_that.stationIndex,_that.position,_that.actorUuid);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String uuid,  int index,  String exerciseUuid,  String name,  int? age,  String? signalement,  String? background,  String? behavior,  int? stationIndex, @NullableLatLngJsonConverter()  LatLng? position,  String? actorUuid)?  $default,) {final _that = this;
switch (_that) {
case _RolePlay() when $default != null:
return $default(_that.uuid,_that.index,_that.exerciseUuid,_that.name,_that.age,_that.signalement,_that.background,_that.behavior,_that.stationIndex,_that.position,_that.actorUuid);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RolePlay implements RolePlay {
  const _RolePlay({required this.uuid, required this.index, required this.exerciseUuid, required this.name, this.age, this.signalement, this.background, this.behavior, this.stationIndex, @NullableLatLngJsonConverter() this.position, this.actorUuid});
  factory _RolePlay.fromJson(Map<String, dynamic> json) => _$RolePlayFromJson(json);

@override final  String uuid;
@override final  int index;
@override final  String exerciseUuid;
@override final  String name;
@override final  int? age;
@override final  String? signalement;
@override final  String? background;
@override final  String? behavior;
@override final  int? stationIndex;
@override@NullableLatLngJsonConverter() final  LatLng? position;
@override final  String? actorUuid;

/// Create a copy of RolePlay
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RolePlayCopyWith<_RolePlay> get copyWith => __$RolePlayCopyWithImpl<_RolePlay>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RolePlayToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RolePlay&&(identical(other.uuid, uuid) || other.uuid == uuid)&&(identical(other.index, index) || other.index == index)&&(identical(other.exerciseUuid, exerciseUuid) || other.exerciseUuid == exerciseUuid)&&(identical(other.name, name) || other.name == name)&&(identical(other.age, age) || other.age == age)&&(identical(other.signalement, signalement) || other.signalement == signalement)&&(identical(other.background, background) || other.background == background)&&(identical(other.behavior, behavior) || other.behavior == behavior)&&(identical(other.stationIndex, stationIndex) || other.stationIndex == stationIndex)&&(identical(other.position, position) || other.position == position)&&(identical(other.actorUuid, actorUuid) || other.actorUuid == actorUuid));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,uuid,index,exerciseUuid,name,age,signalement,background,behavior,stationIndex,position,actorUuid);

@override
String toString() {
  return 'RolePlay(uuid: $uuid, index: $index, exerciseUuid: $exerciseUuid, name: $name, age: $age, signalement: $signalement, background: $background, behavior: $behavior, stationIndex: $stationIndex, position: $position, actorUuid: $actorUuid)';
}


}

/// @nodoc
abstract mixin class _$RolePlayCopyWith<$Res> implements $RolePlayCopyWith<$Res> {
  factory _$RolePlayCopyWith(_RolePlay value, $Res Function(_RolePlay) _then) = __$RolePlayCopyWithImpl;
@override @useResult
$Res call({
 String uuid, int index, String exerciseUuid, String name, int? age, String? signalement, String? background, String? behavior, int? stationIndex,@NullableLatLngJsonConverter() LatLng? position, String? actorUuid
});




}
/// @nodoc
class __$RolePlayCopyWithImpl<$Res>
    implements _$RolePlayCopyWith<$Res> {
  __$RolePlayCopyWithImpl(this._self, this._then);

  final _RolePlay _self;
  final $Res Function(_RolePlay) _then;

/// Create a copy of RolePlay
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? uuid = null,Object? index = null,Object? exerciseUuid = null,Object? name = null,Object? age = freezed,Object? signalement = freezed,Object? background = freezed,Object? behavior = freezed,Object? stationIndex = freezed,Object? position = freezed,Object? actorUuid = freezed,}) {
  return _then(_RolePlay(
uuid: null == uuid ? _self.uuid : uuid // ignore: cast_nullable_to_non_nullable
as String,index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,exerciseUuid: null == exerciseUuid ? _self.exerciseUuid : exerciseUuid // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,age: freezed == age ? _self.age : age // ignore: cast_nullable_to_non_nullable
as int?,signalement: freezed == signalement ? _self.signalement : signalement // ignore: cast_nullable_to_non_nullable
as String?,background: freezed == background ? _self.background : background // ignore: cast_nullable_to_non_nullable
as String?,behavior: freezed == behavior ? _self.behavior : behavior // ignore: cast_nullable_to_non_nullable
as String?,stationIndex: freezed == stationIndex ? _self.stationIndex : stationIndex // ignore: cast_nullable_to_non_nullable
as int?,position: freezed == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as LatLng?,actorUuid: freezed == actorUuid ? _self.actorUuid : actorUuid // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
