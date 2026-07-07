// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'location.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Location {

 String get slug; String get label;@JsonKey(unknownEnumValue: LocationKind.other) LocationKind get kind; String get place;@NullableLatLngJsonConverter() LatLng? get position; String? get note;
/// Create a copy of Location
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LocationCopyWith<Location> get copyWith => _$LocationCopyWithImpl<Location>(this as Location, _$identity);

  /// Serializes this Location to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Location&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.label, label) || other.label == label)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.place, place) || other.place == place)&&(identical(other.position, position) || other.position == position)&&(identical(other.note, note) || other.note == note));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,slug,label,kind,place,position,note);

@override
String toString() {
  return 'Location(slug: $slug, label: $label, kind: $kind, place: $place, position: $position, note: $note)';
}


}

/// @nodoc
abstract mixin class $LocationCopyWith<$Res>  {
  factory $LocationCopyWith(Location value, $Res Function(Location) _then) = _$LocationCopyWithImpl;
@useResult
$Res call({
 String slug, String label,@JsonKey(unknownEnumValue: LocationKind.other) LocationKind kind, String place,@NullableLatLngJsonConverter() LatLng? position, String? note
});




}
/// @nodoc
class _$LocationCopyWithImpl<$Res>
    implements $LocationCopyWith<$Res> {
  _$LocationCopyWithImpl(this._self, this._then);

  final Location _self;
  final $Res Function(Location) _then;

/// Create a copy of Location
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? slug = null,Object? label = null,Object? kind = null,Object? place = null,Object? position = freezed,Object? note = freezed,}) {
  return _then(_self.copyWith(
slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as LocationKind,place: null == place ? _self.place : place // ignore: cast_nullable_to_non_nullable
as String,position: freezed == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as LatLng?,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Location].
extension LocationPatterns on Location {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Location value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Location() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Location value)  $default,){
final _that = this;
switch (_that) {
case _Location():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Location value)?  $default,){
final _that = this;
switch (_that) {
case _Location() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String slug,  String label, @JsonKey(unknownEnumValue: LocationKind.other)  LocationKind kind,  String place, @NullableLatLngJsonConverter()  LatLng? position,  String? note)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Location() when $default != null:
return $default(_that.slug,_that.label,_that.kind,_that.place,_that.position,_that.note);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String slug,  String label, @JsonKey(unknownEnumValue: LocationKind.other)  LocationKind kind,  String place, @NullableLatLngJsonConverter()  LatLng? position,  String? note)  $default,) {final _that = this;
switch (_that) {
case _Location():
return $default(_that.slug,_that.label,_that.kind,_that.place,_that.position,_that.note);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String slug,  String label, @JsonKey(unknownEnumValue: LocationKind.other)  LocationKind kind,  String place, @NullableLatLngJsonConverter()  LatLng? position,  String? note)?  $default,) {final _that = this;
switch (_that) {
case _Location() when $default != null:
return $default(_that.slug,_that.label,_that.kind,_that.place,_that.position,_that.note);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Location implements Location {
  const _Location({required this.slug, this.label = '', @JsonKey(unknownEnumValue: LocationKind.other) this.kind = LocationKind.other, this.place = '', @NullableLatLngJsonConverter() this.position, this.note});
  factory _Location.fromJson(Map<String, dynamic> json) => _$LocationFromJson(json);

@override final  String slug;
@override@JsonKey() final  String label;
@override@JsonKey(unknownEnumValue: LocationKind.other) final  LocationKind kind;
@override@JsonKey() final  String place;
@override@NullableLatLngJsonConverter() final  LatLng? position;
@override final  String? note;

/// Create a copy of Location
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LocationCopyWith<_Location> get copyWith => __$LocationCopyWithImpl<_Location>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LocationToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Location&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.label, label) || other.label == label)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.place, place) || other.place == place)&&(identical(other.position, position) || other.position == position)&&(identical(other.note, note) || other.note == note));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,slug,label,kind,place,position,note);

@override
String toString() {
  return 'Location(slug: $slug, label: $label, kind: $kind, place: $place, position: $position, note: $note)';
}


}

/// @nodoc
abstract mixin class _$LocationCopyWith<$Res> implements $LocationCopyWith<$Res> {
  factory _$LocationCopyWith(_Location value, $Res Function(_Location) _then) = __$LocationCopyWithImpl;
@override @useResult
$Res call({
 String slug, String label,@JsonKey(unknownEnumValue: LocationKind.other) LocationKind kind, String place,@NullableLatLngJsonConverter() LatLng? position, String? note
});




}
/// @nodoc
class __$LocationCopyWithImpl<$Res>
    implements _$LocationCopyWith<$Res> {
  __$LocationCopyWithImpl(this._self, this._then);

  final _Location _self;
  final $Res Function(_Location) _then;

/// Create a copy of Location
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? slug = null,Object? label = null,Object? kind = null,Object? place = null,Object? position = freezed,Object? note = freezed,}) {
  return _then(_Location(
slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as LocationKind,place: null == place ? _self.place : place // ignore: cast_nullable_to_non_nullable
as String,position: freezed == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as LatLng?,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
