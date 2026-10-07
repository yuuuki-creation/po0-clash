import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/permission.dart';
import 'package:fl_clash/common/system_dns.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/plugins/po0_screen.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppStateManager extends ConsumerStatefulWidget {
  final Widget child;

  const AppStateManager({super.key, required this.child});

  @override
  ConsumerState<AppStateManager> createState() => _AppStateManagerState();
}

class _AppStateManagerState extends ConsumerState<AppStateManager>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.listenManual(checkIpProvider, (prev, next) {
      if (prev != next && next.isInit) {
        ref.read(networkDetectionProvider.notifier).startCheck();
      }
    });
    ref.listenManual(configProvider, (prev, next) {
      if (prev != next) {
        ref.read(storeActionProvider.notifier).savePreferencesDebounce();
      }
    });
    ref.listenManual(needUpdateGroupsProvider, (prev, next) {
      if (prev != next) {
        ref.read(proxiesActionProvider.notifier).updateGroupsDebounce();
      }
    });
    ref.listenManual(suspendProvider, (prev, next) {
      final isStart = ref.read(isStartProvider);
      if (prev != next && isStart) {
        debouncer.call(FunctionTag.suspend, () async {
          await ref
              .read(setupActionProvider.notifier)
              .syncListenerWithSuspend();
          ref.read(checkIpNumProvider.notifier).add();
        });
      }
    });
    ref.listenManual(initProvider, (prev, next) {
      if (next) {
        ref.read(po0FirewallProvider.notifier).start();
        ref.read(ggyFirewallProvider.notifier).start();
      }
    }, fireImmediately: true);
    po0Screen?.listen((screenOn) {
      ref.read(po0FirewallProvider.notifier).setScreenOn(screenOn);
      ref.read(ggyFirewallProvider.notifier).setScreenOn(screenOn);
    });
    if (system.isDesktop) {
      _keepOneDesktopRoute();
    }
    final systemDns = systemDnsCoordinator;
    if (systemDns != null) {
      ref.listenManual(shouldPatchSystemDnsProvider, (prev, next) {
        unawaited(systemDns.sync(next));
      }, fireImmediately: true);
    }
  }

  void _keepOneDesktopRoute() {
    final systemAction = ref.read(systemActionProvider.notifier);
    ref.listenManual(
      patchClashConfigProvider.select((state) => state.tun.enable),
      (prev, next) {
        if (prev != next) {
          systemAction.reconcileRoute(changed: DesktopRoute.tun);
        }
      },
    );
    ref.listenManual(
      networkSettingProvider.select((state) => state.systemProxy),
      (prev, next) {
        if (prev != next) {
          systemAction.reconcileRoute(changed: DesktopRoute.systemProxy);
        }
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        systemAction.reconcileRoute();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    commonPrint.log('$state');
    if (state == AppLifecycleState.resumed) {
      permissions.check(ref.read);
      render?.resume();
      ref.read(po0FirewallProvider.notifier).pollNow();
      ref.read(ggyFirewallProvider.notifier).pollNow();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        ref.read(setupActionProvider.notifier).tryCheckIp();
      });
    }
  }

  @override
  void didChangePlatformBrightness() {
    ref.read(themeActionProvider.notifier).updateBrightness();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerHover: (_) {
        render?.resume();
      },
      child: widget.child,
    );
  }
}

class AppEnvManager extends StatelessWidget {
  final Widget child;

  const AppEnvManager({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      if (globalState.isPre) {
        return Banner(
          message: 'DEBUG',
          location: BannerLocation.topEnd,
          child: child,
        );
      }
    }
    if (globalState.isPre) {
      return Banner(
        message: globalState.appEnv.toUpperCase(),
        location: BannerLocation.topEnd,
        child: child,
      );
    }
    return child;
  }
}
