import 'dart:async';
import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

typedef _Call = ({String method, Uri uri});

class _FakeApi {
  final List<Object> responses;
  final calls = <_Call>[];

  _FakeApi(this.responses);

  Future<Po0HttpResponse> send(String method, Uri uri) async {
    calls.add((method: method, uri: uri));
    final next = responses.length > 1 ? responses.removeAt(0) : responses[0];
    if (next is Po0HttpResponse) {
      return next;
    }
    throw next as Exception;
  }
}

Po0HttpResponse _ok({
  String currentIp = '45.82.120.0/24',
  List<Object> whitelist = const [
    {'ip': '45.82.120.0/24', 'slot': null},
    {'ip': '1.2.3.0/24', 'slot': 0},
  ],
  bool enabled = true,
}) {
  return Po0HttpResponse(
    200,
    '{"enabled":$enabled,"whitelist":${_encode(whitelist)},'
    '"limit":5,"currentIp":"${currentIp.replaceAll('/', r'\/')}"}',
  );
}

String _encode(List<Object> whitelist) {
  final items = whitelist.map((item) {
    if (item is Map) {
      return '{"ip":"${item['ip']}","slot":${item['slot']}}';
    }
    return '"$item"';
  });
  return '[${items.join(',')}]';
}

Po0FirewallClient _client(_FakeApi api) =>
    Po0FirewallClient(send: api.send, retryDelay: Duration.zero);

const _token = Po0Token('pgnfw_secret_token_value');

const _ggyLink = Po0Token(
  'https://www.guguyun.com/f/whitelist?token=ctecsfw_abcdefghijkl',
);

const Po0DirectEndpoint _endpoint = (port: 40123, username: 'u', password: 'p');

const _listener = {
  'name': 'po0-direct',
  'type': 'http',
  'listen': '127.0.0.1',
  'port': 40123,
  'users': [
    {'username': 'u', 'password': 'p'},
  ],
  'proxy': 'DIRECT',
};

Po0HttpResponse _ggy({String removed = ''}) {
  return Po0HttpResponse(
    200,
    '{"status":200,"msg":"ok","data":{"cidr":"202.120.8.0\\/24",'
    '"mode":"fifo","slot":null,"removed_cidr":"$removed"}}',
  );
}

void main() {
  group('parsePo0Tokens', () {
    test('splits on the separators and drops legacy slot suffixes', () {
      expect(parsePo0Tokens(' pgnfw_a, pgnfw_b@0|pgnfw_c;pgnfw_d、pgnfw_e\n'), [
        const Po0Token('pgnfw_a'),
        const Po0Token('pgnfw_b'),
        const Po0Token('pgnfw_c'),
        const Po0Token('pgnfw_d'),
        const Po0Token('pgnfw_e'),
      ]);
    });

    test('ignores placeholders and duplicates', () {
      expect(parsePo0Tokens('填入token,pgnfw_a@x,pgnfw_a@1,,'), [
        const Po0Token('pgnfw_a'),
      ]);
      expect(parsePo0Tokens(''), isEmpty);
    });

    test('labels never expose the whole token', () {
      expect(_token.label, 'pgnfw_secret…');
      expect(const Po0Token('pgnfw_').label, 'pgnfw_…');
    });
  });

  group('token entries', () {
    test('a token is one pgnfw_ value without separators', () {
      expect(isPo0Token('pgnfw_abc123'), isTrue);
      for (final value in ['', 'pgnfw_', 'abc', 'pgnfw_a b', 'pgnfw_a,b']) {
        expect(isPo0Token(value), isFalse, reason: value);
      }
      expect(isPo0Token('pgnfw_a@0'), isFalse);
    });

    test('skip invalid and repeated tokens, keeping the first', () {
      final tokens = po0TokensOf(const [
        Po0TokenEntry(token: 'pgnfw_a', name: 'first'),
        Po0TokenEntry(token: 'bogus'),
        Po0TokenEntry(token: 'pgnfw_a', name: 'second'),
        Po0TokenEntry(token: 'pgnfw_b'),
      ]);
      expect(tokens.map((it) => it.token), const [
        Po0Token('pgnfw_a'),
        Po0Token('pgnfw_b'),
      ]);
      expect(tokens.map((it) => it.name), ['first', '']);
    });

    test('a ggy entry is a whole https link, labelled by its token', () {
      expect(isGgyLink(_ggyLink.value), isTrue);
      expect(_ggyLink.kind, Po0TokenKind.ggy);
      expect(_ggyLink.label, 'ctecsfw_abcd…');
      expect(_token.kind, Po0TokenKind.po0);
      for (final value in [
        'http://www.guguyun.com/f/whitelist?token=ctecsfw_a',
        'https://www.example.com/f/whitelist?token=ctecsfw_a',
        'https://evilguguyun.com/f/whitelist?token=ctecsfw_a',
        'https://www.guguyun.com/f/whitelist',
        'https://www.guguyun.com/f/whitelist?token=',
        'https://www.guguyun.com/f/whitelist?token=a b',
        'ctecsfw_abc',
      ]) {
        expect(isGgyLink(value), isFalse, reason: value);
      }
    });

    test('po0 tokens and ggy links are read from their own lists', () {
      final entries = [
        const Po0TokenEntry(token: 'pgnfw_a'),
        Po0TokenEntry(token: _ggyLink.value),
      ];
      expect(po0TokensOf(entries).map((it) => it.token), [
        const Po0Token('pgnfw_a'),
      ]);
      expect(ggyLinksOf(entries).map((it) => it.token), [_ggyLink]);
    });
  });

  group('direct listener', () {
    test('is added once, replacing a stale copy and keeping others', () {
      final raw = <String, dynamic>{
        'mixed-port': 7890,
        'listeners': [
          {'name': 'mine', 'type': 'socks', 'port': 10808},
          {'name': 'po0-direct', 'type': 'http', 'port': 1},
        ],
      };
      final config = withPo0DirectListener(raw, _endpoint);
      expect(config['mixed-port'], 7890);
      expect(config['listeners'], [
        {'name': 'mine', 'type': 'socks', 'port': 10808},
        _listener,
      ]);
      expect(withPo0DirectListener({}, _endpoint)['listeners'], [_listener]);
    });

    test('requests reach it with its own credentials', () {
      expect(po0ListenerRoute(_endpoint), 'PROXY u:p@127.0.0.1:40123');
    });

    test('only po0 falls back to a plain socket', () {
      const route = 'PROXY u:p@127.0.0.1:40123';
      final po0 = Uri.parse('https://124.221.69.228/api/firewall/pgnfw_a');
      expect(po0FindProxy(po0, route), '$route; DIRECT');
      expect(po0FindProxy(Uri.parse(_ggyLink.value), route), route);
      expect(po0FindProxy(po0, 'DIRECT'), 'DIRECT');
    });

    test('opens one free loopback port for the whole session', () async {
      final listener = Po0DirectListener();
      final endpoints = await Future.wait([
        listener.endpoint,
        listener.endpoint,
      ]);
      expect(endpoints.first, endpoints.last);
      expect(await listener.endpoint, endpoints.first);
      expect(endpoints.first.password, isNot(endpoints.first.username));

      final port = endpoints.first.port;
      final socket = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        port,
      );
      await socket.close();
    });
  });

  group('sameC24', () {
    test('matches exact addresses and /24 networks either way round', () {
      expect(sameC24('1.2.3.4', '1.2.3.4'), isTrue);
      expect(sameC24('1.2.3.0/24', '1.2.3.99'), isTrue);
      expect(sameC24('1.2.3.99', '1.2.3.0/24'), isTrue);
      expect(sameC24('1.2.3.4', '1.2.3.5'), isFalse);
      expect(sameC24('1.2.4.0/24', '1.2.3.0/24'), isFalse);
      expect(sameC24(null, '1.2.3.4'), isFalse);
      expect(sameC24('', ''), isFalse);
    });
  });

  group('excludeIpv4Route', () {
    test('carves a single address out of the default route', () {
      final routes = excludeIpv4Route(['0.0.0.0/0'], po0FirewallDirectCidr);
      expect(routes, hasLength(32));
      expect(routes, contains('128.0.0.0/1'));
      expect(routes, contains('124.221.69.229/32'));
      expect(routes, isNot(contains('124.221.69.228/32')));
      final covered = routes
          .map((route) => int.parse(route.split('/')[1]))
          .fold<double>(0, (sum, prefix) => sum + 1 / (1 << prefix));
      expect(covered, closeTo(1 - 1 / (1 << 32), 1e-12));
    });

    test('keeps unrelated and IPv6 routes, drops covered ones', () {
      expect(
        excludeIpv4Route([
          '10.0.0.0/8',
          '::/0',
          'bogus',
          '124.221.69.228/32',
        ], po0FirewallDirectCidr),
        ['10.0.0.0/8', '::/0', 'bogus'],
      );
    });

    test('splits a bypass-private block that covers the address', () {
      final routes = excludeIpv4Route(
        defaultBypassPrivateRouteAddress,
        po0FirewallDirectCidr,
      );
      expect(routes, isNot(contains('124.0.0.0/7')));
      expect(routes, contains('125.0.0.0/8'));
      expect(routes, contains('126.0.0.0/8'));
      expect(routes.length, defaultBypassPrivateRouteAddress.length + 24);
    });
  });

  group('Po0FirewallClient', () {
    test('whitelists through the add endpoint', () async {
      final api = _FakeApi([_ok()]);
      final result = await _client(api).whitelist(const Po0Token('pgnfw_a'));

      expect(api.calls.single.method, 'POST');
      expect(
        api.calls.single.uri.toString(),
        'https://124.221.69.228/api/firewall/pgnfw_a/add',
      );
      expect(result.type, Po0ResultType.applied);
      expect(result.currentIp, '45.82.120.0/24');
      expect(result.limit, 5);
      expect(result.whitelist, [
        const Po0WhitelistEntry(ip: '45.82.120.0/24'),
        const Po0WhitelistEntry(ip: '1.2.3.0/24', slot: 0),
      ]);
    });

    test('queries read-only without touching the add endpoint', () async {
      final api = _FakeApi([
        _ok(currentIp: '9.9.9.9', whitelist: ['1.2.3.4']),
      ]);
      final result = await _client(api).query(_token);

      expect(api.calls.single.method, 'GET');
      expect(api.calls.single.uri.path, '/api/firewall/${_token.value}');
      expect(result.type, Po0ResultType.notApplied);
      expect(result.whitelist.single.ip, '1.2.3.4');
    });

    test('reports a disabled firewall', () async {
      final result = await _client(
        _FakeApi([_ok(enabled: false)]),
      ).whitelist(_token);
      expect(result.type, Po0ResultType.disabled);
    });

    test('a 403 is final and reports its message', () async {
      final api = _FakeApi([
        const Po0HttpResponse(403, '{"currentIp":"1.1.1.1","message":"no"}'),
      ]);
      final result = await _client(api).whitelist(_token);
      expect(result.type, Po0ResultType.rejected);
      expect(result.message, 'no');
      expect(result.currentIp, '1.1.1.1');
      expect(api.calls, hasLength(1));
    });

    test('a JSON error body is final', () async {
      final api = _FakeApi([
        const Po0HttpResponse(400, '{"code":400,"message":"invalid token"}'),
      ]);
      final result = await _client(api).whitelist(_token);
      expect(result.type, Po0ResultType.rejected);
      expect(result.message, 'invalid token');
      expect(api.calls, hasLength(1));
    });

    test('retries transient failures before succeeding', () async {
      final api = _FakeApi([
        const SocketException('reset'),
        const Po0HttpResponse(400, 'Error'),
        _ok(),
      ]);
      final result = await _client(api).whitelist(_token);
      expect(result.type, Po0ResultType.applied);
      expect(api.calls, hasLength(3));
    });

    test('gives up after the last attempt and redacts the token', () async {
      final api = _FakeApi([
        HttpException(
          'Connection closed',
          uri: Uri.parse('https://x/api/firewall/${_token.value}/add'),
        ),
      ]);
      final result = await _client(api).whitelist(_token);
      expect(result.type, Po0ResultType.error);
      expect(api.calls, hasLength(3));
      expect(result.message, contains(_token.label));
      expect(result.message, isNot(contains(_token.value)));
    });

    test('a rate limit is a failure, so the scheduler backs off', () async {
      final api = _FakeApi([
        const Po0HttpResponse(429, '{"status":429,"msg":"slow down"}'),
      ]);
      final result = await _client(api).poll(_ggyLink);
      expect(result.type, Po0ResultType.error);
      expect(api.calls, hasLength(1));
    });

    test('a poll reads once and leaves retrying to the next poll', () async {
      final api = _FakeApi([const Po0HttpResponse(400, 'Error'), _ok()]);
      final result = await _client(api).poll(_token);
      expect(api.calls.single.method, 'GET');
      expect(result.type, Po0ResultType.error);
    });

    test('a timed-out request drops the pooled connection', () async {
      var resets = 0;
      final client = Po0FirewallClient(
        send: (_, _) => Completer<Po0HttpResponse>().future,
        resetConnections: () => resets++,
        pollTimeout: const Duration(milliseconds: 10),
      );
      final result = await client.poll(_token);
      expect(result.type, Po0ResultType.error);
      expect(resets, 1);
    });

    test('an exit already pinned on the server counts as listed', () async {
      final result = await _client(
        _FakeApi([
          _ok(
            currentIp: '1.2.3.0/24',
            whitelist: const [
              {'ip': '1.2.3.0/24', 'slot': 0},
            ],
          ),
        ]),
      ).poll(const Po0Token('pgnfw_a'));
      expect(result.type, Po0ResultType.applied);
      expect(result.whitelist.single.slot, 0);
    });

    test('a ggy link is whitelisted by a GET on the link itself', () async {
      final api = _FakeApi([_ggy()]);
      final result = await _client(api).whitelist(_ggyLink);

      expect(api.calls.single.method, 'GET');
      expect(api.calls.single.uri.toString(), _ggyLink.value);
      expect(result.type, Po0ResultType.applied);
      expect(result.currentIp, '202.120.8.0/24');
      expect(result.whitelist.single.ip, '202.120.8.0/24');
      expect(result.message, isNull);
    });

    test('reports the entry a ggy add evicted', () async {
      final result = await _client(
        _FakeApi([_ggy(removed: '1.2.3.0/24')]),
      ).whitelist(_ggyLink);
      expect(result.type, Po0ResultType.applied);
      expect(result.message, 'evicted 1.2.3.0/24');
    });

    test('a ggy refusal is final and never shows the token', () async {
      final api = _FakeApi([
        Po0HttpResponse(200, '{"status":403,"msg":"bad ${_ggyLink.secret}"}'),
      ]);
      final result = await _client(api).whitelist(_ggyLink);
      expect(result.type, Po0ResultType.rejected);
      expect(result.message, 'bad ${_ggyLink.label}');
      expect(api.calls, hasLength(1));
    });

    test('a failed ggy request never exposes the token', () async {
      final api = _FakeApi([
        HttpException('Connection closed', uri: Uri.parse(_ggyLink.value)),
      ]);
      final result = await _client(api).whitelist(_ggyLink);
      expect(result.type, Po0ResultType.error);
      expect(result.message, isNot(contains(_ggyLink.secret)));
    });

    test('ggy has no read-only form, so polls and queries add', () async {
      final api = _FakeApi([_ggy()]);
      expect((await _client(api).poll(_ggyLink)).type, Po0ResultType.applied);
      expect((await _client(api).query(_ggyLink)).type, Po0ResultType.applied);
      expect(api.calls, hasLength(2));
      for (final call in api.calls) {
        expect(call.method, 'GET');
        expect(call.uri.toString(), _ggyLink.value);
      }
    });

    test('a 2xx body without a whitelist is an error', () async {
      final result = await _client(
        _FakeApi([const Po0HttpResponse(200, '{"ok":true}')]),
      ).whitelist(_token);
      expect(result.type, Po0ResultType.error);
    });
  });

  test('the po0 security context loads the bundled root', () {
    expect(() => po0SecurityContext, returnsNormally);
  });

  group('makeRealProfileTask', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    Future<YamlMap> build(
      List<String> directCidrs, {
      bool listener = false,
    }) async {
      final rawConfig = <String, dynamic>{
        'tun': <String, dynamic>{
          'route-exclude-address': <dynamic>['192.168.0.0/16'],
        },
        'rules': <dynamic>['MATCH,Proxy'],
      };
      final result = await makeRealProfileTask(
        MakeRealProfileState(
          profilesPath: Directory.systemTemp.path,
          profileId: 1,
          rawConfig: listener
              ? withPo0DirectListener(rawConfig, _endpoint)
              : rawConfig,
          realPatchConfig: const PatchClashConfig(),
          overrideDns: false,
          appendSystemDns: false,
          proxyGroups: const [],
          rules: const [],
          addedRules: const [],
          defaultUA: 'FlClash',
          directCidrs: directCidrs,
        ),
      );
      return loadYaml(result.yaml) as YamlMap;
    }

    test('routes the API DIRECT and keeps it out of TUN', () async {
      final config = await build(const [po0FirewallDirectCidr]);
      expect(config['rules'], [
        'IP-CIDR,124.221.69.228/32,DIRECT,no-resolve',
        'MATCH,Proxy',
      ]);
      expect(config['tun']['route-exclude-address'], [
        '192.168.0.0/16',
        '124.221.69.228/32',
      ]);
    });

    test('keeps the direct listener in the written profile', () async {
      final config = await build(const [], listener: true);
      expect(config['listeners'], [_listener]);
    });

    test('leaves the profile alone while disabled', () async {
      final config = await build(const []);
      expect(config['rules'], ['MATCH,Proxy']);
      expect(config['tun']['route-exclude-address'], ['192.168.0.0/16']);
    });
  });
}
