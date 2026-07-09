// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'drill_variable.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$VariableLocation {

 String get place;@NullableLatLngJsonConverter() LatLng? get position;
/// Create a copy of VariableLocation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VariableLocationCopyWith<VariableLocation> get copyWith => _$VariableLocationCopyWithImpl<VariableLocation>(this as VariableLocation, _$identity);

  /// Serializes this VariableLocation to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VariableLocation&&(identical(other.place, place) || other.place == place)&&(identical(other.position, position) || other.position == position));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,place,position);

@override
String toString() {
  return 'VariableLocation(place: $place, position: $position)';
}


}

/// @nodoc
abstract mixin class $VariableLocationCopyWith<$Res>  {
  factory $VariableLocationCopyWith(VariableLocation value, $Res Function(VariableLocation) _then) = _$VariableLocationCopyWithImpl;
@useResult
$Res call({
 String place,@NullableLatLngJsonConverter() LatLng? position
});




}
/// @nodoc
class _$VariableLocationCopyWithImpl<$Res>
    implements $VariableLocationCopyWith<$Res> {
  _$VariableLocationCopyWithImpl(this._self, this._then);

  final VariableLocation _self;
  final $Res Function(VariableLocation) _then;

/// Create a copy of VariableLocation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? place = null,Object? position = freezed,}) {
  return _then(_self.copyWith(
place: null == place ? _self.place : place // ignore: cast_nullable_to_non_nullable
as String,position: freezed == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as LatLng?,
  ));
}

}


/// Adds pattern-matching-related methods to [VariableLocation].
extension VariableLocationPatterns on VariableLocation {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VariableLocation value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VariableLocation() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VariableLocation value)  $default,){
final _that = this;
switch (_that) {
case _VariableLocation():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VariableLocation value)?  $default,){
final _that = this;
switch (_that) {
case _VariableLocation() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String place, @NullableLatLngJsonConverter()  LatLng? position)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VariableLocation() when $default != null:
return $default(_that.place,_that.position);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String place, @NullableLatLngJsonConverter()  LatLng? position)  $default,) {final _that = this;
switch (_that) {
case _VariableLocation():
return $default(_that.place,_that.position);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String place, @NullableLatLngJsonConverter()  LatLng? position)?  $default,) {final _that = this;
switch (_that) {
case _VariableLocation() when $default != null:
return $default(_that.place,_that.position);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VariableLocation implements VariableLocation {
  const _VariableLocation({this.place = '', @NullableLatLngJsonConverter() this.position});
  factory _VariableLocation.fromJson(Map<String, dynamic> json) => _$VariableLocationFromJson(json);

@override@JsonKey() final  String place;
@override@NullableLatLngJsonConverter() final  LatLng? position;

/// Create a copy of VariableLocation
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VariableLocationCopyWith<_VariableLocation> get copyWith => __$VariableLocationCopyWithImpl<_VariableLocation>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VariableLocationToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VariableLocation&&(identical(other.place, place) || other.place == place)&&(identical(other.position, position) || other.position == position));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,place,position);

@override
String toString() {
  return 'VariableLocation(place: $place, position: $position)';
}


}

/// @nodoc
abstract mixin class _$VariableLocationCopyWith<$Res> implements $VariableLocationCopyWith<$Res> {
  factory _$VariableLocationCopyWith(_VariableLocation value, $Res Function(_VariableLocation) _then) = __$VariableLocationCopyWithImpl;
@override @useResult
$Res call({
 String place,@NullableLatLngJsonConverter() LatLng? position
});




}
/// @nodoc
class __$VariableLocationCopyWithImpl<$Res>
    implements _$VariableLocationCopyWith<$Res> {
  __$VariableLocationCopyWithImpl(this._self, this._then);

  final _VariableLocation _self;
  final $Res Function(_VariableLocation) _then;

/// Create a copy of VariableLocation
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? place = null,Object? position = freezed,}) {
  return _then(_VariableLocation(
place: null == place ? _self.place : place // ignore: cast_nullable_to_non_nullable
as String,position: freezed == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as LatLng?,
  ));
}


}


/// @nodoc
mixin _$DrillVariable {

/// Slug, unique within the plan. Must match `^[a-z][a-z0-9_]*$`.
/// This is the reference key used in `{{var.<name>}}`.
 String get name;/// The global default value substituted when no scope overrides it,
/// canonically encoded per [type] (DESIGN-008 follow-up 11). Unused
/// (kept empty) when [type] is [VariableType.location] — that type's
/// value is [location].
 String get value;/// Optional description shown in the insertion picker.
 String? get hint;/// The declared value type (DESIGN-008 follow-up 11). Additive with a
/// back-compatible default: a 1.0–1.2 archive without the key — or one
/// with a type this client does not know — loads as [VariableType.string]
/// and behaves exactly as before typed variables existed.
@JsonKey(unknownEnumValue: VariableType.string) VariableType get type;/// Structured value used only when [type] is [VariableType.location]:
/// the place text plus the canonical `LatLng`. Additive (absent key
/// loads as null); ignored for every other [type].
 VariableLocation? get location;
/// Create a copy of DrillVariable
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DrillVariableCopyWith<DrillVariable> get copyWith => _$DrillVariableCopyWithImpl<DrillVariable>(this as DrillVariable, _$identity);

  /// Serializes this DrillVariable to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DrillVariable&&(identical(other.name, name) || other.name == name)&&(identical(other.value, value) || other.value == value)&&(identical(other.hint, hint) || other.hint == hint)&&(identical(other.type, type) || other.type == type)&&(identical(other.location, location) || other.location == location));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,value,hint,type,location);

@override
String toString() {
  return 'DrillVariable(name: $name, value: $value, hint: $hint, type: $type, location: $location)';
}


}

/// @nodoc
abstract mixin class $DrillVariableCopyWith<$Res>  {
  factory $DrillVariableCopyWith(DrillVariable value, $Res Function(DrillVariable) _then) = _$DrillVariableCopyWithImpl;
@useResult
$Res call({
 String name, String value, String? hint,@JsonKey(unknownEnumValue: VariableType.string) VariableType type, VariableLocation? location
});


$VariableLocationCopyWith<$Res>? get location;

}
/// @nodoc
class _$DrillVariableCopyWithImpl<$Res>
    implements $DrillVariableCopyWith<$Res> {
  _$DrillVariableCopyWithImpl(this._self, this._then);

  final DrillVariable _self;
  final $Res Function(DrillVariable) _then;

/// Create a copy of DrillVariable
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? value = null,Object? hint = freezed,Object? type = null,Object? location = freezed,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String,hint: freezed == hint ? _self.hint : hint // ignore: cast_nullable_to_non_nullable
as String?,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as VariableType,location: freezed == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as VariableLocation?,
  ));
}
/// Create a copy of DrillVariable
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VariableLocationCopyWith<$Res>? get location {
    if (_self.location == null) {
    return null;
  }

  return $VariableLocationCopyWith<$Res>(_self.location!, (value) {
    return _then(_self.copyWith(location: value));
  });
}
}


/// Adds pattern-matching-related methods to [DrillVariable].
extension DrillVariablePatterns on DrillVariable {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DrillVariable value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DrillVariable() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DrillVariable value)  $default,){
final _that = this;
switch (_that) {
case _DrillVariable():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DrillVariable value)?  $default,){
final _that = this;
switch (_that) {
case _DrillVariable() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String value,  String? hint, @JsonKey(unknownEnumValue: VariableType.string)  VariableType type,  VariableLocation? location)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DrillVariable() when $default != null:
return $default(_that.name,_that.value,_that.hint,_that.type,_that.location);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String value,  String? hint, @JsonKey(unknownEnumValue: VariableType.string)  VariableType type,  VariableLocation? location)  $default,) {final _that = this;
switch (_that) {
case _DrillVariable():
return $default(_that.name,_that.value,_that.hint,_that.type,_that.location);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String value,  String? hint, @JsonKey(unknownEnumValue: VariableType.string)  VariableType type,  VariableLocation? location)?  $default,) {final _that = this;
switch (_that) {
case _DrillVariable() when $default != null:
return $default(_that.name,_that.value,_that.hint,_that.type,_that.location);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DrillVariable implements DrillVariable {
  const _DrillVariable({required this.name, this.value = '', this.hint, @JsonKey(unknownEnumValue: VariableType.string) this.type = VariableType.string, this.location});
  factory _DrillVariable.fromJson(Map<String, dynamic> json) => _$DrillVariableFromJson(json);

/// Slug, unique within the plan. Must match `^[a-z][a-z0-9_]*$`.
/// This is the reference key used in `{{var.<name>}}`.
@override final  String name;
/// The global default value substituted when no scope overrides it,
/// canonically encoded per [type] (DESIGN-008 follow-up 11). Unused
/// (kept empty) when [type] is [VariableType.location] — that type's
/// value is [location].
@override@JsonKey() final  String value;
/// Optional description shown in the insertion picker.
@override final  String? hint;
/// The declared value type (DESIGN-008 follow-up 11). Additive with a
/// back-compatible default: a 1.0–1.2 archive without the key — or one
/// with a type this client does not know — loads as [VariableType.string]
/// and behaves exactly as before typed variables existed.
@override@JsonKey(unknownEnumValue: VariableType.string) final  VariableType type;
/// Structured value used only when [type] is [VariableType.location]:
/// the place text plus the canonical `LatLng`. Additive (absent key
/// loads as null); ignored for every other [type].
@override final  VariableLocation? location;

/// Create a copy of DrillVariable
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DrillVariableCopyWith<_DrillVariable> get copyWith => __$DrillVariableCopyWithImpl<_DrillVariable>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DrillVariableToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DrillVariable&&(identical(other.name, name) || other.name == name)&&(identical(other.value, value) || other.value == value)&&(identical(other.hint, hint) || other.hint == hint)&&(identical(other.type, type) || other.type == type)&&(identical(other.location, location) || other.location == location));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,value,hint,type,location);

@override
String toString() {
  return 'DrillVariable(name: $name, value: $value, hint: $hint, type: $type, location: $location)';
}


}

/// @nodoc
abstract mixin class _$DrillVariableCopyWith<$Res> implements $DrillVariableCopyWith<$Res> {
  factory _$DrillVariableCopyWith(_DrillVariable value, $Res Function(_DrillVariable) _then) = __$DrillVariableCopyWithImpl;
@override @useResult
$Res call({
 String name, String value, String? hint,@JsonKey(unknownEnumValue: VariableType.string) VariableType type, VariableLocation? location
});


@override $VariableLocationCopyWith<$Res>? get location;

}
/// @nodoc
class __$DrillVariableCopyWithImpl<$Res>
    implements _$DrillVariableCopyWith<$Res> {
  __$DrillVariableCopyWithImpl(this._self, this._then);

  final _DrillVariable _self;
  final $Res Function(_DrillVariable) _then;

/// Create a copy of DrillVariable
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? value = null,Object? hint = freezed,Object? type = null,Object? location = freezed,}) {
  return _then(_DrillVariable(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String,hint: freezed == hint ? _self.hint : hint // ignore: cast_nullable_to_non_nullable
as String?,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as VariableType,location: freezed == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as VariableLocation?,
  ));
}

/// Create a copy of DrillVariable
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VariableLocationCopyWith<$Res>? get location {
    if (_self.location == null) {
    return null;
  }

  return $VariableLocationCopyWith<$Res>(_self.location!, (value) {
    return _then(_self.copyWith(location: value));
  });
}
}

// dart format on
