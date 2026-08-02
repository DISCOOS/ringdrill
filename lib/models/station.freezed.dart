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

 int get index; String get name;/// Minutes a team spends drilling here, overriding the exercise's
/// `executionTime` (ADR-0062). Null inherits, which is what every station did
/// before and what almost all of them still do.
///
/// Authored on the station because that is where a source document states it —
/// "post b takes 100 minutes" — and where the author is when they know it.
 int? get executionTime;/// Minutes of debrief at this station, overriding the exercise's
/// `evaluationTime`. Null inherits.
///
/// A demanding post earns a longer debrief than a simple one, and the author
/// knows which is which while writing the post.
 int? get evaluationTime;/// Minutes to leave this station and reach the next one, overriding the
/// exercise's `rotationTime`. Null inherits.
///
/// An edge rather than a property, strictly — but a well-defined one, because the
/// route is station order with a wrap. Terrain is what makes it vary: the walk out
/// of a shoreline post is not the walk out of the one beside the car park.
///
/// In `ring` every team rotates at once, so the longest walk sets the round's
/// rotation phase and the rest wait — the same way [executionTime] behaves there.
 int? get rotationTime; String? get variantSuffix;@NullableLatLngJsonConverter() LatLng? get position; String? get description;/// Per-scope value overrides for plan-global variables, keyed by
/// DrillVariable.name. A key that does not name a declared variable is
/// meaningless and is ignored at resolution time (ADR-0046). This scope
/// never declares new variables.
 Map<String, String> get variableOverrides;/// Station-owned scenario geography, referenced as
/// `{{station.loc.<slug>}}` (ADR-0047, DESIGN-009). @Default so
/// archives without the key deserialize to an empty list (additive
/// field, no schema bump).
 List<Location> get locations;/// Station-owned fictional scenario persons, referenced as
/// `{{station.person.<slug>}}` (ADR-0047, DESIGN-009). @Default so
/// archives without the key deserialize to an empty list (additive
/// field, no schema bump).
 List<Person> get persons;// Markdown brief fields — stored as exercises/<uuid>/stations/<index>/<field>.md, not in JSON.
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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Station&&(identical(other.index, index) || other.index == index)&&(identical(other.name, name) || other.name == name)&&(identical(other.executionTime, executionTime) || other.executionTime == executionTime)&&(identical(other.evaluationTime, evaluationTime) || other.evaluationTime == evaluationTime)&&(identical(other.rotationTime, rotationTime) || other.rotationTime == rotationTime)&&(identical(other.variantSuffix, variantSuffix) || other.variantSuffix == variantSuffix)&&(identical(other.position, position) || other.position == position)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other.variableOverrides, variableOverrides)&&const DeepCollectionEquality().equals(other.locations, locations)&&const DeepCollectionEquality().equals(other.persons, persons)&&(identical(other.equipmentMd, equipmentMd) || other.equipmentMd == equipmentMd)&&(identical(other.situationMd, situationMd) || other.situationMd == situationMd)&&(identical(other.missionMd, missionMd) || other.missionMd == missionMd)&&(identical(other.logisticsMd, logisticsMd) || other.logisticsMd == logisticsMd)&&(identical(other.criticalQuestionsMd, criticalQuestionsMd) || other.criticalQuestionsMd == criticalQuestionsMd)&&(identical(other.leaderAnswersMd, leaderAnswersMd) || other.leaderAnswersMd == leaderAnswersMd)&&(identical(other.directorNotesMd, directorNotesMd) || other.directorNotesMd == directorNotesMd));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,index,name,executionTime,evaluationTime,rotationTime,variantSuffix,position,description,const DeepCollectionEquality().hash(variableOverrides),const DeepCollectionEquality().hash(locations),const DeepCollectionEquality().hash(persons),equipmentMd,situationMd,missionMd,logisticsMd,criticalQuestionsMd,leaderAnswersMd,directorNotesMd);

@override
String toString() {
  return 'Station(index: $index, name: $name, executionTime: $executionTime, evaluationTime: $evaluationTime, rotationTime: $rotationTime, variantSuffix: $variantSuffix, position: $position, description: $description, variableOverrides: $variableOverrides, locations: $locations, persons: $persons, equipmentMd: $equipmentMd, situationMd: $situationMd, missionMd: $missionMd, logisticsMd: $logisticsMd, criticalQuestionsMd: $criticalQuestionsMd, leaderAnswersMd: $leaderAnswersMd, directorNotesMd: $directorNotesMd)';
}


}

/// @nodoc
abstract mixin class $StationCopyWith<$Res>  {
  factory $StationCopyWith(Station value, $Res Function(Station) _then) = _$StationCopyWithImpl;
@useResult
$Res call({
 int index, String name, int? executionTime, int? evaluationTime, int? rotationTime, String? variantSuffix,@NullableLatLngJsonConverter() LatLng? position, String? description, Map<String, String> variableOverrides, List<Location> locations, List<Person> persons,@JsonKey(includeFromJson: false, includeToJson: false) String? equipmentMd,@JsonKey(includeFromJson: false, includeToJson: false) String? situationMd,@JsonKey(includeFromJson: false, includeToJson: false) String? missionMd,@JsonKey(includeFromJson: false, includeToJson: false) String? logisticsMd,@JsonKey(includeFromJson: false, includeToJson: false) String? criticalQuestionsMd,@JsonKey(includeFromJson: false, includeToJson: false) String? leaderAnswersMd,@JsonKey(includeFromJson: false, includeToJson: false) String? directorNotesMd
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
@pragma('vm:prefer-inline') @override $Res call({Object? index = null,Object? name = null,Object? executionTime = freezed,Object? evaluationTime = freezed,Object? rotationTime = freezed,Object? variantSuffix = freezed,Object? position = freezed,Object? description = freezed,Object? variableOverrides = null,Object? locations = null,Object? persons = null,Object? equipmentMd = freezed,Object? situationMd = freezed,Object? missionMd = freezed,Object? logisticsMd = freezed,Object? criticalQuestionsMd = freezed,Object? leaderAnswersMd = freezed,Object? directorNotesMd = freezed,}) {
  return _then(_self.copyWith(
index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,executionTime: freezed == executionTime ? _self.executionTime : executionTime // ignore: cast_nullable_to_non_nullable
as int?,evaluationTime: freezed == evaluationTime ? _self.evaluationTime : evaluationTime // ignore: cast_nullable_to_non_nullable
as int?,rotationTime: freezed == rotationTime ? _self.rotationTime : rotationTime // ignore: cast_nullable_to_non_nullable
as int?,variantSuffix: freezed == variantSuffix ? _self.variantSuffix : variantSuffix // ignore: cast_nullable_to_non_nullable
as String?,position: freezed == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as LatLng?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,variableOverrides: null == variableOverrides ? _self.variableOverrides : variableOverrides // ignore: cast_nullable_to_non_nullable
as Map<String, String>,locations: null == locations ? _self.locations : locations // ignore: cast_nullable_to_non_nullable
as List<Location>,persons: null == persons ? _self.persons : persons // ignore: cast_nullable_to_non_nullable
as List<Person>,equipmentMd: freezed == equipmentMd ? _self.equipmentMd : equipmentMd // ignore: cast_nullable_to_non_nullable
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int index,  String name,  int? executionTime,  int? evaluationTime,  int? rotationTime,  String? variantSuffix, @NullableLatLngJsonConverter()  LatLng? position,  String? description,  Map<String, String> variableOverrides,  List<Location> locations,  List<Person> persons, @JsonKey(includeFromJson: false, includeToJson: false)  String? equipmentMd, @JsonKey(includeFromJson: false, includeToJson: false)  String? situationMd, @JsonKey(includeFromJson: false, includeToJson: false)  String? missionMd, @JsonKey(includeFromJson: false, includeToJson: false)  String? logisticsMd, @JsonKey(includeFromJson: false, includeToJson: false)  String? criticalQuestionsMd, @JsonKey(includeFromJson: false, includeToJson: false)  String? leaderAnswersMd, @JsonKey(includeFromJson: false, includeToJson: false)  String? directorNotesMd)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Station() when $default != null:
return $default(_that.index,_that.name,_that.executionTime,_that.evaluationTime,_that.rotationTime,_that.variantSuffix,_that.position,_that.description,_that.variableOverrides,_that.locations,_that.persons,_that.equipmentMd,_that.situationMd,_that.missionMd,_that.logisticsMd,_that.criticalQuestionsMd,_that.leaderAnswersMd,_that.directorNotesMd);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int index,  String name,  int? executionTime,  int? evaluationTime,  int? rotationTime,  String? variantSuffix, @NullableLatLngJsonConverter()  LatLng? position,  String? description,  Map<String, String> variableOverrides,  List<Location> locations,  List<Person> persons, @JsonKey(includeFromJson: false, includeToJson: false)  String? equipmentMd, @JsonKey(includeFromJson: false, includeToJson: false)  String? situationMd, @JsonKey(includeFromJson: false, includeToJson: false)  String? missionMd, @JsonKey(includeFromJson: false, includeToJson: false)  String? logisticsMd, @JsonKey(includeFromJson: false, includeToJson: false)  String? criticalQuestionsMd, @JsonKey(includeFromJson: false, includeToJson: false)  String? leaderAnswersMd, @JsonKey(includeFromJson: false, includeToJson: false)  String? directorNotesMd)  $default,) {final _that = this;
switch (_that) {
case _Station():
return $default(_that.index,_that.name,_that.executionTime,_that.evaluationTime,_that.rotationTime,_that.variantSuffix,_that.position,_that.description,_that.variableOverrides,_that.locations,_that.persons,_that.equipmentMd,_that.situationMd,_that.missionMd,_that.logisticsMd,_that.criticalQuestionsMd,_that.leaderAnswersMd,_that.directorNotesMd);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int index,  String name,  int? executionTime,  int? evaluationTime,  int? rotationTime,  String? variantSuffix, @NullableLatLngJsonConverter()  LatLng? position,  String? description,  Map<String, String> variableOverrides,  List<Location> locations,  List<Person> persons, @JsonKey(includeFromJson: false, includeToJson: false)  String? equipmentMd, @JsonKey(includeFromJson: false, includeToJson: false)  String? situationMd, @JsonKey(includeFromJson: false, includeToJson: false)  String? missionMd, @JsonKey(includeFromJson: false, includeToJson: false)  String? logisticsMd, @JsonKey(includeFromJson: false, includeToJson: false)  String? criticalQuestionsMd, @JsonKey(includeFromJson: false, includeToJson: false)  String? leaderAnswersMd, @JsonKey(includeFromJson: false, includeToJson: false)  String? directorNotesMd)?  $default,) {final _that = this;
switch (_that) {
case _Station() when $default != null:
return $default(_that.index,_that.name,_that.executionTime,_that.evaluationTime,_that.rotationTime,_that.variantSuffix,_that.position,_that.description,_that.variableOverrides,_that.locations,_that.persons,_that.equipmentMd,_that.situationMd,_that.missionMd,_that.logisticsMd,_that.criticalQuestionsMd,_that.leaderAnswersMd,_that.directorNotesMd);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Station implements Station {
  const _Station({required this.index, required this.name, this.executionTime, this.evaluationTime, this.rotationTime, this.variantSuffix, @NullableLatLngJsonConverter() this.position, this.description, final  Map<String, String> variableOverrides = const <String, String>{}, final  List<Location> locations = const <Location>[], final  List<Person> persons = const <Person>[], @JsonKey(includeFromJson: false, includeToJson: false) this.equipmentMd, @JsonKey(includeFromJson: false, includeToJson: false) this.situationMd, @JsonKey(includeFromJson: false, includeToJson: false) this.missionMd, @JsonKey(includeFromJson: false, includeToJson: false) this.logisticsMd, @JsonKey(includeFromJson: false, includeToJson: false) this.criticalQuestionsMd, @JsonKey(includeFromJson: false, includeToJson: false) this.leaderAnswersMd, @JsonKey(includeFromJson: false, includeToJson: false) this.directorNotesMd}): _variableOverrides = variableOverrides,_locations = locations,_persons = persons;
  factory _Station.fromJson(Map<String, dynamic> json) => _$StationFromJson(json);

@override final  int index;
@override final  String name;
/// Minutes a team spends drilling here, overriding the exercise's
/// `executionTime` (ADR-0062). Null inherits, which is what every station did
/// before and what almost all of them still do.
///
/// Authored on the station because that is where a source document states it —
/// "post b takes 100 minutes" — and where the author is when they know it.
@override final  int? executionTime;
/// Minutes of debrief at this station, overriding the exercise's
/// `evaluationTime`. Null inherits.
///
/// A demanding post earns a longer debrief than a simple one, and the author
/// knows which is which while writing the post.
@override final  int? evaluationTime;
/// Minutes to leave this station and reach the next one, overriding the
/// exercise's `rotationTime`. Null inherits.
///
/// An edge rather than a property, strictly — but a well-defined one, because the
/// route is station order with a wrap. Terrain is what makes it vary: the walk out
/// of a shoreline post is not the walk out of the one beside the car park.
///
/// In `ring` every team rotates at once, so the longest walk sets the round's
/// rotation phase and the rest wait — the same way [executionTime] behaves there.
@override final  int? rotationTime;
@override final  String? variantSuffix;
@override@NullableLatLngJsonConverter() final  LatLng? position;
@override final  String? description;
/// Per-scope value overrides for plan-global variables, keyed by
/// DrillVariable.name. A key that does not name a declared variable is
/// meaningless and is ignored at resolution time (ADR-0046). This scope
/// never declares new variables.
 final  Map<String, String> _variableOverrides;
/// Per-scope value overrides for plan-global variables, keyed by
/// DrillVariable.name. A key that does not name a declared variable is
/// meaningless and is ignored at resolution time (ADR-0046). This scope
/// never declares new variables.
@override@JsonKey() Map<String, String> get variableOverrides {
  if (_variableOverrides is EqualUnmodifiableMapView) return _variableOverrides;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_variableOverrides);
}

/// Station-owned scenario geography, referenced as
/// `{{station.loc.<slug>}}` (ADR-0047, DESIGN-009). @Default so
/// archives without the key deserialize to an empty list (additive
/// field, no schema bump).
 final  List<Location> _locations;
/// Station-owned scenario geography, referenced as
/// `{{station.loc.<slug>}}` (ADR-0047, DESIGN-009). @Default so
/// archives without the key deserialize to an empty list (additive
/// field, no schema bump).
@override@JsonKey() List<Location> get locations {
  if (_locations is EqualUnmodifiableListView) return _locations;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_locations);
}

/// Station-owned fictional scenario persons, referenced as
/// `{{station.person.<slug>}}` (ADR-0047, DESIGN-009). @Default so
/// archives without the key deserialize to an empty list (additive
/// field, no schema bump).
 final  List<Person> _persons;
/// Station-owned fictional scenario persons, referenced as
/// `{{station.person.<slug>}}` (ADR-0047, DESIGN-009). @Default so
/// archives without the key deserialize to an empty list (additive
/// field, no schema bump).
@override@JsonKey() List<Person> get persons {
  if (_persons is EqualUnmodifiableListView) return _persons;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_persons);
}

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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Station&&(identical(other.index, index) || other.index == index)&&(identical(other.name, name) || other.name == name)&&(identical(other.executionTime, executionTime) || other.executionTime == executionTime)&&(identical(other.evaluationTime, evaluationTime) || other.evaluationTime == evaluationTime)&&(identical(other.rotationTime, rotationTime) || other.rotationTime == rotationTime)&&(identical(other.variantSuffix, variantSuffix) || other.variantSuffix == variantSuffix)&&(identical(other.position, position) || other.position == position)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other._variableOverrides, _variableOverrides)&&const DeepCollectionEquality().equals(other._locations, _locations)&&const DeepCollectionEquality().equals(other._persons, _persons)&&(identical(other.equipmentMd, equipmentMd) || other.equipmentMd == equipmentMd)&&(identical(other.situationMd, situationMd) || other.situationMd == situationMd)&&(identical(other.missionMd, missionMd) || other.missionMd == missionMd)&&(identical(other.logisticsMd, logisticsMd) || other.logisticsMd == logisticsMd)&&(identical(other.criticalQuestionsMd, criticalQuestionsMd) || other.criticalQuestionsMd == criticalQuestionsMd)&&(identical(other.leaderAnswersMd, leaderAnswersMd) || other.leaderAnswersMd == leaderAnswersMd)&&(identical(other.directorNotesMd, directorNotesMd) || other.directorNotesMd == directorNotesMd));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,index,name,executionTime,evaluationTime,rotationTime,variantSuffix,position,description,const DeepCollectionEquality().hash(_variableOverrides),const DeepCollectionEquality().hash(_locations),const DeepCollectionEquality().hash(_persons),equipmentMd,situationMd,missionMd,logisticsMd,criticalQuestionsMd,leaderAnswersMd,directorNotesMd);

@override
String toString() {
  return 'Station(index: $index, name: $name, executionTime: $executionTime, evaluationTime: $evaluationTime, rotationTime: $rotationTime, variantSuffix: $variantSuffix, position: $position, description: $description, variableOverrides: $variableOverrides, locations: $locations, persons: $persons, equipmentMd: $equipmentMd, situationMd: $situationMd, missionMd: $missionMd, logisticsMd: $logisticsMd, criticalQuestionsMd: $criticalQuestionsMd, leaderAnswersMd: $leaderAnswersMd, directorNotesMd: $directorNotesMd)';
}


}

/// @nodoc
abstract mixin class _$StationCopyWith<$Res> implements $StationCopyWith<$Res> {
  factory _$StationCopyWith(_Station value, $Res Function(_Station) _then) = __$StationCopyWithImpl;
@override @useResult
$Res call({
 int index, String name, int? executionTime, int? evaluationTime, int? rotationTime, String? variantSuffix,@NullableLatLngJsonConverter() LatLng? position, String? description, Map<String, String> variableOverrides, List<Location> locations, List<Person> persons,@JsonKey(includeFromJson: false, includeToJson: false) String? equipmentMd,@JsonKey(includeFromJson: false, includeToJson: false) String? situationMd,@JsonKey(includeFromJson: false, includeToJson: false) String? missionMd,@JsonKey(includeFromJson: false, includeToJson: false) String? logisticsMd,@JsonKey(includeFromJson: false, includeToJson: false) String? criticalQuestionsMd,@JsonKey(includeFromJson: false, includeToJson: false) String? leaderAnswersMd,@JsonKey(includeFromJson: false, includeToJson: false) String? directorNotesMd
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
@override @pragma('vm:prefer-inline') $Res call({Object? index = null,Object? name = null,Object? executionTime = freezed,Object? evaluationTime = freezed,Object? rotationTime = freezed,Object? variantSuffix = freezed,Object? position = freezed,Object? description = freezed,Object? variableOverrides = null,Object? locations = null,Object? persons = null,Object? equipmentMd = freezed,Object? situationMd = freezed,Object? missionMd = freezed,Object? logisticsMd = freezed,Object? criticalQuestionsMd = freezed,Object? leaderAnswersMd = freezed,Object? directorNotesMd = freezed,}) {
  return _then(_Station(
index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,executionTime: freezed == executionTime ? _self.executionTime : executionTime // ignore: cast_nullable_to_non_nullable
as int?,evaluationTime: freezed == evaluationTime ? _self.evaluationTime : evaluationTime // ignore: cast_nullable_to_non_nullable
as int?,rotationTime: freezed == rotationTime ? _self.rotationTime : rotationTime // ignore: cast_nullable_to_non_nullable
as int?,variantSuffix: freezed == variantSuffix ? _self.variantSuffix : variantSuffix // ignore: cast_nullable_to_non_nullable
as String?,position: freezed == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as LatLng?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,variableOverrides: null == variableOverrides ? _self._variableOverrides : variableOverrides // ignore: cast_nullable_to_non_nullable
as Map<String, String>,locations: null == locations ? _self._locations : locations // ignore: cast_nullable_to_non_nullable
as List<Location>,persons: null == persons ? _self._persons : persons // ignore: cast_nullable_to_non_nullable
as List<Person>,equipmentMd: freezed == equipmentMd ? _self.equipmentMd : equipmentMd // ignore: cast_nullable_to_non_nullable
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
