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
mixin _$GroupSlot {

 int get stationIndex; List<int> get teams;
/// Create a copy of GroupSlot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GroupSlotCopyWith<GroupSlot> get copyWith => _$GroupSlotCopyWithImpl<GroupSlot>(this as GroupSlot, _$identity);

  /// Serializes this GroupSlot to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GroupSlot&&(identical(other.stationIndex, stationIndex) || other.stationIndex == stationIndex)&&const DeepCollectionEquality().equals(other.teams, teams));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,stationIndex,const DeepCollectionEquality().hash(teams));

@override
String toString() {
  return 'GroupSlot(stationIndex: $stationIndex, teams: $teams)';
}


}

/// @nodoc
abstract mixin class $GroupSlotCopyWith<$Res>  {
  factory $GroupSlotCopyWith(GroupSlot value, $Res Function(GroupSlot) _then) = _$GroupSlotCopyWithImpl;
@useResult
$Res call({
 int stationIndex, List<int> teams
});




}
/// @nodoc
class _$GroupSlotCopyWithImpl<$Res>
    implements $GroupSlotCopyWith<$Res> {
  _$GroupSlotCopyWithImpl(this._self, this._then);

  final GroupSlot _self;
  final $Res Function(GroupSlot) _then;

/// Create a copy of GroupSlot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? stationIndex = null,Object? teams = null,}) {
  return _then(_self.copyWith(
stationIndex: null == stationIndex ? _self.stationIndex : stationIndex // ignore: cast_nullable_to_non_nullable
as int,teams: null == teams ? _self.teams : teams // ignore: cast_nullable_to_non_nullable
as List<int>,
  ));
}

}


/// Adds pattern-matching-related methods to [GroupSlot].
extension GroupSlotPatterns on GroupSlot {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GroupSlot value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GroupSlot() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GroupSlot value)  $default,){
final _that = this;
switch (_that) {
case _GroupSlot():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GroupSlot value)?  $default,){
final _that = this;
switch (_that) {
case _GroupSlot() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int stationIndex,  List<int> teams)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GroupSlot() when $default != null:
return $default(_that.stationIndex,_that.teams);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int stationIndex,  List<int> teams)  $default,) {final _that = this;
switch (_that) {
case _GroupSlot():
return $default(_that.stationIndex,_that.teams);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int stationIndex,  List<int> teams)?  $default,) {final _that = this;
switch (_that) {
case _GroupSlot() when $default != null:
return $default(_that.stationIndex,_that.teams);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GroupSlot implements GroupSlot {
  const _GroupSlot({required this.stationIndex, final  List<int> teams = const <int>[]}): _teams = teams;
  factory _GroupSlot.fromJson(Map<String, dynamic> json) => _$GroupSlotFromJson(json);

@override final  int stationIndex;
 final  List<int> _teams;
@override@JsonKey() List<int> get teams {
  if (_teams is EqualUnmodifiableListView) return _teams;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_teams);
}


/// Create a copy of GroupSlot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GroupSlotCopyWith<_GroupSlot> get copyWith => __$GroupSlotCopyWithImpl<_GroupSlot>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GroupSlotToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GroupSlot&&(identical(other.stationIndex, stationIndex) || other.stationIndex == stationIndex)&&const DeepCollectionEquality().equals(other._teams, _teams));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,stationIndex,const DeepCollectionEquality().hash(_teams));

@override
String toString() {
  return 'GroupSlot(stationIndex: $stationIndex, teams: $teams)';
}


}

/// @nodoc
abstract mixin class _$GroupSlotCopyWith<$Res> implements $GroupSlotCopyWith<$Res> {
  factory _$GroupSlotCopyWith(_GroupSlot value, $Res Function(_GroupSlot) _then) = __$GroupSlotCopyWithImpl;
@override @useResult
$Res call({
 int stationIndex, List<int> teams
});




}
/// @nodoc
class __$GroupSlotCopyWithImpl<$Res>
    implements _$GroupSlotCopyWith<$Res> {
  __$GroupSlotCopyWithImpl(this._self, this._then);

  final _GroupSlot _self;
  final $Res Function(_GroupSlot) _then;

/// Create a copy of GroupSlot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? stationIndex = null,Object? teams = null,}) {
  return _then(_GroupSlot(
stationIndex: null == stationIndex ? _self.stationIndex : stationIndex // ignore: cast_nullable_to_non_nullable
as int,teams: null == teams ? _self._teams : teams // ignore: cast_nullable_to_non_nullable
as List<int>,
  ));
}


}


/// @nodoc
mixin _$ExerciseGroup {

 List<GroupSlot> get stations;
/// Create a copy of ExerciseGroup
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ExerciseGroupCopyWith<ExerciseGroup> get copyWith => _$ExerciseGroupCopyWithImpl<ExerciseGroup>(this as ExerciseGroup, _$identity);

  /// Serializes this ExerciseGroup to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ExerciseGroup&&const DeepCollectionEquality().equals(other.stations, stations));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(stations));

@override
String toString() {
  return 'ExerciseGroup(stations: $stations)';
}


}

/// @nodoc
abstract mixin class $ExerciseGroupCopyWith<$Res>  {
  factory $ExerciseGroupCopyWith(ExerciseGroup value, $Res Function(ExerciseGroup) _then) = _$ExerciseGroupCopyWithImpl;
@useResult
$Res call({
 List<GroupSlot> stations
});




}
/// @nodoc
class _$ExerciseGroupCopyWithImpl<$Res>
    implements $ExerciseGroupCopyWith<$Res> {
  _$ExerciseGroupCopyWithImpl(this._self, this._then);

  final ExerciseGroup _self;
  final $Res Function(ExerciseGroup) _then;

/// Create a copy of ExerciseGroup
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? stations = null,}) {
  return _then(_self.copyWith(
stations: null == stations ? _self.stations : stations // ignore: cast_nullable_to_non_nullable
as List<GroupSlot>,
  ));
}

}


/// Adds pattern-matching-related methods to [ExerciseGroup].
extension ExerciseGroupPatterns on ExerciseGroup {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ExerciseGroup value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ExerciseGroup() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ExerciseGroup value)  $default,){
final _that = this;
switch (_that) {
case _ExerciseGroup():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ExerciseGroup value)?  $default,){
final _that = this;
switch (_that) {
case _ExerciseGroup() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<GroupSlot> stations)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ExerciseGroup() when $default != null:
return $default(_that.stations);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<GroupSlot> stations)  $default,) {final _that = this;
switch (_that) {
case _ExerciseGroup():
return $default(_that.stations);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<GroupSlot> stations)?  $default,) {final _that = this;
switch (_that) {
case _ExerciseGroup() when $default != null:
return $default(_that.stations);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ExerciseGroup implements ExerciseGroup {
  const _ExerciseGroup({final  List<GroupSlot> stations = const <GroupSlot>[]}): _stations = stations;
  factory _ExerciseGroup.fromJson(Map<String, dynamic> json) => _$ExerciseGroupFromJson(json);

 final  List<GroupSlot> _stations;
@override@JsonKey() List<GroupSlot> get stations {
  if (_stations is EqualUnmodifiableListView) return _stations;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_stations);
}


/// Create a copy of ExerciseGroup
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ExerciseGroupCopyWith<_ExerciseGroup> get copyWith => __$ExerciseGroupCopyWithImpl<_ExerciseGroup>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ExerciseGroupToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ExerciseGroup&&const DeepCollectionEquality().equals(other._stations, _stations));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_stations));

@override
String toString() {
  return 'ExerciseGroup(stations: $stations)';
}


}

/// @nodoc
abstract mixin class _$ExerciseGroupCopyWith<$Res> implements $ExerciseGroupCopyWith<$Res> {
  factory _$ExerciseGroupCopyWith(_ExerciseGroup value, $Res Function(_ExerciseGroup) _then) = __$ExerciseGroupCopyWithImpl;
@override @useResult
$Res call({
 List<GroupSlot> stations
});




}
/// @nodoc
class __$ExerciseGroupCopyWithImpl<$Res>
    implements _$ExerciseGroupCopyWith<$Res> {
  __$ExerciseGroupCopyWithImpl(this._self, this._then);

  final _ExerciseGroup _self;
  final $Res Function(_ExerciseGroup) _then;

/// Create a copy of ExerciseGroup
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? stations = null,}) {
  return _then(_ExerciseGroup(
stations: null == stations ? _self._stations : stations // ignore: cast_nullable_to_non_nullable
as List<GroupSlot>,
  ));
}


}


/// @nodoc
mixin _$Exercise {

 String get uuid; int get index; String get name; SimpleTimeOfDay get startTime; int get numberOfTeams; int get numberOfRounds;/// How teams relate to stations (ADR-0062). Absent in every archive written
/// before it, which is why the default is [ExerciseMode.ring] rather than a
/// migration rung: an old plan *is* a ring route, and says so by omission.
 ExerciseMode get mode;/// One entry per round, for [ExerciseMode.split] only: the stations running at
/// once and the teams on each (ADR-0062). Empty in every other mode, where the
/// grouping is generated from the stations instead.
 List<ExerciseGroup> get groups; int get executionTime; int get evaluationTime; int get rotationTime; List<Station> get stations; List<List<SimpleTimeOfDay>> get schedule; SimpleTimeOfDay get endTime; ExerciseMetadata? get metadata; String? get templateId;/// Per-scope value overrides for plan-global variables, keyed by
/// DrillVariable.name. A key that does not name a declared variable is
/// meaningless and is ignored at resolution time (ADR-0046). This scope
/// never declares new variables.
 Map<String, String> get variableOverrides;// Markdown brief fields — stored as exercises/<uuid>/<field>.md, not in JSON.
@JsonKey(includeFromJson: false, includeToJson: false) String? get methodMd;@JsonKey(includeFromJson: false, includeToJson: false) String? get learningGoalsMd;@JsonKey(includeFromJson: false, includeToJson: false) String? get trainingFocusMd;@JsonKey(includeFromJson: false, includeToJson: false) String? get orderFormatMd;@JsonKey(includeFromJson: false, includeToJson: false) String? get executionTipsMd;@JsonKey(includeFromJson: false, includeToJson: false) String? get commsMd;
/// Create a copy of Exercise
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ExerciseCopyWith<Exercise> get copyWith => _$ExerciseCopyWithImpl<Exercise>(this as Exercise, _$identity);

  /// Serializes this Exercise to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Exercise&&(identical(other.uuid, uuid) || other.uuid == uuid)&&(identical(other.index, index) || other.index == index)&&(identical(other.name, name) || other.name == name)&&(identical(other.startTime, startTime) || other.startTime == startTime)&&(identical(other.numberOfTeams, numberOfTeams) || other.numberOfTeams == numberOfTeams)&&(identical(other.numberOfRounds, numberOfRounds) || other.numberOfRounds == numberOfRounds)&&(identical(other.mode, mode) || other.mode == mode)&&const DeepCollectionEquality().equals(other.groups, groups)&&(identical(other.executionTime, executionTime) || other.executionTime == executionTime)&&(identical(other.evaluationTime, evaluationTime) || other.evaluationTime == evaluationTime)&&(identical(other.rotationTime, rotationTime) || other.rotationTime == rotationTime)&&const DeepCollectionEquality().equals(other.stations, stations)&&const DeepCollectionEquality().equals(other.schedule, schedule)&&(identical(other.endTime, endTime) || other.endTime == endTime)&&(identical(other.metadata, metadata) || other.metadata == metadata)&&(identical(other.templateId, templateId) || other.templateId == templateId)&&const DeepCollectionEquality().equals(other.variableOverrides, variableOverrides)&&(identical(other.methodMd, methodMd) || other.methodMd == methodMd)&&(identical(other.learningGoalsMd, learningGoalsMd) || other.learningGoalsMd == learningGoalsMd)&&(identical(other.trainingFocusMd, trainingFocusMd) || other.trainingFocusMd == trainingFocusMd)&&(identical(other.orderFormatMd, orderFormatMd) || other.orderFormatMd == orderFormatMd)&&(identical(other.executionTipsMd, executionTipsMd) || other.executionTipsMd == executionTipsMd)&&(identical(other.commsMd, commsMd) || other.commsMd == commsMd));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,uuid,index,name,startTime,numberOfTeams,numberOfRounds,mode,const DeepCollectionEquality().hash(groups),executionTime,evaluationTime,rotationTime,const DeepCollectionEquality().hash(stations),const DeepCollectionEquality().hash(schedule),endTime,metadata,templateId,const DeepCollectionEquality().hash(variableOverrides),methodMd,learningGoalsMd,trainingFocusMd,orderFormatMd,executionTipsMd,commsMd]);

@override
String toString() {
  return 'Exercise(uuid: $uuid, index: $index, name: $name, startTime: $startTime, numberOfTeams: $numberOfTeams, numberOfRounds: $numberOfRounds, mode: $mode, groups: $groups, executionTime: $executionTime, evaluationTime: $evaluationTime, rotationTime: $rotationTime, stations: $stations, schedule: $schedule, endTime: $endTime, metadata: $metadata, templateId: $templateId, variableOverrides: $variableOverrides, methodMd: $methodMd, learningGoalsMd: $learningGoalsMd, trainingFocusMd: $trainingFocusMd, orderFormatMd: $orderFormatMd, executionTipsMd: $executionTipsMd, commsMd: $commsMd)';
}


}

/// @nodoc
abstract mixin class $ExerciseCopyWith<$Res>  {
  factory $ExerciseCopyWith(Exercise value, $Res Function(Exercise) _then) = _$ExerciseCopyWithImpl;
@useResult
$Res call({
 String uuid, int index, String name, SimpleTimeOfDay startTime, int numberOfTeams, int numberOfRounds, ExerciseMode mode, List<ExerciseGroup> groups, int executionTime, int evaluationTime, int rotationTime, List<Station> stations, List<List<SimpleTimeOfDay>> schedule, SimpleTimeOfDay endTime, ExerciseMetadata? metadata, String? templateId, Map<String, String> variableOverrides,@JsonKey(includeFromJson: false, includeToJson: false) String? methodMd,@JsonKey(includeFromJson: false, includeToJson: false) String? learningGoalsMd,@JsonKey(includeFromJson: false, includeToJson: false) String? trainingFocusMd,@JsonKey(includeFromJson: false, includeToJson: false) String? orderFormatMd,@JsonKey(includeFromJson: false, includeToJson: false) String? executionTipsMd,@JsonKey(includeFromJson: false, includeToJson: false) String? commsMd
});


$SimpleTimeOfDayCopyWith<$Res> get startTime;$SimpleTimeOfDayCopyWith<$Res> get endTime;$ExerciseMetadataCopyWith<$Res>? get metadata;

}
/// @nodoc
class _$ExerciseCopyWithImpl<$Res>
    implements $ExerciseCopyWith<$Res> {
  _$ExerciseCopyWithImpl(this._self, this._then);

  final Exercise _self;
  final $Res Function(Exercise) _then;

/// Create a copy of Exercise
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? uuid = null,Object? index = null,Object? name = null,Object? startTime = null,Object? numberOfTeams = null,Object? numberOfRounds = null,Object? mode = null,Object? groups = null,Object? executionTime = null,Object? evaluationTime = null,Object? rotationTime = null,Object? stations = null,Object? schedule = null,Object? endTime = null,Object? metadata = freezed,Object? templateId = freezed,Object? variableOverrides = null,Object? methodMd = freezed,Object? learningGoalsMd = freezed,Object? trainingFocusMd = freezed,Object? orderFormatMd = freezed,Object? executionTipsMd = freezed,Object? commsMd = freezed,}) {
  return _then(_self.copyWith(
uuid: null == uuid ? _self.uuid : uuid // ignore: cast_nullable_to_non_nullable
as String,index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,startTime: null == startTime ? _self.startTime : startTime // ignore: cast_nullable_to_non_nullable
as SimpleTimeOfDay,numberOfTeams: null == numberOfTeams ? _self.numberOfTeams : numberOfTeams // ignore: cast_nullable_to_non_nullable
as int,numberOfRounds: null == numberOfRounds ? _self.numberOfRounds : numberOfRounds // ignore: cast_nullable_to_non_nullable
as int,mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as ExerciseMode,groups: null == groups ? _self.groups : groups // ignore: cast_nullable_to_non_nullable
as List<ExerciseGroup>,executionTime: null == executionTime ? _self.executionTime : executionTime // ignore: cast_nullable_to_non_nullable
as int,evaluationTime: null == evaluationTime ? _self.evaluationTime : evaluationTime // ignore: cast_nullable_to_non_nullable
as int,rotationTime: null == rotationTime ? _self.rotationTime : rotationTime // ignore: cast_nullable_to_non_nullable
as int,stations: null == stations ? _self.stations : stations // ignore: cast_nullable_to_non_nullable
as List<Station>,schedule: null == schedule ? _self.schedule : schedule // ignore: cast_nullable_to_non_nullable
as List<List<SimpleTimeOfDay>>,endTime: null == endTime ? _self.endTime : endTime // ignore: cast_nullable_to_non_nullable
as SimpleTimeOfDay,metadata: freezed == metadata ? _self.metadata : metadata // ignore: cast_nullable_to_non_nullable
as ExerciseMetadata?,templateId: freezed == templateId ? _self.templateId : templateId // ignore: cast_nullable_to_non_nullable
as String?,variableOverrides: null == variableOverrides ? _self.variableOverrides : variableOverrides // ignore: cast_nullable_to_non_nullable
as Map<String, String>,methodMd: freezed == methodMd ? _self.methodMd : methodMd // ignore: cast_nullable_to_non_nullable
as String?,learningGoalsMd: freezed == learningGoalsMd ? _self.learningGoalsMd : learningGoalsMd // ignore: cast_nullable_to_non_nullable
as String?,trainingFocusMd: freezed == trainingFocusMd ? _self.trainingFocusMd : trainingFocusMd // ignore: cast_nullable_to_non_nullable
as String?,orderFormatMd: freezed == orderFormatMd ? _self.orderFormatMd : orderFormatMd // ignore: cast_nullable_to_non_nullable
as String?,executionTipsMd: freezed == executionTipsMd ? _self.executionTipsMd : executionTipsMd // ignore: cast_nullable_to_non_nullable
as String?,commsMd: freezed == commsMd ? _self.commsMd : commsMd // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of Exercise
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SimpleTimeOfDayCopyWith<$Res> get startTime {
  
  return $SimpleTimeOfDayCopyWith<$Res>(_self.startTime, (value) {
    return _then(_self.copyWith(startTime: value));
  });
}/// Create a copy of Exercise
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SimpleTimeOfDayCopyWith<$Res> get endTime {
  
  return $SimpleTimeOfDayCopyWith<$Res>(_self.endTime, (value) {
    return _then(_self.copyWith(endTime: value));
  });
}/// Create a copy of Exercise
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String uuid,  int index,  String name,  SimpleTimeOfDay startTime,  int numberOfTeams,  int numberOfRounds,  ExerciseMode mode,  List<ExerciseGroup> groups,  int executionTime,  int evaluationTime,  int rotationTime,  List<Station> stations,  List<List<SimpleTimeOfDay>> schedule,  SimpleTimeOfDay endTime,  ExerciseMetadata? metadata,  String? templateId,  Map<String, String> variableOverrides, @JsonKey(includeFromJson: false, includeToJson: false)  String? methodMd, @JsonKey(includeFromJson: false, includeToJson: false)  String? learningGoalsMd, @JsonKey(includeFromJson: false, includeToJson: false)  String? trainingFocusMd, @JsonKey(includeFromJson: false, includeToJson: false)  String? orderFormatMd, @JsonKey(includeFromJson: false, includeToJson: false)  String? executionTipsMd, @JsonKey(includeFromJson: false, includeToJson: false)  String? commsMd)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Exercise() when $default != null:
return $default(_that.uuid,_that.index,_that.name,_that.startTime,_that.numberOfTeams,_that.numberOfRounds,_that.mode,_that.groups,_that.executionTime,_that.evaluationTime,_that.rotationTime,_that.stations,_that.schedule,_that.endTime,_that.metadata,_that.templateId,_that.variableOverrides,_that.methodMd,_that.learningGoalsMd,_that.trainingFocusMd,_that.orderFormatMd,_that.executionTipsMd,_that.commsMd);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String uuid,  int index,  String name,  SimpleTimeOfDay startTime,  int numberOfTeams,  int numberOfRounds,  ExerciseMode mode,  List<ExerciseGroup> groups,  int executionTime,  int evaluationTime,  int rotationTime,  List<Station> stations,  List<List<SimpleTimeOfDay>> schedule,  SimpleTimeOfDay endTime,  ExerciseMetadata? metadata,  String? templateId,  Map<String, String> variableOverrides, @JsonKey(includeFromJson: false, includeToJson: false)  String? methodMd, @JsonKey(includeFromJson: false, includeToJson: false)  String? learningGoalsMd, @JsonKey(includeFromJson: false, includeToJson: false)  String? trainingFocusMd, @JsonKey(includeFromJson: false, includeToJson: false)  String? orderFormatMd, @JsonKey(includeFromJson: false, includeToJson: false)  String? executionTipsMd, @JsonKey(includeFromJson: false, includeToJson: false)  String? commsMd)  $default,) {final _that = this;
switch (_that) {
case _Exercise():
return $default(_that.uuid,_that.index,_that.name,_that.startTime,_that.numberOfTeams,_that.numberOfRounds,_that.mode,_that.groups,_that.executionTime,_that.evaluationTime,_that.rotationTime,_that.stations,_that.schedule,_that.endTime,_that.metadata,_that.templateId,_that.variableOverrides,_that.methodMd,_that.learningGoalsMd,_that.trainingFocusMd,_that.orderFormatMd,_that.executionTipsMd,_that.commsMd);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String uuid,  int index,  String name,  SimpleTimeOfDay startTime,  int numberOfTeams,  int numberOfRounds,  ExerciseMode mode,  List<ExerciseGroup> groups,  int executionTime,  int evaluationTime,  int rotationTime,  List<Station> stations,  List<List<SimpleTimeOfDay>> schedule,  SimpleTimeOfDay endTime,  ExerciseMetadata? metadata,  String? templateId,  Map<String, String> variableOverrides, @JsonKey(includeFromJson: false, includeToJson: false)  String? methodMd, @JsonKey(includeFromJson: false, includeToJson: false)  String? learningGoalsMd, @JsonKey(includeFromJson: false, includeToJson: false)  String? trainingFocusMd, @JsonKey(includeFromJson: false, includeToJson: false)  String? orderFormatMd, @JsonKey(includeFromJson: false, includeToJson: false)  String? executionTipsMd, @JsonKey(includeFromJson: false, includeToJson: false)  String? commsMd)?  $default,) {final _that = this;
switch (_that) {
case _Exercise() when $default != null:
return $default(_that.uuid,_that.index,_that.name,_that.startTime,_that.numberOfTeams,_that.numberOfRounds,_that.mode,_that.groups,_that.executionTime,_that.evaluationTime,_that.rotationTime,_that.stations,_that.schedule,_that.endTime,_that.metadata,_that.templateId,_that.variableOverrides,_that.methodMd,_that.learningGoalsMd,_that.trainingFocusMd,_that.orderFormatMd,_that.executionTipsMd,_that.commsMd);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Exercise implements Exercise {
  const _Exercise({required this.uuid, this.index = 0, required this.name, required this.startTime, required this.numberOfTeams, required this.numberOfRounds, this.mode = ExerciseMode.ring, final  List<ExerciseGroup> groups = const <ExerciseGroup>[], required this.executionTime, required this.evaluationTime, required this.rotationTime, required final  List<Station> stations, required final  List<List<SimpleTimeOfDay>> schedule, required this.endTime, this.metadata, this.templateId, final  Map<String, String> variableOverrides = const <String, String>{}, @JsonKey(includeFromJson: false, includeToJson: false) this.methodMd, @JsonKey(includeFromJson: false, includeToJson: false) this.learningGoalsMd, @JsonKey(includeFromJson: false, includeToJson: false) this.trainingFocusMd, @JsonKey(includeFromJson: false, includeToJson: false) this.orderFormatMd, @JsonKey(includeFromJson: false, includeToJson: false) this.executionTipsMd, @JsonKey(includeFromJson: false, includeToJson: false) this.commsMd}): _groups = groups,_stations = stations,_schedule = schedule,_variableOverrides = variableOverrides;
  factory _Exercise.fromJson(Map<String, dynamic> json) => _$ExerciseFromJson(json);

@override final  String uuid;
@override@JsonKey() final  int index;
@override final  String name;
@override final  SimpleTimeOfDay startTime;
@override final  int numberOfTeams;
@override final  int numberOfRounds;
/// How teams relate to stations (ADR-0062). Absent in every archive written
/// before it, which is why the default is [ExerciseMode.ring] rather than a
/// migration rung: an old plan *is* a ring route, and says so by omission.
@override@JsonKey() final  ExerciseMode mode;
/// One entry per round, for [ExerciseMode.split] only: the stations running at
/// once and the teams on each (ADR-0062). Empty in every other mode, where the
/// grouping is generated from the stations instead.
 final  List<ExerciseGroup> _groups;
/// One entry per round, for [ExerciseMode.split] only: the stations running at
/// once and the teams on each (ADR-0062). Empty in every other mode, where the
/// grouping is generated from the stations instead.
@override@JsonKey() List<ExerciseGroup> get groups {
  if (_groups is EqualUnmodifiableListView) return _groups;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_groups);
}

@override final  int executionTime;
@override final  int evaluationTime;
@override final  int rotationTime;
 final  List<Station> _stations;
@override List<Station> get stations {
  if (_stations is EqualUnmodifiableListView) return _stations;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_stations);
}

 final  List<List<SimpleTimeOfDay>> _schedule;
@override List<List<SimpleTimeOfDay>> get schedule {
  if (_schedule is EqualUnmodifiableListView) return _schedule;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_schedule);
}

@override final  SimpleTimeOfDay endTime;
@override final  ExerciseMetadata? metadata;
@override final  String? templateId;
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

// Markdown brief fields — stored as exercises/<uuid>/<field>.md, not in JSON.
@override@JsonKey(includeFromJson: false, includeToJson: false) final  String? methodMd;
@override@JsonKey(includeFromJson: false, includeToJson: false) final  String? learningGoalsMd;
@override@JsonKey(includeFromJson: false, includeToJson: false) final  String? trainingFocusMd;
@override@JsonKey(includeFromJson: false, includeToJson: false) final  String? orderFormatMd;
@override@JsonKey(includeFromJson: false, includeToJson: false) final  String? executionTipsMd;
@override@JsonKey(includeFromJson: false, includeToJson: false) final  String? commsMd;

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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Exercise&&(identical(other.uuid, uuid) || other.uuid == uuid)&&(identical(other.index, index) || other.index == index)&&(identical(other.name, name) || other.name == name)&&(identical(other.startTime, startTime) || other.startTime == startTime)&&(identical(other.numberOfTeams, numberOfTeams) || other.numberOfTeams == numberOfTeams)&&(identical(other.numberOfRounds, numberOfRounds) || other.numberOfRounds == numberOfRounds)&&(identical(other.mode, mode) || other.mode == mode)&&const DeepCollectionEquality().equals(other._groups, _groups)&&(identical(other.executionTime, executionTime) || other.executionTime == executionTime)&&(identical(other.evaluationTime, evaluationTime) || other.evaluationTime == evaluationTime)&&(identical(other.rotationTime, rotationTime) || other.rotationTime == rotationTime)&&const DeepCollectionEquality().equals(other._stations, _stations)&&const DeepCollectionEquality().equals(other._schedule, _schedule)&&(identical(other.endTime, endTime) || other.endTime == endTime)&&(identical(other.metadata, metadata) || other.metadata == metadata)&&(identical(other.templateId, templateId) || other.templateId == templateId)&&const DeepCollectionEquality().equals(other._variableOverrides, _variableOverrides)&&(identical(other.methodMd, methodMd) || other.methodMd == methodMd)&&(identical(other.learningGoalsMd, learningGoalsMd) || other.learningGoalsMd == learningGoalsMd)&&(identical(other.trainingFocusMd, trainingFocusMd) || other.trainingFocusMd == trainingFocusMd)&&(identical(other.orderFormatMd, orderFormatMd) || other.orderFormatMd == orderFormatMd)&&(identical(other.executionTipsMd, executionTipsMd) || other.executionTipsMd == executionTipsMd)&&(identical(other.commsMd, commsMd) || other.commsMd == commsMd));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,uuid,index,name,startTime,numberOfTeams,numberOfRounds,mode,const DeepCollectionEquality().hash(_groups),executionTime,evaluationTime,rotationTime,const DeepCollectionEquality().hash(_stations),const DeepCollectionEquality().hash(_schedule),endTime,metadata,templateId,const DeepCollectionEquality().hash(_variableOverrides),methodMd,learningGoalsMd,trainingFocusMd,orderFormatMd,executionTipsMd,commsMd]);

@override
String toString() {
  return 'Exercise(uuid: $uuid, index: $index, name: $name, startTime: $startTime, numberOfTeams: $numberOfTeams, numberOfRounds: $numberOfRounds, mode: $mode, groups: $groups, executionTime: $executionTime, evaluationTime: $evaluationTime, rotationTime: $rotationTime, stations: $stations, schedule: $schedule, endTime: $endTime, metadata: $metadata, templateId: $templateId, variableOverrides: $variableOverrides, methodMd: $methodMd, learningGoalsMd: $learningGoalsMd, trainingFocusMd: $trainingFocusMd, orderFormatMd: $orderFormatMd, executionTipsMd: $executionTipsMd, commsMd: $commsMd)';
}


}

/// @nodoc
abstract mixin class _$ExerciseCopyWith<$Res> implements $ExerciseCopyWith<$Res> {
  factory _$ExerciseCopyWith(_Exercise value, $Res Function(_Exercise) _then) = __$ExerciseCopyWithImpl;
@override @useResult
$Res call({
 String uuid, int index, String name, SimpleTimeOfDay startTime, int numberOfTeams, int numberOfRounds, ExerciseMode mode, List<ExerciseGroup> groups, int executionTime, int evaluationTime, int rotationTime, List<Station> stations, List<List<SimpleTimeOfDay>> schedule, SimpleTimeOfDay endTime, ExerciseMetadata? metadata, String? templateId, Map<String, String> variableOverrides,@JsonKey(includeFromJson: false, includeToJson: false) String? methodMd,@JsonKey(includeFromJson: false, includeToJson: false) String? learningGoalsMd,@JsonKey(includeFromJson: false, includeToJson: false) String? trainingFocusMd,@JsonKey(includeFromJson: false, includeToJson: false) String? orderFormatMd,@JsonKey(includeFromJson: false, includeToJson: false) String? executionTipsMd,@JsonKey(includeFromJson: false, includeToJson: false) String? commsMd
});


@override $SimpleTimeOfDayCopyWith<$Res> get startTime;@override $SimpleTimeOfDayCopyWith<$Res> get endTime;@override $ExerciseMetadataCopyWith<$Res>? get metadata;

}
/// @nodoc
class __$ExerciseCopyWithImpl<$Res>
    implements _$ExerciseCopyWith<$Res> {
  __$ExerciseCopyWithImpl(this._self, this._then);

  final _Exercise _self;
  final $Res Function(_Exercise) _then;

/// Create a copy of Exercise
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? uuid = null,Object? index = null,Object? name = null,Object? startTime = null,Object? numberOfTeams = null,Object? numberOfRounds = null,Object? mode = null,Object? groups = null,Object? executionTime = null,Object? evaluationTime = null,Object? rotationTime = null,Object? stations = null,Object? schedule = null,Object? endTime = null,Object? metadata = freezed,Object? templateId = freezed,Object? variableOverrides = null,Object? methodMd = freezed,Object? learningGoalsMd = freezed,Object? trainingFocusMd = freezed,Object? orderFormatMd = freezed,Object? executionTipsMd = freezed,Object? commsMd = freezed,}) {
  return _then(_Exercise(
uuid: null == uuid ? _self.uuid : uuid // ignore: cast_nullable_to_non_nullable
as String,index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,startTime: null == startTime ? _self.startTime : startTime // ignore: cast_nullable_to_non_nullable
as SimpleTimeOfDay,numberOfTeams: null == numberOfTeams ? _self.numberOfTeams : numberOfTeams // ignore: cast_nullable_to_non_nullable
as int,numberOfRounds: null == numberOfRounds ? _self.numberOfRounds : numberOfRounds // ignore: cast_nullable_to_non_nullable
as int,mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as ExerciseMode,groups: null == groups ? _self._groups : groups // ignore: cast_nullable_to_non_nullable
as List<ExerciseGroup>,executionTime: null == executionTime ? _self.executionTime : executionTime // ignore: cast_nullable_to_non_nullable
as int,evaluationTime: null == evaluationTime ? _self.evaluationTime : evaluationTime // ignore: cast_nullable_to_non_nullable
as int,rotationTime: null == rotationTime ? _self.rotationTime : rotationTime // ignore: cast_nullable_to_non_nullable
as int,stations: null == stations ? _self._stations : stations // ignore: cast_nullable_to_non_nullable
as List<Station>,schedule: null == schedule ? _self._schedule : schedule // ignore: cast_nullable_to_non_nullable
as List<List<SimpleTimeOfDay>>,endTime: null == endTime ? _self.endTime : endTime // ignore: cast_nullable_to_non_nullable
as SimpleTimeOfDay,metadata: freezed == metadata ? _self.metadata : metadata // ignore: cast_nullable_to_non_nullable
as ExerciseMetadata?,templateId: freezed == templateId ? _self.templateId : templateId // ignore: cast_nullable_to_non_nullable
as String?,variableOverrides: null == variableOverrides ? _self._variableOverrides : variableOverrides // ignore: cast_nullable_to_non_nullable
as Map<String, String>,methodMd: freezed == methodMd ? _self.methodMd : methodMd // ignore: cast_nullable_to_non_nullable
as String?,learningGoalsMd: freezed == learningGoalsMd ? _self.learningGoalsMd : learningGoalsMd // ignore: cast_nullable_to_non_nullable
as String?,trainingFocusMd: freezed == trainingFocusMd ? _self.trainingFocusMd : trainingFocusMd // ignore: cast_nullable_to_non_nullable
as String?,orderFormatMd: freezed == orderFormatMd ? _self.orderFormatMd : orderFormatMd // ignore: cast_nullable_to_non_nullable
as String?,executionTipsMd: freezed == executionTipsMd ? _self.executionTipsMd : executionTipsMd // ignore: cast_nullable_to_non_nullable
as String?,commsMd: freezed == commsMd ? _self.commsMd : commsMd // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of Exercise
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SimpleTimeOfDayCopyWith<$Res> get startTime {
  
  return $SimpleTimeOfDayCopyWith<$Res>(_self.startTime, (value) {
    return _then(_self.copyWith(startTime: value));
  });
}/// Create a copy of Exercise
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SimpleTimeOfDayCopyWith<$Res> get endTime {
  
  return $SimpleTimeOfDayCopyWith<$Res>(_self.endTime, (value) {
    return _then(_self.copyWith(endTime: value));
  });
}/// Create a copy of Exercise
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


/// @nodoc
mixin _$SimpleTimeOfDay {

 int get hour; int get minute;
/// Create a copy of SimpleTimeOfDay
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SimpleTimeOfDayCopyWith<SimpleTimeOfDay> get copyWith => _$SimpleTimeOfDayCopyWithImpl<SimpleTimeOfDay>(this as SimpleTimeOfDay, _$identity);

  /// Serializes this SimpleTimeOfDay to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SimpleTimeOfDay&&(identical(other.hour, hour) || other.hour == hour)&&(identical(other.minute, minute) || other.minute == minute));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,hour,minute);



}

/// @nodoc
abstract mixin class $SimpleTimeOfDayCopyWith<$Res>  {
  factory $SimpleTimeOfDayCopyWith(SimpleTimeOfDay value, $Res Function(SimpleTimeOfDay) _then) = _$SimpleTimeOfDayCopyWithImpl;
@useResult
$Res call({
 int hour, int minute
});




}
/// @nodoc
class _$SimpleTimeOfDayCopyWithImpl<$Res>
    implements $SimpleTimeOfDayCopyWith<$Res> {
  _$SimpleTimeOfDayCopyWithImpl(this._self, this._then);

  final SimpleTimeOfDay _self;
  final $Res Function(SimpleTimeOfDay) _then;

/// Create a copy of SimpleTimeOfDay
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? hour = null,Object? minute = null,}) {
  return _then(_self.copyWith(
hour: null == hour ? _self.hour : hour // ignore: cast_nullable_to_non_nullable
as int,minute: null == minute ? _self.minute : minute // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [SimpleTimeOfDay].
extension SimpleTimeOfDayPatterns on SimpleTimeOfDay {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SimpleTimeOfDay value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SimpleTimeOfDay() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SimpleTimeOfDay value)  $default,){
final _that = this;
switch (_that) {
case _SimpleTimeOfDay():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SimpleTimeOfDay value)?  $default,){
final _that = this;
switch (_that) {
case _SimpleTimeOfDay() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int hour,  int minute)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SimpleTimeOfDay() when $default != null:
return $default(_that.hour,_that.minute);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int hour,  int minute)  $default,) {final _that = this;
switch (_that) {
case _SimpleTimeOfDay():
return $default(_that.hour,_that.minute);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int hour,  int minute)?  $default,) {final _that = this;
switch (_that) {
case _SimpleTimeOfDay() when $default != null:
return $default(_that.hour,_that.minute);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SimpleTimeOfDay extends SimpleTimeOfDay {
  const _SimpleTimeOfDay({required this.hour, required this.minute}): super._();
  factory _SimpleTimeOfDay.fromJson(Map<String, dynamic> json) => _$SimpleTimeOfDayFromJson(json);

@override final  int hour;
@override final  int minute;

/// Create a copy of SimpleTimeOfDay
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SimpleTimeOfDayCopyWith<_SimpleTimeOfDay> get copyWith => __$SimpleTimeOfDayCopyWithImpl<_SimpleTimeOfDay>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SimpleTimeOfDayToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SimpleTimeOfDay&&(identical(other.hour, hour) || other.hour == hour)&&(identical(other.minute, minute) || other.minute == minute));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,hour,minute);



}

/// @nodoc
abstract mixin class _$SimpleTimeOfDayCopyWith<$Res> implements $SimpleTimeOfDayCopyWith<$Res> {
  factory _$SimpleTimeOfDayCopyWith(_SimpleTimeOfDay value, $Res Function(_SimpleTimeOfDay) _then) = __$SimpleTimeOfDayCopyWithImpl;
@override @useResult
$Res call({
 int hour, int minute
});




}
/// @nodoc
class __$SimpleTimeOfDayCopyWithImpl<$Res>
    implements _$SimpleTimeOfDayCopyWith<$Res> {
  __$SimpleTimeOfDayCopyWithImpl(this._self, this._then);

  final _SimpleTimeOfDay _self;
  final $Res Function(_SimpleTimeOfDay) _then;

/// Create a copy of SimpleTimeOfDay
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? hour = null,Object? minute = null,}) {
  return _then(_SimpleTimeOfDay(
hour: null == hour ? _self.hour : hour // ignore: cast_nullable_to_non_nullable
as int,minute: null == minute ? _self.minute : minute // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
