import 'dart:convert';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  group('AppSetting provider', () {
    test('default value is defaultAppSettingProps', () {
      final value = container.read(appSettingProvider);
      expect(value.onlyStatisticsProxy, false);
      expect(value.autoLaunch, false);
      expect(value.closeConnections, true);
      expect(value.isAnimateToPage, true);
    });

    test('can update state', () {
      container
          .read(appSettingProvider.notifier)
          .update((_) => const AppSettingProps(autoLaunch: true));
      final value = container.read(appSettingProvider);
      expect(value.autoLaunch, true);
    });
  });

  group('WindowSetting provider', () {
    test('default value has zero dimensions', () {
      final value = container.read(windowSettingProvider);
      expect(value.width, 0);
      expect(value.height, 0);
    });

    test('can update state', () {
      container
          .read(windowSettingProvider.notifier)
          .update((_) => const WindowProps(width: 1024, height: 768));
      final value = container.read(windowSettingProvider);
      expect(value.width, 1024);
      expect(value.height, 768);
    });
  });

  group('VpnSetting provider', () {
    test('default value has enable true', () {
      final value = container.read(vpnSettingProvider);
      expect(value.enable, true);
      expect(value.systemProxy, true);
    });

    test('can update state', () {
      container
          .read(vpnSettingProvider.notifier)
          .update((_) => const VpnProps(enable: false));
      expect(container.read(vpnSettingProvider).enable, false);
    });
  });

  group('NetworkSetting provider', () {
    test('default values', () {
      final value = container.read(networkSettingProvider);
      expect(value.systemProxy, true);
      expect(value.bypassDomain, defaultBypassDomain);
    });

    test('can update state', () {
      container
          .read(networkSettingProvider.notifier)
          .update((_) => const NetworkProps(systemProxy: false));
      expect(container.read(networkSettingProvider).systemProxy, false);
    });
  });

  group('ThemeSetting provider', () {
    test('default value is dark mode', () {
      final value = container.read(themeSettingProvider);
      expect(value.primaryColor, null);
    });

    test('can update state', () {
      container
          .read(themeSettingProvider.notifier)
          .update((_) => const ThemeProps(primaryColor: 0xFF123456));
      expect(container.read(themeSettingProvider).primaryColor, 0xFF123456);
    });
  });

  group('CurrentProfileId provider', () {
    test('default is null', () {
      expect(container.read(currentProfileIdProvider), null);
    });

    test('can set profile id', () {
      container.read(currentProfileIdProvider.notifier).update((_) => 42);
      expect(container.read(currentProfileIdProvider), 42);
    });
  });

  group('DavSetting provider', () {
    test('default is null', () {
      expect(container.read(davSettingProvider), null);
    });

    test('can update WebDAV settings', () {
      const davProps = DAVProps(
        uri: 'https://dav.example.com',
        user: 'user',
        password: 'secret',
      );

      container.read(davSettingProvider.notifier).update((_) => davProps);

      expect(container.read(davSettingProvider), davProps);
      expect(container.read(configProvider).davProps?.password, 'secret');
    });
  });

  group('OverrideDns provider', () {
    test('default is false', () {
      expect(container.read(overrideDnsProvider), false);
    });

    test('can toggle on', () {
      container.read(overrideDnsProvider.notifier).update((_) => true);
      expect(container.read(overrideDnsProvider), true);
    });
  });

  group('ExcludeSSIDs provider', () {
    test('reorders with final insertion index semantics', () {
      container
          .read(excludeSSIDsProvider.notifier)
          .update((_) => ['Home', 'Office', 'Cafe', 'Hotel']);

      container.read(excludeSSIDsProvider.notifier).update((value) {
        return value.copyAndReorder(1, 3);
      });

      expect(container.read(excludeSSIDsProvider), [
        'Home',
        'Cafe',
        'Hotel',
        'Office',
      ]);
    });
  });

  group('HotKeyActions provider', () {
    test('default is empty list', () {
      expect(container.read(hotKeyActionsProvider), isEmpty);
    });

    test('can update hotkey actions', () {
      const actions = [
        HotKeyAction(
          action: HotAction.start,
          key: 1,
          modifiers: {KeyboardModifier.control},
        ),
      ];

      container.read(hotKeyActionsProvider.notifier).update((_) => actions);

      expect(container.read(hotKeyActionsProvider), actions);
    });
  });

  group('ProxiesStyleSetting provider', () {
    test('default values', () {
      final value = container.read(proxiesStyleSettingProvider);
      expect(value.type, ProxiesType.tab);
    });

    test('can update state', () {
      container
          .read(proxiesStyleSettingProvider.notifier)
          .update(
            (_) => const ProxiesStyleProps(sortType: ProxiesSortType.delay),
          );
      expect(
        container.read(proxiesStyleSettingProvider).sortType,
        ProxiesSortType.delay,
      );
    });
  });

  group('configProvider (composite)', () {
    test('composes all sub-providers with defaults', () {
      final config = container.read(configProvider);
      expect(config.appSettingProps.onlyStatisticsProxy, false);
      expect(config.windowProps.width, 0);
      expect(config.vpnProps.enable, true);
      expect(config.networkProps.systemProxy, true);
      expect(config.currentProfileId, null);
      expect(config.overrideDns, false);
      expect(config.hotKeyActions, isEmpty);
      expect(config.patchClashConfig, const PatchClashConfig());
      expect(config.excludeSSIDs, isEmpty);
      expect(config.po0FirewallProps, defaultPo0FirewallProps);
    });

    test('reflects updated sub-provider values', () {
      container.read(currentProfileIdProvider.notifier).update((_) => 99);
      container.read(overrideDnsProvider.notifier).update((_) => true);
      container
          .read(patchClashConfigProvider.notifier)
          .update((_) => const PatchClashConfig(mixedPort: 7890));
      container
          .read(excludeSSIDsProvider.notifier)
          .update((_) => ['Office Wi-Fi']);
      container
          .read(po0FirewallSettingProvider.notifier)
          .update(
            (_) => const Po0FirewallProps(
              enable: true,
              tokenEntries: [Po0TokenEntry(token: 't')],
            ),
          );

      final config = container.read(configProvider);
      expect(config.currentProfileId, 99);
      expect(config.overrideDns, true);
      expect(config.patchClashConfig.mixedPort, 7890);
      expect(config.excludeSSIDs, ['Office Wi-Fi']);
      expect(config.po0FirewallProps.enable, true);
      expect(config.po0FirewallProps.tokenEntries.single.token, 't');
    });

    test('damaged po0 firewall settings fall back to defaults', () {
      final config = Config.fromJson({
        'themeProps': const ThemeProps().toJson(),
        'po0FirewallProps': {'enable': 'yes', 'tokenEntries': 7},
      });
      expect(config.po0FirewallProps, defaultPo0FirewallProps);
      final restored = Config.fromJson(
        jsonDecode(
              jsonEncode(
                config
                    .copyWith(
                      po0FirewallProps: const Po0FirewallProps(
                        enable: true,
                        tokenEntries: [
                          Po0TokenEntry(token: 'pgnfw_a', name: 'home'),
                        ],
                        pollSeconds: 5,
                      ),
                    )
                    .toJson(),
              ),
            )
            as Map<String, Object?>,
      );
      expect(restored.po0FirewallProps.tokenEntries, const [
        Po0TokenEntry(token: 'pgnfw_a', name: 'home'),
      ]);
      expect(restored.po0FirewallProps.pollSeconds, 5);
    });

    test('the old token string and minute interval migrate on load', () {
      final config = Config.fromJson({
        'themeProps': const ThemeProps().toJson(),
        'po0FirewallProps': {
          'enable': true,
          'tokens': 'pgnfw_a, pgnfw_b@0,pgnfw_a',
          'interval': 10,
        },
      });
      expect(
        config.po0FirewallProps,
        const Po0FirewallProps(
          enable: true,
          tokenEntries: [
            Po0TokenEntry(token: 'pgnfw_a'),
            Po0TokenEntry(token: 'pgnfw_b'),
          ],
        ),
      );
      final saved = config.po0FirewallProps.toJson();
      expect(saved, isNot(contains('interval')));
      expect(saved, isNot(contains('tokens')));
    });

    test('a saved token list wins over a leftover token string', () {
      final props = Po0FirewallProps.safeFromJson({
        'tokens': 'pgnfw_old',
        'tokenEntries': [
          {'token': 'pgnfw_new'},
        ],
      });
      expect(props.tokenEntries, const [Po0TokenEntry(token: 'pgnfw_new')]);
    });

    test('ggy links saved among the po0 tokens move to their own list', () {
      const link = 'https://www.guguyun.com/f/whitelist?token=ctecsfw_x';
      final props = Po0FirewallProps.safeFromJson({
        'enable': true,
        'tokenEntries': [
          {'token': 'pgnfw_a', 'name': 'home'},
          {'token': link, 'name': 'ggy'},
        ],
      });
      expect(props.tokenEntries, const [
        Po0TokenEntry(token: 'pgnfw_a', name: 'home'),
      ]);
      expect(props.ggyEntries, const [Po0TokenEntry(token: link, name: 'ggy')]);
      expect(props.enable, isTrue);

      final saved = Po0FirewallProps.safeFromJson(
        jsonDecode(jsonEncode(props.toJson())) as Map<String, Object?>,
      );
      expect(saved, props);
    });

    test('either old switch on leaves the master switch on', () {
      const link = 'https://www.guguyun.com/f/whitelist?token=ctecsfw_x';
      for (final (enable, ggyEnable) in [
        (false, false),
        (true, false),
        (false, true),
        (true, true),
      ]) {
        final props = Po0FirewallProps.safeFromJson({
          'enable': enable,
          'ggyEnable': ggyEnable,
          'tokenEntries': [
            {'token': 'pgnfw_a'},
          ],
          'ggyEntries': [
            {'token': link},
          ],
          'pollSeconds': 20,
        });
        expect(
          props.enable,
          enable || ggyEnable,
          reason: 'enable $enable, ggyEnable $ggyEnable',
        );
        expect(props.tokenEntries, const [Po0TokenEntry(token: 'pgnfw_a')]);
        expect(props.ggyEntries, const [Po0TokenEntry(token: link)]);
        expect(props.pollSeconds, 20);
      }
    });

    test('a switch turned off after the merge stays off across a save', () {
      const link = 'https://www.guguyun.com/f/whitelist?token=ctecsfw_x';
      final config = Config.fromJson({
        'themeProps': const ThemeProps().toJson(),
        'po0FirewallProps': {
          'enable': false,
          'ggyEnable': true,
          'tokenEntries': [
            {'token': 'pgnfw_a', 'name': 'home'},
          ],
          'ggyEntries': [
            {'token': link},
          ],
          'pollSeconds': 20,
        },
      });
      expect(config.po0FirewallProps.enable, true);
      final saved =
          jsonDecode(
                jsonEncode(
                  config
                      .copyWith(
                        po0FirewallProps: config.po0FirewallProps.copyWith(
                          enable: false,
                        ),
                      )
                      .toJson(),
                ),
              )
              as Map<String, Object?>;
      expect(
        (saved['po0FirewallProps'] as Map<String, Object?>).containsKey(
          'ggyEnable',
        ),
        isFalse,
      );
      final restored = Config.fromJson(saved);
      expect(restored.po0FirewallProps.enable, isFalse);
      expect(restored.po0FirewallProps.tokenEntries, const [
        Po0TokenEntry(token: 'pgnfw_a', name: 'home'),
      ]);
      expect(restored.po0FirewallProps.ggyEntries, const [
        Po0TokenEntry(token: link),
      ]);
      expect(restored.po0FirewallProps.pollSeconds, 20);
    });

    test('an existing ggy list wins over the same leftover link', () {
      const link = 'https://www.guguyun.com/f/whitelist?token=ctecsfw_x';
      final props = Po0FirewallProps.safeFromJson({
        'enable': true,
        'tokenEntries': [
          {'token': 'pgnfw_a'},
          {'token': link, 'name': 'leftover'},
        ],
        'ggyEntries': [
          {'token': link, 'name': 'kept'},
        ],
      });
      expect(props.tokenEntries, const [Po0TokenEntry(token: 'pgnfw_a')]);
      expect(props.ggyEntries, const [
        Po0TokenEntry(token: link, name: 'kept'),
      ]);
    });

    test('a non-bool switch restores the defaults', () {
      expect(
        Po0FirewallProps.safeFromJson({'enable': 'yes'}),
        defaultPo0FirewallProps,
      );
      expect(
        Po0FirewallProps.safeFromJson({'enable': false, 'ggyEnable': 1}),
        defaultPo0FirewallProps,
      );
    });

    test('a slot saved by an older version is dropped on load', () {
      final props = Po0FirewallProps.safeFromJson({
        'tokenEntries': [
          {'token': 'pgnfw_a', 'name': 'home', 'slot': 0},
        ],
      });
      expect(props.tokenEntries, const [
        Po0TokenEntry(token: 'pgnfw_a', name: 'home'),
      ]);
      expect(jsonDecode(jsonEncode(props.toJson()))['tokenEntries'], [
        {'token': 'pgnfw_a', 'name': 'home'},
      ]);
    });
  });

  group('buildConfigOverrides', () {
    test('produces correct overrides', () {
      const config = Config(
        themeProps: ThemeProps(),
        currentProfileId: 7,
        overrideDns: true,
      );
      final overrides = buildConfigOverrides(config);
      expect(overrides.length, 13);

      final overrideContainer = ProviderContainer(overrides: overrides);
      addTearDown(overrideContainer.dispose);

      expect(overrideContainer.read(currentProfileIdProvider), 7);
      expect(overrideContainer.read(overrideDnsProvider), true);
      expect(
        overrideContainer.read(patchClashConfigProvider),
        config.patchClashConfig,
      );
      expect(overrideContainer.read(excludeSSIDsProvider), config.excludeSSIDs);
      expect(
        overrideContainer.read(po0FirewallSettingProvider),
        config.po0FirewallProps,
      );
      expect(
        overrideContainer.read(appSettingProvider).onlyStatisticsProxy,
        false,
      );
    });
  });
}
