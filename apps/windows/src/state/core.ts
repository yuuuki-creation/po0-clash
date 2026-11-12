import { proxy } from 'valtio';
import { invoke, listen } from '../ipc';
import { setLanguage, t } from '../lib/i18n.js';

export type PageId = 'home' | 'proxies' | 'profiles' | 'connections' | 'rules' | 'logs' | 'whitelist' | 'settings';

const PAGES: PageId[] = ['home', 'proxies', 'profiles', 'connections', 'rules', 'logs', 'whitelist', 'settings'];
// The macOS shell still names pages as its launch arguments always have.
const LEGACY_PAGES: Record<string, PageId> = { dashboard: 'home', activity: 'connections', tools: 'settings' };

export const app = proxy({
  version: '',
  language: 'en',
  page: 'home' as PageId,
  status: null as any,
  connectedAt: null as number | null,
  profiles: [] as any[],
  groups: [] as any[],
  whitelist: { enabled: false, entries: [] as any[] },
  traffic: { up: 0, down: 0 },
  history: [] as { up: number; down: number }[],
  memory: 0,
  totals: null as any,
  requestCount: 0,
  lan: null as any,
  exitIp: null as any,
  exitIpLoading: false,
  busy: {} as Record<string, boolean>,
  notices: [] as { id: number; kind: 'error' | 'info' | 'success'; title: string; detail: string }[],
});

/** `t()` reads a module-level table, so a language change re-keys the tree (see main.tsx) to redraw every string. */
export function applyLanguage(code: string) {
  setLanguage(code);
  app.language = code;
}

let noticeId = 0;

export function notify(title: unknown, detail = '', kind: 'error' | 'info' | 'success' = 'error') {
  app.notices.push({ id: ++noticeId, kind, title: String(title), detail });
}

export const dismissNotice = (id: number) => {
  app.notices = app.notices.filter((notice) => notice.id !== id);
};

export async function act<T = any>(key: string, command: string, args?: Record<string, unknown>): Promise<T | undefined> {
  app.busy[key] = true;
  try {
    return await invoke<T>(command, args);
  } catch (e) {
    notify(e);
    return undefined;
  } finally {
    delete app.busy[key];
  }
}

// The groups the core reports after a test come back without delays, so the last results are kept here.
const delays = new Map<string, number>();

const withDelays = (group: any) => ({
  ...group,
  nodes: group.nodes.map((node: any) => ({ ...node, delay: delays.get(node.name) ?? node.delay ?? null })),
});

/** A group listed as a node has no delay of its own, so it shows the delay of the node it currently routes to. */
export function resolvedDelay(node: { name: string; delay?: number | null }, groups: readonly any[] = app.groups) {
  let { name, delay } = node;
  const seen = new Set<string>();
  while (delay == null && !seen.has(name)) {
    seen.add(name);
    const group = groups.find((g) => g.name === name);
    if (!group?.now) break;
    name = group.now;
    delay = group.nodes.find((n: any) => n.name === name)?.delay;
  }
  return delay ?? null;
}

export const rankDelay = (delay: number | null) => (delay ? delay : delay === 0 ? 1e9 : 1e8);

export const isTestingNode = (name: string, busy: Record<string, boolean> = app.busy, groups: readonly any[] = app.groups) =>
  !!busy[`node:${name}`] ||
  groups.some((group) => busy[`delay:${group.name}`] && group.nodes.some((node: any) => node.name === name));

export async function testDelay(name: string) {
  const nodes = app.groups.find((group) => group.name === name)?.nodes ?? [];
  if (app.busy[`delay:${name}`] || nodes.some((node: any) => app.busy[`node:${node.name}`])) return;
  const group = await act(`delay:${name}`, 'test_delay', { group: name });
  if (!group) return;
  for (const node of group.nodes) {
    if (node.delay != null) delays.set(node.name, node.delay);
  }
  app.groups = app.groups.map((g) => (g.name === name ? withDelays(group) : withDelays(g)));
}

export async function testNode(name: string) {
  if (isTestingNode(name)) return;
  const delay = await act<number>(`node:${name}`, 'test_node_delay', { node: name });
  if (delay === undefined) return;
  delays.set(name, delay);
  app.groups = app.groups.map(withDelays);
}

async function loadGroups() {
  if (app.status?.engine.state !== 'running') {
    delays.clear();
    app.groups = [];
    return;
  }
  app.groups = (await invoke<any[]>('groups')).map(withDelays);
}

const loaders = {
  status: async () => (app.status = await invoke('status')),
  profiles: async () => (app.profiles = await invoke('profiles')),
  groups: loadGroups,
  whitelist: async () => (app.whitelist = await invoke('whitelist')),
};

export async function refresh(kind: keyof typeof loaders) {
  try {
    await loaders[kind]();
  } catch (e) {
    notify(e);
  }
}

let exitIpRequest = 0;

// Right after a start the engine may still be loading its nodes, so a failed lookup is retried a few times.
export async function refreshExitIp(attempt = 0) {
  const request = ++exitIpRequest;
  app.exitIpLoading = true;
  let result = null;
  try {
    result = await invoke('exit_ip');
  } catch {
    result = null;
  }
  if (request !== exitIpRequest) return;
  app.exitIp = result;
  app.exitIpLoading = false;
  if (!result && attempt < 3 && app.status?.engine.state === 'running') {
    setTimeout(() => request === exitIpRequest && refreshExitIp(attempt + 1), 3000);
  }
}

let routeKey = '';

async function refreshStatus() {
  await refresh('status');
  const s = app.status;
  if (!s) return;
  const engine = s.engine.state;
  if (engine !== 'running') app.connectedAt = null;
  else app.connectedAt ??= Date.now();
  const key = [engine, s.currentNode, s.mode, s.profileId].join('|');
  if (key === routeKey) return;
  const engineChanged = routeKey.split('|')[0] !== engine;
  routeKey = key;
  if (engineChanged) refresh('groups');
  if (engine === 'running' || engine === 'stopped') refreshExitIp();
}

const idle = { traffic: { up: 0, down: 0 }, history: [], memory: 0, totals: null, requestCount: 0 };
let ticks = 0;

async function poll() {
  const tick = ticks++;
  if (tick % 10 === 0) {
    invoke('intranet_ip').then(
      (lan) => (app.lan = lan),
      () => (app.lan = null),
    );
  }
  if (document.hidden || app.status?.engine.state !== 'running') {
    if (app.history.length || app.totals) Object.assign(app, idle);
    return;
  }
  try {
    const [history, memory] = await Promise.all([invoke<any[]>('traffic_history'), invoke<number>('memory')]);
    Object.assign(app, { history, memory, traffic: history.at(-1) ?? { up: 0, down: 0 } });
    if (tick % 2 === 0) {
      const [connections, requests] = await Promise.all([invoke<any>('connections'), invoke<any[]>('requests')]);
      Object.assign(app, { totals: connections, requestCount: requests.length });
    }
  } catch {
    Object.assign(app, { traffic: { up: 0, down: 0 }, history: [], memory: 0 });
  }
}

function explainLaunch(notice: any) {
  if (!notice) return;
  if (notice.cleared && notice.profileName) {
    const profile = app.profiles.find((p) => p.name === notice.profileName);
    const name = profile?.kind === 'links' ? t('profiles.links') : notice.profileName;
    notify(t('launch.crashed'), t('launch.cleared', { name }), 'info');
  } else {
    notify(t('launch.unfinished'), t('launch.skipped'), 'info');
  }
}

export const isRunning = (status: any) => status?.engine.state === 'running';

export async function toggleEngine() {
  const state = app.status?.engine.state;
  if (state === 'starting') return;
  await act('engine', state === 'running' ? 'stop' : 'start');
}

export const setMode = (mode: string) => act('mode', 'set_mode', { mode });
export const setRouteMode = (routeMode: string) => act('route', 'set_route_mode', { routeMode });

export async function toggleRoute(routeMode: string, enabled: boolean) {
  if (app.busy.route || app.busy.engine) return;
  app.busy.route = true;
  try {
    if (!enabled) {
      if (isRunning(app.status) && app.status.routeMode === routeMode) await toggleEngine();
      return;
    }
    await invoke('set_route_mode', { routeMode });
    await refreshStatus();
    if (app.status?.routeMode === routeMode && !isRunning(app.status)) await toggleEngine();
  } catch (error) {
    notify(error);
  } finally {
    delete app.busy.route;
  }
}

export async function init() {
  await listen('core-change', ({ payload }) => {
    if (payload === 'status') return refreshStatus();
    refresh(payload);
    if (payload === 'groups') refreshStatus();
    if (payload === 'profiles') refresh('groups');
  });
  await listen('shell-error', ({ payload }) => notify(payload));
  await listen('navigate', ({ payload }) => {
    const page = LEGACY_PAGES[payload] ?? payload;
    if (PAGES.includes(page)) app.page = page;
  });
  await Promise.all([refreshStatus(), refresh('profiles'), refresh('whitelist')]);
  explainLaunch(await invoke('launch_notice'));
  poll();
  setInterval(poll, 1000);
}
