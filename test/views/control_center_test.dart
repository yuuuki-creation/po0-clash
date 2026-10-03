import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/control/control_center.dart';
import 'package:fl_clash/views/control/tiles.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

class _Detected extends NetworkDetection {
  @override
  NetworkDetectionState build() => const NetworkDetectionState(
    isLoading: false,
    ipInfo: IpInfo(ip: '154.17.22.108', countryCode: 'HK'),
  );
}

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(TestProfiles.new),
        networkDetectionProvider.overrideWith(_Detected.new),
      ],
    );
    globalState.container = container;
    container.listen(networkSettingProvider, (_, _) {});
    container.listen(patchClashConfigProvider, (_, _) {});
    container
        .read(viewSizeProvider.notifier)
        .update((_) => const Size(1000, 900));
  });

  tearDown(() => container.dispose());

  ({bool tun, bool systemProxy}) route() => (
    tun: container.read(patchClashConfigProvider).tun.enable,
    systemProxy: container.read(networkSettingProvider).systemProxy,
  );

  Future<void> pump(WidgetTester tester, Widget child, {double width = 700}) {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    return tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          child: Scaffold(
            body: Center(
              child: SizedBox(width: width, child: child),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('TUN and the system proxy exclude each other', (tester) async {
    await pump(tester, const QuickToggles());

    await tester.tap(find.text('System proxy'));
    await tester.pump();
    expect(route(), (tun: false, systemProxy: true));

    await tester.tap(find.text('TUN'));
    await tester.pump();
    expect(route(), (tun: true, systemProxy: false));

    await tester.tap(find.text('TUN'));
    await tester.pump();
    expect(route(), (tun: true, systemProxy: false), reason: 'never both off');
  });

  testWidgets('the exit IP sits beside the switches and rechecks on tap', (
    tester,
  ) async {
    await pump(tester, const QuickToggles());
    final ip = find.text('154.17.22.108');
    expect(ip, findsOneWidget);
    expect(
      tester.getCenter(ip).dx,
      greaterThan(tester.getCenter(find.text('System proxy')).dx),
    );

    final before = container.read(checkIpNumProvider);
    await tester.tap(ip);
    await tester.pump();
    expect(container.read(checkIpNumProvider), before + 1);
  });

  testWidgets('narrow rows drop the option buttons but keep the labels', (
    tester,
  ) async {
    await pump(tester, const QuickToggles());
    expect(find.byType(GlassIconButton), findsNWidgets(2));

    await pump(tester, const QuickToggles(), width: 360);
    expect(find.byType(GlassIconButton), findsNothing);
    expect(find.text('TUN'), findsOneWidget);

    await tester.longPress(find.text('TUN'));
    await tester.pumpAndSettle();
    expect(find.byType(AdaptiveSheetScaffold), findsOneWidget);
  });

  testWidgets('the sidebar route switch drives the same rule', (tester) async {
    await pump(tester, const DesktopRouteSwitch());
    await tester.tap(find.text('System proxy'));
    await tester.pumpAndSettle();
    expect(route(), (tun: false, systemProxy: true));
    await tester.tap(find.text('TUN'));
    await tester.pumpAndSettle();
    expect(route(), (tun: true, systemProxy: false));
  });

  test('the whitelist card shows what has entries, else po0', () {
    expect(whitelistPagesOf(po0: false, ggy: false), [PageLabel.po0]);
    expect(whitelistPagesOf(po0: true, ggy: false), [PageLabel.po0]);
    expect(whitelistPagesOf(po0: false, ggy: true), [PageLabel.ggy]);
    expect(whitelistPagesOf(po0: true, ggy: true), [
      PageLabel.po0,
      PageLabel.ggy,
    ]);
  });

  testWidgets('the whitelist card takes turns only while both have entries', (
    tester,
  ) async {
    void setEntries({required bool po0}) => container
        .read(po0FirewallSettingProvider.notifier)
        .update(
          (state) => state.copyWith(
            tokenEntries: [if (po0) const Po0TokenEntry(token: 'pgnfw_a')],
            ggyEntries: const [
              Po0TokenEntry(
                token: 'https://www.guguyun.com/f/whitelist?token=ctecsfw_x',
              ),
            ],
          ),
        );

    setEntries(po0: true);
    await pump(tester, const WhitelistStatusCard());
    expect(find.text('po0', findRichText: true), findsOneWidget);
    await tester.pump(WhitelistStatusCard.rotation);
    await tester.pumpAndSettle();
    expect(find.text('ggy', findRichText: true), findsOneWidget);
    expect(find.text('po0', findRichText: true), findsNothing);

    await tester.tap(find.byType(WhitelistStatusCard));
    expect(container.read(currentPageLabelProvider), PageLabel.ggy);

    setEntries(po0: false);
    await tester.pump(WhitelistStatusCard.rotation * 2);
    await tester.pumpAndSettle();
    expect(find.text('ggy', findRichText: true), findsOneWidget);
    expect(find.text('po0', findRichText: true), findsNothing);
  });

  testWidgets('the control center lays out narrow and wide', (tester) async {
    for (final width in [380.0, 820.0]) {
      await pump(tester, const ControlCenterView(), width: width);
      await tester.pump();
      expect(find.byType(QuickToggles), findsOneWidget);
      expect(find.text('Add profile'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'width $width');
    }
  });
}
