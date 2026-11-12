// Stands in for the native shell when the page runs in a plain browser (`npm run dev`); never part of a release build.

const pause = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));
const emit = (payload: string) => window.__po0Emit?.('core-change', payload);
const now = () => Math.floor(Date.now() / 1000);

const SETTINGS_KEY = 'po0-desktop-mock-settings-v1';

const settings = {
  language: null,
  themeMode: 'system',
  themeColor: 0xff0064e0,
  themeColors: [0xff0064e0],
  schemeVariant: 'fidelity',
  pureBlack: false,
  textScale: null,
  launchAtLogin: false,
  silentLaunch: false,
  autoConnect: false,
  minimizeOnClose: true,
  hideFromRecents: false,
  pageAnimation: true,
  showNavLabels: true,
  captureLogs: true,
  closeConnectionsOnSwitch: true,
  onlyProxyTraffic: false,
  notificationStopButton: true,
  autoCheckUpdate: true,
  checkCertificate: true,
  traySpeed: false,
  crashReports: false,
  crashReportsAsked: true,
  disclaimerAccepted: true,
  developerMode: false,
  proxiesLayout: 'list',
  proxiesSort: 'profile',
  proxiesDensity: 'standard',
  proxyTileStyle: 'detailed',
  groupIconStyle: 'standard',
  dashboardCards: ['currentNode', 'speed', 'mode', 'takeover', 'whitelist', 'traffic', 'connections', 'memory', 'intranetIp', 'subscription', 'exitIp'],
  hotkeys: [],
  webdav: null,
  restoreStrategy: 'compatible',
  accessControl: { enabled: false, mode: 'rejectSelected', packages: [] },
  androidVpn: {},
  excludedSsids: [],
  ...JSON.parse(localStorage.getItem(SETTINGS_KEY) ?? '{}'),
};

const options = {
  mixedPort: 7890,
  socksPort: 0,
  httpPort: 0,
  allowLan: false,
  authentication: [],
  logLevel: 'info',
  ipv6: false,
  unifiedDelay: true,
  tcpConcurrent: true,
  findProcessMode: 'off',
  keepAliveInterval: 30,
  interfaceName: '',
  testUrl: 'https://www.gstatic.com/generate_204',
  userAgent: 'clash.meta',
  hosts: {},
  externalController: false,
  tunStack: 'gvisor',
  tunRouteAddress: [],
  tunDnsHijack: ['any:53'],
  geodataLoader: 'memconservative',
  geoAutoUpdate: false,
  geoUpdateInterval: 24,
  geoxUrl: {
    mmdb: 'https://example.com/geoip.metadb',
    asn: 'https://example.com/GeoLite2-ASN.mmdb',
    geoip: 'https://example.com/geoip.dat',
    geosite: 'https://example.com/geosite.dat',
  },
  overrideDns: false,
  dns: {
    enable: true,
    listen: '',
    preferH3: false,
    useHosts: true,
    useSystemHosts: true,
    respectRules: false,
    ipv6: false,
    enhancedMode: 'fakeIp',
    fakeIpRange: '198.18.0.1/16',
    fakeIpFilter: ['*.lan'],
    defaultNameserver: ['223.5.5.5'],
    nameserver: ['https://doh.pub/dns-query'],
    fallback: [],
    proxyServerNameserver: [],
    directNameserver: [],
    nameserverPolicy: {},
    fallbackFilter: { geoip: true, geoipCode: 'CN', geosite: [], ipcidr: ['240.0.0.0/4'], domain: ['+.google.com'] },
  },
  addedRules: [],
  bypassDomains: ['localhost', '127.*', '192.168.*'],
  appendSystemDns: false,
  autoSetSystemDns: true,
};

const cities = ['Tokyo', 'Singapore', 'Hong Kong', 'Los Angeles', 'Frankfurt', 'London', 'Seoul', 'Taipei'];
const flags = ['🇯🇵', '🇸🇬', '🇭🇰', '🇺🇸', '🇩🇪', '🇬🇧', '🇰🇷', '🇹🇼'];
const nodes = Array.from({ length: 32 }, (_, i) => ({
  name: `${flags[i % 8]} ${cities[i % 8]} ${String(Math.floor(i / 8) + 1).padStart(2, '0')}`,
  kind: ['Shadowsocks', 'Vless', 'Trojan', 'Hysteria2'][i % 4],
  delay: i % 11 === 10 ? 0 : i % 5 === 4 ? null : 38 + ((i * 53) % 420),
}));
const builtin = [
  { name: 'DIRECT', kind: 'Direct', delay: null },
  { name: 'REJECT', kind: 'Reject', delay: null },
];

let groups = [
  { name: 'Proxy', kind: 'Selector', selectable: true, now: nodes[1].name, icon: null, nodes: [{ name: 'Auto', kind: 'URLTest', delay: null }, ...nodes] },
  { name: 'Auto', kind: 'URLTest', selectable: false, now: nodes[2].name, icon: null, nodes: nodes.slice(0, 16) },
  { name: 'Streaming', kind: 'Selector', selectable: true, now: nodes[4].name, icon: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><rect width="24" height="24" rx="5" fill="#e50914"/><path d="M9 7v10l8-5z" fill="#fff"/></svg>', nodes: nodes.slice(3, 17) },
  { name: 'Telegram', kind: 'Selector', selectable: true, now: 'Proxy', icon: null, nodes: [{ name: 'Proxy', kind: 'Selector', delay: null }, ...nodes.slice(0, 6)] },
  { name: 'Final', kind: 'Selector', selectable: true, now: 'Proxy', icon: null, nodes: [{ name: 'Proxy', kind: 'Selector', delay: null }, ...builtin] },
  { name: 'GLOBAL', kind: 'Selector', selectable: true, now: 'Proxy', icon: null, nodes: [{ name: 'Proxy', kind: 'Selector', delay: null }, ...nodes] },
];

let profiles: any[] = [
  { id: 'p1', name: 'Example Cloud', kind: 'subscription', url: 'https://example.com/sub?token=abc', updatedAt: now() - 5400, usage: { upload: 5e9, download: 61e9, total: 200e9, expire: now() + 86400 * 47 }, selected: true, autoUpdate: true, updateHours: 12 },
  { id: 'p2', name: 'Backup Airport', kind: 'subscription', url: 'https://backup.example.net/api/v1/client/subscribe', updatedAt: now() - 86400 * 2, usage: { upload: 1e9, download: 9e9, total: 50e9, expire: null }, selected: false, autoUpdate: false, updateHours: 24 },
  { id: 'p3', name: '', kind: 'links', url: null, updatedAt: now() - 86400 * 9, usage: null, selected: false, autoUpdate: false, updateHours: 24 },
  { id: 'p4', name: 'local.yaml', kind: 'file', url: null, updatedAt: now() - 86400 * 30, usage: null, selected: false, autoUpdate: false, updateHours: 24 },
];

const status: any = { engine: { state: 'running' }, mode: 'rule', routeMode: 'systemProxy', profileId: 'p1', currentNode: nodes[1].name };

let whitelist = {
  enabled: true,
  entries: [
    { id: 'w1', kind: 'po0', name: 'Home line', label: 'a1b2…9f', result: { outcome: 'applied', ip: '203.0.113.7', message: null, at: now() - 12 } },
    { id: 'w2', kind: 'ggy', name: 'Office', label: 'ggy.example/…/x7', result: { outcome: 'error', ip: null, message: 'HTTP 502 from upstream', at: now() - 40 } },
    { id: 'w3', kind: 'po0', name: '', label: 'c3d4…1a', result: null },
  ],
};

const hosts = ['www.google.com', 'api.github.com', 'i.ytimg.com', 'cdn.jsdelivr.net', 'update.googleapis.com', 'www.bilibili.com', 'mtalk.google.com'];
const connection = (i: number) => ({
  id: `c${i}`,
  network: i % 6 === 0 ? 'udp' : 'tcp',
  inbound: 'mixed',
  host: hosts[i % hosts.length],
  destination: `142.250.${i % 250}.${(i * 7) % 250}:443`,
  source: `127.0.0.1:${50000 + i}`,
  process: ['chrome.exe', 'Code.exe', 'Telegram.exe', null][i % 4],
  processPath: null,
  rule: ['DOMAIN-SUFFIX', 'GEOSITE', 'MATCH', 'GEOIP'][i % 4],
  rulePayload: ['google.com', 'github', '', 'CN'][i % 4],
  chains: i % 4 === 3 ? ['DIRECT'] : [nodes[i % 8].name, 'Proxy'],
  upload: 1200 * (i + 1),
  download: 98000 * (i + 3),
  start: now() - i * 37,
});
let requests = Array.from({ length: 120 }, (_, i) => connection(i));
let logs = Array.from({ length: 80 }, (_, i) => ({
  level: ['info', 'info', 'warning', 'debug', 'error'][i % 5],
  message: `[TCP] 127.0.0.1:${50000 + i} --> ${hosts[i % hosts.length]}:443 match ${connection(i).rule}(${connection(i).rulePayload}) using ${connection(i).chains.at(-1)}`,
  at: now() - i * 3,
}));
let shareNodes = nodes.slice(0, 6).map(({ name, kind }) => ({ name, kind }));
const overrides: Record<string, any> = {};
let scripts = [{ id: 's1', name: 'Add ad-block rules', content: 'function main(config) {\n  return config;\n}\n' }];
const history = Array.from({ length: 60 }, (_, i) => ({ up: 180000 + i * 2200, down: Math.round(7e6 + Math.sin(i / 4) * 4e6) }));

const running = () => status.engine.state === 'running';

const commands: Record<string, (args: any) => unknown> = {
  app_info: () => ({ version: '7.3.0', language: ['zh', 'ja', 'ru'].find((code) => (settings.language ?? navigator.language).toLowerCase().startsWith(code)) ?? 'en' }),
  launch_notice: () => null,
  status: () => structuredClone(status),
  async start() {
    status.engine = { state: 'starting' };
    emit('status');
    await pause(900);
    status.engine = { state: 'running' };
    emit('status');
  },
  stop() {
    status.engine = { state: 'stopped' };
    emit('status');
  },
  traffic: () => history.at(-1),
  traffic_history() {
    history.push({ up: Math.round(1e5 + Math.random() * 4e5), down: Math.round(2e6 + Math.random() * 9e6) });
    history.shift();
    return history;
  },
  memory: () => 64e6 + Math.round(Math.random() * 4e6),
  connections: () => ({ uploadTotal: 5.2e9, downloadTotal: 25.4e9, items: requests.slice(0, 23) }),
  close_connection: ({ id }) => void (requests = requests.filter((c) => c.id !== id)),
  close_all_connections: () => void (requests = []),
  requests: () => requests,
  clear_requests: () => void (requests = []),
  logs: () => logs,
  clear_logs: () => void (logs = []),
  add_test_logs: () => void logs.unshift({ level: 'warning', message: 'test log entry', at: now() }),
  async exit_ip() {
    await pause(500);
    return running() ? { ip: '203.0.113.7', country: 'JP' } : { ip: '198.51.100.24', country: 'CN' };
  },
  intranet_ip: () => ({ ip: '192.168.1.23', interface: 'Ethernet' }),
  set_mode({ mode }) {
    status.mode = mode;
    emit('status');
  },
  set_route_mode({ routeMode }) {
    status.routeMode = routeMode;
    emit('status');
  },
  profiles: () => profiles,
  async add_subscription({ url }) {
    await pause(800);
    if (!/^https?:\/\//.test(url)) throw 'invalid subscription URL';
    const profile = { id: `p${Date.now()}`, name: new URL(url).hostname, kind: 'subscription', url, updatedAt: now(), usage: null, selected: false, autoUpdate: true, updateHours: 24 };
    profiles = [...profiles, profile];
    emit('profiles');
    return profile;
  },
  async update_profile({ id }) {
    await pause(1000);
    profiles = profiles.map((p) => (p.id === id ? { ...p, updatedAt: now() } : p));
    emit('profiles');
    return profiles.find((p) => p.id === id);
  },
  remove_profile({ id }) {
    profiles = profiles.filter((p) => p.id !== id);
    emit('profiles');
  },
  select_profile({ id }) {
    profiles = profiles.map((p) => ({ ...p, selected: p.id === id }));
    status.profileId = id;
    emit('profiles');
    emit('status');
  },
  import_file({ name }) {
    const profile = { id: `p${Date.now()}`, name, kind: 'file', url: null, updatedAt: now(), usage: null, selected: false, autoUpdate: false, updateHours: 24 };
    profiles = [...profiles, profile];
    emit('profiles');
    return profile;
  },
  edit_profile({ id, edit }) {
    profiles = profiles.map((p) => (p.id === id ? { ...p, ...edit } : p));
    emit('profiles');
    return profiles.find((p) => p.id === id);
  },
  preview_config: () => 'mixed-port: 7890\nmode: rule\nproxies:\n  - name: Tokyo 01\n    type: ss\n    server: example.com\n    port: 443\nrules:\n  - MATCH,Proxy\n',
  reorder_profiles({ ids }) {
    profiles = ids.map((id: string) => profiles.find((p) => p.id === id)).filter(Boolean);
    emit('profiles');
  },
  export_profile: () => 'C:\\Users\\me\\Desktop\\profile.yaml',
  import_links({ text }) {
    const added = text.split('\n').filter((line: string) => line.trim()).length;
    return { profile: profiles.find((p) => p.kind === 'links'), added };
  },
  groups: () => (running() ? groups : []),
  select_node({ group, node }) {
    groups = groups.map((g) => (g.name === group ? { ...g, now: node } : g));
    if (group === 'Proxy') status.currentNode = node;
    emit('groups');
  },
  async test_delay({ group }) {
    await pause(1500);
    const found = groups.find((g) => g.name === group)!;
    return { ...found, nodes: found.nodes.map((node, i) => ({ ...node, delay: i % 9 === 8 ? 0 : 40 + ((i * 37) % 380) })) };
  },
  async test_node_delay() {
    await pause(900);
    return 40 + Math.round(Math.random() * 300);
  },
  whitelist: () => whitelist,
  set_whitelist_enabled({ enabled }) {
    whitelist = { ...whitelist, enabled };
    emit('whitelist');
  },
  add_whitelist_entries({ text, name }) {
    const lines = text.split('\n').filter((line: string) => line.trim());
    whitelist = {
      ...whitelist,
      entries: [...whitelist.entries, ...lines.map((line: string, i: number) => ({ id: `w${Date.now()}${i}`, kind: line.startsWith('http') ? 'ggy' : 'po0', name: name ?? '', label: `${line.slice(0, 4)}…`, result: null }))],
    };
    emit('whitelist');
    return lines.length;
  },
  remove_whitelist_entry({ id }) {
    whitelist = { ...whitelist, entries: whitelist.entries.filter((e) => e.id !== id) };
    emit('whitelist');
  },
  whitelist_now: () => pause(600),
  app_settings: () => structuredClone(settings),
  async set_app_settings({ settings: next }) {
    await pause(120);
    Object.assign(settings, structuredClone(next));
    localStorage.setItem(SETTINGS_KEY, JSON.stringify(settings));
  },
  engine_options: () => structuredClone(options),
  set_engine_options: ({ options: next }) => void Object.assign(options, structuredClone(next)),
  providers: () => [
    { name: 'airport', kind: 'proxy', vehicle: 'HTTP', behavior: null, count: 32, updatedAt: now() - 3600, usage: { upload: 5e9, download: 61e9, total: 200e9, expire: now() + 86400 * 47 } },
    { name: 'reject-list', kind: 'rule', vehicle: 'HTTP', behavior: 'domain', count: 41234, updatedAt: now() - 86400, usage: null },
    { name: 'cn-ip', kind: 'rule', vehicle: 'File', behavior: 'ipcidr', count: 8800, updatedAt: now() - 86400 * 3, usage: null },
  ],
  update_provider: () => pause(800),
  rules: () =>
    Array.from({ length: 400 }, (_, i) => ({
      kind: ['DOMAIN-SUFFIX', 'DOMAIN-KEYWORD', 'GEOSITE', 'GEOIP', 'RULE-SET', 'IP-CIDR'][i % 6],
      payload: ['google.com', 'github', 'cn', 'CN', 'reject-list', '10.0.0.0/8'][i % 6] + (i > 5 ? `-${i}` : ''),
      proxy: ['Proxy', 'Proxy', 'DIRECT', 'DIRECT', 'REJECT', 'DIRECT'][i % 6],
    })).concat([{ kind: 'MATCH', payload: '', proxy: 'Final' }]),
  geo_files: () => [
    { name: 'geoip.metadb', size: 8.2e6, modified: now() - 86400 * 4 },
    { name: 'geosite.dat', size: 4.1e6, modified: now() - 86400 * 4 },
    { name: 'GeoLite2-ASN.mmdb', size: null, modified: null },
  ],
  update_geo: () => pause(1500),
  flush_dns_cache: () => pause(200),
  autostart_enabled: () => false,
  set_autostart: () => undefined,
  backup_to_file: () => 'C:\\Users\\me\\Desktop\\po0-clash-backup.zip',
  restore_from_file: () => true,
  check_webdav: () => pause(600),
  backup_to_webdav: () => pause(900),
  restore_from_webdav: () => pause(900),
  export_diagnostics: () => 'C:\\Users\\me\\Desktop\\po0-clash-diagnostics.zip',
  profile_override: ({ id }) => overrides[id] ?? ({ mode: 'standard', addedRules: ['DOMAIN-SUFFIX,example.org,DIRECT'], disabledGlobalRules: [], matchTarget: null, scriptId: null, customGroups: '', customRules: [] }),
  set_profile_override({ id, overrides: next }) {
    if (next.mode === 'custom' && next.customGroups.trim() && !next.customGroups.trim().startsWith('-')) {
      throw 'custom proxy groups: invalid type: map, expected a sequence at line 1 column 1';
    }
    overrides[id] = structuredClone(next);
  },
  profile_groups_and_rules: () => ({ groups: '- name: Proxy\n  type: select\n  proxies: [DIRECT]\n', rules: ['MATCH,Proxy'] }),
  scripts: () => scripts,
  save_script({ script }) {
    const saved = { ...script, id: script.id || `s${Date.now()}` };
    scripts = [...scripts.filter((s) => s.id !== saved.id), saved];
    return saved;
  },
  remove_script: ({ id }) => void (scripts = scripts.filter((s) => s.id !== id)),
  share_nodes: () => shareNodes,
  rename_share_node({ name, newName }) {
    if (shareNodes.some((n) => n.name === newName.trim())) throw `a node named ${newName.trim()} already exists`;
    shareNodes = shareNodes.map((n) => (n.name === name ? { ...n, name: newName.trim() } : n));
    return null;
  },
  remove_share_node({ name }) {
    shareNodes = shareNodes.filter((n) => n.name !== name);
    return null;
  },
  licenses: () => [
    { name: 'mihomo', version: '1.19.x', license: 'GPL-3.0', url: 'https://github.com/MetaCubeX/mihomo' },
    { name: 'serde', version: '1.0', license: 'MIT OR Apache-2.0', url: 'https://github.com/serde-rs/serde' },
  ],
  loopback_apps: () => [
    { sid: 'S-1-15-2-1', name: 'Microsoft.WindowsStore', displayName: 'Microsoft Store', exempt: true },
    { sid: 'S-1-15-2-2', name: 'Microsoft.WindowsCalculator', displayName: 'Calculator', exempt: false },
  ],
  set_loopback: () => undefined,
  open_url: ({ url }) => void window.open(url, '_blank'),
  hotkey_failures: () => [],
  pause_hotkeys: () => undefined,
  crash_engine() {
    status.engine = { state: 'failed', message: 'mihomo exited unexpectedly' };
    emit('status');
  },
  prune_cache: () => 3,
  clear_data: () => undefined,
  async check_update() {
    await pause(600);
    return { version: '7.4.0', url: 'https://github.com/yuuuki-creation/po0-clash/releases', notes: '- Mock release notes\n- Second line' };
  },
  window_drag: () => undefined,
  window_zoom: () => undefined,
  set_window_background: () => undefined,
};

export async function invoke(command: string, args: Record<string, unknown>) {
  const handler = commands[command];
  if (!handler) throw `The browser mock does not implement ${command}`;
  // The real shells answer a unit result with null, which callers tell apart from a failed `act`.
  return (await handler(args)) ?? null;
}
