import 'package:fl_clash/common/po0_firewall.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/pages/home.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/po0_firewall.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/po0_firewall.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';

class _FakePo0Firewall extends Po0Firewall {
  _FakePo0Firewall(this.initial);

  final Po0FirewallState initial;
  var whitelists = 0;
  var queries = 0;

  @override
  Po0FirewallState build() => initial;

  @override
  Future<void> whitelist() async => whitelists++;

  @override
  Future<void> query() async => queries++;
}

const _enabled = Po0FirewallProps(
  enable: true,
  tokenEntries: [
    Po0TokenEntry(token: 'pgnfw_1a2b3c4d5e6f', name: 'Home'),
    Po0TokenEntry(token: 'pgnfw_9f8e7d6c5b4a'),
  ],
);

const _ggyLink = 'https://www.guguyun.com/f/whitelist?token=ctecsfw_x';

Po0FirewallProps _setting() =>
    globalState.container.read(po0FirewallSettingProvider);

final _results = [
  const Po0TokenResult(
    label: 'pgnfw_1a2b3c…',
    type: Po0ResultType.applied,
    currentIp: '45.82.120.0/24',
    limit: 5,
    whitelist: [
      Po0WhitelistEntry(ip: '45.82.120.0/24'),
      Po0WhitelistEntry(ip: '1.2.3.0/24', slot: 0),
    ],
  ),
  const Po0TokenResult(
    label: 'pgnfw_9f8e7d…',
    type: Po0ResultType.error,
    message: 'timeout',
  ),
];

Future<_FakePo0Firewall> _pump(
  WidgetTester tester, {
  required Po0FirewallProps props,
  Po0FirewallState state = const Po0FirewallState(),
  bool settle = true,
}) async {
  const size = Size(1200, 1000);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final fake = _FakePo0Firewall(state);
  final container = ProviderContainer(
    overrides: [
      po0FirewallSettingProvider.overrideWithBuild((_, _) => props),
      po0FirewallProvider.overrideWith(() => fake),
    ],
  );
  addTearDown(container.dispose);
  globalState.container = container;
  container.read(viewSizeProvider.notifier).update((_) => size);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const TestApp(child: Po0FirewallView()),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 500));
  }
  return fake;
}

FilledButton _filled(WidgetTester tester, String label) =>
    tester.widget<FilledButton>(
      find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate((widget) => widget is FilledButton),
      ),
    );

void main() {
  testWidgets('a disabled whitelist says so and blocks the actions', (
    tester,
  ) async {
    await _pump(tester, props: _enabled.copyWith(enable: false));

    expect(find.text('Auto whitelist is off'), findsOneWidget);
    expect(_filled(tester, 'Whitelist now').onPressed, isNull);
    expect(find.text('Auto whitelist'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });

  testWidgets('asks for a token before it can run', (tester) async {
    await _pump(tester, props: const Po0FirewallProps(enable: true));
    expect(find.text('Add a token to start'), findsOneWidget);
    expect(find.text('Not configured'), findsOneWidget);
  });

  testWidgets('summarises the run and renders one card per token', (
    tester,
  ) async {
    final fake = await _pump(
      tester,
      props: _enabled,
      state: Po0FirewallState(lastRunAt: DateTime.now(), results: _results),
    );

    expect(find.text('1/2 whitelisted'), findsOneWidget);
    expect(find.text('Every 5 s'), findsOneWidget);
    expect(find.text('pgnfw_1a2b3c…'), findsNWidgets(2));
    expect(find.text('Whitelisted'), findsOneWidget);
    expect(find.text('Failed'), findsOneWidget);
    expect(find.byIcon(Icons.push_pin_rounded), findsOneWidget);
    expect(find.text('2/5 used'), findsOneWidget);
    expect(find.text('45.82.120.0/24'), findsNWidgets(2));
    expect(find.byIcon(Icons.my_location_rounded), findsNWidgets(2));
    expect(find.text('Request failed: timeout'), findsOneWidget);

    await tester.tap(find.text('Whitelist now'));
    await tester.tap(find.text('Check status'));
    expect(fake.whitelists, 1);
    expect(fake.queries, 1);
  });

  testWidgets('lists the tokens with their names', (tester) async {
    await _pump(tester, props: _enabled);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('pgnfw_1a2b3c…'), findsOneWidget);
    expect(find.text('pgnfw_9f8e7d…'), findsOneWidget);
    expect(find.text('5 seconds'), findsOneWidget);
  });

  testWidgets('adds a token with a name', (tester) async {
    await _pump(tester, props: const Po0FirewallProps(enable: true));
    await tester.tap(find.text('Add token'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.at(0), ' pgnfw_new ');
    await tester.enterText(fields.at(1), 'Office');
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(_setting().tokenEntries, const [
      Po0TokenEntry(token: 'pgnfw_new', name: 'Office'),
    ]);
    expect(find.text('Office'), findsOneWidget);
  });

  testWidgets('adds a ggy link picked from the type menu', (tester) async {
    await _pump(tester, props: const Po0FirewallProps(enable: true));
    await tester.tap(find.text('Add token'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<Po0TokenKind>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ggy whitelist link').last);
    await tester.pumpAndSettle();

    final link = find.byType(TextFormField).first;
    await tester.enterText(link, 'pgnfw_new');
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Paste the full whitelist link'),
      findsOneWidget,
    );

    await tester.enterText(link, _ggyLink);
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    expect(_setting().tokenEntries, const [Po0TokenEntry(token: _ggyLink)]);
    expect(find.byIcon(Icons.link_rounded), findsOneWidget);
  });

  testWidgets('rejects malformed and duplicate tokens', (tester) async {
    await _pump(tester, props: _enabled);
    await tester.tap(find.text('Add token'));
    await tester.pumpAndSettle();

    final token = find.byType(TextFormField).first;
    await tester.enterText(token, 'pgnfw_a,pgnfw_b');
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    expect(
      find.text('A token starts with pgnfw_ and has no spaces or separators'),
      findsOneWidget,
    );

    await tester.enterText(token, 'pgnfw_9f8e7d6c5b4a');
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    expect(find.text('This token is already in the list'), findsOneWidget);
    expect(_setting().tokenEntries, _enabled.tokenEntries);
  });

  testWidgets('edits and deletes a token', (tester) async {
    await _pump(tester, props: _enabled);
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(1), 'Lab');
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    expect(_setting().tokenEntries.first.name, 'Lab');

    await tester.tap(find.byTooltip('Delete').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(_setting().tokenEntries, [_enabled.tokenEntries.last]);
  });

  testWidgets('the refresh interval accepts 1 to 3600 seconds', (tester) async {
    await _pump(tester, props: _enabled);
    await tester.tap(find.text('Refresh interval'));
    await tester.pumpAndSettle();

    final field = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(field, '0');
    await tester.pumpAndSettle();
    expect(find.text('Enter 1–3600 seconds'), findsOneWidget);

    await tester.enterText(field, '15');
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    expect(_setting().pollSeconds, 15);
    expect(find.text('15 seconds'), findsOneWidget);
  });

  testWidgets('every token applied reads as whitelisted', (tester) async {
    await _pump(
      tester,
      props: _enabled,
      state: Po0FirewallState(
        lastRunAt: DateTime.now(),
        results: [_results.first],
      ),
    );
    expect(find.text('Exit whitelisted'), findsOneWidget);
    expect(find.byIcon(Icons.verified_user_rounded), findsOneWidget);
  });

  testWidgets('shows progress while a run is in flight', (tester) async {
    await _pump(
      tester,
      props: _enabled,
      state: const Po0FirewallState(isRunning: true),
      settle: false,
    );
    expect(find.text('Running…'), findsOneWidget);
    expect(_filled(tester, 'Whitelist now').onPressed, isNull);
  });

  testWidgets('every block is a glass surface', (tester) async {
    await _pump(tester, props: _enabled);
    expect(find.byType(GlassSurface), findsWidgets);
    expect(find.byType(SurfaceCard), findsNothing);
    final auto = find.ancestor(
      of: find.text('Auto whitelist'),
      matching: find.byType(GlassButton),
    );
    await tester.tap(auto);
    await tester.pumpAndSettle();
    expect(_setting().enable, isFalse);
  });

  testWidgets('generateSection keeps full-width rows', (tester) async {
    await tester.pumpWidget(
      TestApp(
        child: Scaffold(
          body: ListView(
            children: generateSection(
              title: 'Group',
              items: const [
                ListTile(title: Text('one')),
                ListTile(title: Text('two')),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.byType(GlassSurface), findsOneWidget);
    expect(find.byType(Divider), findsOneWidget);
    expect(find.text('Group'), findsOneWidget);
  });

  group('PageEntrance', () {
    double opacity(WidgetTester tester) => tester
        .widget<FadeTransition>(find.byType(FadeTransition))
        .opacity
        .value;

    double scale(WidgetTester tester) => tester
        .widget<ScaleTransition>(find.byType(ScaleTransition))
        .scale
        .value;

    Widget entrance({required bool active, required bool enabled}) =>
        Directionality(
          textDirection: TextDirection.ltr,
          child: PageEntrance(
            active: active,
            enabled: enabled,
            child: const SizedBox(),
          ),
        );

    testWidgets('fades and grows a page in when it becomes current', (
      tester,
    ) async {
      await tester.pumpWidget(entrance(active: false, enabled: true));
      expect(opacity(tester), 1);

      await tester.pumpWidget(entrance(active: true, enabled: true));
      await tester.pump(PageEntrance.duration ~/ 4);
      expect(opacity(tester), inExclusiveRange(0, 1));
      expect(scale(tester), inExclusiveRange(0.97, 1));
      await tester.pumpAndSettle();
      expect(opacity(tester), 1);
      expect(scale(tester), 1);
    });

    testWidgets('stays still when disabled', (tester) async {
      await tester.pumpWidget(entrance(active: false, enabled: false));
      await tester.pumpWidget(entrance(active: true, enabled: false));
      await tester.pump(PageEntrance.duration ~/ 4);
      expect(opacity(tester), 1);
    });
  });
}
