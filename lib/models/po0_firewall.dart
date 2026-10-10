import 'package:fl_clash/common/converter.dart';
import 'package:fl_clash/common/po0_firewall.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'generated/po0_firewall.freezed.dart';
part 'generated/po0_firewall.g.dart';

const defaultPo0FirewallProps = Po0FirewallProps();

const po0PollSecondsRange = (min: 1, max: 3600);

@freezed
abstract class Po0TokenEntry with _$Po0TokenEntry {
  const factory Po0TokenEntry({
    required String token,
    @Default('') String name,
  }) = _Po0TokenEntry;

  factory Po0TokenEntry.fromJson(Map<String, Object?> json) =>
      _$Po0TokenEntryFromJson(json);
}

@freezed
abstract class Po0FirewallProps with _$Po0FirewallProps {
  const factory Po0FirewallProps({
    @Default(false) bool enable,
    @Default([]) List<Po0TokenEntry> tokenEntries,
    @Default(5) int pollSeconds,
    @Default([]) List<Po0TokenEntry> ggyEntries,
  }) = _Po0FirewallProps;

  factory Po0FirewallProps.fromJson(Map<String, Object?> json) =>
      _$Po0FirewallPropsFromJson(json);

  factory Po0FirewallProps.safeFromJson(Map<String, Object?>? json) {
    if (json == null) {
      return defaultPo0FirewallProps;
    }
    return decodeOrRestoreDefault(
      'po0 firewall settings',
      () => Po0FirewallProps.fromJson(
        _mergeEnableSwitches(_migrateGgyEntries(_migrateLegacyTokens(json))),
      ),
      () => defaultPo0FirewallProps,
    );
  }
}

/// po0.5 and earlier stored the tokens as one po0fw-style string.
Map<String, Object?> _migrateLegacyTokens(Map<String, Object?> json) {
  final legacy = json['tokens'];
  if (json.containsKey('tokenEntries') || legacy is! String) {
    return json;
  }
  return {
    ...json,
    'tokenEntries': [
      for (final token in parsePo0Tokens(legacy))
        Po0TokenEntry(token: token.value).toJson(),
    ],
  };
}

Map<String, Object?> _migrateGgyEntries(Map<String, Object?> json) {
  final entries = json['tokenEntries'];
  if (entries is! List) {
    return json;
  }
  bool isGgy(Object? entry) => entry is Map && isGgyLink('${entry['token']}');
  final moved = entries.where(isGgy).toList();
  if (moved.isEmpty) {
    return json;
  }
  final existing = json['ggyEntries'] is List
      ? [...json['ggyEntries'] as List]
      : <Object?>[];
  final known = <String>{
    for (final entry in existing)
      if (entry is Map) '${entry['token']}',
  };
  return {
    ...json,
    'tokenEntries': entries.where((entry) => !isGgy(entry)).toList(),
    'ggyEntries': [
      ...existing,
      for (final entry in moved)
        if (known.add('${entry['token']}')) entry,
    ],
  };
}

Map<String, Object?> _mergeEnableSwitches(Map<String, Object?> json) {
  bool switchOf(Object? value, String name) {
    if (value == null) {
      return false;
    }
    if (value is! bool) {
      throw FormatException('$name must be a bool, was ${value.runtimeType}');
    }
    return value;
  }

  final enable =
      switchOf(json['enable'], 'enable') ||
      switchOf(json['ggyEnable'], 'ggyEnable');
  return {...json, 'enable': enable}..remove('ggyEnable');
}

enum Po0ResultType { applied, notApplied, disabled, rejected, error }

/// Ordered by precedence: a queued request keeps the highest kind asked for.
enum Po0RunKind { poll, query, whitelist }

@freezed
abstract class Po0WhitelistEntry with _$Po0WhitelistEntry {
  const factory Po0WhitelistEntry({required String ip, int? slot}) =
      _Po0WhitelistEntry;
}

@Freezed(toStringOverride: false)
abstract class Po0TokenResult with _$Po0TokenResult {
  const factory Po0TokenResult({
    required String label,
    String? name,
    required Po0ResultType type,
    String? currentIp,
    @Default([]) List<Po0WhitelistEntry> whitelist,
    int? limit,
    String? message,
    String? tokenValue,
  }) = _Po0TokenResult;
}

@freezed
abstract class Po0FirewallState with _$Po0FirewallState {
  const factory Po0FirewallState({
    @Default(false) bool isRunning,
    DateTime? lastRunAt,
    @Default(Po0RunKind.poll) Po0RunKind lastRunKind,
    @Default([]) List<Po0TokenResult> results,
  }) = _Po0FirewallState;
}
