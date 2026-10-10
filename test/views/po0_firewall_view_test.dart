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

const _ggyLink = 'https://www.guguyun.com/f/whitelist?token=ctecsfw_x';
const _ggyToken = Po0Token(_ggyLink);

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

class _FakeGgyFirewall extends GgyFirewall {
  _FakeGgyFirewall(this.initial);

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

const _mixed = Po0FirewallProps(
  enable: true,
  tokenEntries: [
    Po0TokenEntry(token: 'pgnfw_1a2b3c4d5e6f', name: 'Home'),
    Po0TokenEntry(token: 'pgnfw_9f8e7d6c5b4a'),
  ],
  ggyEntries: [Po0TokenEntry(token: _ggyLink, name: 'ggy')],
);

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
    tokenValue: 'pgnfw_1a2b3c4d5e6f',
  ),
  const Po0TokenResult(
    label: 'pgnfw_9f8e7d…',
    type: Po0ResultType.error,
    message: 'timeout',
    tokenValue: 'pgnfw_9f8e7d6c5b4a',
  ),
];

const _po0Only = Po0FirewallProps(
  enable: true,
  tokenEntries: [
    Po0TokenEntry(token: 'pgnfw_1a2b3c4d5e6f', name: 'Home'),
    Po0TokenEntry(token: 'pgnfw_9f8e7d6c5b4a'),
  ],
);

Future<({_FakePo0Firewall po0, _FakeGgyFirewall ggy})> _pump(
  WidgetTester tester, {
  required Po0FirewallProps props,
  Po0FirewallState po0State = const Po0FirewallState(),
  Po0FirewallState ggyState = const Po0FirewallState(),
  bool settle = true,
  double width = 1200,
}) async {
  final size = Size(width, 1000);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final po0 = _FakePo0Firewall(po0State);
  final ggy = _FakeGgyFirewall(ggyState);
  final container = ProviderContainer(
    overrides: [
      po0FirewallSettingProvider.overrideWithBuild((_, _) => props),
      po0FirewallProvider.overrideWith(() => po0),
      ggyFirewallProvider.overrideWith(() => ggy),
    ],
  );
  addTearDown(container.dispose);
  globalState.container = container;
  container.read(viewSizeProvider.notifier).update((_) => size);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const TestApp(child: WhitelistView()),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 500));
  }
  return (po0: po0, ggy: ggy);
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
    await _pump(tester, props: _mixed.copyWith(enable: false));

    expect(find.text('Auto whitelist is off'), findsOneWidget);
    expect(_filled(tester, 'Whitelist now').onPressed, isNull);
    expect(find.text('Auto whitelist'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });

  testWidgets('asks for a token or link before it can run', (tester) async {
    await _pump(tester, props: const Po0FirewallProps(enable: true));
    // The overview title and the empty list card share the prompt.
    expect(find.text('Add a token or link to start'), findsNWidgets(2));
    expect(
      find.text(
        'Add a po0 token or a full ggy whitelist link; each '
        'entry runs separately',
      ),
      findsOneWidget,
    );
  });

  testWidgets('summarises the run and renders one card per result', (
    tester,
  ) async {
    final fakes = await _pump(
      tester,
      props: _po0Only,
      po0State: Po0FirewallState(lastRunAt: DateTime.now(), results: _results),
    );

    expect(find.text('1/2 whitelisted'), findsOneWidget);
    expect(find.text('po0 check interval'), findsOneWidget);
    expect(find.text('Home'), findsNWidgets(2));
    expect(find.text('po0 token · pgnfw_1a2b3c…'), findsOneWidget);
    expect(find.text('pgnfw_9f8e7d…'), findsNWidgets(2));
    expect(find.text('Whitelisted'), findsOneWidget);
    expect(find.text('Failed'), findsOneWidget);
    expect(find.byIcon(Icons.push_pin_rounded), findsOneWidget);
    expect(find.text('2/5 used'), findsOneWidget);
    expect(find.text('45.82.120.0/24'), findsNWidgets(2));
    expect(find.byIcon(Icons.my_location_rounded), findsNWidgets(2));
    expect(find.text('Request failed: timeout'), findsOneWidget);

    await tester.tap(find.text('Whitelist now'));
    await tester.tap(find.text('Query po0 status'));
    expect(fakes.po0.whitelists, 1);
    expect(fakes.po0.queries, 1);
    expect(fakes.ggy.whitelists, 0, reason: 'no ggy entry, no ggy call');
  });

  testWidgets('shows progress while a run is in flight', (tester) async {
    await _pump(
      tester,
      props: _mixed,
      po0State: const Po0FirewallState(isRunning: true),
      settle: false,
    );
    expect(find.text('Running…'), findsOneWidget);
    expect(_filled(tester, 'Whitelist now').onPressed, isNull);
    expect(find.text('Query po0 status'), findsOneWidget);
  });

  testWidgets('the mixed list marks each entry with its service', (
    tester,
  ) async {
    await _pump(tester, props: _mixed);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('ggy'), findsOneWidget);
    expect(find.text('po0 token · pgnfw_1a2b3c…'), findsOneWidget);
    expect(find.text('ggy link · ctecsfw_x…'), findsOneWidget);
    expect(find.text('po0 check interval'), findsOneWidget);
    expect(find.text('ggy whitelists every 11 seconds'), findsOneWidget);
  });

  testWidgets('adds a po0 token with a name', (tester) async {
    await _pump(tester, props: const Po0FirewallProps(enable: true));
    await tester.tap(find.text('Add token'));
    await tester.pumpAndSettle();

    expect(find.byType(GlassSegmented<Po0TokenKind>), findsOneWidget);
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

  testWidgets('the dialog switches between the two kinds and validates each', (
    tester,
  ) async {
    await _pump(tester, props: const Po0FirewallProps(enable: true));
    await tester.tap(find.text('Add token'));
    await tester.pumpAndSettle();
    final field = find.byType(TextFormField).first;

    await tester.tap(find.text('ggy link'));
    await tester.pumpAndSettle();
    await tester.enterText(field, 'pgnfw_new');
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Paste the full whitelist link from ggy '
        '(https://www.guguyun.com/…?token=…)',
      ),
      findsOneWidget,
    );

    await tester.enterText(field, _ggyLink);
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    expect(_setting().ggyEntries, const [Po0TokenEntry(token: _ggyLink)]);
    expect(_setting().tokenEntries, isEmpty);
  });

  testWidgets('keeps the typed value while switching kinds', (tester) async {
    await _pump(tester, props: const Po0FirewallProps(enable: true));
    await tester.tap(find.text('Add token'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'pgnfw_new');
    await tester.tap(find.text('ggy link'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'pgnfw_new'), findsOneWidget);
  });

  testWidgets('rejects malformed and duplicate tokens', (tester) async {
    await _pump(tester, props: _po0Only);
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
    expect(_setting().tokenEntries, _po0Only.tokenEntries);
  });

  testWidgets('edits keep the kind fixed and update the name', (tester) async {
    await _pump(tester, props: _mixed);
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    expect(find.text('Type'), findsOneWidget);
    expect(find.byType(GlassSegmented<Po0TokenKind>), findsNothing);
    await tester.enterText(find.byType(TextFormField).at(1), 'Lab');
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    expect(_setting().tokenEntries.first.name, 'Lab');
    expect(_setting().ggyEntries, _mixed.ggyEntries);
  });

  for (final kind in Po0TokenKind.values) {
    final isGgy = kind == Po0TokenKind.ggy;
    testWidgets('rejects a ${kind.name} duplicate restored during an edit', (
      tester,
    ) async {
      await _pump(tester, props: _mixed);
      await tester.tap(find.byTooltip('Edit').at(isGgy ? 2 : 0));
      await tester.pumpAndSettle();

      final duplicate = Po0TokenEntry(
        token: isGgy
            ? 'https://www.guguyun.com/f/whitelist?token=ctecsfw_restored'
            : 'pgnfw_restored',
        name: 'Restored',
      );
      globalState.container
          .read(po0FirewallSettingProvider.notifier)
          .update(
            (state) => isGgy
                ? state.copyWith(ggyEntries: [...state.ggyEntries, duplicate])
                : state.copyWith(
                    tokenEntries: [...state.tokenEntries, duplicate],
                  ),
          );
      await tester.pump();
      final restored = _setting();
      await tester.enterText(find.byType(TextFormField).first, duplicate.token);
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          isGgy
              ? 'This link is already in the list'
              : 'This token is already in the list',
        ),
        findsOneWidget,
      );
      expect(_setting(), restored);
      expect(find.byType(TextFormField), findsNWidgets(2));
    });

    for (final name in ['Renamed', '']) {
      testWidgets(
        '${kind.name} result titles use ${name.isEmpty ? 'cleared' : 'renamed'} '
        'remarks without a request',
        (tester) async {
          final previousName = 'Original ${kind.name}';
          final props = isGgy
              ? _mixed.copyWith(
                  ggyEntries: [
                    _mixed.ggyEntries.single.copyWith(name: previousName),
                  ],
                )
              : _mixed.copyWith(
                  tokenEntries: [
                    _mixed.tokenEntries.first.copyWith(name: previousName),
                    _mixed.tokenEntries.last,
                  ],
                );
          final result = isGgy
              ? Po0TokenResult(
                  label: _ggyToken.label,
                  name: previousName,
                  type: Po0ResultType.applied,
                  tokenValue: _ggyLink,
                )
              : _results.first.copyWith(name: previousName);
          final fakes = await _pump(
            tester,
            props: props,
            po0State: Po0FirewallState(results: isGgy ? [] : [result]),
            ggyState: Po0FirewallState(results: isGgy ? [result] : []),
          );
          expect(find.text(previousName), findsNWidgets(2));
          await tester.tap(find.byTooltip('Edit').at(isGgy ? 2 : 0));
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextFormField).at(1), name);
          await tester.tap(find.text('Submit'));
          await tester.pumpAndSettle();

          final title = name.isEmpty
              ? Po0Token(result.tokenValue!).label
              : name;
          expect(find.text(title), findsNWidgets(2));
          expect(find.text(previousName), findsNothing);
          expect(fakes.po0.whitelists, 0);
          expect(fakes.po0.queries, 0);
          expect(fakes.ggy.whitelists, 0);
          expect(fakes.ggy.queries, 0);
        },
      );
    }
  }

  testWidgets('deleting a ggy entry leaves the po0 list alone', (tester) async {
    await _pump(tester, props: _mixed);
    await tester.tap(find.byTooltip('Delete').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(_setting().ggyEntries, isEmpty);
    expect(_setting().tokenEntries, _mixed.tokenEntries);
  });

  testWidgets('a ggy only page has no query button and no interval setting', (
    tester,
  ) async {
    final fakes = await _pump(
      tester,
      props: const Po0FirewallProps(
        enable: true,
        ggyEntries: [Po0TokenEntry(token: _ggyLink)],
      ),
    );
    expect(find.text('Query po0 status'), findsNothing);
    expect(find.text('po0 check interval'), findsNothing);
    expect(find.text('ggy whitelists every 11 seconds'), findsOneWidget);
    expect(_filled(tester, 'Whitelist now').onPressed, isNotNull);

    await tester.tap(find.text('Whitelist now'));
    expect(fakes.ggy.whitelists, 1);
    expect(fakes.po0.whitelists, 0);
    expect(fakes.po0.queries, 0);
  });

  testWidgets('every entry applied reads as whitelisted', (tester) async {
    await _pump(
      tester,
      props: _po0Only.copyWith(
        tokenEntries: const [
          Po0TokenEntry(token: 'pgnfw_1a2b3c4d5e6f', name: 'Home'),
        ],
      ),
      po0State: Po0FirewallState(
        lastRunAt: DateTime.now(),
        results: [_results.first],
      ),
    );
    expect(find.text('Exit whitelisted'), findsOneWidget);
    expect(find.byIcon(Icons.verified_user_rounded), findsOneWidget);
  });

  testWidgets('stale results of deleted tokens are not rendered', (
    tester,
  ) async {
    await _pump(
      tester,
      props: _po0Only.copyWith(
        tokenEntries: const [
          Po0TokenEntry(token: 'pgnfw_1a2b3c4d5e6f', name: 'Home'),
          Po0TokenEntry(token: 'pgnfw_replaced'),
        ],
      ),
      po0State: Po0FirewallState(lastRunAt: DateTime.now(), results: _results),
    );
    expect(find.text('1/2 whitelisted'), findsOneWidget);
    expect(find.text('Failed'), findsNothing, reason: 'its token is gone');
  });

  testWidgets('the interval accepts 1 to 3600 seconds', (tester) async {
    await _pump(tester, props: _po0Only);
    await tester.tap(find.text('po0 check interval'));
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

  testWidgets('every block is a glass surface and the switch writes enable', (
    tester,
  ) async {
    await _pump(tester, props: _po0Only);
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

  testWidgets('lays out narrow without overflowing', (tester) async {
    await _pump(tester, props: _mixed, width: 380, settle: false);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('lays out wide without overflowing', (tester) async {
    await _pump(tester, props: _mixed, width: 820, settle: false);
    await tester.pump();
    expect(tester.takeException(), isNull);
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
