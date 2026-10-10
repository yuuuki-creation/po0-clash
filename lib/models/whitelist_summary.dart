import 'package:fl_clash/common/po0_firewall.dart';
import 'package:fl_clash/models/po0_firewall.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'generated/whitelist_summary.freezed.dart';

enum WhitelistService { po0, ggy }

@Freezed(toStringOverride: false)
abstract class WhitelistEntryStatus with _$WhitelistEntryStatus {
  const factory WhitelistEntryStatus({
    required WhitelistService service,
    required Po0TokenEntry entry,
    required Po0Token token,
    Po0TokenResult? result,
  }) = _WhitelistEntryStatus;
}

@Freezed(toStringOverride: false)
abstract class WhitelistSummary with _$WhitelistSummary {
  const WhitelistSummary._();

  const factory WhitelistSummary({
    @Default(false) bool enabled,
    @Default(0) int total,
    @Default(0) int applied,
    @Default(0) int waiting,
    @Default(false) bool isRunning,
    DateTime? lastPo0At,
    DateTime? lastGgyAt,
    String? po0Exit,
    String? ggyExit,
    @Default([]) List<WhitelistEntryStatus> entries,
  }) = _WhitelistSummary;

  bool get hasPo0 => entries.any((it) => it.service == WhitelistService.po0);

  bool get hasGgy => entries.any((it) => it.service == WhitelistService.ggy);
}

/// Counts only entries that are valid and still configured: results left over
/// from deleted or replaced tokens count neither as success nor towards the
/// total, so a stale result can never read as "everything whitelisted".
WhitelistSummary buildWhitelistSummary({
  required Po0FirewallProps setting,
  required Po0FirewallState po0State,
  required Po0FirewallState ggyState,
}) {
  final po0Entries = po0TokensOf(setting.tokenEntries);
  final ggyEntries = ggyLinksOf(setting.ggyEntries);
  final entries = [
    ..._statusesOf(WhitelistService.po0, po0Entries, po0State),
    ..._statusesOf(WhitelistService.ggy, ggyEntries, ggyState),
  ];
  String? exitOf(WhitelistService service) {
    for (final status in entries) {
      final ip = status.service == service ? status.result?.currentIp : null;
      if (ip != null) {
        return ip;
      }
    }
    return null;
  }

  return WhitelistSummary(
    enabled: setting.enable,
    total: entries.length,
    applied: entries
        .where((it) => it.result?.type == Po0ResultType.applied)
        .length,
    waiting: entries.where((it) => it.result == null).length,
    isRunning:
        (po0Entries.isNotEmpty && po0State.isRunning) ||
        (ggyEntries.isNotEmpty && ggyState.isRunning),
    lastPo0At: po0State.lastRunAt,
    lastGgyAt: ggyState.lastRunAt,
    po0Exit: exitOf(WhitelistService.po0),
    ggyExit: exitOf(WhitelistService.ggy),
    entries: entries,
  );
}

List<WhitelistEntryStatus> _statusesOf(
  WhitelistService service,
  List<({Po0Token token, String name})> entries,
  Po0FirewallState state,
) {
  final results = <String, Po0TokenResult>{
    for (final result in state.results) ?result.tokenValue: result,
  };
  return [
    for (final entry in entries)
      WhitelistEntryStatus(
        service: service,
        entry: Po0TokenEntry(token: entry.token.value, name: entry.name),
        token: entry.token,
        result: results[entry.token.value],
      ),
  ];
}

/// One shared exit line only when both services report the same network;
/// otherwise the caller shows each service's own exit or none at all.
String? whitelistSharedExitOf(WhitelistSummary summary) {
  final po0 = summary.po0Exit;
  final ggy = summary.ggyExit;
  if (po0 != null && ggy != null) {
    return sameC24(po0, ggy) ? po0 : null;
  }
  return po0 ?? ggy;
}
