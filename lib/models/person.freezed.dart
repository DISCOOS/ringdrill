// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'person.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Person {

 String get slug; String get name; int? get age; String? get gender; String? get signalement;/// References a [Location.slug] on the same station.
 String? get homeSlug; String? get notes;
/// Create a copy of Person
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PersonCopyWith<Person> get copyWith => _$PersonCopyWithImpl<Person>(this as Person, _$identity);

  /// Serializes this Person to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Person&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.name, name) || other.name == name)&&(identical(other.age, age) || other.age == age)&&(identical(other.gender, gender) || other.gender == gender)&&(identical(other.signalement, signalement) || other.signalement == signalement)&&(identical(other.homeSlug, homeSlug) || other.homeSlug == homeSlug)&&(identical(other.notes, notes) || other.notes == notes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,slug,name,age,gender,signalement,homeSlug,notes);

@override
String toString() {
  return 'Person(slug: $slug, name: $name, age: $age, gender: $gender, signalement: $signalement, homeSlug: $homeSlug, notes: $notes)';
}


}

/// @nodoc
abstract mixin class $PersonCopyWith<$Res>  {
  factory $PersonCopyWith(Person value, $Res Function(Person) _then) = _$PersonCopyWithImpl;
@useResult
$Res call({
 String slug, String name, int? age, String? gender, String? signalement, String? homeSlug, String? notes
});




}
/// @nodoc
class _$PersonCopyWithImpl<$Res>
    implements $PersonCopyWith<$Res> {
  _$PersonCopyWithImpl(this._self, this._then);

  final Person _self;
  final $Res Function(Person) _then;

/// Create a copy of Person
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? slug = null,Object? name = null,Object? age = freezed,Object? gender = freezed,Object? signalement = freezed,Object? homeSlug = freezed,Object? notes = freezed,}) {
  return _then(_self.copyWith(
slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,age: freezed == age ? _self.age : age // ignore: cast_nullable_to_non_nullable
as int?,gender: freezed == gender ? _self.gender : gender // ignore: cast_nullable_to_non_nullable
as String?,signalement: freezed == signalement ? _self.signalement : signalement // ignore: cast_nullable_to_non_nullable
as String?,homeSlug: freezed == homeSlug ? _self.homeSlug : homeSlug // ignore: cast_nullable_to_non_nullable
as String?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Person].
extension PersonPatterns on Person {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Person value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Person() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Person value)  $default,){
final _that = this;
switch (_that) {
case _Person():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Person value)?  $default,){
final _that = this;
switch (_that) {
case _Person() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String slug,  String name,  int? age,  String? gender,  String? signalement,  String? homeSlug,  String? notes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Person() when $default != null:
return $default(_that.slug,_that.name,_that.age,_that.gender,_that.signalement,_that.homeSlug,_that.notes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String slug,  String name,  int? age,  String? gender,  String? signalement,  String? homeSlug,  String? notes)  $default,) {final _that = this;
switch (_that) {
case _Person():
return $default(_that.slug,_that.name,_that.age,_that.gender,_that.signalement,_that.homeSlug,_that.notes);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String slug,  String name,  int? age,  String? gender,  String? signalement,  String? homeSlug,  String? notes)?  $default,) {final _that = this;
switch (_that) {
case _Person() when $default != null:
return $default(_that.slug,_that.name,_that.age,_that.gender,_that.signalement,_that.homeSlug,_that.notes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Person implements Person {
  const _Person({required this.slug, this.name = '', this.age, this.gender, this.signalement, this.homeSlug, this.notes});
  factory _Person.fromJson(Map<String, dynamic> json) => _$PersonFromJson(json);

@override final  String slug;
@override@JsonKey() final  String name;
@override final  int? age;
@override final  String? gender;
@override final  String? signalement;
/// References a [Location.slug] on the same station.
@override final  String? homeSlug;
@override final  String? notes;

/// Create a copy of Person
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PersonCopyWith<_Person> get copyWith => __$PersonCopyWithImpl<_Person>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PersonToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Person&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.name, name) || other.name == name)&&(identical(other.age, age) || other.age == age)&&(identical(other.gender, gender) || other.gender == gender)&&(identical(other.signalement, signalement) || other.signalement == signalement)&&(identical(other.homeSlug, homeSlug) || other.homeSlug == homeSlug)&&(identical(other.notes, notes) || other.notes == notes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,slug,name,age,gender,signalement,homeSlug,notes);

@override
String toString() {
  return 'Person(slug: $slug, name: $name, age: $age, gender: $gender, signalement: $signalement, homeSlug: $homeSlug, notes: $notes)';
}


}

/// @nodoc
abstract mixin class _$PersonCopyWith<$Res> implements $PersonCopyWith<$Res> {
  factory _$PersonCopyWith(_Person value, $Res Function(_Person) _then) = __$PersonCopyWithImpl;
@override @useResult
$Res call({
 String slug, String name, int? age, String? gender, String? signalement, String? homeSlug, String? notes
});




}
/// @nodoc
class __$PersonCopyWithImpl<$Res>
    implements _$PersonCopyWith<$Res> {
  __$PersonCopyWithImpl(this._self, this._then);

  final _Person _self;
  final $Res Function(_Person) _then;

/// Create a copy of Person
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? slug = null,Object? name = null,Object? age = freezed,Object? gender = freezed,Object? signalement = freezed,Object? homeSlug = freezed,Object? notes = freezed,}) {
  return _then(_Person(
slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,age: freezed == age ? _self.age : age // ignore: cast_nullable_to_non_nullable
as int?,gender: freezed == gender ? _self.gender : gender // ignore: cast_nullable_to_non_nullable
as String?,signalement: freezed == signalement ? _self.signalement : signalement // ignore: cast_nullable_to_non_nullable
as String?,homeSlug: freezed == homeSlug ? _self.homeSlug : homeSlug // ignore: cast_nullable_to_non_nullable
as String?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
