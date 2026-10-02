import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:fl_clash/common/constant.dart';
import 'package:fl_clash/common/string.dart';
import 'package:fl_clash/models/po0_firewall.dart';

const po0FirewallApiHost = '124.221.69.228';

const po0FirewallDirectCidr = '$po0FirewallApiHost/32';

const _po0FirewallApiBase = 'https://$po0FirewallApiHost/api/firewall';

const _po0TokenPrefix = 'pgnfw_';

const _po0DirectListenerName = 'po0-direct';

enum Po0TokenKind { po0, ggy }

class Po0Token {
  final String value;

  const Po0Token(this.value);

  Po0TokenKind get kind =>
      isGgyLink(value) ? Po0TokenKind.ggy : Po0TokenKind.po0;

  String get secret => _ggyTokenOf(value) ?? value;

  String get label => '${secret.substring(0, min(12, secret.length))}…';

  @override
  bool operator ==(Object other) => other is Po0Token && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

final _po0TokenPattern = RegExp('^$_po0TokenPrefix[^\\s,|;、@]+\$');

bool isPo0Token(String value) => _po0TokenPattern.hasMatch(value);

bool isGgyLink(String value) => _ggyTokenOf(value) != null;

final _whitespace = RegExp(r'\s');

String? _ggyTokenOf(String value) {
  if (value.contains(_whitespace)) {
    return null;
  }
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'https' ||
      !(uri.host == 'guguyun.com' || uri.host.endsWith('.guguyun.com'))) {
    return null;
  }
  try {
    final token = uri.queryParameters['token'];
    return token == null || token.isEmpty ? null : token;
  } on FormatException {
    return null;
  }
}

/// The first entry wins when a token is listed twice, as with the old string.
List<({Po0Token token, String name})> po0TokensOf(List<Po0TokenEntry> entries) {
  final seen = <String>{};
  return [
    for (final entry in entries)
      if ((isPo0Token(entry.token) || isGgyLink(entry.token)) &&
          seen.add(entry.token))
        (token: Po0Token(entry.token), name: entry.name),
  ];
}

typedef Po0DirectEndpoint = ({int port, String username, String password});

/// mihomo resolves a listener's `proxy` before the mode (`resolveMetadata`), so
/// neither global mode nor TUN can send its connections through a node.
Map<String, dynamic> withPo0DirectListener(
  Map<String, dynamic> rawConfig,
  Po0DirectEndpoint endpoint,
) {
  final listeners = rawConfig['listeners'];
  final user = {'username': endpoint.username, 'password': endpoint.password};
  return {
    ...rawConfig,
    'listeners': [
      if (listeners is List)
        for (final listener in listeners)
          if (listener is! Map || listener['name'] != _po0DirectListenerName)
            listener,
      <String, dynamic>{
        'name': _po0DirectListenerName,
        'type': 'http',
        'listen': localhost,
        'port': endpoint.port,
        'users': [user],
        'proxy': 'DIRECT',
      },
    ],
  };
}

String po0ListenerRoute(Po0DirectEndpoint endpoint) {
  final (:port, :username, :password) = endpoint;
  return 'PROXY $username:$password@$localhost:$port';
}

/// po0's address is also kept out of TUN (ADR 0001), so only it falls back.
String po0FindProxy(Uri uri, String route) {
  if (route == 'DIRECT' || uri.host != po0FirewallApiHost) {
    return route;
  }
  return '$route; DIRECT';
}

/// Opened once per session, as the core holds the port once applied; its own
/// credentials keep other local apps from leaving DIRECT through it.
class Po0DirectListener {
  Future<Po0DirectEndpoint>? _endpoint;

  Future<Po0DirectEndpoint> get endpoint => _endpoint ??= _open();

  Future<Po0DirectEndpoint> _open() async {
    try {
      final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = socket.port;
      await socket.close();
      return (
        port: port,
        username: generateRandomSecret(12),
        password: generateRandomSecret(24),
      );
    } catch (_) {
      _endpoint = null;
      rethrow;
    }
  }
}

final po0DirectListener = Po0DirectListener();

List<Po0Token> parsePo0Tokens(String raw) {
  final seen = <String>{};
  final tokens = <Po0Token>[];
  for (final part in raw.split(RegExp(r'[,|;、\s]+'))) {
    if (!part.startsWith(_po0TokenPrefix)) {
      continue;
    }
    final at = part.indexOf('@');
    final value = at == -1 ? part : part.substring(0, at);
    if (seen.add(value)) {
      tokens.add(Po0Token(value));
    }
  }
  return tokens;
}

/// The server whitelists whole /24s and echoes entries as IPs or `x.x.x.0/24`.
bool sameC24(String? a, String? b) {
  if (a == null || b == null || a.isEmpty || b.isEmpty) {
    return false;
  }
  if (a == b) {
    return true;
  }
  if (!a.endsWith('/24') && !b.endsWith('/24')) {
    return false;
  }
  final pa = a.replaceAll('/24', '').split('.');
  final pb = b.replaceAll('/24', '').split('.');
  return pa.length == 4 &&
      pb.length == 4 &&
      pa[0] == pb[0] &&
      pa[1] == pb[1] &&
      pa[2] == pb[2];
}

class _Ipv4Cidr {
  final int network;
  final int prefix;

  const _Ipv4Cidr(this.network, this.prefix);

  static _Ipv4Cidr? tryParse(String value) {
    final parts = value.trim().split('/');
    if (parts.length != 2) {
      return null;
    }
    final prefix = int.tryParse(parts[1]);
    final address = InternetAddress.tryParse(parts[0]);
    if (prefix == null ||
        prefix < 0 ||
        prefix > 32 ||
        address == null ||
        address.type != InternetAddressType.IPv4) {
      return null;
    }
    final ip = address.rawAddress.fold<int>(0, (acc, byte) => acc << 8 | byte);
    return _Ipv4Cidr(ip & _mask(prefix), prefix);
  }

  static int _mask(int prefix) =>
      prefix == 0 ? 0 : (0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF;

  bool contains(_Ipv4Cidr other) =>
      other.prefix >= prefix && (other.network & _mask(prefix)) == network;

  (_Ipv4Cidr, _Ipv4Cidr) split() {
    final next = prefix + 1;
    return (
      _Ipv4Cidr(network, next),
      _Ipv4Cidr(network | (1 << (32 - next)), next),
    );
  }

  @override
  String toString() {
    final octets = [24, 16, 8, 0].map((shift) => (network >> shift) & 0xFF);
    return '${octets.join('.')}/$prefix';
  }
}

/// Android's `VpnService.Builder.excludeRoute` needs API 33, so covering routes
/// are split instead.
List<String> excludeIpv4Route(List<String> routes, String excluded) {
  final target = _Ipv4Cidr.tryParse(excluded);
  if (target == null) {
    return routes;
  }
  final result = <String>[];
  for (final route in routes) {
    final cidr = _Ipv4Cidr.tryParse(route);
    if (cidr == null || !cidr.contains(target)) {
      if (cidr == null || !target.contains(cidr)) {
        result.add(route);
      }
      continue;
    }
    var current = cidr;
    while (current.prefix < target.prefix) {
      final (low, high) = current.split();
      final keepLow = !low.contains(target);
      result.add((keepLow ? low : high).toString());
      current = keepLow ? high : low;
    }
  }
  return result;
}

class Po0HttpResponse {
  final int statusCode;
  final String body;

  const Po0HttpResponse(this.statusCode, this.body);
}

typedef Po0HttpSend = Future<Po0HttpResponse> Function(String method, Uri uri);

/// Android 7.0 lacks ISRG Root X1, and Windows installs it only on demand.
final po0SecurityContext = SecurityContext(withTrustedRoots: true)
  ..setTrustedCertificatesBytes(utf8.encode(_isrgRootX1));

const _isrgRootX1 = '''
-----BEGIN CERTIFICATE-----
MIIFazCCA1OgAwIBAgIRAIIQz7DSQONZRGPgu2OCiwAwDQYJKoZIhvcNAQELBQAw
TzELMAkGA1UEBhMCVVMxKTAnBgNVBAoTIEludGVybmV0IFNlY3VyaXR5IFJlc2Vh
cmNoIEdyb3VwMRUwEwYDVQQDEwxJU1JHIFJvb3QgWDEwHhcNMTUwNjA0MTEwNDM4
WhcNMzUwNjA0MTEwNDM4WjBPMQswCQYDVQQGEwJVUzEpMCcGA1UEChMgSW50ZXJu
ZXQgU2VjdXJpdHkgUmVzZWFyY2ggR3JvdXAxFTATBgNVBAMTDElTUkcgUm9vdCBY
MTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAK3oJHP0FDfzm54rVygc
h77ct984kIxuPOZXoHj3dcKi/vVqbvYATyjb3miGbESTtrFj/RQSa78f0uoxmyF+
0TM8ukj13Xnfs7j/EvEhmkvBioZxaUpmZmyPfjxwv60pIgbz5MDmgK7iS4+3mX6U
A5/TR5d8mUgjU+g4rk8Kb4Mu0UlXjIB0ttov0DiNewNwIRt18jA8+o+u3dpjq+sW
T8KOEUt+zwvo/7V3LvSye0rgTBIlDHCNAymg4VMk7BPZ7hm/ELNKjD+Jo2FR3qyH
B5T0Y3HsLuJvW5iB4YlcNHlsdu87kGJ55tukmi8mxdAQ4Q7e2RCOFvu396j3x+UC
B5iPNgiV5+I3lg02dZ77DnKxHZu8A/lJBdiB3QW0KtZB6awBdpUKD9jf1b0SHzUv
KBds0pjBqAlkd25HN7rOrFleaJ1/ctaJxQZBKT5ZPt0m9STJEadao0xAH0ahmbWn
OlFuhjuefXKnEgV4We0+UXgVCwOPjdAvBbI+e0ocS3MFEvzG6uBQE3xDk3SzynTn
jh8BCNAw1FtxNrQHusEwMFxIt4I7mKZ9YIqioymCzLq9gwQbooMDQaHWBfEbwrbw
qHyGO0aoSCqI3Haadr8faqU9GY/rOPNk3sgrDQoo//fb4hVC1CLQJ13hef4Y53CI
rU7m2Ys6xt0nUW7/vGT1M0NPAgMBAAGjQjBAMA4GA1UdDwEB/wQEAwIBBjAPBgNV
HRMBAf8EBTADAQH/MB0GA1UdDgQWBBR5tFnme7bl5AFzgAiIyBpY9umbbjANBgkq
hkiG9w0BAQsFAAOCAgEAVR9YqbyyqFDQDLHYGmkgJykIrGF1XIpu+ILlaS/V9lZL
ubhzEFnTIZd+50xx+7LSYK05qAvqFyFWhfFQDlnrzuBZ6brJFe+GnY+EgPbk6ZGQ
3BebYhtF8GaV0nxvwuo77x/Py9auJ/GpsMiu/X1+mvoiBOv/2X/qkSsisRcOj/KK
NFtY2PwByVS5uCbMiogziUwthDyC3+6WVwW6LLv3xLfHTjuCvjHIInNzktHCgKQ5
ORAzI4JMPJ+GslWYHb4phowim57iaztXOoJwTdwJx4nLCgdNbOhdjsnvzqvHu7Ur
TkXWStAmzOVyyghqpZXjFaH3pO3JLF+l+/+sKAIuvtd7u+Nxe5AW0wdeRlN8NwdC
jNPElpzVmbUq4JUagEiuTDkHzsxHpFKVK7q4+63SM1N95R1NbdWhscdCb+ZAJzVc
oyi3B43njTOQ5yOf+1CceWxG1bQVs5ZufpsMljq4Ui0/1lvh+wjChP4kqKOJ2qxq
4RgqsahDYVvTH9w7jXbyLeiNdd8XM2w9U/t7y0Ff/9yi0GE44Za4rF2LN9d11TPA
mRGunUHBcnWEvgJBQl9nJEiU0Zsnvgc/ubhPgXRR4Xq37Z0j4r7g1SgEEzwxA57d
emyPxgcYxn/eR44/KJ4EBs+lVDR3veyJm+kXQ99b21/+jh5Xos1AnX5iItreGCc=
-----END CERTIFICATE-----
''';

/// The API sees the request's source address, so the request must leave on
/// the physical network. The app's global [HttpOverrides] would send it to the
/// mixed port, and TUN or the VPN capture a DIRECT socket while the proxy
/// runs, so the route then names the core's DIRECT-only listener. The pooled
/// socket outlives a network switch, so it is dropped on failure and on change.
class Po0DirectTransport {
  Po0DirectTransport({Future<String> Function()? route})
    : _route = route ?? _direct;

  static Future<String> _direct() async => 'DIRECT';

  final Future<String> Function() _route;
  HttpClient? _client;
  String? _clientRoute;

  HttpClient _clientFor(String route) {
    if (route != _clientRoute) {
      reset();
      _clientRoute = route;
    }
    return _client ??= HttpClient(context: po0SecurityContext)
      ..findProxy = ((uri) => po0FindProxy(uri, route))
      ..connectionTimeout = const Duration(seconds: 5)
      ..idleTimeout = const Duration(seconds: 30);
  }

  Future<Po0HttpResponse> send(String method, Uri uri) async {
    final client = _clientFor(await _route());
    try {
      final request = await client.openUrl(method, uri);
      request.headers.contentType = ContentType.json;
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      return Po0HttpResponse(response.statusCode, body);
    } catch (_) {
      if (identical(client, _client)) {
        reset();
      }
      rethrow;
    }
  }

  void reset() {
    _client?.close(force: true);
    _client = null;
  }
}

class Po0FirewallClient {
  final Po0HttpSend? _customSend;
  final void Function()? _customReset;
  final Po0DirectTransport? _transport;
  final Duration retryDelay;
  final Duration requestTimeout;
  final Duration pollTimeout;
  final int maxAttempts;

  Po0FirewallClient({
    Po0HttpSend? send,
    void Function()? resetConnections,
    Future<String> Function()? route,
    this.retryDelay = const Duration(milliseconds: 1500),
    this.requestTimeout = const Duration(seconds: 20),
    this.pollTimeout = const Duration(seconds: 5),
    this.maxAttempts = 3,
  }) : _customSend = send,
       _customReset = resetConnections,
       _transport = send == null ? Po0DirectTransport(route: route) : null;

  Future<Po0HttpResponse> _send(String method, Uri uri) =>
      (_customSend ?? _transport!.send)(method, uri);

  void resetConnections() => (_customReset ?? _transport?.reset)?.call();

  Future<Po0TokenResult> whitelist(Po0Token token) => switch (token.kind) {
    Po0TokenKind.po0 => _call(token, 'POST', _po0Uri(token, '/add')),
    Po0TokenKind.ggy => _call(token, 'GET', Uri.parse(token.value)),
  };

  /// Read-only: the add endpoint would claim a FIFO slot and evict the oldest
  /// entry whenever the current exit is not listed yet.
  Future<Po0TokenResult> query(Po0Token token) =>
      _call(token, 'GET', _queryUri(token));

  Future<Po0TokenResult> poll(Po0Token token) =>
      _call(token, 'GET', _queryUri(token), attempts: 1, timeout: pollTimeout);

  /// ggy has no read-only form: its link adds the caller's /24 on every GET.
  Uri _queryUri(Po0Token token) => switch (token.kind) {
    Po0TokenKind.po0 => _po0Uri(token),
    Po0TokenKind.ggy => Uri.parse(token.value),
  };

  Uri _po0Uri(Po0Token token, [String action = '']) {
    final encoded = Uri.encodeComponent(token.value);
    return Uri.parse('$_po0FirewallApiBase/$encoded$action');
  }

  Future<Po0TokenResult> _call(
    Po0Token token,
    String method,
    Uri uri, {
    int? attempts,
    Duration? timeout,
  }) async {
    Object? lastError;
    for (var attempt = 1; attempt <= (attempts ?? maxAttempts); attempt++) {
      if (attempt > 1) {
        await Future.delayed(retryDelay * (attempt - 1));
      }
      try {
        final response = await _send(
          method,
          uri,
        ).timeout(timeout ?? requestTimeout);
        if (_isTransient(response)) {
          lastError = 'HTTP ${response.statusCode}';
          continue;
        }
        return _parse(token, response);
      } on TimeoutException catch (error) {
        lastError = error;
        resetConnections();
      } catch (error) {
        lastError = error;
      }
    }
    return Po0TokenResult(
      label: token.label,
      type: Po0ResultType.error,
      message: _redact('$lastError', token),
    );
  }

  // The API occasionally answers a bare 400 "Error" or a 5xx that succeeds a
  // few seconds later; a JSON error body (an invalid token) is final. Retrying
  // add is safe because the server treats a listed exit idempotently.
  bool _isTransient(Po0HttpResponse response) {
    final status = response.statusCode;
    if (status >= 500 || status == HttpStatus.tooManyRequests) {
      return true;
    }
    if ((status >= 200 && status < 300) || status == HttpStatus.forbidden) {
      return false;
    }
    return _decodeMap(response.body) == null;
  }

  Po0TokenResult _parse(Po0Token token, Po0HttpResponse response) {
    return switch (token.kind) {
      Po0TokenKind.po0 => _parsePo0(token, response),
      Po0TokenKind.ggy => _parseGgy(token, response),
    };
  }

  Po0TokenResult _parseGgy(Po0Token token, Po0HttpResponse response) {
    final status = response.statusCode;
    final body = _decodeMap(response.body);
    final base = Po0TokenResult(label: token.label, type: Po0ResultType.error);
    if (body == null) {
      return base.copyWith(
        message: 'HTTP $status: ${_snippet(_redact(response.body, token))}',
      );
    }
    final data = body['data'];
    final cidr = data is Map ? '${data['cidr'] ?? ''}' : '';
    final apiStatus = '${body['status'] ?? 200}';
    if (status < 200 || status >= 300 || apiStatus != '200' || cidr.isEmpty) {
      final message = body['msg'] ?? body['message'] ?? 'HTTP $status';
      return base.copyWith(
        type: Po0ResultType.rejected,
        message: _redact('$message', token),
      );
    }
    final removed = '${data['removed_cidr'] ?? ''}';
    return base.copyWith(
      type: Po0ResultType.applied,
      currentIp: cidr,
      whitelist: [Po0WhitelistEntry(ip: cidr)],
      message: removed.isEmpty ? null : 'evicted $removed',
    );
  }

  Po0TokenResult _parsePo0(Po0Token token, Po0HttpResponse response) {
    final status = response.statusCode;
    final data = _decodeMap(response.body);
    final base = Po0TokenResult(
      label: token.label,
      type: Po0ResultType.error,
      currentIp: data?['currentIp']?.toString(),
    );
    if (data == null) {
      return base.copyWith(message: 'HTTP $status: ${_snippet(response.body)}');
    }
    if (status < 200 || status >= 300) {
      final message = data['message'] ?? data['msg'] ?? data['error'];
      return base.copyWith(
        type: Po0ResultType.rejected,
        message: _redact('${message ?? 'HTTP $status'}', token),
      );
    }
    final rawWhitelist = data['whitelist'];
    if (rawWhitelist is! List) {
      return base.copyWith(message: _snippet(response.body));
    }
    final whitelist = rawWhitelist
        .map(
          (item) => item is Map
              ? Po0WhitelistEntry(
                  ip: '${item['ip']}',
                  slot: item['slot'] is num
                      ? (item['slot'] as num).toInt()
                      : null,
                )
              : Po0WhitelistEntry(ip: '$item'),
        )
        .toList();
    final limit = data['limit'];
    final listed = whitelist.any((entry) => sameC24(entry.ip, base.currentIp));
    final type = data['enabled'] == false
        ? Po0ResultType.disabled
        : listed
        ? Po0ResultType.applied
        : Po0ResultType.notApplied;
    return base.copyWith(
      type: type,
      whitelist: whitelist,
      limit: limit is num ? limit.toInt() : null,
    );
  }

  Map<String, dynamic>? _decodeMap(String body) {
    try {
      final data = json.decode(body);
      return data is Map<String, dynamic> ? data : null;
    } catch (_) {
      return null;
    }
  }

  String _snippet(String body) {
    final text = body.trim();
    return text.length > 80 ? '${text.substring(0, 80)}…' : text;
  }

  String _redact(String text, Po0Token token) =>
      text.replaceAll(token.secret, token.label);
}
