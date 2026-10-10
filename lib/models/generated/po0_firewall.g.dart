// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../po0_firewall.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Po0TokenEntry _$Po0TokenEntryFromJson(Map<String, dynamic> json) =>
    _Po0TokenEntry(
      token: json['token'] as String,
      name: json['name'] as String? ?? '',
    );

Map<String, dynamic> _$Po0TokenEntryToJson(_Po0TokenEntry instance) =>
    <String, dynamic>{'token': instance.token, 'name': instance.name};

_Po0FirewallProps _$Po0FirewallPropsFromJson(Map<String, dynamic> json) =>
    _Po0FirewallProps(
      enable: json['enable'] as bool? ?? false,
      tokenEntries:
          (json['tokenEntries'] as List<dynamic>?)
              ?.map((e) => Po0TokenEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      pollSeconds: (json['pollSeconds'] as num?)?.toInt() ?? 5,
      ggyEntries:
          (json['ggyEntries'] as List<dynamic>?)
              ?.map((e) => Po0TokenEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$Po0FirewallPropsToJson(_Po0FirewallProps instance) =>
    <String, dynamic>{
      'enable': instance.enable,
      'tokenEntries': instance.tokenEntries,
      'pollSeconds': instance.pollSeconds,
      'ggyEntries': instance.ggyEntries,
    };
