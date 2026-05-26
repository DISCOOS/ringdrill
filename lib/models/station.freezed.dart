// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'station.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Station {

 int get index; String get name; String? get variantSuffix;@NullableLatLngJsonConverter() LatLng? get position; String? get description;// Markdown brief fields — stored as exercises/<uuid>/stations/<index>/<field>.md, not in JSON.
@JsonKey(includeFromJson: false, includeToJson: false) String? get equipmentMd;@JsonKey(includeFromJson: false, includeToJson: false) String? get situationMd;@JsonKey(includeFromJson: false, includeToJson: false) String? get missionMd;@JsonKey(includeFromJson: false, includeToJson: false) String? get logisticsMd;@JsonKey(includeFromJson: false, includeToJson: false) String? get criticalQuestionsMd;@JsonKey(includeFromJson: false, includeToJson: false) String? get leaderAnswersMd;@JsonKey(includeFromJson: false, includeToJson: false) String? get directorNotesMd;
/// Create a copy of Station
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StationCopyWith<Station> get copyWith => _$StationCopyWithImpl<Station>(this as Station, _$identity);

  /// Serializes this Station to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Station&&(identical(other.index, index) || other.index == index)&&(identical(other.name, name) || other.name == name)&&(identical(other.variantSuffix, variantSuffix) || other.variantSuffix == variantSuffix)&&(identical(other.position, position) || other.position == position)&&(identical(other.description, description) || other.description == description)&&(identical(other.equipmentMd, equipmentMd) || other.equipmentMd == equipmentMd)&&(identical(other.situationMd, situationMd) || other.situationMd == situationMd)&&(identical(other.missionMd, missionMd) || other.missionMd == missionMd)&&(identical(other.logisticsMd, logisticsMd) || other.logisticsMd == logisticsMd)&&(identical(other.criticalQuestionsMd, criticalQuestionsMd) || other.criticalQuestionsMd == criticalQuestionsMd)&&(identical(other.leaderAnswersMd, leaderAnswersMd) || other.leaderAnswersMd == leaderAnswersMd)&&(identical(other.directorNotesMd, directorNotesMd) || other.directorNotesMd == directorNotesMd));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,index,name,variantSuffix,position,description,equipmentMd,situationMd,missionMd,logisticsMd,criticalQuestionsMd,leaderAnswersMd,directorNotesMd);

@override
String toString() {
  return 'Station(index: $index, name: $name, variantSuffix: $variantSuffix, position: $position, description: $description, equipmentMd: $equipmentMd, situationMd: $situationMd, missionMd: $missionMd, logisticsMd: $logisticsMd, criticalQuestionsMd: $criticalQuestionsMd, leaderAnswersMd: $leaderAnswersMd, directorNotesMd: $directorNotesMd)';
}


}

/// @nodoc
abstract mixin class $StationCopyWith<$Res>  {
  factory $StationCopyWith(Station value, $Res Function(Station) _then) = _$StationCopyWithImpl;
@useResult
$Res call({
 int index, String name, String? variantSuffix,@NullableLatLngJsonConverter() LatLng? position, String? description,@JsonKey(includeFromJson: false, includeToJson: false) String? equipmentMd,@JsonKey(includeFromJson: false, includeToJson: false) String? situationMd,@JsonKey(includeFromJson: false, includeToJson: false) String? missionMd,@JsonKey(includeFromJson: false, includeToJson: false) String? logisticsMd,@JsonKey(includeFromJson: false, includeToJson: false) String? criticalQuestionsMd,@JsonKey(includeFromJson: false, includeToJson: false) String? leaderAnswersMd,@JsonKey(includeFromJson: false, includeToJson: false) String? directorNotesMd
});




}
/// @nodoc
class _$StationCopyWithImpl<$Res>
    implements $StationCopyWith<$Res> {
  _$StationCopyWithImpl(this._self, this._then);

  final Station _self;
  final $Res Function(Station) _then;

/// Create a copy of Station
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? index = null,Object? name = null,Object? variantSuffix = freezed,Object? position = freezed,Object? description = freezed,Object? equipmentMd = freezed,Object? situationMd = freezed,Object? missionMd = freezed,Object? logisticsMd = freezed,Object? criticalQuestionsMd = freezed,Object? leaderAnswersMd = freezed,Object? directorNotesMd = freezed,}) {
  return _then(_self.copyWith(
index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,variantSuffix: freezed == variantSuffix ? _self.variantSuffix : variantSuffix // ignore: cast_nullable_to_non_nullable
as String?,position: freezed == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as LatLng?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,equipmentMd: freezed == equipmentMd ? _self.equipmentMd : equipmentMd // ignore: cast_nullable_to_non_nullable
as String?,situationMd: freezed == situationMd ? _self.situationMd : situationMd // ignore: cast_nullable_to_non_nullable
as String?,missionMd: freezed == missionMd ? _self.missionMd : missionMd // ignore: cast_nullable_to_non_nullable
as String?,logisticsMd: freezed == logisticsMd ? _self.logisticsMd : logisticsMd // ignore: cast_nullable_to_non_nullable
as String?,criticalQuestionsMd: freezed == criticalQuestionsMd ? _self.criticalQuestionsMd : criticalQuestionsMd // ignore: cast_nullable_to_non_nullable
as String?,leaderAnswersMd: freezed == leaderAnswersMd ? _self.leaderAnswersMd : leaderAnswersMd // ignore: cast_nullable_to_non_nullable
as String?,directorNotesMd: freezed == directorNotesMd ? _self.directorNotesMd : directorNotesMd // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Station].
extension StationPatterns on Station {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Station value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Station() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Station value)  $default,){
final _that = this;
switch (_that) {
case _Station():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Station value)?  $default,){
final _that = this;
switch (_that) {
case _Station() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int index,  String name,  String? variantSuffix, @NullableLatLngJsonConverter()  LatLng? position,  String? description, @JsonKey(includeFromJson: false, includeToJson: false)  String? equipmentMd, @JsonKey(includeFromJson: false, includeToJson: false)  String? situationMd, @JsonKey(includeFromJson: false, includeToJson: false)  String? missionMd, @JsonKey(includeFromJson: false, includeToJson: false)  String? logisticsMd, @JsonKey(includeFromJson: false, includeToJson: false)  String? criticalQuestionsMd, @JsonKey(includeFromJson: false, includeToJson: false)  String? leaderAnswersMd, @JsonKey(includeFromJson: false, includeToJson: false)  String? directorNotesMd)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Station() when $default != null:
return $default(_that.index,_that.name,_that.variantSuffix,_that.position,_that.description,_that.equipmentMd,_that.situationMd,_that.missionMd,_that.logisticsMd,_that.criticalQuestionsMd,_that.leaderAnswersMd,_that.directorNotesMd);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int index,  String name,  String? variantSuffix, @NullableLatLngJsonConverter()  LatLng? position,  String? description, @JsonKey(includeFromJson: false, includeToJson: false)  String? equipmentMd, @JsonKey(includeFromJson: false, includeToJson: false)  String? situationMd, @JsonKey(includeFromJson: false, includeToJson: false)  String? missionMd, @JsonKey(includeFromJson: false, includeToJson: false)  String? logisticsMd, @JsonKey(includeFromJson: false, includeToJson: false)  String? criticalQuestionsMd, @JsonKey(includeFromJson: false, includeToJson: false)  String? leaderAnswersMd, @JsonKey(includeFromJson: false, includeToJson: false)  String? directorNotesMd)  $default,) {final _that = this;
switch (_that) {
case _Station():
return $default(_that.index,_that.name,_that.variantSuffix,_that.position,_that.description,_that.equipmentMd,_that.situationMd,_that.missionMd,_that.logisticsMd,_that.criticalQuestionsMd,_that.leaderAnswersMd,_that.directorNotesMd);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int index,  String name,  String? variantSuffix, @NullableLatLngJsonConverter()  LatLng? position,  String? description, @JsonKey(includeFromJson: false, includeToJson: false)  String? equipmentMd, @JsonKey(includeFromJson: false, includeToJson: false)  String? situationMd, @JsonKey(includeFromJson: false, includeToJson: false)  String? missionMd, @JsonKey(includeFromJson: false, includeToJson: false)  String? logisticsMd, @JsonKey(includeFromJson: false, includeToJson: false)  String? criticalQuestionsMd, @JsonKey(includeFromJson: false, includeToJson: false)  String? leaderAnswersMd, @JsonKey(includeFromJson: false, includeToJson: false)  String? directorNotesMd)?  $default,) {final _that = this;
switch (_that) {
case _Station() when $default != null:
return $default(_that.index,_that.name,_that.variantSuffix,_that.position,_that.description,_that.equipmentMd,_that.situationMd,_that.missionMd,_that.logisticsMd,_that.criticalQuestionsMd,_that.leaderAnswersMd,_that.directorNotesMd);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Station implements Station {
  const _Station({required this.index, required this.name, this.variantSuffix, @NullableLatLngJsonConverter() this.position, this.description, @JsonKey(includeFromJson: false, includeToJson: false) this.equipmentMd, @JsonKey(includeFromJson: false, includeToJson: false) this.situationMd, @JsonKey(includeFromJson: false, includeToJson: false) this.missionMd, @JsonKey(includeFromJson: false, includeToJson: false) this.logisticsMd, @JsonKey(includeFromJson: false, includeToJson: false) this.criticalQuestionsMd, @JsonKey(includeFromJson: false, includeToJson: false) this.leaderAnswersMd, @JsonKey(includeFromJson: false, includeToJson: false) this.directorNotesMd});
  factory _Station.fromJson(Map<String, dynamic> json) => _$StationFromJson(json);

@override final  int index;
@override final  String name;
@override final  String? variantSuffix;
@override@NullableLatLngJsonConverter() final  LatLng? position;
@override final  String? description;
// Markdown brief fields — stored as exercises/<uuid>/stations/<index>/<field>.md, not in JSON.
@override@JsonKey(includeFromJson: false, includeToJson: false) final  String? equipmentMd;
@override@JsonKey(includeFromJson: false, includeToJson: false) final  String? situationMd;
@override@JsonKey(includeFromJson: false, includeToJson: false) final  String? missionMd;
@override@JsonKey(includeFromJson: false, includeToJson: false) final  String? logisticsMd;
@override@JsonKey(includeFromJson: false, includeToJson: false) final  String? criticalQuestionsMd;
@override@JsonKey(includeFromJson: false, includeToJson: false) final  String? leaderAnswersMd;
@override@JsonKey(includeFromJson: false, includeToJson: false) final  String? directorNotesMd;

/// Create a copy of Station
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StationCopyWith<_Station> get copyWith => __$StationCopyWithImpl<_Station>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$StationToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Station&&(identical(other.index, index) || other.index == index)&&(identical(other.name, name) || other.name == name)&&(identical(other.variantSuffix, variantSuffix) || other.variantSuffix == variantSuffix)&&(identical(other.position, position) || other.position == position)&&(identical(other.description, description) || other.description == description)&&(identical(other.equipmentMd, equipmentMd) || other.equipmentMd == equipmentMd)&&(identical(other.situationMd, situationMd) || other.situationMd == situationMd)&&(identical(other.missionMd, missionMd) || other.missionMd == missionMd)&&(identical(other.logisticsMd, logisticsMd) || other.logisticsMd == logisticsMd)&&(identical(other.criticalQuestionsMd, criticalQuestionsMd) || other.criticalQuestionsMd == criticalQuestionsMd)&&(identical(other.leaderAnswersMd, leaderAnswersMd) || other.leaderAnswersMd == leaderAnswersMd)&&(identical(other.directorNotesMd, directorNotesMd) || other.directorNotesMd == directorNotesMd));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,index,name,variantSuffix,position,description,equipmentMd,situationMd,missionMd,logisticsMd,criticalQuestionsMd,leaderAnswersMd,directorNotesMd);

@override
String toString() {
  return 'Station(index: $index, name: $name, variantSuffix: $variantSuffix, position: $position, description: $description, equipmentMd: $equipmentMd, situationMd: $situationMd, missionMd: $missionMd, logisticsMd: $logisticsMd, criticalQuestionsMd: $criticalQuestionsMd, leaderAnswersMd: $leaderAnswersMd, directorNotesMd: $directorNotesMd)';
}


}

/// @nodoc
abstract mixin class _$StationCopyWith<$Res> implements $StationCopyWith<$Res> {
  factory _$StationCopyWith(_Station value, $Res Function(_Station) _then) = __$StationCopyWithImpl;
@override @useResult
$Res call({
 int index, String name, String? variantSuffix,@NullableLatLngJsonConverter() LatLng? position, String? description,@JsonKey(includeFromJson: false, includeToJson: false) String? equipmentMd,@JsonKey(includeFromJson: false, includeToJson: false) String? situationMd,@JsonKey(includeFromJson: false, includeToJson: false) String? missionMd,@JsonKey(includeFromJson: false, includeToJson: false) String? logisticsMd,@JsonKey(includeFromJson: false, includeToJson: false) String? criticalQuestionsMd,@JsonKey(includeFromJson: false, includeToJson: false) String? leaderAnswersMd,@JsonKey(includeFromJson: false, includeToJson: false) String? directorNotesMd
});




}
/// @nodoc
class __$StationCopyWithImpl<$Res>
    implements _$StationCopyWith<$Res> {
  __$StationCopyWithImpl(this._self, this._then);

  final _Station _self;
  final $Res Function(_Station) _then;

/// Create a copy of Station
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? index = null,Object? name = null,Object? variantSuffix = freezed,Object? position = freezed,Object? description = freezed,Object? equipmentMd = freezed,Object? situationMd = freezed,Object? missionMd = freezed,Object? logisticsMd = freezed,Object? criticalQuestionsMd = freezed,Object? leaderAnswersMd = freezed,Object? directorNotesMd = freezed,}) {
  return _then(_Station(
index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,variantSuffix: freezed == variantSuffix ? _self.variantSuffix : variantSuffix // ignore: cast_nullable_to_non_nullable
as String?,position: freezed == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as LatLng?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,equipmentMd: freezed == equipmentMd ? _self.equipmentMd : equipmentMd // ignore: cast_nullable_to_non_nullable
as String?,situationMd: freezed == situationMd ? _self.situationMd : situationMd // ignore: cast_nullable_to_non_nullable
as String?,missionMd: freezed == missionMd ? _self.missionMd : missionMd // ignore: cast_nullable_to_non_nullable
as String?,logisticsMd: freezed == logisticsMd ? _self.logisticsMd : logisticsMd // ignore: cast_nullable_to_non_nullable
as String?,criticalQuestionsMd: freezed == criticalQuestionsMd ? _self.criticalQuestionsMd : criticalQuestionsMd // ignore: cast_nullable_to_non_nullable
as String?,leaderAnswersMd: freezed == leaderAnswersMd ? _self.leaderAnswersMd : leaderAnswersMd // ignore: cast_nullable_to_non_nullable
as String?,directorNotesMd: freezed == directorNotesMd ? _self.directorNotesMd : directorNotesMd // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
