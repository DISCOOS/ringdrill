// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'person.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Person _$PersonFromJson(Map<String, dynamic> json) => _Person(
  slug: json['slug'] as String,
  name: json['name'] as String? ?? '',
  age: (json['age'] as num?)?.toInt(),
  gender: json['gender'] as String?,
  signalement: json['signalement'] as String?,
  locSlug: json['locSlug'] as String?,
  notes: json['notes'] as String?,
);

Map<String, dynamic> _$PersonToJson(_Person instance) => <String, dynamic>{
  'slug': instance.slug,
  'name': instance.name,
  'age': instance.age,
  'gender': instance.gender,
  'signalement': instance.signalement,
  'locSlug': instance.locSlug,
  'notes': instance.notes,
};
