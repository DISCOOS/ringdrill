// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'program.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Program {

 String get uuid; String get name; String get description; ProgramMetadata get metadata; ProgramSource get source; String? get contentHash; List<Team> get teams; List<Session> get sessions; List<Exercise> get exercises;// @Default([]) so 1.0 archives without these keys deserialize to empty
// lists rather than failing (ADR-0018 backward-compat requirement).
 List<RolePlay> get rolePlays; List<Actor> get actors;
/// Create a copy of Program
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProgramCopyWith<Program> get copyWith => _$ProgramCopyWithImpl<Program>(this as Program, _$identity);

  /// Serializes this Program to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Program&&(identical(other.uuid, uuid) || other.uuid == uuid)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.metadata, metadata) || other.metadata == metadata)&&(identical(other.source, source) || other.source == source)&&(identical(other.contentHash, contentHash) || other.contentHash == contentHash)&&const DeepCollectionEquality().equals(other.teams, teams)&&const DeepCollectionEquality().equals(other.sessions, sessions)&&const DeepCollectionEquality().equals(other.exercises, exercises)&&const DeepCollectionEquality().equals(other.rolePlays, rolePlays)&&const DeepCollectionEquality().equals(other.actors, actors));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,uuid,name,description,metadata,source,contentHash,const DeepCollectionEquality().hash(teams),const DeepCollectionEquality().hash(sessions),const DeepCollectionEquality().hash(exercises),const DeepCollectionEquality().hash(rolePlays),const DeepCollectionEquality().hash(actors));

@override
String toString() {
  return 'Program(uuid: $uuid, name: $name, description: $description, metadata: $metadata, source: $source, contentHash: $contentHash, teams: $teams, sessions: $sessions, exercises: $exercises, rolePlays: $rolePlays, actors: $actors)';
}


}

/// @nodoc
abstract mixin class $ProgramCopyWith<$Res>  {
  factory $ProgramCopyWith(Program value, $Res Function(Program) _then) = _$ProgramCopyWithImpl;
@useResult
$Res call({
 String uuid, String name, String description, ProgramMetadata metadata, ProgramSource source, String? contentHash, List<Team> teams, List<Session> sessions, List<Exercise> exercises, List<RolePlay> rolePlays, List<Actor> actors
});


$ProgramMetadataCopyWith<$Res> get metadata;$ProgramSourceCopyWith<$Res> get source;

}
/// @nodoc
class _$ProgramCopyWithImpl<$Res>
    implements $ProgramCopyWith<$Res> {
  _$ProgramCopyWithImpl(this._self, this._then);

  final Program _self;
  final $Res Function(Program) _then;

/// Create a copy of Program
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? uuid = null,Object? name = null,Object? description = null,Object? metadata = null,Object? source = null,Object? contentHash = freezed,Object? teams = null,Object? sessions = null,Object? exercises = null,Object? rolePlays = null,Object? actors = null,}) {
  return _then(_self.copyWith(
uuid: null == uuid ? _self.uuid : uuid // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,metadata: null == metadata ? _self.metadata : metadata // ignore: cast_nullable_to_non_nullable
as ProgramMetadata,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as ProgramSource,contentHash: freezed == contentHash ? _self.contentHash : contentHash // ignore: cast_nullable_to_non_nullable
as String?,teams: null == teams ? _self.teams : teams // ignore: cast_nullable_to_non_nullable
as List<Team>,sessions: null == sessions ? _self.sessions : sessions // ignore: cast_nullable_to_non_nullable
as List<Session>,exercises: null == exercises ? _self.exercises : exercises // ignore: cast_nullable_to_non_nullable
as List<Exercise>,rolePlays: null == rolePlays ? _self.rolePlays : rolePlays // ignore: cast_nullable_to_non_nullable
as List<RolePlay>,actors: null == actors ? _self.actors : actors // ignore: cast_nullable_to_non_nullable
as List<Actor>,
  ));
}
/// Create a copy of Program
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProgramMetadataCopyWith<$Res> get metadata {
  
  return $ProgramMetadataCopyWith<$Res>(_self.metadata, (value) {
    return _then(_self.copyWith(metadata: value));
  });
}/// Create a copy of Program
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProgramSourceCopyWith<$Res> get source {
  
  return $ProgramSourceCopyWith<$Res>(_self.source, (value) {
    return _then(_self.copyWith(source: value));
  });
}
}


/// Adds pattern-matching-related methods to [Program].
extension ProgramPatterns on Program {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Program value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Program() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Program value)  $default,){
final _that = this;
switch (_that) {
case _Program():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Program value)?  $default,){
final _that = this;
switch (_that) {
case _Program() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String uuid,  String name,  String description,  ProgramMetadata metadata,  ProgramSource source,  String? contentHash,  List<Team> teams,  List<Session> sessions,  List<Exercise> exercises,  List<RolePlay> rolePlays,  List<Actor> actors)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Program() when $default != null:
return $default(_that.uuid,_that.name,_that.description,_that.metadata,_that.source,_that.contentHash,_that.teams,_that.sessions,_that.exercises,_that.rolePlays,_that.actors);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String uuid,  String name,  String description,  ProgramMetadata metadata,  ProgramSource source,  String? contentHash,  List<Team> teams,  List<Session> sessions,  List<Exercise> exercises,  List<RolePlay> rolePlays,  List<Actor> actors)  $default,) {final _that = this;
switch (_that) {
case _Program():
return $default(_that.uuid,_that.name,_that.description,_that.metadata,_that.source,_that.contentHash,_that.teams,_that.sessions,_that.exercises,_that.rolePlays,_that.actors);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String uuid,  String name,  String description,  ProgramMetadata metadata,  ProgramSource source,  String? contentHash,  List<Team> teams,  List<Session> sessions,  List<Exercise> exercises,  List<RolePlay> rolePlays,  List<Actor> actors)?  $default,) {final _that = this;
switch (_that) {
case _Program() when $default != null:
return $default(_that.uuid,_that.name,_that.description,_that.metadata,_that.source,_that.contentHash,_that.teams,_that.sessions,_that.exercises,_that.rolePlays,_that.actors);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Program implements Program {
  const _Program({required this.uuid, required this.name, required this.description, required this.metadata, this.source = const ProgramSource.local(), this.contentHash, required final  List<Team> teams, required final  List<Session> sessions, required final  List<Exercise> exercises, final  List<RolePlay> rolePlays = const [], final  List<Actor> actors = const []}): _teams = teams,_sessions = sessions,_exercises = exercises,_rolePlays = rolePlays,_actors = actors;
  factory _Program.fromJson(Map<String, dynamic> json) => _$ProgramFromJson(json);

@override final  String uuid;
@override final  String name;
@override final  String description;
@override final  ProgramMetadata metadata;
@override@JsonKey() final  ProgramSource source;
@override final  String? contentHash;
 final  List<Team> _teams;
@override List<Team> get teams {
  if (_teams is EqualUnmodifiableListView) return _teams;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_teams);
}

 final  List<Session> _sessions;
@override List<Session> get sessions {
  if (_sessions is EqualUnmodifiableListView) return _sessions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_sessions);
}

 final  List<Exercise> _exercises;
@override List<Exercise> get exercises {
  if (_exercises is EqualUnmodifiableListView) return _exercises;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_exercises);
}

// @Default([]) so 1.0 archives without these keys deserialize to empty
// lists rather than failing (ADR-0018 backward-compat requirement).
 final  List<RolePlay> _rolePlays;
// @Default([]) so 1.0 archives without these keys deserialize to empty
// lists rather than failing (ADR-0018 backward-compat requirement).
@override@JsonKey() List<RolePlay> get rolePlays {
  if (_rolePlays is EqualUnmodifiableListView) return _rolePlays;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_rolePlays);
}

 final  List<Actor> _actors;
@override@JsonKey() List<Actor> get actors {
  if (_actors is EqualUnmodifiableListView) return _actors;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_actors);
}


/// Create a copy of Program
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProgramCopyWith<_Program> get copyWith => __$ProgramCopyWithImpl<_Program>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProgramToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Program&&(identical(other.uuid, uuid) || other.uuid == uuid)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.metadata, metadata) || other.metadata == metadata)&&(identical(other.source, source) || other.source == source)&&(identical(other.contentHash, contentHash) || other.contentHash == contentHash)&&const DeepCollectionEquality().equals(other._teams, _teams)&&const DeepCollectionEquality().equals(other._sessions, _sessions)&&const DeepCollectionEquality().equals(other._exercises, _exercises)&&const DeepCollectionEquality().equals(other._rolePlays, _rolePlays)&&const DeepCollectionEquality().equals(other._actors, _actors));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,uuid,name,description,metadata,source,contentHash,const DeepCollectionEquality().hash(_teams),const DeepCollectionEquality().hash(_sessions),const DeepCollectionEquality().hash(_exercises),const DeepCollectionEquality().hash(_rolePlays),const DeepCollectionEquality().hash(_actors));

@override
String toString() {
  return 'Program(uuid: $uuid, name: $name, description: $description, metadata: $metadata, source: $source, contentHash: $contentHash, teams: $teams, sessions: $sessions, exercises: $exercises, rolePlays: $rolePlays, actors: $actors)';
}


}

/// @nodoc
abstract mixin class _$ProgramCopyWith<$Res> implements $ProgramCopyWith<$Res> {
  factory _$ProgramCopyWith(_Program value, $Res Function(_Program) _then) = __$ProgramCopyWithImpl;
@override @useResult
$Res call({
 String uuid, String name, String description, ProgramMetadata metadata, ProgramSource source, String? contentHash, List<Team> teams, List<Session> sessions, List<Exercise> exercises, List<RolePlay> rolePlays, List<Actor> actors
});


@override $ProgramMetadataCopyWith<$Res> get metadata;@override $ProgramSourceCopyWith<$Res> get source;

}
/// @nodoc
class __$ProgramCopyWithImpl<$Res>
    implements _$ProgramCopyWith<$Res> {
  __$ProgramCopyWithImpl(this._self, this._then);

  final _Program _self;
  final $Res Function(_Program) _then;

/// Create a copy of Program
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? uuid = null,Object? name = null,Object? description = null,Object? metadata = null,Object? source = null,Object? contentHash = freezed,Object? teams = null,Object? sessions = null,Object? exercises = null,Object? rolePlays = null,Object? actors = null,}) {
  return _then(_Program(
uuid: null == uuid ? _self.uuid : uuid // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,metadata: null == metadata ? _self.metadata : metadata // ignore: cast_nullable_to_non_nullable
as ProgramMetadata,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as ProgramSource,contentHash: freezed == contentHash ? _self.contentHash : contentHash // ignore: cast_nullable_to_non_nullable
as String?,teams: null == teams ? _self._teams : teams // ignore: cast_nullable_to_non_nullable
as List<Team>,sessions: null == sessions ? _self._sessions : sessions // ignore: cast_nullable_to_non_nullable
as List<Session>,exercises: null == exercises ? _self._exercises : exercises // ignore: cast_nullable_to_non_nullable
as List<Exercise>,rolePlays: null == rolePlays ? _self._rolePlays : rolePlays // ignore: cast_nullable_to_non_nullable
as List<RolePlay>,actors: null == actors ? _self._actors : actors // ignore: cast_nullable_to_non_nullable
as List<Actor>,
  ));
}

/// Create a copy of Program
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProgramMetadataCopyWith<$Res> get metadata {
  
  return $ProgramMetadataCopyWith<$Res>(_self.metadata, (value) {
    return _then(_self.copyWith(metadata: value));
  });
}/// Create a copy of Program
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProgramSourceCopyWith<$Res> get source {
  
  return $ProgramSourceCopyWith<$Res>(_self.source, (value) {
    return _then(_self.copyWith(source: value));
  });
}
}

ProgramSource _$ProgramSourceFromJson(
  Map<String, dynamic> json
) {
        switch (json['runtimeType']) {
                  case 'local':
          return _Local.fromJson(
            json
          );
                case 'imported':
          return _Imported.fromJson(
            json
          );
                case 'catalog':
          return _Catalog.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'runtimeType',
  'ProgramSource',
  'Invalid union type "${json['runtimeType']}"!'
);
        }
      
}

/// @nodoc
mixin _$ProgramSource {



  /// Serializes this ProgramSource to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProgramSource);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ProgramSource()';
}


}

/// @nodoc
class $ProgramSourceCopyWith<$Res>  {
$ProgramSourceCopyWith(ProgramSource _, $Res Function(ProgramSource) __);
}


/// Adds pattern-matching-related methods to [ProgramSource].
extension ProgramSourcePatterns on ProgramSource {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _Local value)?  local,TResult Function( _Imported value)?  imported,TResult Function( _Catalog value)?  catalog,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Local() when local != null:
return local(_that);case _Imported() when imported != null:
return imported(_that);case _Catalog() when catalog != null:
return catalog(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _Local value)  local,required TResult Function( _Imported value)  imported,required TResult Function( _Catalog value)  catalog,}){
final _that = this;
switch (_that) {
case _Local():
return local(_that);case _Imported():
return imported(_that);case _Catalog():
return catalog(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _Local value)?  local,TResult? Function( _Imported value)?  imported,TResult? Function( _Catalog value)?  catalog,}){
final _that = this;
switch (_that) {
case _Local() when local != null:
return local(_that);case _Imported() when imported != null:
return imported(_that);case _Catalog() when catalog != null:
return catalog(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  local,TResult Function( String fileName)?  imported,TResult Function( String slug,  String latestEtag,  DateTime? installedAt)?  catalog,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Local() when local != null:
return local();case _Imported() when imported != null:
return imported(_that.fileName);case _Catalog() when catalog != null:
return catalog(_that.slug,_that.latestEtag,_that.installedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  local,required TResult Function( String fileName)  imported,required TResult Function( String slug,  String latestEtag,  DateTime? installedAt)  catalog,}) {final _that = this;
switch (_that) {
case _Local():
return local();case _Imported():
return imported(_that.fileName);case _Catalog():
return catalog(_that.slug,_that.latestEtag,_that.installedAt);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  local,TResult? Function( String fileName)?  imported,TResult? Function( String slug,  String latestEtag,  DateTime? installedAt)?  catalog,}) {final _that = this;
switch (_that) {
case _Local() when local != null:
return local();case _Imported() when imported != null:
return imported(_that.fileName);case _Catalog() when catalog != null:
return catalog(_that.slug,_that.latestEtag,_that.installedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Local implements ProgramSource {
  const _Local({final  String? $type}): $type = $type ?? 'local';
  factory _Local.fromJson(Map<String, dynamic> json) => _$LocalFromJson(json);



@JsonKey(name: 'runtimeType')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$LocalToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Local);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ProgramSource.local()';
}


}




/// @nodoc
@JsonSerializable()

class _Imported implements ProgramSource {
  const _Imported({required this.fileName, final  String? $type}): $type = $type ?? 'imported';
  factory _Imported.fromJson(Map<String, dynamic> json) => _$ImportedFromJson(json);

 final  String fileName;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of ProgramSource
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ImportedCopyWith<_Imported> get copyWith => __$ImportedCopyWithImpl<_Imported>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ImportedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Imported&&(identical(other.fileName, fileName) || other.fileName == fileName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,fileName);

@override
String toString() {
  return 'ProgramSource.imported(fileName: $fileName)';
}


}

/// @nodoc
abstract mixin class _$ImportedCopyWith<$Res> implements $ProgramSourceCopyWith<$Res> {
  factory _$ImportedCopyWith(_Imported value, $Res Function(_Imported) _then) = __$ImportedCopyWithImpl;
@useResult
$Res call({
 String fileName
});




}
/// @nodoc
class __$ImportedCopyWithImpl<$Res>
    implements _$ImportedCopyWith<$Res> {
  __$ImportedCopyWithImpl(this._self, this._then);

  final _Imported _self;
  final $Res Function(_Imported) _then;

/// Create a copy of ProgramSource
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? fileName = null,}) {
  return _then(_Imported(
fileName: null == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class _Catalog implements ProgramSource {
  const _Catalog({required this.slug, required this.latestEtag, this.installedAt, final  String? $type}): $type = $type ?? 'catalog';
  factory _Catalog.fromJson(Map<String, dynamic> json) => _$CatalogFromJson(json);

 final  String slug;
 final  String latestEtag;
 final  DateTime? installedAt;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of ProgramSource
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CatalogCopyWith<_Catalog> get copyWith => __$CatalogCopyWithImpl<_Catalog>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CatalogToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Catalog&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.latestEtag, latestEtag) || other.latestEtag == latestEtag)&&(identical(other.installedAt, installedAt) || other.installedAt == installedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,slug,latestEtag,installedAt);

@override
String toString() {
  return 'ProgramSource.catalog(slug: $slug, latestEtag: $latestEtag, installedAt: $installedAt)';
}


}

/// @nodoc
abstract mixin class _$CatalogCopyWith<$Res> implements $ProgramSourceCopyWith<$Res> {
  factory _$CatalogCopyWith(_Catalog value, $Res Function(_Catalog) _then) = __$CatalogCopyWithImpl;
@useResult
$Res call({
 String slug, String latestEtag, DateTime? installedAt
});




}
/// @nodoc
class __$CatalogCopyWithImpl<$Res>
    implements _$CatalogCopyWith<$Res> {
  __$CatalogCopyWithImpl(this._self, this._then);

  final _Catalog _self;
  final $Res Function(_Catalog) _then;

/// Create a copy of ProgramSource
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? slug = null,Object? latestEtag = null,Object? installedAt = freezed,}) {
  return _then(_Catalog(
slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,latestEtag: null == latestEtag ? _self.latestEtag : latestEtag // ignore: cast_nullable_to_non_nullable
as String,installedAt: freezed == installedAt ? _self.installedAt : installedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$ProgramDiff {

/// Local name when it differs from remote. Null when names match.
 String? get nameLocal;/// Remote name when it differs from local. Null when names match.
 String? get nameRemote;/// Local description when it differs from remote. Null when descriptions
/// match.
 String? get descriptionLocal;/// Remote description when it differs from local. Null when descriptions
/// match.
 String? get descriptionRemote; List<String> get addedExercises; List<String> get removedExercises; List<String> get modifiedExercises; List<String> get addedTeams; List<String> get removedTeams; List<String> get modifiedTeams; List<String> get addedSessions; List<String> get removedSessions; List<String> get modifiedSessions;// rolePlays are included in the content hash; actors are not.
 List<String> get addedRolePlays; List<String> get removedRolePlays; List<String> get modifiedRolePlays;
/// Create a copy of ProgramDiff
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProgramDiffCopyWith<ProgramDiff> get copyWith => _$ProgramDiffCopyWithImpl<ProgramDiff>(this as ProgramDiff, _$identity);

  /// Serializes this ProgramDiff to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProgramDiff&&(identical(other.nameLocal, nameLocal) || other.nameLocal == nameLocal)&&(identical(other.nameRemote, nameRemote) || other.nameRemote == nameRemote)&&(identical(other.descriptionLocal, descriptionLocal) || other.descriptionLocal == descriptionLocal)&&(identical(other.descriptionRemote, descriptionRemote) || other.descriptionRemote == descriptionRemote)&&const DeepCollectionEquality().equals(other.addedExercises, addedExercises)&&const DeepCollectionEquality().equals(other.removedExercises, removedExercises)&&const DeepCollectionEquality().equals(other.modifiedExercises, modifiedExercises)&&const DeepCollectionEquality().equals(other.addedTeams, addedTeams)&&const DeepCollectionEquality().equals(other.removedTeams, removedTeams)&&const DeepCollectionEquality().equals(other.modifiedTeams, modifiedTeams)&&const DeepCollectionEquality().equals(other.addedSessions, addedSessions)&&const DeepCollectionEquality().equals(other.removedSessions, removedSessions)&&const DeepCollectionEquality().equals(other.modifiedSessions, modifiedSessions)&&const DeepCollectionEquality().equals(other.addedRolePlays, addedRolePlays)&&const DeepCollectionEquality().equals(other.removedRolePlays, removedRolePlays)&&const DeepCollectionEquality().equals(other.modifiedRolePlays, modifiedRolePlays));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,nameLocal,nameRemote,descriptionLocal,descriptionRemote,const DeepCollectionEquality().hash(addedExercises),const DeepCollectionEquality().hash(removedExercises),const DeepCollectionEquality().hash(modifiedExercises),const DeepCollectionEquality().hash(addedTeams),const DeepCollectionEquality().hash(removedTeams),const DeepCollectionEquality().hash(modifiedTeams),const DeepCollectionEquality().hash(addedSessions),const DeepCollectionEquality().hash(removedSessions),const DeepCollectionEquality().hash(modifiedSessions),const DeepCollectionEquality().hash(addedRolePlays),const DeepCollectionEquality().hash(removedRolePlays),const DeepCollectionEquality().hash(modifiedRolePlays));

@override
String toString() {
  return 'ProgramDiff(nameLocal: $nameLocal, nameRemote: $nameRemote, descriptionLocal: $descriptionLocal, descriptionRemote: $descriptionRemote, addedExercises: $addedExercises, removedExercises: $removedExercises, modifiedExercises: $modifiedExercises, addedTeams: $addedTeams, removedTeams: $removedTeams, modifiedTeams: $modifiedTeams, addedSessions: $addedSessions, removedSessions: $removedSessions, modifiedSessions: $modifiedSessions, addedRolePlays: $addedRolePlays, removedRolePlays: $removedRolePlays, modifiedRolePlays: $modifiedRolePlays)';
}


}

/// @nodoc
abstract mixin class $ProgramDiffCopyWith<$Res>  {
  factory $ProgramDiffCopyWith(ProgramDiff value, $Res Function(ProgramDiff) _then) = _$ProgramDiffCopyWithImpl;
@useResult
$Res call({
 String? nameLocal, String? nameRemote, String? descriptionLocal, String? descriptionRemote, List<String> addedExercises, List<String> removedExercises, List<String> modifiedExercises, List<String> addedTeams, List<String> removedTeams, List<String> modifiedTeams, List<String> addedSessions, List<String> removedSessions, List<String> modifiedSessions, List<String> addedRolePlays, List<String> removedRolePlays, List<String> modifiedRolePlays
});




}
/// @nodoc
class _$ProgramDiffCopyWithImpl<$Res>
    implements $ProgramDiffCopyWith<$Res> {
  _$ProgramDiffCopyWithImpl(this._self, this._then);

  final ProgramDiff _self;
  final $Res Function(ProgramDiff) _then;

/// Create a copy of ProgramDiff
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? nameLocal = freezed,Object? nameRemote = freezed,Object? descriptionLocal = freezed,Object? descriptionRemote = freezed,Object? addedExercises = null,Object? removedExercises = null,Object? modifiedExercises = null,Object? addedTeams = null,Object? removedTeams = null,Object? modifiedTeams = null,Object? addedSessions = null,Object? removedSessions = null,Object? modifiedSessions = null,Object? addedRolePlays = null,Object? removedRolePlays = null,Object? modifiedRolePlays = null,}) {
  return _then(_self.copyWith(
nameLocal: freezed == nameLocal ? _self.nameLocal : nameLocal // ignore: cast_nullable_to_non_nullable
as String?,nameRemote: freezed == nameRemote ? _self.nameRemote : nameRemote // ignore: cast_nullable_to_non_nullable
as String?,descriptionLocal: freezed == descriptionLocal ? _self.descriptionLocal : descriptionLocal // ignore: cast_nullable_to_non_nullable
as String?,descriptionRemote: freezed == descriptionRemote ? _self.descriptionRemote : descriptionRemote // ignore: cast_nullable_to_non_nullable
as String?,addedExercises: null == addedExercises ? _self.addedExercises : addedExercises // ignore: cast_nullable_to_non_nullable
as List<String>,removedExercises: null == removedExercises ? _self.removedExercises : removedExercises // ignore: cast_nullable_to_non_nullable
as List<String>,modifiedExercises: null == modifiedExercises ? _self.modifiedExercises : modifiedExercises // ignore: cast_nullable_to_non_nullable
as List<String>,addedTeams: null == addedTeams ? _self.addedTeams : addedTeams // ignore: cast_nullable_to_non_nullable
as List<String>,removedTeams: null == removedTeams ? _self.removedTeams : removedTeams // ignore: cast_nullable_to_non_nullable
as List<String>,modifiedTeams: null == modifiedTeams ? _self.modifiedTeams : modifiedTeams // ignore: cast_nullable_to_non_nullable
as List<String>,addedSessions: null == addedSessions ? _self.addedSessions : addedSessions // ignore: cast_nullable_to_non_nullable
as List<String>,removedSessions: null == removedSessions ? _self.removedSessions : removedSessions // ignore: cast_nullable_to_non_nullable
as List<String>,modifiedSessions: null == modifiedSessions ? _self.modifiedSessions : modifiedSessions // ignore: cast_nullable_to_non_nullable
as List<String>,addedRolePlays: null == addedRolePlays ? _self.addedRolePlays : addedRolePlays // ignore: cast_nullable_to_non_nullable
as List<String>,removedRolePlays: null == removedRolePlays ? _self.removedRolePlays : removedRolePlays // ignore: cast_nullable_to_non_nullable
as List<String>,modifiedRolePlays: null == modifiedRolePlays ? _self.modifiedRolePlays : modifiedRolePlays // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [ProgramDiff].
extension ProgramDiffPatterns on ProgramDiff {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProgramDiff value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProgramDiff() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProgramDiff value)  $default,){
final _that = this;
switch (_that) {
case _ProgramDiff():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProgramDiff value)?  $default,){
final _that = this;
switch (_that) {
case _ProgramDiff() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? nameLocal,  String? nameRemote,  String? descriptionLocal,  String? descriptionRemote,  List<String> addedExercises,  List<String> removedExercises,  List<String> modifiedExercises,  List<String> addedTeams,  List<String> removedTeams,  List<String> modifiedTeams,  List<String> addedSessions,  List<String> removedSessions,  List<String> modifiedSessions,  List<String> addedRolePlays,  List<String> removedRolePlays,  List<String> modifiedRolePlays)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProgramDiff() when $default != null:
return $default(_that.nameLocal,_that.nameRemote,_that.descriptionLocal,_that.descriptionRemote,_that.addedExercises,_that.removedExercises,_that.modifiedExercises,_that.addedTeams,_that.removedTeams,_that.modifiedTeams,_that.addedSessions,_that.removedSessions,_that.modifiedSessions,_that.addedRolePlays,_that.removedRolePlays,_that.modifiedRolePlays);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? nameLocal,  String? nameRemote,  String? descriptionLocal,  String? descriptionRemote,  List<String> addedExercises,  List<String> removedExercises,  List<String> modifiedExercises,  List<String> addedTeams,  List<String> removedTeams,  List<String> modifiedTeams,  List<String> addedSessions,  List<String> removedSessions,  List<String> modifiedSessions,  List<String> addedRolePlays,  List<String> removedRolePlays,  List<String> modifiedRolePlays)  $default,) {final _that = this;
switch (_that) {
case _ProgramDiff():
return $default(_that.nameLocal,_that.nameRemote,_that.descriptionLocal,_that.descriptionRemote,_that.addedExercises,_that.removedExercises,_that.modifiedExercises,_that.addedTeams,_that.removedTeams,_that.modifiedTeams,_that.addedSessions,_that.removedSessions,_that.modifiedSessions,_that.addedRolePlays,_that.removedRolePlays,_that.modifiedRolePlays);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? nameLocal,  String? nameRemote,  String? descriptionLocal,  String? descriptionRemote,  List<String> addedExercises,  List<String> removedExercises,  List<String> modifiedExercises,  List<String> addedTeams,  List<String> removedTeams,  List<String> modifiedTeams,  List<String> addedSessions,  List<String> removedSessions,  List<String> modifiedSessions,  List<String> addedRolePlays,  List<String> removedRolePlays,  List<String> modifiedRolePlays)?  $default,) {final _that = this;
switch (_that) {
case _ProgramDiff() when $default != null:
return $default(_that.nameLocal,_that.nameRemote,_that.descriptionLocal,_that.descriptionRemote,_that.addedExercises,_that.removedExercises,_that.modifiedExercises,_that.addedTeams,_that.removedTeams,_that.modifiedTeams,_that.addedSessions,_that.removedSessions,_that.modifiedSessions,_that.addedRolePlays,_that.removedRolePlays,_that.modifiedRolePlays);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProgramDiff implements ProgramDiff {
  const _ProgramDiff({this.nameLocal, this.nameRemote, this.descriptionLocal, this.descriptionRemote, final  List<String> addedExercises = const [], final  List<String> removedExercises = const [], final  List<String> modifiedExercises = const [], final  List<String> addedTeams = const [], final  List<String> removedTeams = const [], final  List<String> modifiedTeams = const [], final  List<String> addedSessions = const [], final  List<String> removedSessions = const [], final  List<String> modifiedSessions = const [], final  List<String> addedRolePlays = const [], final  List<String> removedRolePlays = const [], final  List<String> modifiedRolePlays = const []}): _addedExercises = addedExercises,_removedExercises = removedExercises,_modifiedExercises = modifiedExercises,_addedTeams = addedTeams,_removedTeams = removedTeams,_modifiedTeams = modifiedTeams,_addedSessions = addedSessions,_removedSessions = removedSessions,_modifiedSessions = modifiedSessions,_addedRolePlays = addedRolePlays,_removedRolePlays = removedRolePlays,_modifiedRolePlays = modifiedRolePlays;
  factory _ProgramDiff.fromJson(Map<String, dynamic> json) => _$ProgramDiffFromJson(json);

/// Local name when it differs from remote. Null when names match.
@override final  String? nameLocal;
/// Remote name when it differs from local. Null when names match.
@override final  String? nameRemote;
/// Local description when it differs from remote. Null when descriptions
/// match.
@override final  String? descriptionLocal;
/// Remote description when it differs from local. Null when descriptions
/// match.
@override final  String? descriptionRemote;
 final  List<String> _addedExercises;
@override@JsonKey() List<String> get addedExercises {
  if (_addedExercises is EqualUnmodifiableListView) return _addedExercises;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_addedExercises);
}

 final  List<String> _removedExercises;
@override@JsonKey() List<String> get removedExercises {
  if (_removedExercises is EqualUnmodifiableListView) return _removedExercises;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_removedExercises);
}

 final  List<String> _modifiedExercises;
@override@JsonKey() List<String> get modifiedExercises {
  if (_modifiedExercises is EqualUnmodifiableListView) return _modifiedExercises;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_modifiedExercises);
}

 final  List<String> _addedTeams;
@override@JsonKey() List<String> get addedTeams {
  if (_addedTeams is EqualUnmodifiableListView) return _addedTeams;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_addedTeams);
}

 final  List<String> _removedTeams;
@override@JsonKey() List<String> get removedTeams {
  if (_removedTeams is EqualUnmodifiableListView) return _removedTeams;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_removedTeams);
}

 final  List<String> _modifiedTeams;
@override@JsonKey() List<String> get modifiedTeams {
  if (_modifiedTeams is EqualUnmodifiableListView) return _modifiedTeams;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_modifiedTeams);
}

 final  List<String> _addedSessions;
@override@JsonKey() List<String> get addedSessions {
  if (_addedSessions is EqualUnmodifiableListView) return _addedSessions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_addedSessions);
}

 final  List<String> _removedSessions;
@override@JsonKey() List<String> get removedSessions {
  if (_removedSessions is EqualUnmodifiableListView) return _removedSessions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_removedSessions);
}

 final  List<String> _modifiedSessions;
@override@JsonKey() List<String> get modifiedSessions {
  if (_modifiedSessions is EqualUnmodifiableListView) return _modifiedSessions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_modifiedSessions);
}

// rolePlays are included in the content hash; actors are not.
 final  List<String> _addedRolePlays;
// rolePlays are included in the content hash; actors are not.
@override@JsonKey() List<String> get addedRolePlays {
  if (_addedRolePlays is EqualUnmodifiableListView) return _addedRolePlays;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_addedRolePlays);
}

 final  List<String> _removedRolePlays;
@override@JsonKey() List<String> get removedRolePlays {
  if (_removedRolePlays is EqualUnmodifiableListView) return _removedRolePlays;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_removedRolePlays);
}

 final  List<String> _modifiedRolePlays;
@override@JsonKey() List<String> get modifiedRolePlays {
  if (_modifiedRolePlays is EqualUnmodifiableListView) return _modifiedRolePlays;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_modifiedRolePlays);
}


/// Create a copy of ProgramDiff
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProgramDiffCopyWith<_ProgramDiff> get copyWith => __$ProgramDiffCopyWithImpl<_ProgramDiff>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProgramDiffToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProgramDiff&&(identical(other.nameLocal, nameLocal) || other.nameLocal == nameLocal)&&(identical(other.nameRemote, nameRemote) || other.nameRemote == nameRemote)&&(identical(other.descriptionLocal, descriptionLocal) || other.descriptionLocal == descriptionLocal)&&(identical(other.descriptionRemote, descriptionRemote) || other.descriptionRemote == descriptionRemote)&&const DeepCollectionEquality().equals(other._addedExercises, _addedExercises)&&const DeepCollectionEquality().equals(other._removedExercises, _removedExercises)&&const DeepCollectionEquality().equals(other._modifiedExercises, _modifiedExercises)&&const DeepCollectionEquality().equals(other._addedTeams, _addedTeams)&&const DeepCollectionEquality().equals(other._removedTeams, _removedTeams)&&const DeepCollectionEquality().equals(other._modifiedTeams, _modifiedTeams)&&const DeepCollectionEquality().equals(other._addedSessions, _addedSessions)&&const DeepCollectionEquality().equals(other._removedSessions, _removedSessions)&&const DeepCollectionEquality().equals(other._modifiedSessions, _modifiedSessions)&&const DeepCollectionEquality().equals(other._addedRolePlays, _addedRolePlays)&&const DeepCollectionEquality().equals(other._removedRolePlays, _removedRolePlays)&&const DeepCollectionEquality().equals(other._modifiedRolePlays, _modifiedRolePlays));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,nameLocal,nameRemote,descriptionLocal,descriptionRemote,const DeepCollectionEquality().hash(_addedExercises),const DeepCollectionEquality().hash(_removedExercises),const DeepCollectionEquality().hash(_modifiedExercises),const DeepCollectionEquality().hash(_addedTeams),const DeepCollectionEquality().hash(_removedTeams),const DeepCollectionEquality().hash(_modifiedTeams),const DeepCollectionEquality().hash(_addedSessions),const DeepCollectionEquality().hash(_removedSessions),const DeepCollectionEquality().hash(_modifiedSessions),const DeepCollectionEquality().hash(_addedRolePlays),const DeepCollectionEquality().hash(_removedRolePlays),const DeepCollectionEquality().hash(_modifiedRolePlays));

@override
String toString() {
  return 'ProgramDiff(nameLocal: $nameLocal, nameRemote: $nameRemote, descriptionLocal: $descriptionLocal, descriptionRemote: $descriptionRemote, addedExercises: $addedExercises, removedExercises: $removedExercises, modifiedExercises: $modifiedExercises, addedTeams: $addedTeams, removedTeams: $removedTeams, modifiedTeams: $modifiedTeams, addedSessions: $addedSessions, removedSessions: $removedSessions, modifiedSessions: $modifiedSessions, addedRolePlays: $addedRolePlays, removedRolePlays: $removedRolePlays, modifiedRolePlays: $modifiedRolePlays)';
}


}

/// @nodoc
abstract mixin class _$ProgramDiffCopyWith<$Res> implements $ProgramDiffCopyWith<$Res> {
  factory _$ProgramDiffCopyWith(_ProgramDiff value, $Res Function(_ProgramDiff) _then) = __$ProgramDiffCopyWithImpl;
@override @useResult
$Res call({
 String? nameLocal, String? nameRemote, String? descriptionLocal, String? descriptionRemote, List<String> addedExercises, List<String> removedExercises, List<String> modifiedExercises, List<String> addedTeams, List<String> removedTeams, List<String> modifiedTeams, List<String> addedSessions, List<String> removedSessions, List<String> modifiedSessions, List<String> addedRolePlays, List<String> removedRolePlays, List<String> modifiedRolePlays
});




}
/// @nodoc
class __$ProgramDiffCopyWithImpl<$Res>
    implements _$ProgramDiffCopyWith<$Res> {
  __$ProgramDiffCopyWithImpl(this._self, this._then);

  final _ProgramDiff _self;
  final $Res Function(_ProgramDiff) _then;

/// Create a copy of ProgramDiff
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? nameLocal = freezed,Object? nameRemote = freezed,Object? descriptionLocal = freezed,Object? descriptionRemote = freezed,Object? addedExercises = null,Object? removedExercises = null,Object? modifiedExercises = null,Object? addedTeams = null,Object? removedTeams = null,Object? modifiedTeams = null,Object? addedSessions = null,Object? removedSessions = null,Object? modifiedSessions = null,Object? addedRolePlays = null,Object? removedRolePlays = null,Object? modifiedRolePlays = null,}) {
  return _then(_ProgramDiff(
nameLocal: freezed == nameLocal ? _self.nameLocal : nameLocal // ignore: cast_nullable_to_non_nullable
as String?,nameRemote: freezed == nameRemote ? _self.nameRemote : nameRemote // ignore: cast_nullable_to_non_nullable
as String?,descriptionLocal: freezed == descriptionLocal ? _self.descriptionLocal : descriptionLocal // ignore: cast_nullable_to_non_nullable
as String?,descriptionRemote: freezed == descriptionRemote ? _self.descriptionRemote : descriptionRemote // ignore: cast_nullable_to_non_nullable
as String?,addedExercises: null == addedExercises ? _self._addedExercises : addedExercises // ignore: cast_nullable_to_non_nullable
as List<String>,removedExercises: null == removedExercises ? _self._removedExercises : removedExercises // ignore: cast_nullable_to_non_nullable
as List<String>,modifiedExercises: null == modifiedExercises ? _self._modifiedExercises : modifiedExercises // ignore: cast_nullable_to_non_nullable
as List<String>,addedTeams: null == addedTeams ? _self._addedTeams : addedTeams // ignore: cast_nullable_to_non_nullable
as List<String>,removedTeams: null == removedTeams ? _self._removedTeams : removedTeams // ignore: cast_nullable_to_non_nullable
as List<String>,modifiedTeams: null == modifiedTeams ? _self._modifiedTeams : modifiedTeams // ignore: cast_nullable_to_non_nullable
as List<String>,addedSessions: null == addedSessions ? _self._addedSessions : addedSessions // ignore: cast_nullable_to_non_nullable
as List<String>,removedSessions: null == removedSessions ? _self._removedSessions : removedSessions // ignore: cast_nullable_to_non_nullable
as List<String>,modifiedSessions: null == modifiedSessions ? _self._modifiedSessions : modifiedSessions // ignore: cast_nullable_to_non_nullable
as List<String>,addedRolePlays: null == addedRolePlays ? _self._addedRolePlays : addedRolePlays // ignore: cast_nullable_to_non_nullable
as List<String>,removedRolePlays: null == removedRolePlays ? _self._removedRolePlays : removedRolePlays // ignore: cast_nullable_to_non_nullable
as List<String>,modifiedRolePlays: null == modifiedRolePlays ? _self._modifiedRolePlays : modifiedRolePlays // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}


/// @nodoc
mixin _$Session {

 String get uuid; DateTime? get startedAt; DateTime? get endedAt; String get exerciseUuid; SimpleTimeOfDay get startTime;
/// Create a copy of Session
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionCopyWith<Session> get copyWith => _$SessionCopyWithImpl<Session>(this as Session, _$identity);

  /// Serializes this Session to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Session&&(identical(other.uuid, uuid) || other.uuid == uuid)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.endedAt, endedAt) || other.endedAt == endedAt)&&(identical(other.exerciseUuid, exerciseUuid) || other.exerciseUuid == exerciseUuid)&&(identical(other.startTime, startTime) || other.startTime == startTime));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,uuid,startedAt,endedAt,exerciseUuid,startTime);

@override
String toString() {
  return 'Session(uuid: $uuid, startedAt: $startedAt, endedAt: $endedAt, exerciseUuid: $exerciseUuid, startTime: $startTime)';
}


}

/// @nodoc
abstract mixin class $SessionCopyWith<$Res>  {
  factory $SessionCopyWith(Session value, $Res Function(Session) _then) = _$SessionCopyWithImpl;
@useResult
$Res call({
 String uuid, DateTime? startedAt, DateTime? endedAt, String exerciseUuid, SimpleTimeOfDay startTime
});


$SimpleTimeOfDayCopyWith<$Res> get startTime;

}
/// @nodoc
class _$SessionCopyWithImpl<$Res>
    implements $SessionCopyWith<$Res> {
  _$SessionCopyWithImpl(this._self, this._then);

  final Session _self;
  final $Res Function(Session) _then;

/// Create a copy of Session
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? uuid = null,Object? startedAt = freezed,Object? endedAt = freezed,Object? exerciseUuid = null,Object? startTime = null,}) {
  return _then(_self.copyWith(
uuid: null == uuid ? _self.uuid : uuid // ignore: cast_nullable_to_non_nullable
as String,startedAt: freezed == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,endedAt: freezed == endedAt ? _self.endedAt : endedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,exerciseUuid: null == exerciseUuid ? _self.exerciseUuid : exerciseUuid // ignore: cast_nullable_to_non_nullable
as String,startTime: null == startTime ? _self.startTime : startTime // ignore: cast_nullable_to_non_nullable
as SimpleTimeOfDay,
  ));
}
/// Create a copy of Session
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SimpleTimeOfDayCopyWith<$Res> get startTime {
  
  return $SimpleTimeOfDayCopyWith<$Res>(_self.startTime, (value) {
    return _then(_self.copyWith(startTime: value));
  });
}
}


/// Adds pattern-matching-related methods to [Session].
extension SessionPatterns on Session {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Session value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Session() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Session value)  $default,){
final _that = this;
switch (_that) {
case _Session():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Session value)?  $default,){
final _that = this;
switch (_that) {
case _Session() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String uuid,  DateTime? startedAt,  DateTime? endedAt,  String exerciseUuid,  SimpleTimeOfDay startTime)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Session() when $default != null:
return $default(_that.uuid,_that.startedAt,_that.endedAt,_that.exerciseUuid,_that.startTime);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String uuid,  DateTime? startedAt,  DateTime? endedAt,  String exerciseUuid,  SimpleTimeOfDay startTime)  $default,) {final _that = this;
switch (_that) {
case _Session():
return $default(_that.uuid,_that.startedAt,_that.endedAt,_that.exerciseUuid,_that.startTime);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String uuid,  DateTime? startedAt,  DateTime? endedAt,  String exerciseUuid,  SimpleTimeOfDay startTime)?  $default,) {final _that = this;
switch (_that) {
case _Session() when $default != null:
return $default(_that.uuid,_that.startedAt,_that.endedAt,_that.exerciseUuid,_that.startTime);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Session implements Session {
  const _Session({required this.uuid, required this.startedAt, required this.endedAt, required this.exerciseUuid, required this.startTime});
  factory _Session.fromJson(Map<String, dynamic> json) => _$SessionFromJson(json);

@override final  String uuid;
@override final  DateTime? startedAt;
@override final  DateTime? endedAt;
@override final  String exerciseUuid;
@override final  SimpleTimeOfDay startTime;

/// Create a copy of Session
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionCopyWith<_Session> get copyWith => __$SessionCopyWithImpl<_Session>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Session&&(identical(other.uuid, uuid) || other.uuid == uuid)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.endedAt, endedAt) || other.endedAt == endedAt)&&(identical(other.exerciseUuid, exerciseUuid) || other.exerciseUuid == exerciseUuid)&&(identical(other.startTime, startTime) || other.startTime == startTime));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,uuid,startedAt,endedAt,exerciseUuid,startTime);

@override
String toString() {
  return 'Session(uuid: $uuid, startedAt: $startedAt, endedAt: $endedAt, exerciseUuid: $exerciseUuid, startTime: $startTime)';
}


}

/// @nodoc
abstract mixin class _$SessionCopyWith<$Res> implements $SessionCopyWith<$Res> {
  factory _$SessionCopyWith(_Session value, $Res Function(_Session) _then) = __$SessionCopyWithImpl;
@override @useResult
$Res call({
 String uuid, DateTime? startedAt, DateTime? endedAt, String exerciseUuid, SimpleTimeOfDay startTime
});


@override $SimpleTimeOfDayCopyWith<$Res> get startTime;

}
/// @nodoc
class __$SessionCopyWithImpl<$Res>
    implements _$SessionCopyWith<$Res> {
  __$SessionCopyWithImpl(this._self, this._then);

  final _Session _self;
  final $Res Function(_Session) _then;

/// Create a copy of Session
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? uuid = null,Object? startedAt = freezed,Object? endedAt = freezed,Object? exerciseUuid = null,Object? startTime = null,}) {
  return _then(_Session(
uuid: null == uuid ? _self.uuid : uuid // ignore: cast_nullable_to_non_nullable
as String,startedAt: freezed == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,endedAt: freezed == endedAt ? _self.endedAt : endedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,exerciseUuid: null == exerciseUuid ? _self.exerciseUuid : exerciseUuid // ignore: cast_nullable_to_non_nullable
as String,startTime: null == startTime ? _self.startTime : startTime // ignore: cast_nullable_to_non_nullable
as SimpleTimeOfDay,
  ));
}

/// Create a copy of Session
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SimpleTimeOfDayCopyWith<$Res> get startTime {
  
  return $SimpleTimeOfDayCopyWith<$Res>(_self.startTime, (value) {
    return _then(_self.copyWith(startTime: value));
  });
}
}


/// @nodoc
mixin _$ProgramMetadata {

 DateTime get created; DateTime get updated; String get version;// Optional schema marker added in schema 1.1 (ADR-0018).
// Absent in 1.0 archives; readers treat null as '1.0'.
 String? get schema;
/// Create a copy of ProgramMetadata
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProgramMetadataCopyWith<ProgramMetadata> get copyWith => _$ProgramMetadataCopyWithImpl<ProgramMetadata>(this as ProgramMetadata, _$identity);

  /// Serializes this ProgramMetadata to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProgramMetadata&&(identical(other.created, created) || other.created == created)&&(identical(other.updated, updated) || other.updated == updated)&&(identical(other.version, version) || other.version == version)&&(identical(other.schema, schema) || other.schema == schema));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,created,updated,version,schema);

@override
String toString() {
  return 'ProgramMetadata(created: $created, updated: $updated, version: $version, schema: $schema)';
}


}

/// @nodoc
abstract mixin class $ProgramMetadataCopyWith<$Res>  {
  factory $ProgramMetadataCopyWith(ProgramMetadata value, $Res Function(ProgramMetadata) _then) = _$ProgramMetadataCopyWithImpl;
@useResult
$Res call({
 DateTime created, DateTime updated, String version, String? schema
});




}
/// @nodoc
class _$ProgramMetadataCopyWithImpl<$Res>
    implements $ProgramMetadataCopyWith<$Res> {
  _$ProgramMetadataCopyWithImpl(this._self, this._then);

  final ProgramMetadata _self;
  final $Res Function(ProgramMetadata) _then;

/// Create a copy of ProgramMetadata
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? created = null,Object? updated = null,Object? version = null,Object? schema = freezed,}) {
  return _then(_self.copyWith(
created: null == created ? _self.created : created // ignore: cast_nullable_to_non_nullable
as DateTime,updated: null == updated ? _self.updated : updated // ignore: cast_nullable_to_non_nullable
as DateTime,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String,schema: freezed == schema ? _self.schema : schema // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ProgramMetadata].
extension ProgramMetadataPatterns on ProgramMetadata {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProgramMetadata value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProgramMetadata() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProgramMetadata value)  $default,){
final _that = this;
switch (_that) {
case _ProgramMetadata():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProgramMetadata value)?  $default,){
final _that = this;
switch (_that) {
case _ProgramMetadata() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DateTime created,  DateTime updated,  String version,  String? schema)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProgramMetadata() when $default != null:
return $default(_that.created,_that.updated,_that.version,_that.schema);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DateTime created,  DateTime updated,  String version,  String? schema)  $default,) {final _that = this;
switch (_that) {
case _ProgramMetadata():
return $default(_that.created,_that.updated,_that.version,_that.schema);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DateTime created,  DateTime updated,  String version,  String? schema)?  $default,) {final _that = this;
switch (_that) {
case _ProgramMetadata() when $default != null:
return $default(_that.created,_that.updated,_that.version,_that.schema);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProgramMetadata implements ProgramMetadata {
  const _ProgramMetadata({required this.created, required this.updated, required this.version, this.schema});
  factory _ProgramMetadata.fromJson(Map<String, dynamic> json) => _$ProgramMetadataFromJson(json);

@override final  DateTime created;
@override final  DateTime updated;
@override final  String version;
// Optional schema marker added in schema 1.1 (ADR-0018).
// Absent in 1.0 archives; readers treat null as '1.0'.
@override final  String? schema;

/// Create a copy of ProgramMetadata
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProgramMetadataCopyWith<_ProgramMetadata> get copyWith => __$ProgramMetadataCopyWithImpl<_ProgramMetadata>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProgramMetadataToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProgramMetadata&&(identical(other.created, created) || other.created == created)&&(identical(other.updated, updated) || other.updated == updated)&&(identical(other.version, version) || other.version == version)&&(identical(other.schema, schema) || other.schema == schema));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,created,updated,version,schema);

@override
String toString() {
  return 'ProgramMetadata(created: $created, updated: $updated, version: $version, schema: $schema)';
}


}

/// @nodoc
abstract mixin class _$ProgramMetadataCopyWith<$Res> implements $ProgramMetadataCopyWith<$Res> {
  factory _$ProgramMetadataCopyWith(_ProgramMetadata value, $Res Function(_ProgramMetadata) _then) = __$ProgramMetadataCopyWithImpl;
@override @useResult
$Res call({
 DateTime created, DateTime updated, String version, String? schema
});




}
/// @nodoc
class __$ProgramMetadataCopyWithImpl<$Res>
    implements _$ProgramMetadataCopyWith<$Res> {
  __$ProgramMetadataCopyWithImpl(this._self, this._then);

  final _ProgramMetadata _self;
  final $Res Function(_ProgramMetadata) _then;

/// Create a copy of ProgramMetadata
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? created = null,Object? updated = null,Object? version = null,Object? schema = freezed,}) {
  return _then(_ProgramMetadata(
created: null == created ? _self.created : created // ignore: cast_nullable_to_non_nullable
as DateTime,updated: null == updated ? _self.updated : updated // ignore: cast_nullable_to_non_nullable
as DateTime,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String,schema: freezed == schema ? _self.schema : schema // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
