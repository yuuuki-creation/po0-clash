import 'dart:async';
import 'dart:math';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'action.dart';
import 'app.dart';
import 'config.dart';
import 'state.dart';

part 'generated/po0_firewall.g.dart';

@Riverpod(keepAlive: true)
Po0FirewallClient po0FirewallClient(Ref ref) => Po0FirewallClient(
  route: () async {
    if (!ref.read(isStartProvider) || ref.read(suspendProvider)) {
      return 'DIRECT';
    }
    return po0ListenerRoute(await po0DirectListener.endpoint);
  },
);

/// Keeps the current exit whitelisted for as long as the app runs, whether or
/// not the proxy is started: a read-only query each interval, and an add only
/// when the exit is missing. Android pauses while the screen is off.
@Riverpod(keepAlive: true)
class Po0Firewall extends _$Po0Firewall {
  static const maxBackoff = Duration(seconds: 30);

  Timer? _timer;
  bool _started = false;
  bool _screenOn = true;
  bool _inFlight = false;
  bool _routingPending = false;
  Po0RunKind? _queued;
  int _failures = 0;
  int _enableVersion = 0;
  final _signatures = <String, String>{};

  Po0FirewallProps get _setting => ref.read(po0FirewallSettingProvider);

  @override
  Po0FirewallState build() {
    ref.onDispose(_cancelTimer);
    ref.listen(po0FirewallSettingProvider, _handleSettingChanged);
    return const Po0FirewallState();
  }

  /// Called once the app has attached: Core runs and the profile already
  /// carries the DIRECT route for the API, so the first request cannot leave
  /// through the proxy.
  void start() {
    if (_started) {
      return;
    }
    _started = true;
    pollNow();
  }

  void pollNow() => unawaited(_run(Po0RunKind.poll));

  void setScreenOn(bool value) {
    if (_screenOn == value) {
      return;
    }
    _screenOn = value;
    if (value) {
      pollNow();
    } else {
      _cancelTimer();
    }
  }

  void onNetworkChanged() {
    if (!_started || !_setting.enable) {
      return;
    }
    ref.read(po0FirewallClientProvider).resetConnections();
    _failures = 0;
    pollNow();
  }

  Future<void> whitelist() => _run(Po0RunKind.whitelist);

  Future<void> query() => _run(Po0RunKind.query);

  @protected
  DateTime now() => DateTime.now();

  @protected
  Future<void> reapplyRouting() async {
    if (!ref.read(initProvider)) {
      return;
    }
    await ref.read(setupActionProvider.notifier).applyProfile(silence: true);
  }

  void _handleSettingChanged(Po0FirewallProps? prev, Po0FirewallProps next) {
    if (!_started || prev == null || prev == next) {
      return;
    }
    if (prev.enable != next.enable) {
      _cancelTimer();
      unawaited(_applyEnable(next.enable));
      return;
    }
    if (!listEquals(_tokensOf(prev), _tokensOf(next))) {
      _signatures.clear();
      unawaited(whitelist());
      return;
    }
    if (prev.pollSeconds != next.pollSeconds && !_inFlight) {
      _scheduleNext();
    }
  }

  List<Po0Token> _tokensOf(Po0FirewallProps setting) =>
      po0TokensOf(setting.tokenEntries).map((it) => it.token).toList();

  Future<void> _applyEnable(bool enable) async {
    final version = ++_enableVersion;
    _routingPending = true;
    try {
      await reapplyRouting();
    } catch (error) {
      commonPrint.log(
        'po0 firewall: applying the DIRECT route failed: $error',
        logLevel: LogLevel.warning,
      );
    } finally {
      if (version == _enableVersion) {
        _routingPending = false;
      }
    }
    if (!ref.mounted || version != _enableVersion) {
      return;
    }
    _queued = null;
    _failures = 0;
    if (enable) {
      await whitelist();
    }
  }

  Future<void> _run(Po0RunKind kind) async {
    final setting = _setting;
    final entries = po0TokensOf(setting.tokenEntries);
    final tokens = entries.map((it) => it.token).toList();
    if (!_started || !setting.enable || tokens.isEmpty) {
      return;
    }
    if (kind == Po0RunKind.poll && !_screenOn) {
      return;
    }
    if (_inFlight || _routingPending) {
      final queued = _queued;
      if (queued == null || kind.index > queued.index) {
        _queued = kind;
      }
      return;
    }
    _inFlight = true;
    _cancelTimer();
    if (kind != Po0RunKind.poll) {
      state = state.copyWith(isRunning: true);
    }
    final client = ref.read(po0FirewallClientProvider);
    final added = <int>{};
    var results = <Po0TokenResult>[];
    try {
      results = await Future.wait(
        tokens.indexed.map(
          (entry) => switch (kind) {
            Po0RunKind.poll => _pollToken(client, entry.$2, () {
              added.add(entry.$1);
            }),
            Po0RunKind.whitelist => client.whitelist(entry.$2),
            Po0RunKind.query => client.query(entry.$2),
          },
        ),
      );
    } catch (error) {
      results = [
        for (final token in tokens)
          Po0TokenResult(
            label: token.label,
            type: Po0ResultType.error,
            message: '$error',
          ),
      ];
    } finally {
      _inFlight = false;
    }
    if (!ref.mounted) {
      return;
    }
    results = [
      for (final (index, result) in results.indexed)
        result.copyWith(
          name: entries[index].name.isEmpty ? null : entries[index].name,
        ),
    ];
    _failures = results.any((it) => it.type == Po0ResultType.error)
        ? _failures + 1
        : 0;
    state = Po0FirewallState(
      lastRunAt: now(),
      lastRunKind: kind,
      results: results,
    );
    _log(kind, tokens, results, added);
    final queued = _queued;
    _queued = null;
    if (queued != null) {
      unawaited(_run(queued));
    } else {
      _scheduleNext();
    }
  }

  Future<Po0TokenResult> _pollToken(
    Po0FirewallClient client,
    Po0Token token,
    void Function() onAdd,
  ) async {
    final status = await client.poll(token);
    if (status.type != Po0ResultType.notApplied) {
      return status;
    }
    onAdd();
    return client.whitelist(token);
  }

  void _scheduleNext() {
    _cancelTimer();
    if (!_started || !_setting.enable || !_screenOn) {
      return;
    }
    _timer = Timer(nextDelayFor(_failures, pollIntervalOf(_setting)), pollNow);
  }

  static Duration pollIntervalOf(Po0FirewallProps setting) => Duration(
    seconds: setting.pollSeconds.clamp(
      po0PollSecondsRange.min,
      po0PollSecondsRange.max,
    ),
  );

  @visibleForTesting
  static Duration nextDelayFor(int failures, Duration interval) {
    if (failures == 0) {
      return interval;
    }
    final backoff = interval * (1 << min(failures, 5));
    final cap = interval > maxBackoff ? interval : maxBackoff;
    return backoff < cap ? backoff : cap;
  }

  void _log(
    Po0RunKind kind,
    List<Po0Token> tokens,
    List<Po0TokenResult> results,
    Set<int> added,
  ) {
    for (final (index, result) in results.indexed) {
      final signature = '${result.type.name} ${result.currentIp}';
      final changed = _signatures[tokens[index].value] != signature;
      _signatures[tokens[index].value] = signature;
      if (kind == Po0RunKind.poll &&
          !changed &&
          !_reportsEviction(result) &&
          !added.contains(index)) {
        continue;
      }
      final action = kind == Po0RunKind.poll && added.contains(index)
          ? 'whitelist'
          : kind.name;
      final detail = [?result.currentIp, ?result.message].join(' ');
      commonPrint.log(
        'po0 firewall $action #${index + 1} ${result.label} '
        '${result.type.name} $detail',
        logLevel: result.type == Po0ResultType.applied
            ? LogLevel.info
            : LogLevel.warning,
      );
    }
  }

  /// Only a ggy add carries a message on success: the entry its FIFO evicted.
  bool _reportsEviction(Po0TokenResult result) =>
      result.type == Po0ResultType.applied && result.message != null;

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }
}
