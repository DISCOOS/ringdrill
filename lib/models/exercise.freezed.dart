// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'exercise.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Exercise {

 String get uuid; String get name;@TimeOfDayConverter() TimeOfDay get startTime; int get numberOfTeams; int get numberOfRounds; int get executionTime; int get evaluationTime; int get rotationTime; List<Team> get teams; List<Station> get stations;@TimeOfDayConverter() List<List<TimeOfDay>> get schedule;@TimeOfDayConverter() TimeOfDay get endTime; ExerciseMetadata? get metadata;
/// Create a copy of Exercise
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ExerciseCopyWith<Exercise> get copyWith => _$ExerciseCopyWithImpl<Exercise>(this as Exercise, _$identity);

  /// Serializes this Exercise to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Exercise&&(identical(other.uuid, uuid) || other.uuid == uuid)&&(identical(other.name, name) || other.name == name)&&(identical(other.startTime, startTime) || other.startTime == startTime)&&(identical(other.numberOfTeams, numberOfTeams) || other.numberOfTeams == numberOfTeams)&&(identical(other.numberOfRounds, numberOfRounds) || other.numberOfRounds == numberOfRounds)&&(identical(other.executionTime, executionTime) || other.executionTime == executionTime)&&(identical(other.evaluationTime, evaluationTime) || other.evaluationTime == evaluationTime)&&(identical(other.rotationTime, rotationTime) || other.rotationTime == rotationTime)&&const DeepCollectionEquality().equals(other.teams, teams)&&const DeepCollectionEquality().equals(other.stations, stations)&&const DeepCollectionEquality().equals(other.schedule, schedule)&&(identical(other.endTime, endTime) || other.endTime == endTime)&&(identical(other.metadata, metadata) || other.metadata == metadata));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,uuid,name,startTime,numberOfTeams,numberOfRounds,executionTime,evaluationTime,rotationTime,const DeepCollectionEquality().hash(teams),const DeepCollectionEquality().hash(stations),const DeepCollectionEquality().hash(schedule),endTime,metadata);

@override
String toString() {
  return 'Exercise(uuid: $uuid, name: $name, startTime: $startTime, numberOfTeams: $numberOfTeams, numberOfRounds: $numberOfRounds, executionTime: $executionTime, evaluationTime: $evaluationTime, rotationTime: $rotationTime, teams: $teams, stations: $stations, schedule: $schedule, endTime: $endTime, metadata: $metadata)';
}


}

/// @nodoc
abstract mixin class $ExerciseCopyWith<$Res>  {
  factory $ExerciseCopyWith(Exercise value, $Res Function(Exercise) _then) = _$ExerciseCopyWithImpl;
@useResult
$Res call({
 String uuid, String name,@TimeOfDayConverter() TimeOfDay startTime, int numberOfTeams, int numberOfRounds, int executionTime, int evaluationTime, int rotationTime, List<Team> teams, List<Station> stations,@TimeOfDayConverter() List<List<TimeOfDay>> schedule,@TimeOfDayConverter() TimeOfDay endTime, ExerciseMetadata? metadata
});


$ExerciseMetadataCopyWith<$Res>? get metadata;

}
/// @nodoc
class _$ExerciseCopyWithImpl<$Res>
    implements $ExerciseCopyWith<$Res> {
  _$ExerciseCopyWithImpl(this._self, this._then);

  final Exercise _self;
  final $Res Function(Exercise) _then;

/// Create a copy of Exercise
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? uuid = null,Object? name = null,Object? startTime = null,Object? numberOfTeams = null,Object? numberOfRounds = null,Object? executionTime = null,Object? evaluationTime = null,Object? rotationTime = null,Object? teams = null,Object? stations = null,Object? schedule = null,Object? endTime = null,Object? metadata = freezed,}) {
  return _then(_self.copyWith(
uuid: null == uuid ? _self.uuid : uuid // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,startTime: null == startTime ? _self.startTime : startTime // ignore: cast_nullable_to_non_nullable
as TimeOfDay,numberOfTeams: null == numberOfTeams ? _self.numberOfTeams : numberOfTeams // ignore: cast_nullable_to_non_nullable
as int,numberOfRounds: null == numberOfRounds ? _self.numberOfRounds : numberOfRounds // ignore: cast_nullable_to_non_nullable
as int,executionTime: null == executionTime ? _self.executionTime : executionTime // ignore: cast_nullable_to_non_nullable
as int,evaluationTime: null == evaluationTime ? _self.evaluationTime : evaluationTime // ignore: cast_nullable_to_non_nullable
as int,rotationTime: null == rotationTime ? _self.rotationTime : rotationTime // ignore: cast_nullable_to_non_nullable
as int,teams: null == teams ? _self.teams : teams // ignore: cast_nullable_to_non_nullable
as List<Team>,stations: null == stations ? _self.stations : stations // ignore: cast_nullable_to_non_nullable
as List<Station>,schedule: null == schedule ? _self.schedule : schedule // ignore: cast_nullable_to_non_nullable
as List<List<TimeOfDay>>,endTime: null == endTime ? _self.endTime : endTime // ignore: cast_nullable_to_non_nullable
as TimeOfDay,metadata: freezed == metadata ? _self.metadata : metadata // ignore: cast_nullable_to_non_nullable
as ExerciseMetadata?,
  ));
}
/// Create a copy of Exercise
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ExerciseMetadataCopyWith<$Res>? get metadata {
    if (_self.metadata == null) {
    return null;
  }

  return $ExerciseMetadataCopyWith<$Res>(_self.metadata!, (value) {
    return _then(_self.copyWith(metadata: value));
  });
}
}


/// Adds pattern-matching-related methods to [Exercise].
extension ExercisePatterns on Exercise {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Exercise value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Exercise() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Exercise value)  $default,){
final _that = this;
switch (_that) {
case _Exercise():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Exercise value)?  $default,){
final _that = this;
switch (_that) {
case _Exercise() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String uuid,  String name, @TimeOfDayConverter()  TimeOfDay startTime,  int numberOfTeams,  int numberOfRounds,  int executionTime,  int evaluationTime,  int rotationTime,  List<Team> teams,  List<Station> stations, @TimeOfDayConverter()  List<List<TimeOfDay>> schedule, @TimeOfDayConverter()  TimeOfDay endTime,  ExerciseMetadata? metadata)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Exercise() when $default != null:
return $default(_that.uuid,_that.name,_that.startTime,_that.numberOfTeams,_that.numberOfRounds,_that.executionTime,_that.evaluationTime,_that.rotationTime,_that.teams,_that.stations,_that.schedule,_that.endTime,_that.metadata);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String uuid,  String name, @TimeOfDayConverter()  TimeOfDay startTime,  int numberOfTeams,  int numberOfRounds,  int executionTime,  int evaluationTime,  int rotationTime,  List<Team> teams,  List<Station> stations, @TimeOfDayConverter()  List<List<TimeOfDay>> schedule, @TimeOfDayConverter()  TimeOfDay endTime,  ExerciseMetadata? metadata)  $default,) {final _that = this;
switch (_that) {
case _Exercise():
return $default(_that.uuid,_that.name,_that.startTime,_that.numberOfTeams,_that.numberOfRounds,_that.executionTime,_that.evaluationTime,_that.rotationTime,_that.teams,_that.stations,_that.schedule,_that.endTime,_that.metadata);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String uuid,  String name, @TimeOfDayConverter()  TimeOfDay startTime,  int numberOfTeams,  int numberOfRounds,  int executionTime,  int evaluationTime,  int rotationTime,  List<Team> teams,  List<Station> stations, @TimeOfDayConverter()  List<List<TimeOfDay>> schedule, @TimeOfDayConverter()  TimeOfDay endTime,  ExerciseMetadata? metadata)?  $default,) {final _that = this;
switch (_that) {
case _Exercise() when $default != null:
return $default(_that.uuid,_that.name,_that.startTime,_that.numberOfTeams,_that.numberOfRounds,_that.executionTime,_that.evaluationTime,_that.rotationTime,_that.teams,_that.stations,_that.schedule,_that.endTime,_that.metadata);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Exercise implements Exercise {
  const _Exercise({required this.uuid, required this.name, @TimeOfDayConverter() required this.startTime, required this.numberOfTeams, required this.numberOfRounds, required this.executionTime, required this.evaluationTime, required this.rotationTime, required final  List<Team> teams, required final  List<Station> stations, @TimeOfDayConverter() required final  List<List<TimeOfDay>> schedule, @TimeOfDayConverter() required this.endTime, this.metadata}): _teams = teams,_stations = stations,_schedule = schedule;
  factory _Exercise.fromJson(Map<String, dynamic> json) => _$ExerciseFromJson(json);

@override final  String uuid;
@override final  String name;
@override@TimeOfDayConverter() final  TimeOfDay startTime;
@override final  int numberOfTeams;
@override final  int numberOfRounds;
@override final  int executionTime;
@override final  int evaluationTime;
@override final  int rotationTime;
 final  List<Team> _teams;
@override List<Team> get teams {
  if (_teams is EqualUnmodifiableListView) return _teams;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_teams);
}

 final  List<Station> _stations;
@override List<Station> get stations {
  if (_stations is EqualUnmodifiableListView) return _stations;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_stations);
}

 final  List<List<TimeOfDay>> _schedule;
@override@TimeOfDayConverter() List<List<TimeOfDay>> get schedule {
  if (_schedule is EqualUnmodifiableListView) return _schedule;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_schedule);
}

@override@TimeOfDayConverter() final  TimeOfDay endTime;
@override final  ExerciseMetadata? metadata;

/// Create a copy of Exercise
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ExerciseCopyWith<_Exercise> get copyWith => __$ExerciseCopyWithImpl<_Exercise>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ExerciseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Exercise&&(identical(other.uuid, uuid) || other.uuid == uuid)&&(identical(other.name, name) || other.name == name)&&(identical(other.startTime, startTime) || other.startTime == startTime)&&(identical(other.numberOfTeams, numberOfTeams) || other.numberOfTeams == numberOfTeams)&&(identical(other.numberOfRounds, numberOfRounds) || other.numberOfRounds == numberOfRounds)&&(identical(other.executionTime, executionTime) || other.executionTime == executionTime)&&(identical(other.evaluationTime, evaluationTime) || other.evaluationTime == evaluationTime)&&(identical(other.rotationTime, rotationTime) || other.rotationTime == rotationTime)&&const DeepCollectionEquality().equals(other._teams, _teams)&&const DeepCollectionEquality().equals(other._stations, _stations)&&const DeepCollectionEquality().equals(other._schedule, _schedule)&&(identical(other.endTime, endTime) || other.endTime == endTime)&&(identical(other.metadata, metadata) || other.metadata == metadata));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,uuid,name,startTime,numberOfTeams,numberOfRounds,executionTime,evaluationTime,rotationTime,const DeepCollectionEquality().hash(_teams),const DeepCollectionEquality().hash(_stations),const DeepCollectionEquality().hash(_schedule),endTime,metadata);

@override
String toString() {
  return 'Exercise(uuid: $uuid, name: $name, startTime: $startTime, numberOfTeams: $numberOfTeams, numberOfRounds: $numberOfRounds, executionTime: $executionTime, evaluationTime: $evaluationTime, rotationTime: $rotationTime, teams: $teams, stations: $stations, schedule: $schedule, endTime: $endTime, metadata: $metadata)';
}


}

/// @nodoc
abstract mixin class _$ExerciseCopyWith<$Res> implements $ExerciseCopyWith<$Res> {
  factory _$ExerciseCopyWith(_Exercise value, $Res Function(_Exercise) _then) = __$ExerciseCopyWithImpl;
@override @useResult
$Res call({
 String uuid, String name,@TimeOfDayConverter() TimeOfDay startTime, int numberOfTeams, int numberOfRounds, int executionTime, int evaluationTime, int rotationTime, List<Team> teams, List<Station> stations,@TimeOfDayConverter() List<List<TimeOfDay>> schedule,@TimeOfDayConverter() TimeOfDay endTime, ExerciseMetadata? metadata
});


@override $ExerciseMetadataCopyWith<$Res>? get metadata;

}
/// @nodoc
class __$ExerciseCopyWithImpl<$Res>
    implements _$ExerciseCopyWith<$Res> {
  __$ExerciseCopyWithImpl(this._self, this._then);

  final _Exercise _self;
  final $Res Function(_Exercise) _then;

/// Create a copy of Exercise
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? uuid = null,Object? name = null,Object? startTime = null,Object? numberOfTeams = null,Object? numberOfRounds = null,Object? executionTime = null,Object? evaluationTime = null,Object? rotationTime = null,Object? teams = null,Object? stations = null,Object? schedule = null,Object? endTime = null,Object? metadata = freezed,}) {
  return _then(_Exercise(
uuid: null == uuid ? _self.uuid : uuid // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,startTime: null == startTime ? _self.startTime : startTime // ignore: cast_nullable_to_non_nullable
as TimeOfDay,numberOfTeams: null == numberOfTeams ? _self.numberOfTeams : numberOfTeams // ignore: cast_nullable_to_non_nullable
as int,numberOfRounds: null == numberOfRounds ? _self.numberOfRounds : numberOfRounds // ignore: cast_nullable_to_non_nullable
as int,executionTime: null == executionTime ? _self.executionTime : executionTime // ignore: cast_nullable_to_non_nullable
as int,evaluationTime: null == evaluationTime ? _self.evaluationTime : evaluationTime // ignore: cast_nullable_to_non_nullable
as int,rotationTime: null == rotationTime ? _self.rotationTime : rotationTime // ignore: cast_nullable_to_non_nullable
as int,teams: null == teams ? _self._teams : teams // ignore: cast_nullable_to_non_nullable
as List<Team>,stations: null == stations ? _self._stations : stations // ignore: cast_nullable_to_non_nullable
as List<Station>,schedule: null == schedule ? _self._schedule : schedule // ignore: cast_nullable_to_non_nullable
as List<List<TimeOfDay>>,endTime: null == endTime ? _self.endTime : endTime // ignore: cast_nullable_to_non_nullable
as TimeOfDay,metadata: freezed == metadata ? _self.metadata : metadata // ignore: cast_nullable_to_non_nullable
as ExerciseMetadata?,
  ));
}

/// Create a copy of Exercise
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ExerciseMetadataCopyWith<$Res>? get metadata {
    if (_self.metadata == null) {
    return null;
  }

  return $ExerciseMetadataCopyWith<$Res>(_self.metadata!, (value) {
    return _then(_self.copyWith(metadata: value));
  });
}
}


/// @nodoc
mixin _$Station {

 int get index; String get name; LatLng? get position; String? get description;
/// Create a copy of Station
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StationCopyWith<Station> get copyWith => _$StationCopyWithImpl<Station>(this as Station, _$identity);

  /// Serializes this Station to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Station&&(identical(other.index, index) || other.index == index)&&(identical(other.name, name) || other.name == name)&&(identical(other.position, position) || other.position == position)&&(identical(other.description, description) || other.description == description));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,index,name,position,description);

@override
String toString() {
  return 'Station(index: $index, name: $name, position: $position, description: $description)';
}


}

/// @nodoc
abstract mixin class $StationCopyWith<$Res>  {
  factory $StationCopyWith(Station value, $Res Function(Station) _then) = _$StationCopyWithImpl;
@useResult
$Res call({
 int index, String name, LatLng? position, String? description
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
@pragma('vm:prefer-inline') @override $Res call({Object? index = null,Object? name = null,Object? position = freezed,Object? description = freezed,}) {
  return _then(_self.copyWith(
index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,position: freezed == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as LatLng?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int index,  String name,  LatLng? position,  String? description)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Station() when $default != null:
return $default(_that.index,_that.name,_that.position,_that.description);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int index,  String name,  LatLng? position,  String? description)  $default,) {final _that = this;
switch (_that) {
case _Station():
return $default(_that.index,_that.name,_that.position,_that.description);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int index,  String name,  LatLng? position,  String? description)?  $default,) {final _that = this;
switch (_that) {
case _Station() when $default != null:
return $default(_that.index,_that.name,_that.position,_that.description);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Station implements Station {
  const _Station({required this.index, required this.name, this.position, this.description});
  factory _Station.fromJson(Map<String, dynamic> json) => _$StationFromJson(json);

@override final  int index;
@override final  String name;
@override final  LatLng? position;
@override final  String? description;

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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Station&&(identical(other.index, index) || other.index == index)&&(identical(other.name, name) || other.name == name)&&(identical(other.position, position) || other.position == position)&&(identical(other.description, description) || other.description == description));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,index,name,position,description);

@override
String toString() {
  return 'Station(index: $index, name: $name, position: $position, description: $description)';
}


}

/// @nodoc
abstract mixin class _$StationCopyWith<$Res> implements $StationCopyWith<$Res> {
  factory _$StationCopyWith(_Station value, $Res Function(_Station) _then) = __$StationCopyWithImpl;
@override @useResult
$Res call({
 int index, String name, LatLng? position, String? description
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
@override @pragma('vm:prefer-inline') $Res call({Object? index = null,Object? name = null,Object? position = freezed,Object? description = freezed,}) {
  return _then(_Station(
index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,position: freezed == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as LatLng?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$Team {

 int get index; String get name; int? get numberOfMembers; LatLng? get position;
/// Create a copy of Team
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TeamCopyWith<Team> get copyWith => _$TeamCopyWithImpl<Team>(this as Team, _$identity);

  /// Serializes this Team to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Team&&(identical(other.index, index) || other.index == index)&&(identical(other.name, name) || other.name == name)&&(identical(other.numberOfMembers, numberOfMembers) || other.numberOfMembers == numberOfMembers)&&(identical(other.position, position) || other.position == position));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,index,name,numberOfMembers,position);

@override
String toString() {
  return 'Team(index: $index, name: $name, numberOfMembers: $numberOfMembers, position: $position)';
}


}

/// @nodoc
abstract mixin class $TeamCopyWith<$Res>  {
  factory $TeamCopyWith(Team value, $Res Function(Team) _then) = _$TeamCopyWithImpl;
@useResult
$Res call({
 int index, String name, int? numberOfMembers, LatLng? position
});




}
/// @nodoc
class _$TeamCopyWithImpl<$Res>
    implements $TeamCopyWith<$Res> {
  _$TeamCopyWithImpl(this._self, this._then);

  final Team _self;
  final $Res Function(Team) _then;

/// Create a copy of Team
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? index = null,Object? name = null,Object? numberOfMembers = freezed,Object? position = freezed,}) {
  return _then(_self.copyWith(
index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,numberOfMembers: freezed == numberOfMembers ? _self.numberOfMembers : numberOfMembers // ignore: cast_nullable_to_non_nullable
as int?,position: freezed == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as LatLng?,
  ));
}

}


/// Adds pattern-matching-related methods to [Team].
extension TeamPatterns on Team {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Team value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Team() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Team value)  $default,){
final _that = this;
switch (_that) {
case _Team():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Team value)?  $default,){
final _that = this;
switch (_that) {
case _Team() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int index,  String name,  int? numberOfMembers,  LatLng? position)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Team() when $default != null:
return $default(_that.index,_that.name,_that.numberOfMembers,_that.position);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int index,  String name,  int? numberOfMembers,  LatLng? position)  $default,) {final _that = this;
switch (_that) {
case _Team():
return $default(_that.index,_that.name,_that.numberOfMembers,_that.position);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int index,  String name,  int? numberOfMembers,  LatLng? position)?  $default,) {final _that = this;
switch (_that) {
case _Team() when $default != null:
return $default(_that.index,_that.name,_that.numberOfMembers,_that.position);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Team implements Team {
  const _Team({required this.index, required this.name, this.numberOfMembers, this.position});
  factory _Team.fromJson(Map<String, dynamic> json) => _$TeamFromJson(json);

@override final  int index;
@override final  String name;
@override final  int? numberOfMembers;
@override final  LatLng? position;

/// Create a copy of Team
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TeamCopyWith<_Team> get copyWith => __$TeamCopyWithImpl<_Team>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TeamToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Team&&(identical(other.index, index) || other.index == index)&&(identical(other.name, name) || other.name == name)&&(identical(other.numberOfMembers, numberOfMembers) || other.numberOfMembers == numberOfMembers)&&(identical(other.position, position) || other.position == position));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,index,name,numberOfMembers,position);

@override
String toString() {
  return 'Team(index: $index, name: $name, numberOfMembers: $numberOfMembers, position: $position)';
}


}

/// @nodoc
abstract mixin class _$TeamCopyWith<$Res> implements $TeamCopyWith<$Res> {
  factory _$TeamCopyWith(_Team value, $Res Function(_Team) _then) = __$TeamCopyWithImpl;
@override @useResult
$Res call({
 int index, String name, int? numberOfMembers, LatLng? position
});




}
/// @nodoc
class __$TeamCopyWithImpl<$Res>
    implements _$TeamCopyWith<$Res> {
  __$TeamCopyWithImpl(this._self, this._then);

  final _Team _self;
  final $Res Function(_Team) _then;

/// Create a copy of Team
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? index = null,Object? name = null,Object? numberOfMembers = freezed,Object? position = freezed,}) {
  return _then(_Team(
index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,numberOfMembers: freezed == numberOfMembers ? _self.numberOfMembers : numberOfMembers // ignore: cast_nullable_to_non_nullable
as int?,position: freezed == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as LatLng?,
  ));
}


}


/// @nodoc
mixin _$ExerciseMetadata {

 String? get copyOfUuid;
/// Create a copy of ExerciseMetadata
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ExerciseMetadataCopyWith<ExerciseMetadata> get copyWith => _$ExerciseMetadataCopyWithImpl<ExerciseMetadata>(this as ExerciseMetadata, _$identity);

  /// Serializes this ExerciseMetadata to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ExerciseMetadata&&(identical(other.copyOfUuid, copyOfUuid) || other.copyOfUuid == copyOfUuid));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,copyOfUuid);

@override
String toString() {
  return 'ExerciseMetadata(copyOfUuid: $copyOfUuid)';
}


}

/// @nodoc
abstract mixin class $ExerciseMetadataCopyWith<$Res>  {
  factory $ExerciseMetadataCopyWith(ExerciseMetadata value, $Res Function(ExerciseMetadata) _then) = _$ExerciseMetadataCopyWithImpl;
@useResult
$Res call({
 String? copyOfUuid
});




}
/// @nodoc
class _$ExerciseMetadataCopyWithImpl<$Res>
    implements $ExerciseMetadataCopyWith<$Res> {
  _$ExerciseMetadataCopyWithImpl(this._self, this._then);

  final ExerciseMetadata _self;
  final $Res Function(ExerciseMetadata) _then;

/// Create a copy of ExerciseMetadata
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? copyOfUuid = freezed,}) {
  return _then(_self.copyWith(
copyOfUuid: freezed == copyOfUuid ? _self.copyOfUuid : copyOfUuid // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ExerciseMetadata].
extension ExerciseMetadataPatterns on ExerciseMetadata {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ExerciseMetadata value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ExerciseMetadata() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ExerciseMetadata value)  $default,){
final _that = this;
switch (_that) {
case _ExerciseMetadata():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ExerciseMetadata value)?  $default,){
final _that = this;
switch (_that) {
case _ExerciseMetadata() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? copyOfUuid)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ExerciseMetadata() when $default != null:
return $default(_that.copyOfUuid);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? copyOfUuid)  $default,) {final _that = this;
switch (_that) {
case _ExerciseMetadata():
return $default(_that.copyOfUuid);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? copyOfUuid)?  $default,) {final _that = this;
switch (_that) {
case _ExerciseMetadata() when $default != null:
return $default(_that.copyOfUuid);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ExerciseMetadata implements ExerciseMetadata {
  const _ExerciseMetadata({this.copyOfUuid});
  factory _ExerciseMetadata.fromJson(Map<String, dynamic> json) => _$ExerciseMetadataFromJson(json);

@override final  String? copyOfUuid;

/// Create a copy of ExerciseMetadata
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ExerciseMetadataCopyWith<_ExerciseMetadata> get copyWith => __$ExerciseMetadataCopyWithImpl<_ExerciseMetadata>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ExerciseMetadataToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ExerciseMetadata&&(identical(other.copyOfUuid, copyOfUuid) || other.copyOfUuid == copyOfUuid));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,copyOfUuid);

@override
String toString() {
  return 'ExerciseMetadata(copyOfUuid: $copyOfUuid)';
}


}

/// @nodoc
abstract mixin class _$ExerciseMetadataCopyWith<$Res> implements $ExerciseMetadataCopyWith<$Res> {
  factory _$ExerciseMetadataCopyWith(_ExerciseMetadata value, $Res Function(_ExerciseMetadata) _then) = __$ExerciseMetadataCopyWithImpl;
@override @useResult
$Res call({
 String? copyOfUuid
});




}
/// @nodoc
class __$ExerciseMetadataCopyWithImpl<$Res>
    implements _$ExerciseMetadataCopyWith<$Res> {
  __$ExerciseMetadataCopyWithImpl(this._self, this._then);

  final _ExerciseMetadata _self;
  final $Res Function(_ExerciseMetadata) _then;

/// Create a copy of ExerciseMetadata
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? copyOfUuid = freezed,}) {
  return _then(_ExerciseMetadata(
copyOfUuid: freezed == copyOfUuid ? _self.copyOfUuid : copyOfUuid // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
