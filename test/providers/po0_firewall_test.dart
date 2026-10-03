import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/po0_firewall.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';

class _TestPo0Firewall extends Po0Firewall {
  DateTime clock = DateTime(2026, 1, 1, 12);
  final reapplied = <bool>[];

  @override
  DateTime now() => clock;

  @override
  Future<void> reapplyRouting() async {
    reapplied.add(ref.read(po0FirewallSettingProvider).enable);
  }
}

class _TestGgyFirewall extends GgyFirewall {
  final reapplied = <bool>[];

  @override
  Future<void> reapplyRouting() async {
    reapplied.add(ref.read(po0FirewallSettingProvider).ggyEnable);
  }
}

class _FakeClient extends Po0FirewallClient {
  _FakeClient() : super(send: (_, _) => throw UnimplementedError());

  final polled = <Po0Token>[];
  final whitelisted = <Po0Token>[];
  final queried = <Po0Token>[];
  var resets = 0;
  Po0ResultType pollType = Po0ResultType.applied;
  Completer<void>? gate;

  Po0TokenResult _result(Po0Token token, Po0ResultType type) => Po0TokenResult(
    label: token.label,
    type: type,
    currentIp: '1.2.3.0/24',
    whitelist: [
      if (type == Po0ResultType.applied)
        const Po0WhitelistEntry(ip: '1.2.3.0/24'),
    ],
  );

  @override
  Future<Po0TokenResult> poll(Po0Token token) async {
    polled.add(token);
    await gate?.future;
    return _result(token, pollType);
  }

  @override
  Future<Po0TokenResult> whitelist(Po0Token token) async {
    whitelisted.add(token);
    await gate?.future;
    return _result(token, Po0ResultType.applied);
  }

  @override
  Future<Po0TokenResult> query(Po0Token token) async {
    queried.add(token);
    return _result(token, Po0ResultType.applied);
  }

  @override
  void resetConnections() => resets++;
}

const _enabled = Po0FirewallProps(
  enable: true,
  tokenEntries: [
    Po0TokenEntry(token: 'pgnfw_a', name: 'home'),
    Po0TokenEntry(token: 'pgnfw_b'),
  ],
  pollSeconds: 1,
);

const _tokens = [Po0Token('pgnfw_a'), Po0Token('pgnfw_b')];

const _second = Duration(seconds: 1);

const _ggyLink = 'https://www.guguyun.com/f/whitelist?token=ctecsfw_x';

const _ggyOnly = Po0FirewallProps(
  ggyEnable: true,
  ggyEntries: [Po0TokenEntry(token: _ggyLink)],
);

void main() {
  late _FakeClient client;
  late _TestPo0Firewall notifier;
  late _TestGgyFirewall ggy;
  late ProviderContainer container;

  void createContainer(Po0FirewallProps props) {
    client = _FakeClient();
    container = ProviderContainer(
      overrides: [
        po0FirewallSettingProvider.overrideWithBuild((_, _) => props),
        po0FirewallClientProvider.overrideWithValue(client),
        po0FirewallProvider.overrideWith(() => notifier = _TestPo0Firewall()),
        ggyFirewallProvider.overrideWith(() => ggy = _TestGgyFirewall()),
      ],
    );
    container.read(po0FirewallProvider);
    container.read(ggyFirewallProvider);
  }

  void updateSetting(Po0FirewallProps Function(Po0FirewallProps) update) {
    container.read(po0FirewallSettingProvider.notifier).update(update);
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  Po0FirewallState read() => container.read(po0FirewallProvider);

  // Fake-async tests must not leave the poll timer pending.
  void disposeInTest() {
    container.dispose();
    container = ProviderContainer();
  }

  tearDown(() => container.dispose());

  test('start polls every token and adds nothing that is listed', () async {
    createContainer(_enabled);
    notifier.start();
    await settle();

    expect(client.polled, _tokens);
    expect(client.whitelisted, isEmpty);
    final state = read();
    expect(state.isRunning, isFalse);
    expect(state.lastRunAt, notifier.clock);
    expect(state.lastRunKind, Po0RunKind.poll);
    expect(state.results.map((it) => it.type), [
      Po0ResultType.applied,
      Po0ResultType.applied,
    ]);
  });

  test('a missing exit is added through the add endpoint', () async {
    createContainer(_enabled);
    client.pollType = Po0ResultType.notApplied;
    notifier.start();
    await settle();
    await settle();

    expect(client.whitelisted, _tokens);
    expect(read().results.map((it) => it.type), [
      Po0ResultType.applied,
      Po0ResultType.applied,
    ]);
  });

  test('a failed read is not turned into an add', () async {
    createContainer(_enabled);
    client.pollType = Po0ResultType.error;
    notifier.start();
    await settle();

    expect(client.whitelisted, isEmpty);
    expect(read().results.first.type, Po0ResultType.error);
  });

  test('does nothing before start or while disabled', () async {
    createContainer(_enabled.copyWith(enable: false));
    await notifier.whitelist();
    notifier.start();
    notifier.pollNow();
    notifier.onNetworkChanged();
    await settle();
    expect(client.polled, isEmpty);
    expect(client.whitelisted, isEmpty);
    expect(read().lastRunAt, isNull);
  });

  test('enabling applies the DIRECT route before the first add', () async {
    createContainer(_enabled.copyWith(enable: false));
    notifier.start();
    updateSetting((state) => state.copyWith(enable: true));
    await settle();
    await settle();

    expect(notifier.reapplied, [true]);
    expect(client.whitelisted, hasLength(2));

    updateSetting((state) => state.copyWith(enable: false));
    await settle();
    expect(notifier.reapplied, [true, false]);
    expect(client.whitelisted, hasLength(2));
  });

  test('manual runs show progress, background polls do not', () async {
    createContainer(_enabled);
    client.gate = Completer<void>();
    notifier.start();
    await settle();
    expect(read().isRunning, isFalse);

    client.gate!.complete();
    client.gate = Completer<void>();
    await settle();
    unawaited(notifier.whitelist());
    await settle();
    expect(read().isRunning, isTrue);

    client.gate!.complete();
    client.gate = null;
    await settle();
    expect(read().isRunning, isFalse);
    expect(read().lastRunKind, Po0RunKind.whitelist);
  });

  test('requests during a run are queued behind it, strongest first', () async {
    createContainer(_enabled);
    client.gate = Completer<void>();
    notifier.start();
    await settle();

    notifier.pollNow();
    unawaited(notifier.query());
    unawaited(notifier.whitelist());
    notifier.pollNow();
    await settle();
    expect(client.whitelisted, isEmpty);

    client.gate!.complete();
    client.gate = null;
    await settle();
    await settle();
    expect(client.whitelisted, _tokens);
    expect(client.queried, isEmpty);
    expect(client.polled, hasLength(2));
  });

  test('changing the tokens adds the new ones right away', () async {
    createContainer(_enabled);
    notifier.start();
    await settle();

    updateSetting(
      (state) =>
          state.copyWith(tokenEntries: const [Po0TokenEntry(token: 'pgnfw_c')]),
    );
    await settle();
    expect(client.whitelisted, [const Po0Token('pgnfw_c')]);
  });

  test('renaming a token does not trigger an add', () async {
    createContainer(_enabled);
    notifier.start();
    await settle();

    updateSetting(
      (state) => state.copyWith(
        tokenEntries: [
          for (final entry in state.tokenEntries)
            entry.copyWith(name: 'renamed'),
        ],
      ),
    );
    await settle();
    expect(client.whitelisted, isEmpty);
  });

  test('each token is checked on its own and carries its name', () async {
    createContainer(
      _enabled.copyWith(
        tokenEntries: [
          ..._enabled.tokenEntries,
          const Po0TokenEntry(token: 'pgnfw_a', name: 'duplicate'),
          const Po0TokenEntry(token: 'not-a-token'),
        ],
      ),
    );
    notifier.start();
    await settle();

    expect(client.polled, _tokens);
    expect(read().results.map((it) => it.name), ['home', null]);
  });

  test('query reads status without adding', () async {
    createContainer(_enabled);
    notifier.start();
    await settle();

    await notifier.query();
    expect(client.queried, _tokens);
    expect(client.whitelisted, isEmpty);
    expect(read().lastRunKind, Po0RunKind.query);
  });

  test('failures back off up to the cap, never below the interval', () {
    List<int> delays(int seconds) => [
      for (var i = 0; i <= 6; i++)
        WhitelistScheduler.nextDelayFor(
          i,
          Duration(seconds: seconds),
        ).inSeconds,
    ];
    expect(delays(1), [1, 2, 4, 8, 16, 30, 30]);
    expect(delays(10), [10, 20, 30, 30, 30, 30, 30]);
    expect(delays(120), [120, 120, 120, 120, 120, 120, 120]);
  });

  test('checks every five seconds unless configured otherwise', () {
    expect(defaultPo0FirewallProps.pollSeconds, 5);
    expect(
      Po0Firewall.pollIntervalOf(defaultPo0FirewallProps),
      const Duration(seconds: 5),
    );
  });

  test('the interval is clamped to the supported range', () {
    expect(
      Po0Firewall.pollIntervalOf(_enabled.copyWith(pollSeconds: 0)),
      _second,
    );
    expect(
      Po0Firewall.pollIntervalOf(_enabled.copyWith(pollSeconds: 99999)),
      const Duration(hours: 1),
    );
  });

  testWidgets('polls again every second', (tester) async {
    createContainer(_enabled);
    notifier.start();
    await tester.pump();
    expect(client.polled, hasLength(2));

    await tester.pump(const Duration(milliseconds: 900));
    expect(client.polled, hasLength(2));
    await tester.pump(const Duration(milliseconds: 100));
    expect(client.polled, hasLength(4));
    await tester.pump(_second);
    expect(client.polled, hasLength(6));
    disposeInTest();
  });

  testWidgets('polls at the configured interval', (tester) async {
    createContainer(_enabled.copyWith(pollSeconds: 5));
    notifier.start();
    await tester.pump();

    await tester.pump(const Duration(seconds: 4));
    expect(client.polled, hasLength(2));
    await tester.pump(_second);
    expect(client.polled, hasLength(4));
    disposeInTest();
  });

  testWidgets('a new interval applies to the next poll', (tester) async {
    createContainer(_enabled.copyWith(pollSeconds: 60));
    notifier.start();
    await tester.pump();

    updateSetting((state) => state.copyWith(pollSeconds: 2));
    await tester.pump(_second);
    expect(client.polled, hasLength(2));
    await tester.pump(_second);
    expect(client.polled, hasLength(4));
    disposeInTest();
  });

  testWidgets('a failing API is polled less often', (tester) async {
    createContainer(_enabled);
    client.pollType = Po0ResultType.error;
    notifier.start();
    await tester.pump();

    await tester.pump(const Duration(seconds: 1));
    expect(client.polled, hasLength(2));
    await tester.pump(const Duration(seconds: 1));
    expect(client.polled, hasLength(4));

    client.pollType = Po0ResultType.applied;
    await tester.pump(const Duration(seconds: 4));
    expect(client.polled, hasLength(6));
    await tester.pump(const Duration(seconds: 1));
    expect(client.polled, hasLength(8));
    disposeInTest();
  });

  testWidgets('the screen turning off pauses polling until it is back', (
    tester,
  ) async {
    createContainer(_enabled);
    notifier.start();
    await tester.pump();

    notifier.setScreenOn(false);
    await tester.pump(const Duration(seconds: 10));
    expect(client.polled, hasLength(2));
    notifier.pollNow();
    await tester.pump();
    expect(client.polled, hasLength(2));

    notifier.setScreenOn(true);
    await tester.pump();
    expect(client.polled, hasLength(4));
    await tester.pump(_second);
    expect(client.polled, hasLength(6));
    disposeInTest();
  });

  testWidgets('a network change drops the connection and polls at once', (
    tester,
  ) async {
    createContainer(_enabled);
    client.pollType = Po0ResultType.error;
    notifier.start();
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(client.polled, hasLength(4));

    client.pollType = Po0ResultType.applied;
    notifier.onNetworkChanged();
    await tester.pump();
    expect(client.resets, 1);
    expect(client.polled, hasLength(6));
    await tester.pump(_second);
    expect(client.polled, hasLength(8));
    disposeInTest();
  });

  testWidgets('ggy sends its links every 11 seconds, whatever po0 uses', (
    tester,
  ) async {
    createContainer(_ggyOnly.copyWith(pollSeconds: 1));
    notifier.start();
    ggy.start();
    await tester.pump();
    expect(client.polled, [const Po0Token(_ggyLink)]);

    await tester.pump(const Duration(seconds: 10));
    expect(client.polled, hasLength(1));
    await tester.pump(_second);
    expect(client.polled, hasLength(2));
    disposeInTest();
  });

  test('each switch drives only its own list', () async {
    createContainer(
      _enabled.copyWith(ggyEntries: const [Po0TokenEntry(token: _ggyLink)]),
    );
    notifier.start();
    ggy.start();
    await settle();
    expect(client.polled, _tokens);
    expect(container.read(ggyFirewallProvider).results, isEmpty);

    updateSetting((state) => state.copyWith(ggyEnable: true));
    await settle();
    await settle();
    expect(ggy.reapplied, [true]);
    expect(notifier.reapplied, isEmpty);
    expect(client.whitelisted, [const Po0Token(_ggyLink)]);
  });
}
