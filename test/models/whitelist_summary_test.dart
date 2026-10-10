import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

const _link = 'https://www.guguyun.com/f/whitelist?token=ctecsfw_x';

Po0TokenResult _result(
  String tokenValue,
  Po0ResultType type, {
  String? ip,
  String? message,
}) {
  final prefix = tokenValue.length > 12
      ? tokenValue.substring(0, 12)
      : tokenValue;
  return Po0TokenResult(
    label: '$prefix…',
    type: type,
    currentIp: ip,
    message: message,
    tokenValue: tokenValue,
  );
}

Po0FirewallState _state({
  bool isRunning = false,
  List<Po0TokenResult> results = const [],
}) => Po0FirewallState(
  isRunning: isRunning,
  lastRunAt: results.isEmpty ? null : DateTime(2026, 1, 2),
  results: results,
);

WhitelistSummary _summary({
  Po0FirewallProps? setting,
  Po0FirewallState po0State = const Po0FirewallState(),
  Po0FirewallState ggyState = const Po0FirewallState(),
}) => buildWhitelistSummary(
  setting:
      setting ??
      const Po0FirewallProps(
        enable: true,
        tokenEntries: [Po0TokenEntry(token: 'pgnfw_a', name: 'home')],
        ggyEntries: [Po0TokenEntry(token: _link, name: 'ggy')],
      ),
  po0State: po0State,
  ggyState: ggyState,
);

void main() {
  test('an off switch reports off and keeps counts at zero', () {
    final summary = _summary(
      setting: const Po0FirewallProps(
        enable: false,
        tokenEntries: [Po0TokenEntry(token: 'pgnfw_a')],
      ),
      po0State: _state(results: [_result('pgnfw_a', Po0ResultType.applied)]),
    );
    expect(summary.enabled, isFalse);
    expect(summary.total, 1);
    expect(summary.applied, 1);
  });

  test('no valid entries means nothing to count', () {
    final summary = _summary(
      setting: const Po0FirewallProps(
        enable: true,
        tokenEntries: [Po0TokenEntry(token: 'bogus')],
      ),
    );
    expect(summary.total, 0);
    expect(summary.applied, 0);
    expect(summary.waiting, 0);
    expect(summary.hasPo0, isFalse);
    expect(summary.hasGgy, isFalse);
  });

  test('a success and a missing result read as 1/2', () {
    final summary = _summary(
      po0State: _state(results: [_result('pgnfw_a', Po0ResultType.applied)]),
    );
    expect(summary.total, 2);
    expect(summary.applied, 1);
    expect(summary.waiting, 1);
  });

  test('every entry applied reads as whitelisted', () {
    final summary = _summary(
      po0State: _state(results: [_result('pgnfw_a', Po0ResultType.applied)]),
      ggyState: _state(
        results: [_result(_link, Po0ResultType.applied, ip: '1.2.3.0/24')],
      ),
    );
    expect(summary.applied, summary.total);
    expect(summary.waiting, 0);
    expect(summary.hasPo0, isTrue);
    expect(summary.hasGgy, isTrue);
  });

  test('a ggy whitelist response counts as applied without a full list', () {
    final summary = _summary(
      setting: const Po0FirewallProps(
        enable: true,
        ggyEntries: [Po0TokenEntry(token: _link)],
      ),
      ggyState: _state(results: [_result(_link, Po0ResultType.applied)]),
    );
    expect(summary.applied, 1);
  });

  test('results of deleted entries leave the counts alone', () {
    final summary = _summary(
      po0State: _state(
        results: [
          _result('pgnfw_gone', Po0ResultType.applied),
          _result('pgnfw_a', Po0ResultType.notApplied, ip: '1.1.1.1'),
        ],
      ),
    );
    expect(summary.total, 2);
    expect(summary.applied, 0);
    expect(summary.waiting, 1, reason: 'only the ggy link has no result yet');
    expect(
      summary.entries
          .firstWhere((it) => it.service == WhitelistService.po0)
          .result
          ?.type,
      Po0ResultType.notApplied,
    );
  });

  test('replacing a token does not inherit the old result', () {
    final summary = _summary(
      setting: const Po0FirewallProps(
        enable: true,
        tokenEntries: [Po0TokenEntry(token: 'pgnfw_new')],
      ),
      po0State: _state(results: [_result('pgnfw_old', Po0ResultType.applied)]),
    );
    expect(summary.applied, 0);
    expect(summary.waiting, 1);
  });

  test('a shared twelve character prefix still matches by full value', () {
    final summary = _summary(
      setting: const Po0FirewallProps(
        enable: true,
        tokenEntries: [
          Po0TokenEntry(token: 'pgnfw_aaa111'),
          Po0TokenEntry(token: 'pgnfw_aaa222'),
        ],
      ),
      po0State: _state(
        results: [
          _result('pgnfw_aaa111', Po0ResultType.applied),
          _result('pgnfw_aaa222', Po0ResultType.notApplied),
        ],
      ),
    );
    expect(summary.applied, 1);
    expect(summary.waiting, 0);
    expect(summary.entries.map((it) => it.result?.type).toList(), [
      Po0ResultType.applied,
      Po0ResultType.notApplied,
    ]);
  });

  test('duplicate and invalid entries do not inflate the total', () {
    final summary = _summary(
      setting: const Po0FirewallProps(
        enable: true,
        tokenEntries: [
          Po0TokenEntry(token: 'pgnfw_a'),
          Po0TokenEntry(token: 'pgnfw_a', name: 'again'),
          Po0TokenEntry(token: 'nope'),
        ],
        ggyEntries: [
          Po0TokenEntry(token: _link),
          Po0TokenEntry(token: 'https://www.guguyun.com/f/whitelist?token='),
        ],
      ),
    );
    expect(summary.total, 2);
  });

  test('a manual task shows as running only for a service with entries', () {
    final withPo0 = _summary(po0State: _state(isRunning: true));
    expect(withPo0.isRunning, isTrue);
    final withoutEntries = _summary(
      setting: const Po0FirewallProps(
        enable: true,
        ggyEntries: [Po0TokenEntry(token: _link)],
      ),
      po0State: _state(isRunning: true),
    );
    expect(withoutEntries.isRunning, isFalse);
  });

  test('the result keeps the latest name from the config', () {
    final summary = _summary(
      po0State: _state(results: [_result('pgnfw_a', Po0ResultType.applied)]),
    );
    expect(
      summary.entries.first.entry,
      const Po0TokenEntry(token: 'pgnfw_a', name: 'home'),
    );
  });

  test('the shared exit only appears when both services agree on the /24', () {
    final same = _summary(
      po0State: _state(
        results: [_result('pgnfw_a', Po0ResultType.applied, ip: '1.2.3.4')],
      ),
      ggyState: _state(
        results: [_result(_link, Po0ResultType.applied, ip: '1.2.3.0/24')],
      ),
    );
    expect(whitelistSharedExitOf(same), '1.2.3.4');
    final different = _summary(
      po0State: _state(
        results: [_result('pgnfw_a', Po0ResultType.applied, ip: '1.2.3.4')],
      ),
      ggyState: _state(
        results: [_result(_link, Po0ResultType.applied, ip: '5.6.7.8')],
      ),
    );
    expect(whitelistSharedExitOf(different), isNull);
    final po0Only = _summary(
      setting: const Po0FirewallProps(
        enable: true,
        tokenEntries: [Po0TokenEntry(token: 'pgnfw_a')],
      ),
      po0State: _state(
        results: [_result('pgnfw_a', Po0ResultType.applied, ip: '1.2.3.4')],
      ),
    );
    expect(whitelistSharedExitOf(po0Only), '1.2.3.4');
  });

  test("the summary carries each service's own last run time", () {
    final summary = _summary(
      po0State: _state(results: [_result('pgnfw_a', Po0ResultType.applied)]),
    );
    expect(summary.lastPo0At, DateTime(2026, 1, 2));
    expect(summary.lastGgyAt, isNull);
  });
}
