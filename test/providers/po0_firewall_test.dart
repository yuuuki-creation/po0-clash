import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/po0_firewall.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';

class _TestPo0Firewall extends Po0Firewall {
  DateTime clock = DateTime(2026, 1, 1, 12);

  @override
  DateTime now() => clock;
}

class _TestGgyFirewall extends GgyFirewall {}

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
  enable: true,
  ggyEntries: [Po0TokenEntry(token: _ggyLink)],
);

void main() {
  late _FakeClient client;
  late _TestPo0Firewall notifier;
  late _TestGgyFirewall ggy;
  late ProviderContainer container;
  late List<bool> reapplied;
  Completer<void>? applyGate;

  void createContainer(Po0FirewallProps props) {
    client = _FakeClient();
    reapplied = [];
    applyGate = null;
    container = ProviderContainer(
      overrides: [
        initProvider.overrideWithBuild((_, _) => true),
        po0FirewallSettingProvider.overrideWithBuild((_, _) => props),
        po0FirewallClientProvider.overrideWithValue(client),
        po0FirewallProvider.overrideWith(() => notifier = _TestPo0Firewall()),
        ggyFirewallProvider.overrideWith(() => ggy = _TestGgyFirewall()),
        whitelistCoordinatorProvider.overrideWith((ref) {
          final coordinator = WhitelistCoordinator(
            po0: ref.read(po0FirewallProvider.notifier),
            ggy: ref.read(ggyFirewallProvider.notifier),
            applyProfile: () async {
              reapplied.add(ref.read(po0FirewallSettingProvider).enable);
              final gate = applyGate;
              if (gate != null) {
                await gate.future;
              }
              return true;
            },
            initialized: () => ref.read(initProvider),
          );
          coordinator.listen(ref);
          return coordinator;
        }),
      ],
    );
    container.read(po0FirewallProvider);
    container.read(ggyFirewallProvider);
    container.read(whitelistCoordinatorProvider);
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
    expect(state.results.map((it) => it.tokenValue), ['pgnfw_a', 'pgnfw_b']);
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

  test(
    'one switch change reloads the profile once and runs both lists',
    () async {
      createContainer(
        _enabled.copyWith(ggyEntries: const [Po0TokenEntry(token: _ggyLink)]),
      );
      notifier.start();
      ggy.start();
      updateSetting((state) => state.copyWith(enable: false));
      await settle();
      updateSetting((state) => state.copyWith(enable: true));
      await settle();
      await settle();

      expect(reapplied, [false, true]);
      expect(client.whitelisted, [..._tokens, const Po0Token(_ggyLink)]);
      expect(read().isRunning, isFalse);
      expect(container.read(ggyFirewallProvider).isRunning, isFalse);
    },
  );

  test('the reload gates both schedulers until it has finished', () async {
    createContainer(
      _enabled.copyWith(
        enable: false,
        ggyEntries: const [Po0TokenEntry(token: _ggyLink)],
      ),
    );
    notifier.start();
    ggy.start();
    await settle();
    expect(client.polled, isEmpty);
    expect(client.whitelisted, isEmpty);

    applyGate = Completer<void>();
    updateSetting((state) => state.copyWith(enable: true));
    await settle();
    expect(reapplied, [true]);
    expect(client.polled, isEmpty);
    expect(client.whitelisted, isEmpty, reason: 'the reload has not finished');

    applyGate!.complete();
    await settle();
    await settle();
    expect(client.whitelisted, [..._tokens, const Po0Token(_ggyLink)]);
    expect(read().isRunning, isFalse);
    expect(container.read(ggyFirewallProvider).isRunning, isFalse);
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

  test('a queued manual request is busy before it starts', () async {
    createContainer(_enabled);
    client.gate = Completer<void>();
    notifier.start();
    await settle();

    unawaited(notifier.whitelist());
    await settle();
    expect(read().isRunning, isTrue, reason: 'queued behind the poll');
    expect(client.whitelisted, isEmpty);

    client.gate!.complete();
    await settle();
    await settle();
    expect(client.whitelisted, _tokens);
    expect(read().isRunning, isFalse);
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

  testWidgets('an empty list never creates a polling timer', (tester) async {
    createContainer(const Po0FirewallProps(enable: true));
    notifier.start();
    ggy.start();
    await tester.pump();
    await tester.pump(const Duration(seconds: 30));
    expect(client.polled, isEmpty);
    disposeInTest();
  });

  testWidgets('removing the last po0 token stops only po0 polling', (
    tester,
  ) async {
    createContainer(
      _enabled.copyWith(ggyEntries: const [Po0TokenEntry(token: _ggyLink)]),
    );
    notifier.start();
    ggy.start();
    await tester.pump();
    expect(client.polled, hasLength(3));

    updateSetting((state) => state.copyWith(tokenEntries: []));
    await tester.pump(_second);
    final po0Polls = client.polled
        .where((token) => token.value.startsWith('pgnfw_'))
        .length;
    final ggyPolls = client.polled.length - po0Polls;
    expect(po0Polls, 2, reason: 'no new po0 rounds after the list emptied');
    expect(ggyPolls, 1, reason: 'ggy keeps its own cadence');
    await tester.pump(const Duration(seconds: 11));
    expect(
      client.polled.where((token) => token.value.startsWith('pgnfw_')),
      hasLength(2),
    );
    expect(client.polled, hasLength(4));
    disposeInTest();
  });

  testWidgets('a single switch change reloads the profile once', (
    tester,
  ) async {
    createContainer(_enabled.copyWith(enable: false));
    notifier.start();
    await tester.pump();
    expect(client.whitelisted, isEmpty);

    applyGate = Completer<void>();
    updateSetting((state) => state.copyWith(enable: true));
    await tester.pump();
    expect(reapplied, [true]);
    expect(client.whitelisted, isEmpty, reason: 'the reload gates the run');

    applyGate!.complete();
    await tester.pump();
    expect(client.whitelisted, hasLength(2));
    expect(read().isRunning, isFalse);

    updateSetting((state) => state.copyWith(enable: false));
    await tester.pump();
    expect(reapplied, [true, false]);
    expect(client.whitelisted, hasLength(2), reason: 'off sends nothing more');
    expect(read().isRunning, isFalse);
    await tester.pump(const Duration(seconds: 5));
    expect(client.whitelisted, hasLength(2));
    disposeInTest();
  });

  testWidgets('rapid switch changes converge on the latest intent', (
    tester,
  ) async {
    createContainer(_enabled.copyWith(enable: false));
    notifier.start();
    await tester.pump();

    applyGate = Completer<void>();
    updateSetting((state) => state.copyWith(enable: true));
    await tester.pump();
    expect(reapplied, [true]);
    expect(client.whitelisted, isEmpty, reason: 'the reload is still running');

    updateSetting((state) => state.copyWith(enable: false));
    await tester.pump();
    updateSetting((state) => state.copyWith(enable: true));
    await tester.pump();
    expect(reapplied, [true], reason: 'the blocked reload is still processing');

    applyGate!.complete();
    await tester.pump();
    await tester.pump();

    expect(reapplied, [true, true]);
    expect(client.whitelisted, hasLength(2));
    expect(read().isRunning, isFalse);
    disposeInTest();
  });

  for (final fails in [false, true]) {
    testWidgets(
      'disposing while a reload ${fails ? 'fails' : 'completes'} cancels '
      'the newer switch transition',
      (tester) async {
        createContainer(_enabled.copyWith(enable: false));
        notifier.start();
        ggy.start();
        applyGate = Completer<void>();
        updateSetting((state) => state.copyWith(enable: true));
        await tester.pump();
        updateSetting((state) => state.copyWith(enable: false));
        await tester.pump();
        expect(reapplied, [true]);

        disposeInTest();
        if (fails) {
          applyGate!.completeError(StateError('reload failed'));
        } else {
          applyGate!.complete();
        }
        await tester.pump();
        await tester.pump();

        expect(reapplied, [true]);
        expect(client.whitelisted, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('a request already running when the switch turns off completes '
      'but nothing follows', (tester) async {
    createContainer(_enabled);
    client.gate = Completer<void>();
    notifier.start();
    await tester.pump();
    expect(client.polled, hasLength(2));

    updateSetting((state) => state.copyWith(enable: false));
    await tester.pump();
    expect(reapplied, [false]);

    client.gate!.complete();
    client.gate = null;
    await tester.pump();
    await tester.pump();
    expect(
      client.polled,
      hasLength(2),
      reason: 'the off gate stops the next round',
    );
    expect(read().isRunning, isFalse);
    disposeInTest();
  });

  testWidgets('turning the switch off cancels a queued manual request', (
    tester,
  ) async {
    createContainer(_enabled.copyWith(enable: false));
    notifier.start();
    updateSetting((state) => state.copyWith(enable: true));
    await tester.pump();
    await tester.pump();
    expect(client.whitelisted, hasLength(2));

    client.gate = Completer<void>();
    unawaited(notifier.whitelist());
    await tester.pump();
    await tester.pump();
    expect(client.whitelisted, hasLength(4));
    expect(read().isRunning, isTrue);

    unawaited(notifier.query());
    await tester.pump();
    expect(client.queried, isEmpty, reason: 'queued behind the whitelist');
    expect(read().isRunning, isTrue);

    updateSetting((state) => state.copyWith(enable: false));
    await tester.pump();
    expect(read().isRunning, isFalse, reason: 'the queued query was dropped');

    client.gate!.complete();
    client.gate = null;
    await tester.pump();
    await tester.pump();
    expect(client.whitelisted, hasLength(4));
    expect(client.queried, isEmpty, reason: 'the queued query was cancelled');
    expect(read().isRunning, isFalse);
    disposeInTest();
  });
}
