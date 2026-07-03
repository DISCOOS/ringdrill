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
mixin _$DrillVariable {

/// Slug, unique within the plan. Must match `^[a-z][a-z0-9_]*$`.
/// This is the reference key used in `{{var.<name>}}`.
 String get name;/// The global default value substituted when no scope overrides it.
 String get value;/// Optional description shown in the insertion picker.
 String? get hint;
/// Create a copy of DrillVariable
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DrillVariableCopyWith<DrillVariable> get copyWith => _$DrillVariableCopyWithImpl<DrillVariable>(this as DrillVariable, _$identity);

  /// Serializes this DrillVariable to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DrillVariable&&(identical(other.name, name) || other.name == name)&&(identical(other.value, value) || other.value == value)&&(identical(other.hint, hint) || other.hint == hint));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,value,hint);

@override
String toString() {
  return 'DrillVariable(name: $name, value: $value, hint: $hint)';
}


}

/// @nodoc
abstract mixin class $DrillVariableCopyWith<$Res>  {
  factory $DrillVariableCopyWith(DrillVariable value, $Res Function(DrillVariable) _then) = _$DrillVariableCopyWithImpl;
@useResult
$Res call({
 String name, String value, String? hint
});




}
/// @nodoc
class _$DrillVariableCopyWithImpl<$Res>
    implements $DrillVariableCopyWith<$Res> {
  _$DrillVariableCopyWithImpl(this._self, this._then);

  final DrillVariable _self;
  final $Res Function(DrillVariable) _then;

/// Create a copy of DrillVariable
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? value = null,Object? hint = freezed,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String,hint: freezed == hint ? _self.hint : hint // ignore: cast_nullable_to_non_nullable
as String?,
  ));
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String value,  String? hint)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DrillVariable() when $default != null:
return $default(_that.name,_that.value,_that.hint);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String value,  String? hint)  $default,) {final _that = this;
switch (_that) {
case _DrillVariable():
return $default(_that.name,_that.value,_that.hint);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String value,  String? hint)?  $default,) {final _that = this;
switch (_that) {
case _DrillVariable() when $default != null:
return $default(_that.name,_that.value,_that.hint);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DrillVariable implements DrillVariable {
  const _DrillVariable({required this.name, this.value = '', this.hint});
  factory _DrillVariable.fromJson(Map<String, dynamic> json) => _$DrillVariableFromJson(json);

/// Slug, unique within the plan. Must match `^[a-z][a-z0-9_]*$`.
/// This is the reference key used in `{{var.<name>}}`.
@override final  String name;
/// The global default value substituted when no scope overrides it.
@override@JsonKey() final  String value;
/// Optional description shown in the insertion picker.
@override final  String? hint;

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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DrillVariable&&(identical(other.name, name) || other.name == name)&&(identical(other.value, value) || other.value == value)&&(identical(other.hint, hint) || other.hint == hint));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,value,hint);

@override
String toString() {
  return 'DrillVariable(name: $name, value: $value, hint: $hint)';
}


}

/// @nodoc
abstract mixin class _$DrillVariableCopyWith<$Res> implements $DrillVariableCopyWith<$Res> {
  factory _$DrillVariableCopyWith(_DrillVariable value, $Res Function(_DrillVariable) _then) = __$DrillVariableCopyWithImpl;
@override @useResult
$Res call({
 String name, String value, String? hint
});




}
/// @nodoc
class __$DrillVariableCopyWithImpl<$Res>
    implements _$DrillVariableCopyWith<$Res> {
  __$DrillVariableCopyWithImpl(this._self, this._then);

  final _DrillVariable _self;
  final $Res Function(_DrillVariable) _then;

/// Create a copy of DrillVariable
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? value = null,Object? hint = freezed,}) {
  return _then(_DrillVariable(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String,hint: freezed == hint ? _self.hint : hint // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
