// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'location.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Location _$LocationFromJson(Map<String, dynamic> json) => _Location(
  slug: json['slug'] as String,
  label: json['label'] as String? ?? '',
  kind:
      $enumDecodeNullable(
        _$LocationKindEnumMap,
        json['kind'],
        unknownValue: LocationKind.other,
      ) ??
      LocationKind.other,
  place: json['place'] as String? ?? '',
  position: const NullableLatLngJsonConverter().fromJson(
    json['position'] as Map<String, dynamic>?,
  ),
  note: json['note'] as String?,
);

Map<String, dynamic> _$LocationToJson(_Location instance) => <String, dynamic>{
  'slug': instance.slug,
  'label': instance.label,
  'kind': _$LocationKindEnumMap[instance.kind]!,
  'place': instance.place,
  'position': const NullableLatLngJsonConverter().toJson(instance.position),
  'note': instance.note,
};

const _$LocationKindEnumMap = {
  LocationKind.lkp: 'lkp',
  LocationKind.ipp: 'ipp',
  LocationKind.pp: 'pp',
  LocationKind.rendezvous: 'rendezvous',
  LocationKind.commandPost: 'commandPost',
  LocationKind.home: 'home',
  LocationKind.trackFound: 'trackFound',
  LocationKind.dogInterest: 'dogInterest',
  LocationKind.obstacle: 'obstacle',
  LocationKind.notSearchable: 'notSearchable',
  LocationKind.phoneTrace: 'phoneTrace',
  LocationKind.observation: 'observation',
  LocationKind.vantagePoint: 'vantagePoint',
  LocationKind.containmentPost: 'containmentPost',
  LocationKind.personFound: 'personFound',
  LocationKind.other: 'other',
};
