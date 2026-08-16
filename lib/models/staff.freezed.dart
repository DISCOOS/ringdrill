// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'staff.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Staff {

 String get uuid; String get realName; String? get phone;@JsonKey(includeFromJson: false, includeToJson: false) String? get notes;/// The roles this person holds. Additive and defaulted, so a record written
/// before DESIGN-011 reads back unchanged — and one written before [actor]
/// existed still reads as an actor when a roleplay is cast to them.
 Set<StaffRole> get roles;/// The account user this row was created from, when it came from one.
///
/// **A link, not an identity.** The row is still a plain local record: the
/// name here is a copy made when it was added, and nothing keeps the two in
/// step. What the id buys is knowing that two rows are the same person —
/// "you are already on this roster" instead of a second you, which is
/// otherwise unanswerable when the only handle is a name somebody typed.
/// It is also what ADR-0057's self-edit rule can key on: an actor may put
/// *themselves* on the list, and "themselves" needs a referent.
///
/// Null for everyone typed in by hand, which is most of a roster — markører
/// recruited for a day have no RingDrill account and never will.
///
/// Stays inside the `staff/` folder the publisher strips (ADR-0018), so it
/// never reaches the catalog.
 String? get userId;
/// Create a copy of Staff
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StaffCopyWith<Staff> get copyWith => _$StaffCopyWithImpl<Staff>(this as Staff, _$identity);

  /// Serializes this Staff to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Staff&&(identical(other.uuid, uuid) || other.uuid == uuid)&&(identical(other.realName, realName) || other.realName == realName)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.notes, notes) || other.notes == notes)&&const DeepCollectionEquality().equals(other.roles, roles)&&(identical(other.userId, userId) || other.userId == userId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,uuid,realName,phone,notes,const DeepCollectionEquality().hash(roles),userId);

@override
String toString() {
  return 'Staff(uuid: $uuid, realName: $realName, phone: $phone, notes: $notes, roles: $roles, userId: $userId)';
}


}

/// @nodoc
abstract mixin class $StaffCopyWith<$Res>  {
  factory $StaffCopyWith(Staff value, $Res Function(Staff) _then) = _$StaffCopyWithImpl;
@useResult
$Res call({
 String uuid, String realName, String? phone,@JsonKey(includeFromJson: false, includeToJson: false) String? notes, Set<StaffRole> roles, String? userId
});




}
/// @nodoc
class _$StaffCopyWithImpl<$Res>
    implements $StaffCopyWith<$Res> {
  _$StaffCopyWithImpl(this._self, this._then);

  final Staff _self;
  final $Res Function(Staff) _then;

/// Create a copy of Staff
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? uuid = null,Object? realName = null,Object? phone = freezed,Object? notes = freezed,Object? roles = null,Object? userId = freezed,}) {
  return _then(_self.copyWith(
uuid: null == uuid ? _self.uuid : uuid // ignore: cast_nullable_to_non_nullable
as String,realName: null == realName ? _self.realName : realName // ignore: cast_nullable_to_non_nullable
as String,phone: freezed == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,roles: null == roles ? _self.roles : roles // ignore: cast_nullable_to_non_nullable
as Set<StaffRole>,userId: freezed == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Staff].
extension StaffPatterns on Staff {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Staff value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Staff() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Staff value)  $default,){
final _that = this;
switch (_that) {
case _Staff():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Staff value)?  $default,){
final _that = this;
switch (_that) {
case _Staff() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String uuid,  String realName,  String? phone, @JsonKey(includeFromJson: false, includeToJson: false)  String? notes,  Set<StaffRole> roles,  String? userId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Staff() when $default != null:
return $default(_that.uuid,_that.realName,_that.phone,_that.notes,_that.roles,_that.userId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String uuid,  String realName,  String? phone, @JsonKey(includeFromJson: false, includeToJson: false)  String? notes,  Set<StaffRole> roles,  String? userId)  $default,) {final _that = this;
switch (_that) {
case _Staff():
return $default(_that.uuid,_that.realName,_that.phone,_that.notes,_that.roles,_that.userId);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String uuid,  String realName,  String? phone, @JsonKey(includeFromJson: false, includeToJson: false)  String? notes,  Set<StaffRole> roles,  String? userId)?  $default,) {final _that = this;
switch (_that) {
case _Staff() when $default != null:
return $default(_that.uuid,_that.realName,_that.phone,_that.notes,_that.roles,_that.userId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Staff implements Staff {
  const _Staff({required this.uuid, required this.realName, this.phone, @JsonKey(includeFromJson: false, includeToJson: false) this.notes, final  Set<StaffRole> roles = const <StaffRole>{}, this.userId}): _roles = roles;
  factory _Staff.fromJson(Map<String, dynamic> json) => _$StaffFromJson(json);

@override final  String uuid;
@override final  String realName;
@override final  String? phone;
@override@JsonKey(includeFromJson: false, includeToJson: false) final  String? notes;
/// The roles this person holds. Additive and defaulted, so a record written
/// before DESIGN-011 reads back unchanged — and one written before [actor]
/// existed still reads as an actor when a roleplay is cast to them.
 final  Set<StaffRole> _roles;
/// The roles this person holds. Additive and defaulted, so a record written
/// before DESIGN-011 reads back unchanged — and one written before [actor]
/// existed still reads as an actor when a roleplay is cast to them.
@override@JsonKey() Set<StaffRole> get roles {
  if (_roles is EqualUnmodifiableSetView) return _roles;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_roles);
}

/// The account user this row was created from, when it came from one.
///
/// **A link, not an identity.** The row is still a plain local record: the
/// name here is a copy made when it was added, and nothing keeps the two in
/// step. What the id buys is knowing that two rows are the same person —
/// "you are already on this roster" instead of a second you, which is
/// otherwise unanswerable when the only handle is a name somebody typed.
/// It is also what ADR-0057's self-edit rule can key on: an actor may put
/// *themselves* on the list, and "themselves" needs a referent.
///
/// Null for everyone typed in by hand, which is most of a roster — markører
/// recruited for a day have no RingDrill account and never will.
///
/// Stays inside the `staff/` folder the publisher strips (ADR-0018), so it
/// never reaches the catalog.
@override final  String? userId;

/// Create a copy of Staff
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StaffCopyWith<_Staff> get copyWith => __$StaffCopyWithImpl<_Staff>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$StaffToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Staff&&(identical(other.uuid, uuid) || other.uuid == uuid)&&(identical(other.realName, realName) || other.realName == realName)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.notes, notes) || other.notes == notes)&&const DeepCollectionEquality().equals(other._roles, _roles)&&(identical(other.userId, userId) || other.userId == userId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,uuid,realName,phone,notes,const DeepCollectionEquality().hash(_roles),userId);

@override
String toString() {
  return 'Staff(uuid: $uuid, realName: $realName, phone: $phone, notes: $notes, roles: $roles, userId: $userId)';
}


}

/// @nodoc
abstract mixin class _$StaffCopyWith<$Res> implements $StaffCopyWith<$Res> {
  factory _$StaffCopyWith(_Staff value, $Res Function(_Staff) _then) = __$StaffCopyWithImpl;
@override @useResult
$Res call({
 String uuid, String realName, String? phone,@JsonKey(includeFromJson: false, includeToJson: false) String? notes, Set<StaffRole> roles, String? userId
});




}
/// @nodoc
class __$StaffCopyWithImpl<$Res>
    implements _$StaffCopyWith<$Res> {
  __$StaffCopyWithImpl(this._self, this._then);

  final _Staff _self;
  final $Res Function(_Staff) _then;

/// Create a copy of Staff
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? uuid = null,Object? realName = null,Object? phone = freezed,Object? notes = freezed,Object? roles = null,Object? userId = freezed,}) {
  return _then(_Staff(
uuid: null == uuid ? _self.uuid : uuid // ignore: cast_nullable_to_non_nullable
as String,realName: null == realName ? _self.realName : realName // ignore: cast_nullable_to_non_nullable
as String,phone: freezed == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,roles: null == roles ? _self._roles : roles // ignore: cast_nullable_to_non_nullable
as Set<StaffRole>,userId: freezed == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
