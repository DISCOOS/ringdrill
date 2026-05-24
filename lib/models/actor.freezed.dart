// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'actor.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Actor {

 String get uuid; String get realName; String? get phone; String? get notes;
/// Create a copy of Actor
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ActorCopyWith<Actor> get copyWith => _$ActorCopyWithImpl<Actor>(this as Actor, _$identity);

  /// Serializes this Actor to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Actor&&(identical(other.uuid, uuid) || other.uuid == uuid)&&(identical(other.realName, realName) || other.realName == realName)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.notes, notes) || other.notes == notes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,uuid,realName,phone,notes);

@override
String toString() {
  return 'Actor(uuid: $uuid, realName: $realName, phone: $phone, notes: $notes)';
}


}

/// @nodoc
abstract mixin class $ActorCopyWith<$Res>  {
  factory $ActorCopyWith(Actor value, $Res Function(Actor) _then) = _$ActorCopyWithImpl;
@useResult
$Res call({
 String uuid, String realName, String? phone, String? notes
});




}
/// @nodoc
class _$ActorCopyWithImpl<$Res>
    implements $ActorCopyWith<$Res> {
  _$ActorCopyWithImpl(this._self, this._then);

  final Actor _self;
  final $Res Function(Actor) _then;

/// Create a copy of Actor
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? uuid = null,Object? realName = null,Object? phone = freezed,Object? notes = freezed,}) {
  return _then(_self.copyWith(
uuid: null == uuid ? _self.uuid : uuid // ignore: cast_nullable_to_non_nullable
as String,realName: null == realName ? _self.realName : realName // ignore: cast_nullable_to_non_nullable
as String,phone: freezed == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Actor].
extension ActorPatterns on Actor {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Actor value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Actor() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Actor value)  $default,){
final _that = this;
switch (_that) {
case _Actor():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Actor value)?  $default,){
final _that = this;
switch (_that) {
case _Actor() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String uuid,  String realName,  String? phone,  String? notes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Actor() when $default != null:
return $default(_that.uuid,_that.realName,_that.phone,_that.notes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String uuid,  String realName,  String? phone,  String? notes)  $default,) {final _that = this;
switch (_that) {
case _Actor():
return $default(_that.uuid,_that.realName,_that.phone,_that.notes);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String uuid,  String realName,  String? phone,  String? notes)?  $default,) {final _that = this;
switch (_that) {
case _Actor() when $default != null:
return $default(_that.uuid,_that.realName,_that.phone,_that.notes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Actor implements Actor {
  const _Actor({required this.uuid, required this.realName, this.phone, this.notes});
  factory _Actor.fromJson(Map<String, dynamic> json) => _$ActorFromJson(json);

@override final  String uuid;
@override final  String realName;
@override final  String? phone;
@override final  String? notes;

/// Create a copy of Actor
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ActorCopyWith<_Actor> get copyWith => __$ActorCopyWithImpl<_Actor>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ActorToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Actor&&(identical(other.uuid, uuid) || other.uuid == uuid)&&(identical(other.realName, realName) || other.realName == realName)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.notes, notes) || other.notes == notes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,uuid,realName,phone,notes);

@override
String toString() {
  return 'Actor(uuid: $uuid, realName: $realName, phone: $phone, notes: $notes)';
}


}

/// @nodoc
abstract mixin class _$ActorCopyWith<$Res> implements $ActorCopyWith<$Res> {
  factory _$ActorCopyWith(_Actor value, $Res Function(_Actor) _then) = __$ActorCopyWithImpl;
@override @useResult
$Res call({
 String uuid, String realName, String? phone, String? notes
});




}
/// @nodoc
class __$ActorCopyWithImpl<$Res>
    implements _$ActorCopyWith<$Res> {
  __$ActorCopyWithImpl(this._self, this._then);

  final _Actor _self;
  final $Res Function(_Actor) _then;

/// Create a copy of Actor
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? uuid = null,Object? realName = null,Object? phone = freezed,Object? notes = freezed,}) {
  return _then(_Actor(
uuid: null == uuid ? _self.uuid : uuid // ignore: cast_nullable_to_non_nullable
as String,realName: null == realName ? _self.realName : realName // ignore: cast_nullable_to_non_nullable
as String,phone: freezed == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
