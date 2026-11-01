import { mockIPC, mockWindows } from '@tauri-apps/api/mocks';
import { mount } from 'svelte';
import App from '../src/App.svelte';
import '../src/app.css';
import { app } from '../src/lib/core.svelte.js';
import { setLanguage } from '../src/lib/i18n.js';
import { loadSettings, settings } from '../src/lib/settings.svelte.js';
import { watchAppearance } from '../src/lib/theme.svelte.js';

const key = 'po0-windows-ui-fixture-settings-v1';
const defaults = {
  dashboardCards: ['currentNode', 'speed', 'mode', 'takeover', 'whitelist', 'traffic', 'connections', 'memory', 'intranetIp', 'subscription', 'exitIp'],
  proxiesLayout: 'tabs',
  proxiesSort: 'profile',
  proxiesDensity: 'standard',
  proxyTileStyle: 'detailed',
  groupIconStyle: 'standard',
  showNavLabels: true,
  themeMode: 'system',
  themeColor: 0xff24694c,
  themeColors: [0xff24694c, 0xff007aff],
  schemeVariant: 'tonalSpot',
  pureBlack: false,
  textScale: null,
  pageAnimation: true,
  language: 'en',
  hotkeys: [],
};
let stored = { ...defaults, ...JSON.parse(localStorage.getItem(key) ?? '{}') };
const pause = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const nodes = Array.from({ length: 18 }, (_, i) => ({
  name: `${['Tokyo', 'Singapore', 'Hong Kong', 'Los Angeles', 'Frankfurt', 'London'][i % 6]} ${String(i + 1).padStart(2, '0')}`,
  kind: i % 3 === 0 ? 'Shadowsocks' : 'VLESS',
  delay: i % 7 === 0 ? 0 : 35 + i * 47,
}));
Object.assign(app, {
  page: new URLSearchParams(location.search).get('page') === 'proxies' ? 'proxies' : 'dashboard',
  version: 'fixture',
  status: { engine: { state: 'running' }, currentNode: nodes[1].name, mode: 'rule', routeMode: 'systemProxy' },
  groups: [
    { name: 'Proxy', kind: 'Selector', selectable: true, now: nodes[1].name, nodes },
    { name: 'Streaming', kind: 'Selector', selectable: true, now: nodes[4].name, nodes: nodes.slice(3, 14) },
    { name: 'Automatic', kind: 'URLTest', selectable: true, now: nodes[2].name, nodes: nodes.slice(0, 8) },
  ],
  profiles: [{ id: 'fixture', name: 'Example subscription', kind: 'subscription', selected: true, updatedAt: Date.now() / 1000, usage: { upload: 5e9, download: 25e9, total: 100e9 } }],
  connectedAt: Date.now() - 125000,
  traffic: { up: 256000, down: 12400000 },
  history: Array.from({ length: 60 }, (_, i) => ({ up: 180000 + i * 1200, down: 7e6 + Math.sin(i / 4) * 4e6 })),
  memory: 64e6,
  totals: { uploadTotal: 5e9, downloadTotal: 25e9, items: Array.from({ length: 23 }) },
  requestCount: 426,
  lan: { ip: '192.0.2.10', interface: 'Ethernet' },
  exitIp: { ip: '203.0.113.7', country: 'Japan' },
});

mockWindows('main');
mockIPC(async (command, args) => {
  if (command === 'app_settings') return structuredClone(stored);
  if (command === 'set_app_settings') {
    await pause(180);
    stored = structuredClone(args.settings);
    localStorage.setItem(key, JSON.stringify(stored));
    return;
  }
  if (command === 'test_delay') {
    await pause(1500);
    const group = app.groups.find((group) => group.name === args.group);
    return { ...group, nodes: group.nodes.map((node, i) => ({ ...node, delay: i === 5 ? 0 : 45 + i * 31 })) };
  }
  if (command === 'test_node_delay') { await pause(1200); return 68; }
  if (command === 'select_node') {
    app.groups = app.groups.map((group) => group.name === args.group ? { ...group, now: args.node } : group);
    app.status.currentNode = args.node;
    return;
  }
  if (command === 'set_mode') { app.status.mode = args.mode; return; }
  if (command === 'set_route_mode') { app.status.routeMode = args.routeMode; return; }
  if (command === 'set_whitelist_enabled') { app.whitelist.enabled = args.enabled; return; }
  if (command === 'exit_ip') return { ip: '203.0.113.7', country: 'Japan' };
  if (command === 'start' || command === 'stop') {
    app.status.engine.state = command === 'start' ? 'running' : 'stopped';
    return;
  }
  if (command === 'plugin:window|is_maximized') return false;
  if (command.startsWith('plugin:')) return null;
  throw new Error(`The UI fixture does not implement ${command}`);
}, { shouldMockEvents: true });

await loadSettings();
setLanguage(settings.value.language ?? 'en');
watchAppearance();
mount(App, { target: document.getElementById('app') });
window.fixture = { app, settings, storageKey: key };
